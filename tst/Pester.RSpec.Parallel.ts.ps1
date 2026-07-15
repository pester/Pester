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

    b "Run.Parallel durations" {
        t "uses wall-clock for the run total and blanks the per-phase run totals (#2794)" {
            # Two files that each sleep ~1s would total ~2s if their container durations were summed.
            # Running them in parallel overlaps that time, so the run's actual wall-clock is closer to
            # a single file. Summing the container durations therefore overstates Run.Duration; the
            # run total must instead be the orchestrator's measured wall-clock.
            $folder = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().Guid)
            $null = New-Item -ItemType Directory -Path $folder -Force
            Set-Content -Path (Join-Path $folder 'Slow1.Tests.ps1') -Value @'
Describe 'Slow1' {
    BeforeAll { Start-Sleep -Milliseconds 1000 }
    It 'passes' { 1 | Should -Be 1 }
}
'@
            Set-Content -Path (Join-Path $folder 'Slow2.Tests.ps1') -Value @'
Describe 'Slow2' {
    BeforeAll { Start-Sleep -Milliseconds 1000 }
    It 'passes' { 1 | Should -Be 1 }
}
'@
            try {
                $c = [PesterConfiguration]::Default
                $c.Run.Path = $folder
                $c.Run.Parallel = $true
                $c.Run.PassThru = $true
                $c.Output.Verbosity = 'None'

                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $r = Invoke-Pester -Configuration $c
                $sw.Stop()

                if ($PSVersionTable.PSVersion.Major -ge 7) {
                    # Naive sum of the overlapping container durations - the old (wrong) run total.
                    $containerSum = [TimeSpan]::Zero
                    foreach ($container in $r.Containers) { $containerSum += $container.Duration }

                    # Run total is the measured wall-clock: positive, never larger than the elapsed
                    # time around the whole call, and well below the naive sum because the files overlap.
                    ($r.Duration -gt [TimeSpan]::Zero) | Verify-True
                    ($r.Duration -le $sw.Elapsed) | Verify-True
                    ($r.Duration -lt $containerSum) | Verify-True

                    # The per-phase run totals are blanked - a single wall-clock figure for user,
                    # framework or discovery time is not meaningful once the files overlap.
                    ($r.UserDuration -eq [TimeSpan]::Zero) | Verify-True
                    ($r.FrameworkDuration -eq [TimeSpan]::Zero) | Verify-True
                    ($r.DiscoveryDuration -eq [TimeSpan]::Zero) | Verify-True

                    # Parallelism is file-level, so each container keeps its full duration breakdown.
                    foreach ($container in $r.Containers) {
                        ($container.Duration -gt [TimeSpan]::Zero) | Verify-True
                        ($container.UserDuration -gt [TimeSpan]::Zero) | Verify-True
                    }
                    # Discovery is measured per container too (summed here only to avoid per-file flakiness).
                    $discoverySum = [TimeSpan]::Zero
                    foreach ($container in $r.Containers) { $discoverySum += $container.DiscoveryDuration }
                    ($discoverySum -gt [TimeSpan]::Zero) | Verify-True
                }
            }
            finally { Remove-Item -Path $folder -Recurse -Force }
        }
    }

    b "Run.Parallel data passing" {
        t "passes container -Data to each parallel worker's param() block" {
            # New-PesterContainer -Path ... -Data must bind the file's param() block under parallel
            # the same way it does sequentially. (#2793)
            $folder = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().Guid)
            $null = New-Item -ItemType Directory -Path $folder -Force
            foreach ($n in 1..2) {
                Set-Content -Path (Join-Path $folder "Data$n.Tests.ps1") -Value @'
param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $Module, $Data)
Describe 'D' { It 'sees data' { $Module | Should -Be 'hello'; $Data.k | Should -Be 42 } }
'@
            }
            try {
                $c = [PesterConfiguration]::Default
                $c.Run.Container = New-PesterContainer -Path $folder -Data @{ Module = 'hello'; Data = @{ k = 42 } }
                $c.Run.Parallel = $true
                $c.Run.PassThru = $true
                $c.Output.Verbosity = 'None'
                $r = Invoke-Pester -Configuration $c

                $r.PassedCount | Verify-Equal 2
                $r.FailedCount | Verify-Equal 0
            }
            finally { Remove-Item -Path $folder -Recurse -Force }
        }
    }

    b "Run.Parallel module loading" {
        t "imports a module that lists Pester in RequiredModules (#2816)" {
            # Each parallel worker imports Pester so test bodies can use it. The worker must import
            # Pester *via its manifest* so the loaded module keeps its real ModuleVersion. Importing
            # the bare root module instead would load Pester as 0.0.0.0, and any module a test imports
            # whose manifest lists Pester in RequiredModules (e.g. @{ ModuleName = 'Pester';
            # ModuleVersion = '5.0.0' }) would then fail to resolve that requirement against the
            # loaded 0.0.0.0 Pester - the bug reported in #2816.
            $folder = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().Guid)
            $null = New-Item -ItemType Directory -Path $folder -Force
            try {
                $moduleDir = Join-Path $folder 'RequiresPester'
                $null = New-Item -ItemType Directory -Path $moduleDir -Force
                Set-Content -Path (Join-Path $moduleDir 'RequiresPester.psm1') -Value 'function Get-RequiresPester { ''ok'' }'
                Set-Content -Path (Join-Path $moduleDir 'RequiresPester.psd1') -Value @'
@{
    RootModule        = 'RequiresPester.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'b3c4d5e6-f7a8-4901-b2c3-d4e5f6a7b8c9'
    RequiredModules   = @( @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' } )
    FunctionsToExport = @('Get-RequiresPester')
}
'@
                $manifest = Join-Path $moduleDir 'RequiresPester.psd1'
                Set-Content -Path (Join-Path $folder 'Import.Tests.ps1') -Value @"
Describe 'Module import' {
    It 'imports a module that requires Pester' {
        { Import-Module '$manifest' -Force -ErrorAction Stop } | Should -Not -Throw
    }
}
"@
                $c = [PesterConfiguration]::Default
                $c.Run.Path = $folder
                $c.Run.Parallel = $true
                $c.Run.PassThru = $true
                $c.Output.Verbosity = 'None'

                $r = Invoke-Pester -Configuration $c

                $r.PassedCount | Verify-Equal 1
                $r.FailedCount | Verify-Equal 0
            }
            finally {
                # Import.Tests.ps1 imports RequiresPester, which takes a dependency on Pester. When
                # Run.Parallel falls back to sequential (e.g. Windows PowerShell 5.1) that import runs
                # in this process, so the module leaks into the shared P-test session and the next
                # *.ts.ps1 file's `Remove-Module Pester` fails with "required by 'RequiresPester'".
                # Unload it first - this also releases the lock on its .psm1 so the folder can be removed.
                Get-Module RequiresPester | Remove-Module -Force
                Remove-Item -Path $folder -Recurse -Force
            }
        }
    }

    b "Pester.BeforeContainer.ps1 convention" {
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

        t "shares a single bootstrap across many files in parallel, anchored on the stable `$PSScriptRoot" {
            # Compelling real-world case: instead of repeating an Import-Module + mock defaults setup
            # in every test file, put it once in Pester.BeforeContainer.ps1. Because it is a real
            # file, it always has a stable `$PSScriptRoot` to resolve the module relative to
            # (unlike the removed Run.BeforeContainer scriptblock option, which only had the unstable
            # `$pwd` - see #2838). Each parallel worker starts from a clean runspace and re-runs the
            # bootstrap, so the shared helpers are available to every file without duplication.
            $folder = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().Guid)
            $null = New-Item -ItemType Directory -Path $folder -Force

            Set-Content -Path (Join-Path $folder 'Helpers.psm1') -Value @'
function Get-Answer { 42 }
'@

            # Resolve the module relative to $PSScriptRoot (the folder of this bootstrap file), which
            # is stable regardless of the working directory Invoke-Pester was called from.
            Set-Content -Path (Join-Path $folder 'Pester.BeforeContainer.ps1') -Value @'
Import-Module -Name (Join-Path $PSScriptRoot 'Helpers.psm1') -Force
'@

            Set-Content -Path (Join-Path $folder 'First.Tests.ps1') -Value @'
Describe 'First' {
    It 'uses the shared helper' { Get-Answer | Should -Be 42 }
}
'@
            Set-Content -Path (Join-Path $folder 'Second.Tests.ps1') -Value @'
Describe 'Second' {
    It 'uses the shared helper too' { Get-Answer | Should -Be 42 }
}
'@
            try {
                $c = [PesterConfiguration]::Default
                $c.Run.Path = $folder
                $c.Run.RepoRoot = $folder
                $c.Run.Parallel = $true
                $c.Run.PassThru = $true
                $c.Output.Verbosity = 'None'
                # Call from a different working directory to prove the bootstrap does not depend on $pwd.
                Push-Location ([IO.Path]::GetTempPath())
                try { $r = Invoke-Pester -Configuration $c } finally { Pop-Location }

                $r.PassedCount | Verify-Equal 2
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

        t "collects and merges code coverage across parallel workers" {
            $folder = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().Guid)
            $null = New-Item -ItemType Directory -Path $folder -Force
            try {
                # A shared code file to measure coverage on, plus two parallelizable test files that
                # each exercise a different function in it. The parallel run must collect coverage
                # from every worker and merge it into one report - matching a sequential run exactly.
                Set-Content -Path (Join-Path $folder 'lib.ps1') -Value @'
function Get-One { 1 }
function Get-Two { 2 }
function Get-Three { 3 }
function Get-Four { 4 }
'@
                Set-Content -Path (Join-Path $folder 'A.Tests.ps1') -Value @'
BeforeAll { . $PSScriptRoot/lib.ps1 }
Describe 'A' { It 'a1 passes' { Get-One | Should -Be 1 } }
'@
                Set-Content -Path (Join-Path $folder 'B.Tests.ps1') -Value @'
BeforeAll { . $PSScriptRoot/lib.ps1 }
Describe 'B' { It 'b1 passes' { Get-Two | Should -Be 2 } }
'@
                $newConfig = {
                    $c = [PesterConfiguration]::Default
                    $c.Run.Path = $folder
                    $c.Run.PassThru = $true
                    $c.CodeCoverage.Enabled = $true
                    $c.CodeCoverage.Path = (Join-Path $folder 'lib.ps1')
                    $c
                }

                $sequential = & $newConfig
                $sequential.Run.Parallel = $false
                $seq = Invoke-Pester -Configuration $sequential

                $parallel = & $newConfig
                $parallel.Run.Parallel = $true
                $par = Invoke-Pester -Configuration $parallel

                # Two of the four functions are covered; parallel must match sequential exactly.
                $par.PassedCount | Verify-Equal 2
                $par.CodeCoverage | Verify-NotNull
                $par.CodeCoverage.CommandsAnalyzedCount | Verify-Equal $seq.CodeCoverage.CommandsAnalyzedCount
                $par.CodeCoverage.CommandsExecutedCount | Verify-Equal $seq.CodeCoverage.CommandsExecutedCount
                $par.CodeCoverage.CommandsMissedCount | Verify-Equal $seq.CodeCoverage.CommandsMissedCount
                $par.CodeCoverage.CommandsExecutedCount | Verify-Equal 2
            }
            finally { Remove-Item -Path $folder -Recurse -Force }
        }

        t "merges code coverage from a file marked #pester:no-parallel" {
            $folder = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().Guid)
            $null = New-Item -ItemType Directory -Path $folder -Force
            try {
                # A,B run in parallel; C opts out and runs in the parent. Coverage from the in-parent
                # (non-parallel) file must be merged with the worker coverage.
                Set-Content -Path (Join-Path $folder 'lib.ps1') -Value @'
function Get-One { 1 }
function Get-Two { 2 }
function Get-Three { 3 }
function Get-Four { 4 }
'@
                Set-Content -Path (Join-Path $folder 'A.Tests.ps1') -Value @'
BeforeAll { . $PSScriptRoot/lib.ps1 }
Describe 'A' { It 'a1 passes' { Get-One | Should -Be 1 } }
'@
                Set-Content -Path (Join-Path $folder 'B.Tests.ps1') -Value @'
BeforeAll { . $PSScriptRoot/lib.ps1 }
Describe 'B' { It 'b1 passes' { Get-Two | Should -Be 2 } }
'@
                Set-Content -Path (Join-Path $folder 'C.Tests.ps1') -Value @'
#pester:no-parallel
BeforeAll { . $PSScriptRoot/lib.ps1 }
Describe 'C' { It 'c1 passes' { Get-Three | Should -Be 3 } }
'@
                $c = [PesterConfiguration]::Default
                $c.Run.Path = $folder
                $c.Run.Parallel = $true
                $c.Run.PassThru = $true
                $c.CodeCoverage.Enabled = $true
                $c.CodeCoverage.Path = (Join-Path $folder 'lib.ps1')

                $r = Invoke-Pester -Configuration $c

                $r.PassedCount | Verify-Equal 3
                $r.CodeCoverage | Verify-NotNull
                # Get-One, Get-Two (workers) and Get-Three (#pester:no-parallel) were executed.
                $r.CodeCoverage.CommandsExecutedCount | Verify-Equal 3
                $r.CodeCoverage.CommandsMissedCount | Verify-Equal 1
                $executedLines = $r.CodeCoverage.CommandsExecuted.StartLine
                $executedLines -contains 3 | Verify-True
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

    b "Run.Parallel output" {
        t "renders Describing/Context block headers in Detailed output" {
            # In parallel each file runs in a silent worker whose result tree is replayed to the
            # parent's reporting plugins. The worker's end-of-run cleanup used to strip every block's
            # FrameworkData (which carries the Describe/Context command name), and because the replay
            # tape holds live references to those same block objects the parent was then left without
            # a CommandUsed to render - so the "Describing"/"Context" headers silently vanished from
            # Detailed/Diagnostic output (#2824). Assert they are present in a parallel run.
            $folder = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().Guid)
            $null = New-Item -ItemType Directory -Path $folder -Force
            try {
                Set-Content -Path (Join-Path $folder 'One.Tests.ps1') -Value @'
Describe 'OuterOne' {
    Context 'CtxA' { It 'a1 passes' { 1 | Should -Be 1 } }
}
'@
                Set-Content -Path (Join-Path $folder 'Two.Tests.ps1') -Value @'
Describe 'OuterTwo' {
    Context 'CtxB' { It 'b1 passes' { 1 | Should -Be 1 } }
}
'@
                $c = [PesterConfiguration]::Default
                $c.Run.Path = $folder
                $c.Run.Parallel = $true
                $c.Run.PassThru = $true
                $c.Output.Verbosity = 'Detailed'
                $c.Output.RenderMode = 'Plaintext'

                # Write-PesterHostMessage uses Write-Host, so console output lands on the
                # information stream (6) and can be captured in-process.
                $output = (Invoke-Pester -Configuration $c 6>&1 | Out-String)

                $output | Verify-Like '*Describing OuterOne*'
                $output | Verify-Like '*Context CtxA*'
                $output | Verify-Like '*Describing OuterTwo*'
                $output | Verify-Like '*Context CtxB*'
            }
            finally { Remove-Item -Path $folder -Recurse -Force }
        }
    }

    b "Run.Parallel debug output" {
        t "captures debug output and replays it interleaved with each file's tests" {
            # Each worker runs silently and records its screen and debug output into the shared tape;
            # the parent replays that tape in order. So debug output must come back interleaved with the
            # per-test output of the file that produced it, not dumped up front detached from it (#2825).
            $folder = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().Guid)
            $null = New-Item -ItemType Directory -Path $folder -Force
            try {
                Set-Content -Path (Join-Path $folder 'A.Tests.ps1') -Value @'
Describe 'A' { It 'a1 passes' { 1 | Should -Be 1 } }
'@
                Set-Content -Path (Join-Path $folder 'B.Tests.ps1') -Value @'
Describe 'B' { It 'b1 passes' { 1 | Should -Be 1 } }
'@
                $c = [PesterConfiguration]::Default
                $c.Run.Path = $folder
                $c.Run.Parallel = $true
                $c.Run.PassThru = $true
                $c.Output.Verbosity = 'Diagnostic'
                $c.Output.RenderMode = 'Plaintext'

                # 6>&1 folds the host output (written as information records) into the pipeline so we can
                # replay it exactly as it was rendered; the Pester.Run object comes out alongside it.
                $out = Invoke-Pester -Configuration $c 3>$null 6>&1
                $r = @($out).Where({ $_ -is [Pester.Run] })[0]

                # The run still executes in parallel and produces correct results.
                $r.PassedCount | Verify-Equal 2

                # PowerShell 5.1 has no ForEach-Object -Parallel and falls back to a sequential run whose
                # output differs, so only assert the exact parallel rendering on 7+.
                if ($PSVersionTable.PSVersion.Major -ge 7) {
                    # Rebuild the console text from the captured Write-Host records (honouring -NoNewline),
                    # then blank out the volatile version, temp paths and timings so the snapshot is stable.
                    $sb = [System.Text.StringBuilder]::new()
                    foreach ($rec in @($out)) {
                        if ($rec -isnot [System.Management.Automation.InformationRecord]) { continue }
                        $md = $rec.MessageData
                        if ($md -is [System.Management.Automation.HostInformationMessage]) {
                            $null = $sb.Append($md.Message)
                            if (-not $md.NoNewLine) { $null = $sb.Append("`n") }
                        }
                    }
                    $normalized = $sb.ToString() `
                        -replace 'Pester v\S+', 'Pester v<version>' `
                        -replace ([regex]::Escape($folder + [IO.Path]::DirectorySeparatorChar)), '' `
                        -replace '\d+ ms', '<time> ms' `
                        -replace '\d+ms', '<time>ms'
                    $actual = (($normalized -split "`r`n|`r|`n").ForEach({ $_.TrimEnd() }) -join "`n").Trim()

                    # Each file's discovery is immediately followed by that same file's run - A fully, then
                    # B fully - instead of both discoveries being dumped up front, detached from the tests.
                    $expected = @'
Pester v<version>

Running tests from 2 files in parallel.
Discovery: Discovering tests in A.Tests.ps1
Discovery: Found 1 tests in <time> ms

Running tests from 'A.Tests.ps1'
Describing A
  [+] a1 passes <time>ms
Discovery: Discovering tests in B.Tests.ps1
Discovery: Found 1 tests in <time> ms

Running tests from 'B.Tests.ps1'
Describing B
  [+] b1 passes <time>ms
Tests completed in <time>ms
Tests Passed: 2, Failed: 0, Skipped: 0, Inconclusive: 0, NotRun: 0
'@ -replace "`r`n", "`n"

                    $actual | Verify-Equal $expected
                }
            }
            finally { Remove-Item -Path $folder -Recurse -Force }
        }
    }
}
