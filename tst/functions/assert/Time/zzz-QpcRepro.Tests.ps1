Set-StrictMode -Version Latest

Describe 'Sleep timing diagnostic' {
    It 'compares Start-Sleep vs Thread.Sleep measured by QPC against an independent timer clock' {
        $helper = @'
using System;
using System.Runtime.InteropServices;

public static class Clock
{
    private static readonly bool Win = Environment.OSVersion.Platform == PlatformID.Win32NT;

    [DllImport("kernel32.dll")] private static extern bool QueryPerformanceCounter(out long v);
    [DllImport("kernel32.dll")] private static extern bool QueryPerformanceFrequency(out long v);
    [DllImport("winmm.dll")] private static extern uint timeGetTime();
    [DllImport("winmm.dll")] private static extern uint timeBeginPeriod(uint p);
    [DllImport("winmm.dll")] private static extern uint timeEndPeriod(uint p);

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
    public static long Indep()
    {
        if (Win) return timeGetTime();
        return (long)(uint)Environment.TickCount;
    }
    public static void BeginPeriod() { if (Win) timeBeginPeriod(1); }
    public static void EndPeriod() { if (Win) timeEndPeriod(1); }
}
'@
        if (-not ('Clock' -as [type])) { Add-Type -TypeDefinition $helper -Language CSharp -ErrorAction Stop | Out-Null }

        try { Write-Host ("QPCDIAG:: HOST psVersion=" + $PSVersionTable.PSVersion.ToString() + " psEdition=" + $PSVersionTable.PSEdition) } catch { }
        try { Write-Host ("QPCDIAG:: HOST framework=" + [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription) } catch { Write-Host "QPCDIAG:: HOST framework=unknown" }

        [Clock]::BeginPeriod()
        $freq = [Clock]::Freq()
        Write-Host ("QPCDIAG:: ENV qpcFreq=" + $freq + " cpus=" + [Environment]::ProcessorCount)

        $durations = 10, 15, 20, 30, 50, 100
        $budgetMs  = 20000
        $maxIters  = 100000

        function Measure-Op {
            param($Label, $D, $Invoke)
            $subMs = 0; $early = 0; $glitch = 0
            $minSw = [double]::MaxValue; $minIndep = [double]::MaxValue
            $n = 0
            $budget = [System.Diagnostics.Stopwatch]::StartNew()
            while ($n -lt $maxIters -and $budget.ElapsedMilliseconds -lt $budgetMs) {
                $q0 = [Clock]::Qpc(); $t0 = [Clock]::Indep()
                & $Invoke
                $t1 = [Clock]::Indep(); $q1 = [Clock]::Qpc()
                $swMs = ($q1 - $q0) * 1000.0 / $freq
                $indepMs = [double]($t1 - $t0)
                if ($swMs -lt $minSw) { $minSw = $swMs }
                if ($indepMs -lt $minIndep) { $minIndep = $indepMs }
                if ($swMs -lt 1.0) {
                    $subMs++
                    if ($indepMs -lt 2.0) { $early++ }
                    elseif ($indepMs -ge ($D / 2.0)) { $glitch++ }
                }
                $n++
            }
            Write-Host ("QPCDIAG:: {0} dur={1} n={2} swMin={3} indepMin={4} subMs(<1)={5} earlyReturn={6} qpcGlitch={7}" -f `
                $Label, $D, $n, [math]::Round($minSw, 3), $minIndep, $subMs, $early, $glitch)
        }

        foreach ($d in $durations) {
            $ssb = [scriptblock]::Create("Start-Sleep -Milliseconds $d")
            $tsb = [scriptblock]::Create("[System.Threading.Thread]::Sleep($d)")
            Measure-Op -Label 'STARTSLEEP' -D $d -Invoke $ssb
            Measure-Op -Label 'THREADSLEEP' -D $d -Invoke $tsb
        }

        [Clock]::EndPeriod()
        $true | Should -Be $true
    }
}
