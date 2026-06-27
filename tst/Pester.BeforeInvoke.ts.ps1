param ([switch] $PassThru, [switch] $NoBuild)

Get-Module P, PTestHelpers, Pester, Axiom | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking

if (-not $NoBuild) { & "$PSScriptRoot\..\build.ps1" }
Import-Module $PSScriptRoot\..\bin\Pester.psd1

$global:PesterPreference = @{
    Debug  = @{
        ShowFullErrors         = $true
        WriteDebugMessages     = $false
        WriteDebugMessagesFrom = "Mock"
        ReturnRawResultObject  = $true
    }
    Output = @{
        Verbosity = "None"
    }
}
$PSDefaultParameterValues = @{}

function New-BeforeInvokeSandbox {
    # Builds a temp repo-like tree: <root>/.git, <root>/sub and a test file under sub. When
    # -Bootstrap is given it is written to <root>/Pester.BeforeInvoke.ps1 (the convention file).
    param(
        [string] $Bootstrap,
        [string] $Test = 'Describe "d" { It "untagged" { 1 | Should -Be 1 }; It "tagged" -Tag only { 1 | Should -Be 1 } }'
    )

    $root = Join-Path ([IO.Path]::GetTempPath()) ("PesterBeforeInvoke_" + [Guid]::NewGuid().ToString('N'))
    $sub = Join-Path $root 'sub'
    $null = New-Item -ItemType Directory -Path $sub -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $root '.git') -Force

    if ($PSBoundParameters.ContainsKey('Bootstrap')) {
        $Bootstrap | Set-Content -LiteralPath (Join-Path $root 'Pester.BeforeInvoke.ps1')
    }

    $Test | Set-Content -LiteralPath (Join-Path $sub 'demo.Tests.ps1')

    [PSCustomObject]@{ Root = $root; Sub = $sub }
}

function New-BeforeInvokeConfiguration {
    param($Sandbox)

    $cfg = New-PesterConfiguration
    $cfg.Run.Path = $Sandbox.Sub
    $cfg.Run.RepoRoot = $Sandbox.Root
    $cfg.Run.PassThru = $true
    $cfg.Output.Verbosity = 'None'
    $cfg
}

function Invoke-ResolveBeforeInvoke {
    # Calls the internal resolver in the Pester module scope.
    param($Configuration)
    & (Get-Module Pester) { param($c) Resolve-PesterBeforeInvoke -Configuration $c } $Configuration
}

