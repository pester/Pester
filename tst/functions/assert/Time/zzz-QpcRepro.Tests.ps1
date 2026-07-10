Set-StrictMode -Version Latest

Describe 'Sleep timing diagnostic (high power, default timer)' {
    It 'hammers Start-Sleep 10ms vs Thread.Sleep 10ms with QPC vs an independent tick clock' {
        $helper = @'
using System;
using System.Runtime.InteropServices;

public static class Clock2
{
    private static readonly bool Win = Environment.OSVersion.Platform == PlatformID.Win32NT;

    [DllImport("kernel32.dll")] private static extern bool QueryPerformanceCounter(out long v);
    [DllImport("kernel32.dll")] private static extern bool QueryPerformanceFrequency(out long v);
    [DllImport("kernel32.dll")] private static extern ulong GetTickCount64();

    public static long Qpc()
    {
        if (Win) { long v; QueryPerformanceCounter(out v); return v; }
        return System.Diagnostics.Stopwatch.GetTimestamp();
    }
    public static long Freq()
    {
        if (Win) { long v; QueryPerformanceFrequency(out v); return v; }
        return System.Diagnostics.Stopwatch.Frequency;
    }
    // Independent of QPC/TSC: system tick counter (~15.6ms granularity). Coarse, but it
    // cannot manufacture a sub-1ms QPC reading, so it is a valid witness for the specific
    // "QPC says <1ms while real time was a full ~15ms tick" anomaly we are hunting.
    public static long Tick()
    {
        if (Win) return (long)GetTickCount64();
        return (long)(uint)Environment.TickCount;
    }
}
'@
        if (-not ('Clock2' -as [type])) { Add-Type -TypeDefinition $helper -Language CSharp -ErrorAction Stop | Out-Null }

        try { Write-Host ("QPCDIAG:: HOST psVersion=" + $PSVersionTable.PSVersion.ToString() + " psEdition=" + $PSVersionTable.PSEdition) } catch { }
        try { Write-Host ("QPCDIAG:: HOST framework=" + [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription) } catch { Write-Host "QPCDIAG:: HOST framework=unknown" }
        # NOTE: deliberately NOT calling timeBeginPeriod, to match the real Pester run where the
        # timer resolution is the default ~15.6ms and Start-Sleep -Milliseconds 10 takes ~15.6ms.
        $freq = [Clock2]::Freq()
        Write-Host ("QPCDIAG:: ENV qpcFreq=" + $freq + " cpus=" + [Environment]::ProcessorCount)

        $budgetMs = 80000
        $maxIters = 500000

        function Measure-Op {
            param($Label, $D, $Invoke)
            $subMs = 0; $early = 0; $glitch = 0
            $minSw = [double]::MaxValue
            $lt5 = 0; $lt10 = 0
            $n = 0
            $budget = [System.Diagnostics.Stopwatch]::StartNew()
            while ($n -lt $maxIters -and $budget.ElapsedMilliseconds -lt $budgetMs) {
                $q0 = [Clock2]::Qpc(); $k0 = [Clock2]::Tick()
                & $Invoke
                $k1 = [Clock2]::Tick(); $q1 = [Clock2]::Qpc()
                $swMs = ($q1 - $q0) * 1000.0 / $freq
                $tickMs = [double]($k1 - $k0)
                if ($swMs -lt $minSw) { $minSw = $swMs }
                if ($swMs -lt 5.0) { $lt5++ }
                if ($swMs -lt 10.0) { $lt10++ }
                if ($swMs -lt 1.0) {
                    $subMs++
                    if ($tickMs -lt 8.0) { $early++ } else { $glitch++ }
                    if (($subMs -le 8)) {
                        Write-Host ("QPCDIAG:: HIT {0} dur={1} i={2} swMs={3} tickMs={4}" -f $Label, $D, $n, [math]::Round($swMs,4), $tickMs)
                    }
                }
                $n++
            }
            Write-Host ("QPCDIAG:: {0} dur={1} n={2} swMin={3} lt5={4} lt10={5} subMs(<1)={6} earlyReturn={7} qpcGlitch={8}" -f `
                $Label, $D, $n, [math]::Round($minSw, 4), $lt5, $lt10, $subMs, $early, $glitch)
        }

        $ssb = [scriptblock]::Create("Start-Sleep -Milliseconds 10")
        $tsb = [scriptblock]::Create("[System.Threading.Thread]::Sleep(10)")
        Measure-Op -Label 'STARTSLEEP' -D 10 -Invoke $ssb
        Measure-Op -Label 'THREADSLEEP' -D 10 -Invoke $tsb

        $true | Should -Be $true
    }
}
