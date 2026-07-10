Set-StrictMode -Version Latest

Describe 'QPC anomaly diagnostic' {
    It 'measures QueryPerformanceCounter against an independent timer clock across sleep durations' {
        $src = @'
// QpcAnomalyRepro
// -----------------------------------------------------------------------------
// Standalone, framework-agnostic repro for a per-call QueryPerformanceCounter
// (QPC / Stopwatch) under-measurement seen on some virtualized Windows hosts.
//
// It brackets a real Thread.Sleep(D) with TWO INDEPENDENT clocks:
//
//   * QPC          - QueryPerformanceCounter (raw P/Invoke on Windows, the same
//                    source System.Diagnostics.Stopwatch uses). This is the
//                    suspected-buggy clock.
//   * Independent  - timeGetTime (Windows, ~1ms with timeBeginPeriod(1)) /
//                    Environment.TickCount (other). Driven by the periodic
//                    system timer interrupt, NOT by TSC/QPC, so it is an
//                    independent witness that real time actually elapsed. Its
//                    ~1ms quantization is far smaller than the multi-ms QPC
//                    under-measurement it exposes.
//
// If a single bracketed measurement reports QPC < 1 ms while the independent
// tick counter confirms the full sleep elapsed, the sleep did NOT return early:
// QPC under-measured a real interval. That is the bug, and it is what makes a
// "measured time" occasionally read ~0 on CI.
//
// The program also sweeps several sleep durations so you can see whether a
// longer duration is "safe" (i.e. how low the measured value can drop for a
// real 10 / 20 / 50 / 100 / 200 ms interval) and what the worst downward error
// is. That answers "what is the shortest duration users can rely on?".
//
// Build (portable):   dotnet run -c Release -- [options]
// Windows PS 5.1:      see Run-Repro.ps1 (compiles this with Add-Type on .NET FW)
//
// Options (all optional):
//   --durations 10,20,50,100,200   sleep targets in ms (csv)
//   --iters 3000                   max iterations per duration
//   --budget-ms 20000              wall-time cap per duration (ms)
//   --load 0                       background CPU-spinner threads (raise to
//                                  increase core migration / repro rate)
//   --sub-ms 1.0                   threshold (ms) below which a measurement is
//                                  considered "impossibly fast"
// -----------------------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Threading;

public static class QpcAnomalyRepro
{
    [DllImport("kernel32.dll")] private static extern ulong GetTickCount64();
    [DllImport("kernel32.dll")] private static extern uint GetCurrentProcessorNumber();
    [DllImport("kernel32.dll")] private static extern bool QueryPerformanceCounter(out long value);
    [DllImport("kernel32.dll")] private static extern bool QueryPerformanceFrequency(out long value);
    [DllImport("winmm.dll")] private static extern uint timeGetTime();
    [DllImport("winmm.dll")] private static extern uint timeBeginPeriod(uint period);
    [DllImport("winmm.dll")] private static extern uint timeEndPeriod(uint period);

    private static bool _isWindows;
    private static long _qpcFreq;
    private static volatile bool _stopLoad;

    public static int Main(string[] args)
    {
        _isWindows = Environment.OSVersion.Platform == PlatformID.Win32NT;

        int[] durations = new int[] { 10, 20, 50, 100, 200 };
        int maxIters = 3000;
        int budgetMs = 20000;
        int loadThreads = 0;
        double subMs = 1.0;

        for (int i = 0; i < args.Length - 1; i++)
        {
            string a = args[i];
            string v = args[i + 1];
            if (a == "--durations") durations = ParseInts(v);
            else if (a == "--iters") maxIters = int.Parse(v, CultureInfo.InvariantCulture);
            else if (a == "--budget-ms") budgetMs = int.Parse(v, CultureInfo.InvariantCulture);
            else if (a == "--load") loadThreads = int.Parse(v, CultureInfo.InvariantCulture);
            else if (a == "--sub-ms") subMs = double.Parse(v, CultureInfo.InvariantCulture);
        }

        if (_isWindows)
        {
            timeBeginPeriod(1);
            long f;
            _qpcFreq = QueryPerformanceFrequency(out f) ? f : Stopwatch.Frequency;
        }
        else
        {
            _qpcFreq = Stopwatch.Frequency;
        }

        Line("ENV os=" + Environment.OSVersion +
             " bits=" + (IntPtr.Size * 8) +
             " clr=" + Environment.Version +
             " cpus=" + Environment.ProcessorCount +
             " qpcFreq=" + _qpcFreq +
             " swFreq=" + Stopwatch.Frequency +
             " swHighRes=" + Stopwatch.IsHighResolution +
             " load=" + loadThreads);

        List<Thread> load = StartLoad(loadThreads);

        double worstDownErr = 0.0;
        double lowestMeasuredEver = double.MaxValue;
        int totalAnomalies = 0;

        try
        {
            foreach (int d in durations)
            {
                Result r = RunDuration(d, maxIters, budgetMs, subMs);
                Line(r.Summary());
                for (int k = 0; k < r.Examples.Count && k < 5; k++) Line(r.Examples[k]);
                if (r.MaxDownErr > worstDownErr) worstDownErr = r.MaxDownErr;
                if (r.MinMeasured < lowestMeasuredEver) lowestMeasuredEver = r.MinMeasured;
                totalAnomalies += r.Anomalies;
            }
        }
        finally
        {
            _stopLoad = true;
            foreach (Thread t in load) t.Join();
            if (_isWindows) timeEndPeriod(1);
        }

        Line("RELIABILITY totalAnomalies=" + totalAnomalies +
             " lowestMeasuredMs=" + F(lowestMeasuredEver) +
             " worstDownErrMs=" + F(worstDownErr));
        Line("RELIABILITY note: measured time can drop to ~" + F(lowestMeasuredEver) +
             " ms regardless of the real duration; keep assertion thresholds at least ~" +
             F(Math.Ceiling(worstDownErr)) + " ms away from the real run time (a safe rule is a floor/ceiling far from it).");
        return 0;
    }

    private static Result RunDuration(int d, int maxIters, int budgetMs, double subMs)
    {
        Result r = new Result();
        r.Duration = d;
        r.SubMs = subMs;
        List<double> qpcSamples = new List<double>(maxIters);

        Stopwatch budget = Stopwatch.StartNew();
        int i = 0;
        for (; i < maxIters; i++)
        {
            if (budget.ElapsedMilliseconds > budgetMs) break;

            uint proc0 = CurrentProcessor();
            long q0 = ReadQpc();
            ulong t0 = ReadTick();

            Thread.Sleep(d);

            ulong t1 = ReadTick();
            long q1 = ReadQpc();
            uint proc1 = CurrentProcessor();

            long qpcDelta = q1 - q0;
            double qpcMs = qpcDelta * 1000.0 / _qpcFreq;
            double tickMs = (double)(t1 - t0);

            qpcSamples.Add(qpcMs);
            if (qpcMs < r.MinMeasured) r.MinMeasured = qpcMs;
            if (tickMs < r.MinTick) r.MinTick = tickMs;
            if (qpcDelta <= 0) r.NegOrZeroQpc++;
            if (qpcMs < subMs) r.SubMsCount++;

            double downErr = tickMs - qpcMs;
            if (downErr > r.MaxDownErr) r.MaxDownErr = downErr;

            // Anomaly: independent tick clock confirms real time elapsed
            // (>= half the requested sleep) but QPC reported < subMs.
            bool realTimeElapsed = tickMs >= Math.Max(2.0, d * 0.5);
            if (realTimeElapsed && qpcMs < subMs)
            {
                r.Anomalies++;
                if (proc0 != proc1) r.MigratedAnomalies++;
                if (r.Examples.Count < 5)
                {
                    r.Examples.Add("ANOMALY dur=" + d + " i=" + i +
                                   " qpcMs=" + F(qpcMs) + " tickMs=" + F(tickMs) +
                                   " qpcDeltaTicks=" + qpcDelta +
                                   " proc " + ProcStr(proc0) + "->" + ProcStr(proc1));
                }
            }
        }
        r.Iterations = i;
        qpcSamples.Sort();
        r.QpcP50 = Percentile(qpcSamples, 0.50);
        r.QpcP01 = Percentile(qpcSamples, 0.01);
        r.QpcMax = qpcSamples.Count > 0 ? qpcSamples[qpcSamples.Count - 1] : 0.0;
        return r;
    }

    private sealed class Result
    {
        public int Duration;
        public int Iterations;
        public double SubMs;
        public double MinMeasured = double.MaxValue;
        public double MinTick = double.MaxValue;
        public double MaxDownErr;
        public double QpcP50;
        public double QpcP01;
        public double QpcMax;
        public int SubMsCount;
        public int Anomalies;
        public int MigratedAnomalies;
        public int NegOrZeroQpc;
        public List<string> Examples = new List<string>();

        public string Summary()
        {
            double rate = Iterations > 0 ? (100.0 * Anomalies / Iterations) : 0.0;
            return "SWEEP dur=" + Duration +
                   " n=" + Iterations +
                   " qpcP50=" + F(QpcP50) +
                   " qpcP01=" + F(QpcP01) +
                   " qpcMin=" + F(MinMeasured) +
                   " qpcMax=" + F(QpcMax) +
                   " tickMin=" + F(MinTick) +
                   " subMs(<" + F(SubMs) + ")=" + SubMsCount +
                   " anomalies=" + Anomalies + " (" + F(rate) + "%)" +
                   " migAnom=" + MigratedAnomalies +
                   " negQpc=" + NegOrZeroQpc +
                   " maxDownErrMs=" + F(MaxDownErr);
        }
    }

    private static long ReadQpc()
    {
        if (_isWindows)
        {
            long v;
            QueryPerformanceCounter(out v);
            return v;
        }
        return Stopwatch.GetTimestamp();
    }

    private static ulong ReadTick()
    {
        if (_isWindows) return timeGetTime();
        return (ulong)(uint)Environment.TickCount;
    }

    private static uint CurrentProcessor()
    {
        if (_isWindows) return GetCurrentProcessorNumber();
        return uint.MaxValue;
    }

    private static string ProcStr(uint p)
    {
        return p == uint.MaxValue ? "?" : p.ToString(CultureInfo.InvariantCulture);
    }

    private static List<Thread> StartLoad(int n)
    {
        List<Thread> threads = new List<Thread>();
        for (int i = 0; i < n; i++)
        {
            Thread t = new Thread(Spin);
            t.IsBackground = true;
            t.Start();
            threads.Add(t);
        }
        return threads;
    }

    private static void Spin()
    {
        double x = 0.0;
        while (!_stopLoad)
        {
            for (int i = 0; i < 100000; i++) x += i * 0.5;
            if (x < 0) Console.Write("");
        }
    }

    private static int[] ParseInts(string csv)
    {
        string[] parts = csv.Split(',');
        List<int> list = new List<int>();
        foreach (string p in parts)
        {
            string s = p.Trim();
            if (s.Length > 0) list.Add(int.Parse(s, CultureInfo.InvariantCulture));
        }
        return list.ToArray();
    }

    private static double Percentile(List<double> sorted, double q)
    {
        if (sorted.Count == 0) return 0.0;
        int idx = (int)Math.Floor(q * (sorted.Count - 1));
        if (idx < 0) idx = 0;
        if (idx >= sorted.Count) idx = sorted.Count - 1;
        return sorted[idx];
    }

    private static string F(double d)
    {
        return d.ToString("0.###", CultureInfo.InvariantCulture);
    }

    private static void Line(string s)
    {
        Console.WriteLine("QPCDIAG:: " + s);
    }
}
'@
        if (-not ('QpcAnomalyRepro' -as [type])) {
            Add-Type -TypeDefinition $src -Language CSharp -ErrorAction Stop | Out-Null
        }
        try { Write-Host ("QPCDIAG:: HOST psVersion=" + $PSVersionTable.PSVersion.ToString() + " psEdition=" + $PSVersionTable.PSEdition) } catch { }
        try { Write-Host ("QPCDIAG:: HOST framework=" + [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription) } catch { Write-Host "QPCDIAG:: HOST framework=unknown" }
        # No background load: a lone Start-Sleep(10) really takes ~10-16ms, the danger zone where a
        # bounded QPC under-measurement can drop the measured value below a small threshold.
        $argv = [string[]]@('--durations','10,15,20,30,50,100','--iters','100000','--budget-ms','30000','--load','0','--sub-ms','1.0')
        [QpcAnomalyRepro]::Main($argv) | Out-Null
        $true | Should -Be $true
    }
}
