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

# A container with a known structure. Every It records its path into $global:__order when it runs,
# so we can observe the real execution order at every level:
#   - the Describes directly in the file (A, B, C),
#   - the Context/Describe nested in a Describe (A\A-inner),
#   - the Its in a block (a1..a2, c1..c3, ...).
$script:SampleBlock = {
    Describe 'A' {
        It 'a1' { $global:__order.Add('A.a1') }
        It 'a2' { $global:__order.Add('A.a2') }
        Context 'A-inner' {
            It 'ai1' { $global:__order.Add('A.inner.ai1') }
            It 'ai2' { $global:__order.Add('A.inner.ai2') }
        }
    }
    Describe 'B' {
        It 'b1' { $global:__order.Add('B.b1') }
        It 'b2' { $global:__order.Add('B.b2') }
    }
    Describe 'C' {
        It 'c1' { $global:__order.Add('C.c1') }
        It 'c2' { $global:__order.Add('C.c2') }
        It 'c3' { $global:__order.Add('C.c3') }
    }
}

function Get-ExecutionOrder {
    param (
        [ScriptBlock] $ScriptBlock = $script:SampleBlock,
        [switch] $Random,
        [int] $Seed = 0
    )

    $global:__order = [System.Collections.Generic.List[string]]::new()
    $c = [PesterConfiguration]::Default
    $c.Run.ScriptBlock = $ScriptBlock
    $c.Run.Random = [bool]$Random
    $c.Run.RandomSeed = $Seed
    $c.Run.PassThru = $true
    $c.Output.Verbosity = 'None'
    $r = Invoke-Pester -Configuration $c

    [PSCustomObject]@{
        Order        = $global:__order.ToArray()
        OrderString  = $global:__order -join ','
        ResolvedSeed = $r.Configuration.Run.RandomSeed.Value
        Result       = $r
    }
}

