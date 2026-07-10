# CI diagnostic for the Should-BeFasterThan flake. Prints SLEEPDIAG:: lines harvested from logs.
# Discriminates: interrupt (marker missing / exception) vs QPC short-read (Stopwatch<1ms but an
# independent non-QPC clock says ~10ms). Never fails the build (exit 0).
$ErrorActionPreference = 'Stop'
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture
Import-Module ./bin/Pester.psd1 -Force

$psver = $PSVersionTable.PSVersion.ToString()
$isWin = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
$os    = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription.Trim()
$freq  = [System.Diagnostics.Stopwatch]::Frequency
"SLEEPDIAG:: START ps=$psver os=$os stopwatchFrequency=$freq isWindows=$isWin"

# Independent, non-QPC clock: winmm timeGetTime (~1ms with timeBeginPeriod). Windows only.
$haveWinmm = $false
if ($isWin) {
    try {
        Add-Type -Namespace Native -Name Winmm -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("winmm.dll", EntryPoint="timeGetTime")]
public static extern uint TimeGetTime();
[System.Runtime.InteropServices.DllImport("winmm.dll", EntryPoint="timeBeginPeriod")]
public static extern uint TimeBeginPeriod(uint uPeriod);
[System.Runtime.InteropServices.DllImport("winmm.dll", EntryPoint="timeEndPeriod")]
public static extern uint TimeEndPeriod(uint uPeriod);
'@
        [void][Native.Winmm]::TimeBeginPeriod(1)
        $haveWinmm = $true
    } catch { "SLEEPDIAG:: WARN winmm unavailable: $($_.Exception.Message)" }
}
"SLEEPDIAG:: winmm=$haveWinmm"

# Part 1 - sanity: the Select-First (absorbed) interrupt really is silent & <1ms.
$mmin=[double]::MaxValue;$mmax=0.0;$mexc=0
foreach($i in 1..20){
  $sw=[System.Diagnostics.Stopwatch]::StartNew()
  try{ & {'x';Start-Sleep -Milliseconds 10;'y'} | Select-Object -First 1 | Out-Null }catch{$mexc++}
  $sw.Stop();$e=$sw.Elapsed.TotalMilliseconds
  if($e -lt $mmin){$mmin=$e};if($e -gt $mmax){$mmax=$e}
}
"SLEEPDIAG:: MECH selectFirst_min_ms=$([math]::Round($mmin,3)) max_ms=$([math]::Round($mmax,3)) exceptions=$mexc"

# Part 2 - discriminating hammer: replicate EXACTLY the production measurement
# ($sw=StartNew; & $Actual; $sw.Stop) and bracket it with the independent clock + a marker.
$marker = @{ Ran = $false }
$sb = { Start-Sleep -Milliseconds 10; $marker.Ran = $true }

$deadline=[DateTime]::UtcNow.AddSeconds(120)
$n=0; $under1=0; $exc=0; $qpcMin=[double]::MaxValue
$anom = [System.Collections.Generic.List[string]]::new()
while([DateTime]::UtcNow -lt $deadline){
  $n++; $marker.Ran=$false
  $mm0 = if($haveWinmm){[Native.Winmm]::TimeGetTime()}else{[uint32]0}
  $u0  = [DateTime]::UtcNow
  $sw=[System.Diagnostics.Stopwatch]::StartNew()
  $threw=$null
  try{ & $sb }catch{ $threw=$_.Exception.GetType().Name }
  $sw.Stop()
  $u1  = [DateTime]::UtcNow
  $mm1 = if($haveWinmm){[Native.Winmm]::TimeGetTime()}else{[uint32]0}
  $qpcMs=$sw.Elapsed.TotalMilliseconds
  $mmMs =[double]([int64]$mm1 - [int64]$mm0)
  $dtMs =($u1-$u0).TotalMilliseconds
  if($qpcMs -lt $qpcMin){$qpcMin=$qpcMs}
  if($threw){ $exc++; if($anom.Count -lt 25){$anom.Add("EXC iter=$n type=$threw qpcMs=$([math]::Round($qpcMs,3)) winmmMs=$mmMs dtMs=$([math]::Round($dtMs,3)) markerRan=$($marker.Ran)")}; continue }
  if($qpcMs -lt 1.0){ $under1++; if($anom.Count -lt 25){$anom.Add("UNDER1 iter=$n qpcMs=$([math]::Round($qpcMs,4)) winmmMs=$mmMs dtMs=$([math]::Round($dtMs,4)) markerRan=$($marker.Ran)")} }
}
"SLEEPDIAG:: HAMMER n=$n under1ms=$under1 exceptions=$exc qpcMin_ms=$([math]::Round($qpcMin,4))"
foreach($a in $anom){ "SLEEPDIAG:: ANOM $a" }

# Part 3 - cross-check through the REAL exported assertion (un-injected).
$deadline2=[DateTime]::UtcNow.AddSeconds(30)
$rn=0;$rmis=0; $rsb={ Start-Sleep -Milliseconds 10 }
while([DateTime]::UtcNow -lt $deadline2){
  $rn++; $t=$false
  try{ $rsb | Should-BeFasterThan -Expected 1ms }catch{$t=$true}
  if(-not $t){$rmis++}
}
"SLEEPDIAG:: REALASSERT n=$rn misfires=$rmis (expect 0)"

if($haveWinmm){ [void][Native.Winmm]::TimeEndPeriod(1) }
"SLEEPDIAG:: DONE ps=$psver os=$os"
exit 0