i -PassThru:$PassThru {
    b "Resolve-PesterBeforeInvoke" {
        t "returns the explicit Run.BeforeInvoke scriptblocks and ignores the convention file" {
            $sandbox = New-BeforeInvokeSandbox -Bootstrap 'throw "the convention file must be ignored"'
            try {
                $sb1 = { 'one' }
                $sb2 = { 'two' }
                $cfg = New-BeforeInvokeConfiguration -Sandbox $sandbox
                $cfg.Run.BeforeInvoke = @($sb1, $sb2)

                $resolved = @(Invoke-ResolveBeforeInvoke -Configuration $cfg)

                $resolved.Count | Verify-Equal 2
                $resolved[0].ToString() | Verify-Equal $sb1.ToString()
                $resolved[1].ToString() | Verify-Equal $sb2.ToString()
            }
            finally {
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -LiteralPath $sandbox.Root
            }
        }

        t "discovers the convention file by walking up from Run.Path to the repo root" {
            $sandbox = New-BeforeInvokeSandbox -Bootstrap '$null = $null'
            try {
                $cfg = New-BeforeInvokeConfiguration -Sandbox $sandbox

                $resolved = @(Invoke-ResolveBeforeInvoke -Configuration $cfg)

                $resolved.Count | Verify-Equal 1
                $expected = Join-Path $sandbox.Root 'Pester.BeforeInvoke.ps1'
                $resolved[0].ToString().Contains($expected) | Verify-True
            }
            finally {
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -LiteralPath $sandbox.Root
            }
        }

        t "does not look for the convention file above the repo root" {
            $base = Join-Path ([IO.Path]::GetTempPath()) ("PesterBeforeInvoke_" + [Guid]::NewGuid().ToString('N'))
            $outer = Join-Path $base 'outer'
            $repo = Join-Path $outer 'repo'
            $sub = Join-Path $repo 'sub'
            try {
                $null = New-Item -ItemType Directory -Path $sub -Force
                $null = New-Item -ItemType Directory -Path (Join-Path $repo '.git') -Force
                # Convention file lives ABOVE the repo root and must not be picked up.
                '$null = $null' | Set-Content -LiteralPath (Join-Path $outer 'Pester.BeforeInvoke.ps1')

                $cfg = New-PesterConfiguration
                $cfg.Run.Path = $sub
                $cfg.Run.RepoRoot = $repo

                $resolved = @(Invoke-ResolveBeforeInvoke -Configuration $cfg)

                $resolved.Count | Verify-Equal 0
            }
            finally {
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -LiteralPath $base
            }
        }

        t "returns each discovered convention file only once across multiple paths" {
            $sandbox = New-BeforeInvokeSandbox -Bootstrap '$null = $null'
            try {
                $sub2 = Join-Path $sandbox.Root 'sub2'
                $null = New-Item -ItemType Directory -Path $sub2 -Force

                $cfg = New-PesterConfiguration
                $cfg.Run.Path = @($sandbox.Sub, $sub2)
                $cfg.Run.RepoRoot = $sandbox.Root

                $resolved = @(Invoke-ResolveBeforeInvoke -Configuration $cfg)

                $resolved.Count | Verify-Equal 1
            }
            finally {
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -LiteralPath $sandbox.Root
            }
        }

        t "returns nothing when there is no convention file and no option" {
            $sandbox = New-BeforeInvokeSandbox
            try {
                $cfg = New-BeforeInvokeConfiguration -Sandbox $sandbox

                $resolved = @(Invoke-ResolveBeforeInvoke -Configuration $cfg)

                $resolved.Count | Verify-Equal 0
            }
            finally {
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -LiteralPath $sandbox.Root
            }
        }
    }

    b "Invoke-Pester with Run.BeforeInvoke" {
        t "runs the convention file in the caller's scope before the run" {
            $sandbox = New-BeforeInvokeSandbox -Bootstrap '$global:PesterBeforeInvokeMarker = "ran"'
            $global:PesterBeforeInvokeMarker = $null
            try {
                $cfg = New-BeforeInvokeConfiguration -Sandbox $sandbox
                $r = Invoke-Pester -Configuration $cfg

                $global:PesterBeforeInvokeMarker | Verify-Equal "ran"
                $r | Verify-NotNull
            }
            finally {
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -LiteralPath $sandbox.Root
                Remove-Variable -Scope Global -Name PesterBeforeInvokeMarker -ErrorAction SilentlyContinue
            }
        }

        t "lets the convention file provide configuration via `$PesterPreference" {
            $bootstrap = @'
$PesterPreference = New-PesterConfiguration
$PesterPreference.Filter.Tag = 'only'
$PesterPreference.Output.Verbosity = 'None'
'@
            $sandbox = New-BeforeInvokeSandbox -Bootstrap $bootstrap
            try {
                $cfg = New-BeforeInvokeConfiguration -Sandbox $sandbox

                # Isolate the $PesterPreference the bootstrap defines to this child scope.
                $r = & { Invoke-Pester -Configuration $cfg }

                # Only the 'only'-tagged test should run, proving the bootstrap's filter was applied.
                $r.PassedCount | Verify-Equal 1
                $r.NotRunCount | Verify-Equal 1
            }
            finally {
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -LiteralPath $sandbox.Root
            }
        }

        t "runs explicit Run.BeforeInvoke scriptblocks and ignores the convention file" {
            $sandbox = New-BeforeInvokeSandbox -Bootstrap 'throw "the convention file must be ignored"'
            $global:PesterBeforeInvokeExplicit = $null
            try {
                $cfg = New-BeforeInvokeConfiguration -Sandbox $sandbox
                $cfg.Run.BeforeInvoke = { $global:PesterBeforeInvokeExplicit = "yes" }

                $r = Invoke-Pester -Configuration $cfg

                $global:PesterBeforeInvokeExplicit | Verify-Equal "yes"
                $r | Verify-NotNull
            }
            finally {
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -LiteralPath $sandbox.Root
                Remove-Variable -Scope Global -Name PesterBeforeInvokeExplicit -ErrorAction SilentlyContinue
            }
        }

        t "is skipped for nested Pester-in-Pester runs" {
            # Inner tree with its own convention file - it must NOT run because it is invoked from
            # inside a test (nested run).
            $inner = New-BeforeInvokeSandbox -Bootstrap '$global:PesterBeforeInvokeCount++' -Test 'Describe "inner" { It "x" { 1 | Should -Be 1 } }'
            $innerPath = $inner.Sub -replace '\\', '/'
            $innerRoot = $inner.Root -replace '\\', '/'

            $outerTest = @"
Describe 'outer' {
    It 'runs a nested Invoke-Pester' {
        `$c = New-PesterConfiguration
        `$c.Run.Path = '$innerPath'
        `$c.Run.RepoRoot = '$innerRoot'
        `$c.Run.PassThru = `$true
        `$c.Output.Verbosity = 'None'
        `$null = Invoke-Pester -Configuration `$c
        1 | Should -Be 1
    }
}
"@
            $outer = New-BeforeInvokeSandbox -Bootstrap '$global:PesterBeforeInvokeCount++' -Test $outerTest
            $global:PesterBeforeInvokeCount = 0
            try {
                $cfg = New-BeforeInvokeConfiguration -Sandbox $outer
                $null = Invoke-Pester -Configuration $cfg

                # Only the top-level bootstrap ran; the nested one was skipped.
                $global:PesterBeforeInvokeCount | Verify-Equal 1
            }
            finally {
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -LiteralPath $outer.Root
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -LiteralPath $inner.Root
                Remove-Variable -Scope Global -Name PesterBeforeInvokeCount -ErrorAction SilentlyContinue
            }
        }
    }
}