i -PassThru:$PassThru {
    b "Run.Random configuration options" {
        t "Run.Random exists and defaults to disabled" {
            $c = [PesterConfiguration]::Default
            $c.Run.Random.Value | Verify-False
        }

        t "Run.RandomSeed exists and defaults to 0" {
            $c = [PesterConfiguration]::Default
            $c.Run.RandomSeed.Value | Verify-Equal 0
        }

        t "Run.Random can be enabled and Run.RandomSeed can be set" {
            $c = [PesterConfiguration]::Default
            $c.Run.Random = $true
            $c.Run.RandomSeed = 123
            $c.Run.Random.Value | Verify-True
            $c.Run.RandomSeed.Value | Verify-Equal 123
        }

        t "options can be set from a hashtable" {
            $c = [PesterConfiguration]@{ Run = @{ Random = $true; RandomSeed = 99 } }
            $c.Run.Random.Value | Verify-True
            $c.Run.RandomSeed.Value | Verify-Equal 99
        }
    }

    b "Default order (Run.Random disabled)" {
        t "keeps the discovery (declaration) order" {
            $r = Get-ExecutionOrder
            $r.OrderString | Verify-Equal 'A.a1,A.a2,A.inner.ai1,A.inner.ai2,B.b1,B.b2,C.c1,C.c2,C.c3'
        }
    }

    b "Randomized order is repeatable" {
        t "the same seed produces the same order across runs" {
            $first = Get-ExecutionOrder -Random -Seed 42
            $second = Get-ExecutionOrder -Random -Seed 42
            $first.OrderString | Verify-Equal $second.OrderString
        }

        t "a randomized run differs from the declaration order" {
            $ordered = Get-ExecutionOrder
            $shuffled = Get-ExecutionOrder -Random -Seed 42
            ($shuffled.OrderString -ne $ordered.OrderString) | Verify-True
        }

        t "different seeds produce different orders" {
            $a = Get-ExecutionOrder -Random -Seed 42
            $b = Get-ExecutionOrder -Random -Seed 7
            ($a.OrderString -ne $b.OrderString) | Verify-True
        }
    }

    b "Randomized order shuffles every level, dropping nothing" {
        t "runs exactly the same set of tests, only reordered" {
            $ordered = Get-ExecutionOrder
            $shuffled = Get-ExecutionOrder -Random -Seed 42

            $shuffled.Order.Count | Verify-Equal $ordered.Order.Count
            $expected = $ordered.Order | Sort-Object
            $actual = $shuffled.Order | Sort-Object
            ($actual -join ',') | Verify-Equal ($expected -join ',')
        }

        t "reorders top-level Describes in a file" {
            # Reduce each entry to its top-level Describe and keep the order they first appear in.
            $shuffled = Get-ExecutionOrder -Random -Seed 42
            $topLevel = @($shuffled.Order | ForEach-Object { ($_ -split '\.')[0] } | Select-Object -Unique)
            (($topLevel -join ',') -ne 'A,B,C') | Verify-True
        }

        t "reorders the Its inside a block" {
            # Seeds are chosen so the C block's tests are not in declaration order.
            $found = $false
            foreach ($seed in 1..20) {
                $shuffled = Get-ExecutionOrder -Random -Seed $seed
                $cTests = @($shuffled.Order | Where-Object { $_ -like 'C.*' })
                if (($cTests -join ',') -ne 'C.c1,C.c2,C.c3') { $found = $true; break }
            }
            $found | Verify-True
        }

        t "reorders the Its inside a nested Context" {
            $found = $false
            foreach ($seed in 1..20) {
                $shuffled = Get-ExecutionOrder -Random -Seed $seed
                $inner = @($shuffled.Order | Where-Object { $_ -like 'A.inner.*' })
                if (($inner -join ',') -ne 'A.inner.ai1,A.inner.ai2') { $found = $true; break }
            }
            $found | Verify-True
        }
    }

    b "Auto seed (Run.RandomSeed = 0)" {
        t "resolves a non-zero seed and reports it on the result configuration" {
            $r = Get-ExecutionOrder -Random -Seed 0
            ($r.ResolvedSeed -ne 0) | Verify-True
        }

        t "does not mutate the caller's configuration object" {
            $c = [PesterConfiguration]::Default
            $c.Run.ScriptBlock = $script:SampleBlock
            $c.Run.Random = $true
            $c.Run.RandomSeed = 0
            $c.Output.Verbosity = 'None'
            $global:__order = [System.Collections.Generic.List[string]]::new()
            $null = Invoke-Pester -Configuration $c
            # The run works on a merged copy, so the caller's seed stays 0 (a fresh seed each run).
            $c.Run.RandomSeed.Value | Verify-Equal 0
        }

        t "the reported seed reproduces the same order" {
            $auto = Get-ExecutionOrder -Random -Seed 0
            $repro = Get-ExecutionOrder -Random -Seed $auto.ResolvedSeed
            $auto.OrderString | Verify-Equal $repro.OrderString
        }
    }

    b "Randomized order keeps setup and teardown correct" {
        t "one-time and each setup/teardown still run the right number of times" {
            # If shuffling broke the First/Last markers, one-time setup/teardown would fire at the
            # wrong item. Count invocations to prove they stay correct under a shuffled order.
            $global:__oneTime = 0
            $global:__each = 0
            $sb = {
                Describe 'S' {
                    BeforeAll { $global:__oneTime++ }
                    AfterAll { $global:__oneTime++ }
                    BeforeEach { $global:__each++ }
                    AfterEach { $global:__each++ }
                    It 's1' { 1 | Should -Be 1 }
                    It 's2' { 1 | Should -Be 1 }
                    It 's3' { 1 | Should -Be 1 }
                }
            }
            $c = [PesterConfiguration]::Default
            $c.Run.ScriptBlock = $sb
            $c.Run.Random = $true
            $c.Run.RandomSeed = 42
            $c.Run.PassThru = $true
            $c.Output.Verbosity = 'None'
            $r = Invoke-Pester -Configuration $c

            $r.PassedCount | Verify-Equal 3
            $r.FailedCount | Verify-Equal 0
            # BeforeAll + AfterAll once each.
            $global:__oneTime | Verify-Equal 2
            # BeforeEach + AfterEach for each of the 3 tests.
            $global:__each | Verify-Equal 6
        }
    }

    b "Randomized file order" {
        t "shuffles the order test files run in, repeatably" {
            $folder = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().Guid)
            $null = New-Item -ItemType Directory -Path $folder -Force
            foreach ($n in 'One', 'Two', 'Three', 'Four', 'Five') {
                Set-Content -Path (Join-Path $folder "$n.Tests.ps1") -Value "Describe '$n' { It 'i' { `$global:__forder.Add('$n') } }"
            }
            try {
                function Get-FileOrder ([int] $Seed) {
                    $global:__forder = [System.Collections.Generic.List[string]]::new()
                    $c = [PesterConfiguration]::Default
                    $c.Run.Path = $folder
                    $c.Run.Random = $true
                    $c.Run.RandomSeed = $Seed
                    $c.Output.Verbosity = 'None'
                    $null = Invoke-Pester -Configuration $c
                    $global:__forder -join ','
                }

                $ordered = ('One', 'Two', 'Three', 'Four', 'Five') -join ','
                $a = Get-FileOrder -Seed 12345
                $b = Get-FileOrder -Seed 12345

                # same set of files ran
                (($a -split ',' | Sort-Object) -join ',') | Verify-Equal (($ordered -split ',' | Sort-Object) -join ',')
                # repeatable
                $a | Verify-Equal $b
                # actually reordered
                ($a -ne $ordered) | Verify-True
            }
            finally { Remove-Item -Path $folder -Recurse -Force }
        }
    }
}
