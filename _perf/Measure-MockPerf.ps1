#Requires -Version 5.1
<#
    .SYNOPSIS
        Self-contained mock-performance benchmark used to compare the mock hot path
        across configurations and PowerShell versions (Windows PowerShell 5.1 vs 7).

        It generates a mock-saturated workload (each It defines a Mock, invokes it and
        verifies with Should -Invoke), imports the locally built Pester, warms up, then
        times N runs and reports median/min. It throws if any test fails, so an invalid
        workload can never be reported as "fast".

        This is a temporary tool that lives outside ./src so the build analyzer does not
        apply to it.
#>
param(
    [int] $Runs = 7,
    [int] $Describes = 80,
    [int] $ItsPerContext = 12,
    [string] $WorkloadPath = (Join-Path $PSScriptRoot 'Generated.Mock.Tests.ps1'),
    [string] $Label = ''
)

$ErrorActionPreference = 'Stop'

# 1. Generate the mock-heavy workload if it is not already present (so every config
#    in a run measures the exact same file).
if (-not (Test-Path -LiteralPath $WorkloadPath)) {
    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine(@'
BeforeAll {
    function Get-Thing { param([string] $Name, [int] $Count = 1) "real:$Name" }
    function Set-Thing { param([string] $Name, $Value) }
}
'@)
    for ($d = 1; $d -le $Describes; $d++) {
        $null = $sb.AppendLine("Describe 'Describe $d' {")
        for ($i = 1; $i -le $ItsPerContext; $i++) {
            if ($i % 3 -eq 0) {
                $null = $sb.AppendLine("    It 'mock filtered $i' {")
                $null = $sb.AppendLine("        Mock Get-Thing { 'mocked' } -ParameterFilter { `$Name -eq 'x' }")
                $null = $sb.AppendLine("        Get-Thing -Name 'x' -Count 2")
                $null = $sb.AppendLine("        Should -Invoke Get-Thing -Times 1 -Exactly -ParameterFilter { `$Name -eq 'x' }")
                $null = $sb.AppendLine("    }")
            }
            elseif ($i % 3 -eq 1) {
                $null = $sb.AppendLine("    It 'mock simple $i' {")
                $null = $sb.AppendLine("        Mock Get-Thing { 'mocked' }")
                $null = $sb.AppendLine("        `$null = Get-Thing -Name 'y'")
                $null = $sb.AppendLine("        Should -Invoke Get-Thing -Times 1 -Exactly")
                $null = $sb.AppendLine("    }")
            }
            else {
                $null = $sb.AppendLine("    It 'mock multi $i' {")
                $null = $sb.AppendLine("        Mock Get-Thing { 'mocked' }")
                $null = $sb.AppendLine("        Mock Set-Thing { }")
                $null = $sb.AppendLine("        Set-Thing -Name 'z' -Value 1")
                $null = $sb.AppendLine("        Should -Invoke Set-Thing -Times 1")
                $null = $sb.AppendLine("        Should -Invoke Get-Thing -Times 0")
                $null = $sb.AppendLine("    }")
            }
        }
        $null = $sb.AppendLine("}")
        $null = $sb.AppendLine("")
    }
    [System.IO.File]::WriteAllText($WorkloadPath, $sb.ToString())
}

# 2. Import the locally built Pester (bin is produced by ./build.ps1).
$repo = Split-Path -Path $PSScriptRoot -Parent
$psd1 = Join-Path $repo 'bin/Pester.psd1'
if (-not (Test-Path -LiteralPath $psd1)) {
    throw "Built Pester not found at $psd1 - run ./build.ps1 first."
}
Import-Module $psd1 -Force

# 3. Build a configuration once, outside the timed loop.
$config = [PesterConfiguration]::Default
$config.Run.Path = $WorkloadPath
$config.Run.PassThru = $true
$config.Output.Verbosity = 'None'
$config.CodeCoverage.Enabled = $false

# 4. Warm up (JIT, module init, first-time codegen) so it is not counted.
$null = Invoke-Pester -Configuration $config

# 5. Timed runs.
$times = foreach ($i in 1..$Runs) {
    $r = Invoke-Pester -Configuration $config
    if ($r.FailedCount -ne 0) {
        throw "Workload had $($r.FailedCount) failing tests - benchmark is invalid."
    }
    $r.Duration.TotalMilliseconds
}

$sorted = $times | Sort-Object
$median = $sorted[[math]::Floor($sorted.Count / 2)]
$min = $sorted[0]
$runsText = ($times | ForEach-Object { '{0:N0}' -f $_ }) -join ', '
$pesterVersion = (Get-Module Pester).Version

Write-Host ("RESULT | {0,-9} | PS {1} | Pester {2} | runs(ms): {3} | median={4:N0} | min={5:N0}" -f `
        $Label, $PSVersionTable.PSVersion.ToString(), $pesterVersion, $runsText, $median, $min)
