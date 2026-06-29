param ([switch] $PassThru, [switch] $NoBuild)

Get-Module P, PTestHelpers, Pester, Axiom | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking

if (-not $NoBuild) { & "$PSScriptRoot\..\build.ps1" }
Import-Module $PSScriptRoot\..\bin\Pester.psd1

$global:PesterPreference = @{
    Debug  = @{
        ShowFullErrors = $true
    }
    Output = @{
        Verbosity = 'None'
    }
}
$PSDefaultParameterValues = @{}

function New-ParallelTestFolder {
    # Creates a temp folder with a known mix of test files and returns its path.
    # Totals across the folder: 8 tests => 6 passed, 1 failed, 1 skipped.
    $folder = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().Guid)
    $null = New-Item -ItemType Directory -Path $folder -Force

    Set-Content -Path (Join-Path $folder 'A.Tests.ps1') -Value @'
Describe 'A' {
    It 'a1 passes' { 1 | Should -Be 1 }
    It 'a2 passes' { 2 | Should -Be 2 }
    It 'a3 fails'  { 1 | Should -Be 2 }
}
'@

    Set-Content -Path (Join-Path $folder 'B.Tests.ps1') -Value @'
Describe 'B' {
    It 'b1 passes' { 'x' | Should -Be 'x' }
    It 'b2 skipped' -Skip { 1 | Should -Be 1 }
}
'@

    Set-Content -Path (Join-Path $folder 'C.Tests.ps1') -Value @'
Describe 'C' {
    It 'c1 passes' { $true | Should -BeTrue }
}
'@

    # Marked as non-parallel; runs sequentially after the parallel batch.
    Set-Content -Path (Join-Path $folder 'D.Tests.ps1') -Value @'
#pester:no-parallel
Describe 'D' {
    It 'd1 passes' { 10 | Should -Be 10 }
    It 'd2 passes' { 20 | Should -Be 20 }
}
'@

    $folder
}

function New-BeforeContainerTestFolder {
    # Creates a temp folder with a Pester.BeforeContainer.ps1 that defines a helper function and a
    # test file whose only test calls that helper. Without BeforeContainer running first the test
    # errors (command not found); with it, the test passes. Returns the folder path.
    $folder = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().Guid)
    $null = New-Item -ItemType Directory -Path $folder -Force

    Set-Content -Path (Join-Path $folder 'Pester.BeforeContainer.ps1') -Value @'
function Get-BeforeContainerMarker { 'before-container-ran' }
'@

    Set-Content -Path (Join-Path $folder 'Marker.Tests.ps1') -Value @'
Describe 'Marker' {
    It 'can call the helper from Pester.BeforeContainer.ps1' {
        Get-BeforeContainerMarker | Should -Be 'before-container-ran'
    }
}
'@

    $folder
}

function Get-ExpectedParallelFallbackWarning {
    # Windows PowerShell 5.1 has no 'ForEach-Object -Parallel', so every Run.Parallel run trips the
    # PowerShell-version gate and falls back to sequential before any feature-specific check
    # (ScriptBlock / CodeCoverage / SkipRemainingOnFailure) is reached. The run still produces
    # identical results either way - only the warning text differs - so tests assert the
    # feature-specific text on PowerShell 7+ and the version text on 5.1.
    param ([Parameter(Mandatory)] [string] $Ps7Pattern)
    if ($PSVersionTable.PSVersion.Major -ge 7) { $Ps7Pattern } else { '*requires PowerShell 7*' }
}

i -PassThru:$PassThru {
    b "Run.Parallel configuration option" {
        t "exists and defaults to disabled" {
            $c = [PesterConfiguration]::Default
            $c.Run.Parallel.Value | Verify-False
        }

        t "can be enabled" {
            $c = [PesterConfiguration]::Default
            $c.Run.Parallel = $true
            $c.Run.Parallel.Value | Verify-True
        }
    }

    b "Run duration in parallel mode" {
        t "uses the measured wall-clock for the total and still sums the per-phase work" {
            # Two files that each sleep run sequentially would total ~1.2s; in parallel the wall-clock
            # is closer to a single file, so summing container durations overstates the run. (#2794)
            $folder = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().Guid)
            $null = New-Item -ItemType Directory -Path $folder -Force
            Set-Content -Path (Join-Path $folder 'Slow1.Tests.ps1') -Value @'
Describe 'Slow1' { BeforeAll { Start-Sleep -Milliseconds 600 }; It 'p' { 1 | Should -Be 1 } }
'@
            Set-Content -Path (Join-Path $folder 'Slow2.Tests.ps1') -Value @'
Describe 'Slow2' { BeforeAll { Start-Sleep -Milliseconds 600 }; It 'p' { 1 | Should -Be 1 } }
'@
            try {
                $c = [PesterConfiguration]::Default
                $c.Run.Path = $folder
                $c.Run.Parallel = $true
                $c.Run.PassThru = $true
                $c.Output.Verbosity = 'None'
                $r = Invoke-Pester -Configuration $c

                if ($PSVersionTable.PSVersion.Major -ge 7) {
                    $containerSum = [TimeSpan]::Zero
                    foreach ($container in $r.Containers) { $containerSum += $container.Duration }
                    # Wall-clock run duration is measured, so it is less than the naive sum of the
                    # two slow files that overlap in parallel.
                    ($r.Duration -lt $containerSum) | Verify-True
                    ($r.Duration -gt [TimeSpan]::Zero) | Verify-True
                    # Per-phase totals are still measured (summed across the overlapping workers),
                    # not blanked, so they add up to the total container work.
                    ($r.UserDuration -gt [TimeSpan]::Zero) | Verify-True
                    ($r.DiscoveryDuration + $r.UserDuration + $r.FrameworkDuration) | Verify-Equal $containerSum
                }
            }
            finally { Remove-Item -Path $folder -Recurse -Force }
        }
    }

    b "Run.BeforeContainer" {
        t "runs the repo-root Pester.BeforeContainer.ps1 before each file in a sequential run" {
            $folder = New-BeforeContainerTestFolder
            try {
                $c = [PesterConfiguration]::Default
                $c.Run.Path = $folder
                $c.Run.RepoRoot = $folder
                $c.Run.PassThru = $true
                $c.Output.Verbosity = 'None'
                $r = Invoke-Pester -Configuration $c

                $r.PassedCount | Verify-Equal 1
                $r.FailedCount | Verify-Equal 0
            }
            finally { Remove-Item -Path $folder -Recurse -Force }
        }

        t "runs the repo-root Pester.BeforeContainer.ps1 inside each parallel worker" {
            $folder = New-BeforeContainerTestFolder
            try {
                $c = [PesterConfiguration]::Default
                $c.Run.Path = $folder
                $c.Run.RepoRoot = $folder
                $c.Run.Parallel = $true
                $c.Run.PassThru = $true
                $c.Output.Verbosity = 'None'
                $r = Invoke-Pester -Configuration $c

                $r.PassedCount | Verify-Equal 1
                $r.FailedCount | Verify-Equal 0
            }
            finally { Remove-Item -Path $folder -Recurse -Force }
        }

        t "uses explicit Run.BeforeContainer scriptblocks instead of the convention file" {
            $folder = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().Guid)
            $null = New-Item -ItemType Directory -Path $folder -Force
            Set-Content -Path (Join-Path $folder 'Marker.Tests.ps1') -Value @'
Describe 'Marker' {
    It 'can call the helper defined by Run.BeforeContainer' {
        Get-ExplicitMarker | Should -Be 'explicit'
    }
}
'@
            try {
                $c = [PesterConfiguration]::Default
                $c.Run.Path = $folder
                $c.Run.PassThru = $true
                $c.Output.Verbosity = 'None'
                $c.Run.BeforeContainer = { function Get-ExplicitMarker { 'explicit' } }
                $r = Invoke-Pester -Configuration $c

                $r.PassedCount | Verify-Equal 1
                $r.FailedCount | Verify-Equal 0
            }
            finally { Remove-Item -Path $folder -Recurse -Force }
        }
    }

    b "#pester:no-parallel directive parsing" {
        t "detects the directive when written as a comment" {
            $folder = New-ParallelTestFolder
            try {
                $path = Join-Path $folder 'D.Tests.ps1'
                $result = & (Get-Module Pester) { param($p) Test-PesterFileIsNonParallel -Path $p } $path
                $result | Verify-True
            }
            finally { Remove-Item -Path $folder -Recurse -Force }
        }

        t "ignores files without the directive" {
            $folder = New-ParallelTestFolder
            try {
                $path = Join-Path $folder 'A.Tests.ps1'
                $result = & (Get-Module Pester) { param($p) Test-PesterFileIsNonParallel -Path $p } $path
                $result | Verify-False
            }
            finally { Remove-Item -Path $folder -Recurse -Force }
        }

        t "does not match the marker inside a string literal" {
            $folder = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().Guid)
            $null = New-Item -ItemType Directory -Path $folder -Force
            try {
                $path = Join-Path $folder 'String.Tests.ps1'
                Set-Content -Path $path -Value @'
Describe 'S' {
    It 'has the marker in a string' { '#pester:no-parallel' | Should -Be '#pester:no-parallel' }
}
'@
                $result = & (Get-Module Pester) { param($p) Test-PesterFileIsNonParallel -Path $p } $path
                $result | Verify-False
            }
            finally { Remove-Item -Path $folder -Recurse -Force }
        }
    }

    b "Parallel execution" {
        t "merges aggregate counts across files" {
            $folder = New-ParallelTestFolder
            try {
                $c = [PesterConfiguration]::Default
                $c.Run.Path = $folder
                $c.Run.Parallel = $true
                $c.Run.PassThru = $true
                $r = Invoke-Pester -Configuration $c

                $r.TotalCount | Verify-Equal 8
                $r.PassedCount | Verify-Equal 6
                $r.FailedCount | Verify-Equal 1
                $r.SkippedCount | Verify-Equal 1
            }
            finally { Remove-Item -Path $folder -Recurse -Force }
        }

        t "produces the same counts as a sequential run" {
            $folder = New-ParallelTestFolder
            try {
                $sequential = [PesterConfiguration]::Default
                $sequential.Run.Path = $folder
                $sequential.Run.Parallel = $false
                $sequential.Run.PassThru = $true
                $s = Invoke-Pester -Configuration $sequential

                $parallel = [PesterConfiguration]::Default
                $parallel.Run.Path = $folder
                $parallel.Run.Parallel = $true
                $parallel.Run.PassThru = $true
                $p = Invoke-Pester -Configuration $parallel

                $p.TotalCount | Verify-Equal $s.TotalCount
                $p.PassedCount | Verify-Equal $s.PassedCount
                $p.FailedCount | Verify-Equal $s.FailedCount
                $p.SkippedCount | Verify-Equal $s.SkippedCount
            }
            finally { Remove-Item -Path $folder -Recurse -Force }
        }

        t "preserves discovery order of containers" {
            $folder = New-ParallelTestFolder
            try {
                $c = [PesterConfiguration]::Default
                $c.Run.Path = $folder
                $c.Run.Parallel = $true
                $c.Run.PassThru = $true
                $r = Invoke-Pester -Configuration $c

                $names = $r.Containers | ForEach-Object { $_.Item.Name }
                ($names -join ',') | Verify-Equal 'A.Tests.ps1,B.Tests.ps1,C.Tests.ps1,D.Tests.ps1'
            }
            finally { Remove-Item -Path $folder -Recurse -Force }
        }

        t "runs and merges a file marked #pester:no-parallel" {
            $folder = New-ParallelTestFolder
            try {
                $c = [PesterConfiguration]::Default
                $c.Run.Path = $folder
                $c.Run.Parallel = $true
                $c.Run.PassThru = $true
                $r = Invoke-Pester -Configuration $c

                $d = $r.Containers | Where-Object { $_.Item.Name -eq 'D.Tests.ps1' }
                $d | Verify-NotNull
                $d.PassedCount | Verify-Equal 2
            }
            finally { Remove-Item -Path $folder -Recurse -Force }
        }

        t "falls back to sequential with a warning for ScriptBlock containers" {
            $c = [PesterConfiguration]::Default
            $c.Run.ScriptBlock = { Describe 'SB' { It 'passes' { 1 | Should -Be 1 } } }
            $c.Run.Parallel = $true
            $c.Run.PassThru = $true

            $r = Invoke-Pester -Configuration $c -WarningVariable warnings 3>$null

            $r.TotalCount | Verify-Equal 1
            $r.PassedCount | Verify-Equal 1
            ($warnings -join "`n") | Verify-Like (Get-ExpectedParallelFallbackWarning '*parallelizes only file-based runs*')
        }

        t "falls back to sequential with a warning when CodeCoverage is enabled" {
            $folder = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().Guid)
            $null = New-Item -ItemType Directory -Path $folder -Force
            try {
                # A code file to measure coverage on, plus two parallelizable test files that use it.
                Set-Content -Path (Join-Path $folder 'lib.ps1') -Value @'
function Get-One { 1 }
function Get-Two { 2 }
'@
                Set-Content -Path (Join-Path $folder 'A.Tests.ps1') -Value @'
BeforeAll { . $PSScriptRoot/lib.ps1 }
Describe 'A' { It 'a1 passes' { Get-One | Should -Be 1 } }
'@
                Set-Content -Path (Join-Path $folder 'B.Tests.ps1') -Value @'
BeforeAll { . $PSScriptRoot/lib.ps1 }
Describe 'B' { It 'b1 passes' { Get-Two | Should -Be 2 } }
'@
                $c = [PesterConfiguration]::Default
                $c.Run.Path = $folder
                $c.Run.Parallel = $true
                $c.Run.PassThru = $true
                $c.CodeCoverage.Enabled = $true
                $c.CodeCoverage.Path = (Join-Path $folder 'lib.ps1')

                $r = Invoke-Pester -Configuration $c -WarningVariable warnings 3>$null

                # The tests still run and produce correct counts.
                $r.TotalCount | Verify-Equal 2
                $r.PassedCount | Verify-Equal 2
                # Parallel cannot collect coverage yet, so it must warn and run sequentially...
                ($warnings -join "`n") | Verify-Like (Get-ExpectedParallelFallbackWarning '*does not support CodeCoverage*')
                # ...which means real coverage was collected (the parallel path collects none).
                $r.CodeCoverage | Verify-NotNull
                ($r.CodeCoverage.CommandsAnalyzedCount -gt 0) | Verify-True
            }
            finally { Remove-Item -Path $folder -Recurse -Force }
        }

        t "runs sequentially when every file opts out of parallel" {
            $folder = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().Guid)
            $null = New-Item -ItemType Directory -Path $folder -Force
            try {
                Set-Content -Path (Join-Path $folder 'A.Tests.ps1') -Value @'
#pester:no-parallel
Describe 'A' { It 'a1 passes' { 1 | Should -Be 1 } }
'@
                Set-Content -Path (Join-Path $folder 'B.Tests.ps1') -Value @'
#pester:no-parallel
Describe 'B' { It 'b1 passes' { 2 | Should -Be 2 } }
'@
                $c = [PesterConfiguration]::Default
                $c.Run.Path = $folder
                $c.Run.Parallel = $true
                $c.Run.PassThru = $true

                $r = Invoke-Pester -Configuration $c

                $r.TotalCount | Verify-Equal 2
                $r.PassedCount | Verify-Equal 2
            }
            finally { Remove-Item -Path $folder -Recurse -Force }
        }

        t "falls back to sequential with a warning for Run.SkipRemainingOnFailure = 'Run'" {
            # 'Run' scope must stop the whole run after the first failure, which means a failure
            # in the first file skips every later file. That cannot work across isolated worker
            # runspaces, so parallel must fall back to sequential. Proof: the second file's test
            # ends up Skipped (not Passed, which is what a real parallel run would have produced).
            $folder = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().Guid)
            $null = New-Item -ItemType Directory -Path $folder -Force
            try {
                Set-Content -Path (Join-Path $folder 'A.Tests.ps1') -Value @'
Describe 'A' {
    It 'a1 fails' { 1 | Should -Be 2 }
    It 'a2 never runs' { 1 | Should -Be 1 }
}
'@
                Set-Content -Path (Join-Path $folder 'B.Tests.ps1') -Value @'
Describe 'B' { It 'b1 never runs' { 1 | Should -Be 1 } }
'@
                $c = [PesterConfiguration]::Default
                $c.Run.Path = $folder
                $c.Run.Parallel = $true
                $c.Run.PassThru = $true
                $c.Run.SkipRemainingOnFailure = 'Run'

                $r = Invoke-Pester -Configuration $c -WarningVariable warnings 3>$null

                ($warnings -join "`n") | Verify-Like (Get-ExpectedParallelFallbackWarning "*does not support Run.SkipRemainingOnFailure*")
                $r.TotalCount | Verify-Equal 3
                $r.FailedCount | Verify-Equal 1
                # a2 and the whole of B are skipped once the first test fails.
                $r.SkippedCount | Verify-Equal 2
                $r.PassedCount | Verify-Equal 0
            }
            finally { Remove-Item -Path $folder -Recurse -Force }
        }
    }
}
