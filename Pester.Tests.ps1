﻿$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$manifestPath   = (Join-Path $here 'Pester.psd1')
$changeLogPath = (Join-Path $here 'CHANGELOG.md')

# DO NOT CHANGE THIS TAG NAME; IT AFFECTS THE CI BUILD.

Describe -Tags 'VersionChecks' "Pester manifest and changelog" {
    $script:manifest = $null
    It "has a valid manifest" {
        {
            $script:manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop -WarningAction SilentlyContinue
        } | Should Not Throw
    }

    It "has a valid name in the manifest" {
        $script:manifest.Name | Should Be Pester
    }

    It "has a valid guid in the manifest" {
        $script:manifest.Guid | Should Be 'a699dea5-2c73-4616-a270-1f7abb777e71'
    }

    It "has a valid version in the manifest" {
        $script:manifest.Version -as [Version] | Should Not BeNullOrEmpty
    }

    $script:changelogVersion = $null
    It "has a valid version in the changelog" {

        foreach ($line in (Get-Content $changeLogPath))
        {
            if ($line -match "^\D*(?<Version>(\d+\.){1,3}\d+)")
            {
                $script:changelogVersion = $matches.Version
                break
            }
        }
        $script:changelogVersion                | Should Not BeNullOrEmpty
        $script:changelogVersion -as [Version]  | Should Not BeNullOrEmpty
    }

    It "changelog and manifest versions are the same" {
        $script:changelogVersion -as [Version] | Should be ( $script:manifest.Version -as [Version] )
    }

    if (Get-Command git.exe -ErrorAction SilentlyContinue)
    {
        $skipVersionTest = -not [bool]((git remote -v 2>&1) -match "github.com/Pester/")
        $script:tagVersion = $null
        It "is tagged with a valid version" -skip:$skipVersionTest {
            $thisCommit = git.exe log --decorate --oneline HEAD~1..HEAD

            if ($thisCommit -match 'tag:\s*(\d+(?:\.\d+)*)')
            {
                $script:tagVersion = $matches[1]
            }

            $script:tagVersion                  | Should Not BeNullOrEmpty
            $script:tagVersion -as [Version]    | Should Not BeNullOrEmpty
        }

        It "all versions are the same" -skip:$skipVersionTest {
            $script:changelogVersion -as [Version] | Should be ( $script:manifest.Version -as [Version] )
            $script:manifest.Version -as [Version] | Should be ( $script:tagVersion -as [Version] )
        }

    }
}

if ($PSVersionTable.PSVersion.Major -ge 3)
{
    $error.Clear()
    Describe 'Clean treatment of the $error variable' {
        Context 'A Context' {
            It 'Performs a successful test' {
                $true | Should Be $true
            }
        }

        It 'Did not add anything to the $error variable' {
            $error.Count | Should Be 0
        }
    }

    InModuleScope Pester {
        Describe 'SafeCommands table' {
            $path = $ExecutionContext.SessionState.Module.ModuleBase
            $filesToCheck = Get-ChildItem -Path $path -Recurse -Include *.ps1,*.psm1 -Exclude *.Tests.ps1
            $callsToSafeCommands = @(
                foreach ($file in $filesToCheck)
                {
                    $tokens = $parseErrors = $null
                    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref] $tokens, [ref] $parseErrors)
                    $filter = {
                        $args[0] -is [System.Management.Automation.Language.CommandAst] -and
                        $args[0].InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Ampersand -and
                        $args[0].CommandElements[0] -is [System.Management.Automation.Language.IndexExpressionAst] -and
                        $args[0].CommandElements[0].Target -is [System.Management.Automation.Language.VariableExpressionAst] -and
                        $args[0].CommandElements[0].Target.VariablePath.UserPath -match '^(?:script:)?SafeCommands$'
                    }

                    $ast.FindAll($filter, $true)
                }
            )

            $uniqueSafeCommands = $callsToSafeCommands | ForEach-Object { $_.CommandElements[0].Index.Value } | Select-Object -Unique

            $missingSafeCommands = $uniqueSafeCommands | Where { -not $script:SafeCommands.ContainsKey($_) }

            # These commands are conditionally added to the safeCommands table due to Nano / Core versus PSv2 compatibility; one will always
            # be missing, and can be ignored.
            $missingSafeCommands = $missingSafeCommands | Where { @('Get-WmiObject', 'Get-CimInstance') -notcontains $_ }

            It 'The SafeCommands table contains all commands that are called from the module' {
                $missingSafeCommands | Should Be $null
            }
        }
    }
}

Describe 'Public API' {
    It 'all non-deprecated, non-internal public commands use CmdletBinding' {
        $r = Get-Command -Module Pester |
        Where { $_.CommandType -ne 'Alias' } | # Get-Command outputs aliases in PowerShell 2
        Where { -not $_.CmdletBinding } |
        ForEach { $_.Name } |
        Where {
            @(
                'Get-TestDriveItem' # deprecated in 4.0
                'SafeGetCommand' # Pester internal
                'GetPesterPsVersion' # Pester internal
                'GetPesterOs' # Pester internal
                'Get-TempDirectory' # Pester internal
                'Setup' # deprecated
            ) -notcontains $_
        }
        $r | Should beNullOrEmpty
    }
}

Describe 'Style rules' {
    $pesterRoot = (Get-Module Pester).ModuleBase

    $files = @(
        Get-ChildItem $pesterRoot\* -Include *.ps1,*.psm1
        Get-ChildItem (Join-Path $pesterRoot 'Functions') -Include *.ps1,*.psm1 -Recurse
    )

    It 'Pester source files contain no trailing whitespace' {
        $badLines = @(
            foreach ($file in $files)
            {
                $lines = [System.IO.File]::ReadAllLines($file.FullName)
                $lineCount = $lines.Count

                for ($i = 0; $i -lt $lineCount; $i++)
                {
                    if ($lines[$i] -match '\s+$') {
                        'File: {0}, Line: {1}' -f $file.FullName, ($i + 1)
                    }
                }
            }
        )

        if ($badLines.Count -gt 0)
        {
            throw "The following $($badLines.Count) lines contain trailing whitespace: `r`n`r`n$($badLines -join "`r`n")"
        }
    }
    It 'Spaces are used for indentation in all code files, not tabs' {
        $badLines = @(
            foreach ($file in $files)
            {
                $lines = [System.IO.File]::ReadAllLines($file.FullName)
                $lineCount = $lines.Count

                for ($i = 0; $i -lt $lineCount; $i++)
                {
                    if ($lines[$i] -match '^[  ]*\t|^\t|^\t[  ]*') {
                        'File: {0}, Line: {1}' -f $file.FullName, ($i + 1)
                    }
                }
            }
        )

        if ($badLines.Count -gt 0)
        {
            throw "The following $($badLines.Count) lines start with a tab character: `r`n`r`n$($badLines -join "`r`n")"
        }
    }

    It 'Pester Source Files all end with a newline' {
        $badFiles = @(
            foreach ($file in $files) {
                $string = [System.IO.File]::ReadAllText($file.FullName)
                if ($string.Length -gt 0 -and $string[-1] -ne "`n") {
                    $file.FullName
                }
            }
        )

        if ($badFiles.Count -gt 0) {
            throw "The following files do not end with a newline: `r`n`r`n$($badFiles -join "`r`n")"
        }
    }
}

InModuleScope Pester {
    Describe 'ResolveTestScripts' {
        Setup -File SomeFile.ps1
        Setup -File SomeFile.Tests.ps1
        Setup -File SomeOtherFile.ps1
        Setup -File SomeOtherFile.Tests.ps1

        It 'Resolves non-wildcarded file paths regardless of whether the file ends with Tests.ps1' {
            $result = @(ResolveTestScripts (Join-Path $TestDrive 'SomeOtherFile.ps1'))
            $result.Count | Should Be 1
            $result[0].Path | Should Be (Join-Path $TestDrive 'SomeOtherFile.ps1')
        }

        It 'Finds only *.Tests.ps1 files when the path contains wildcards' {
            $result = @(ResolveTestScripts (Join-Path $TestDrive '*.ps1'))
            $result.Count | Should Be 2

            $paths = $result | Select-Object -ExpandProperty Path

            ($paths -contains (Join-Path $TestDrive 'SomeFile.Tests.ps1')) | Should Be $true
            ($paths -contains (Join-Path $TestDrive 'SomeOtherFile.Tests.ps1')) | Should Be $true
        }

        It 'Finds only *.Tests.ps1 files when the path refers to a directory and does not contain wildcards' {
            $result = @(ResolveTestScripts $TestDrive)

            $result.Count | Should Be 2

            $paths = $result | Select-Object -ExpandProperty Path

            ($paths -contains ( Join-Path $TestDrive 'SomeFile.Tests.ps1')) | Should Be $true
            ($paths -contains ( Join-Path $TestDrive 'SomeOtherFile.Tests.ps1')) | Should Be $true
        }

        It 'Assigns empty array and hashtable to the Arguments and Parameters properties when none are specified by the caller' {
            $result = @(ResolveTestScripts (Join-Path $TestDrive 'SomeFile.ps1'))

            $result.Count | Should Be 1
            $result[0].Path | Should Be (Join-Path $TestDrive 'SomeFile.ps1')

            ,$result[0].Arguments | Should Not Be $null
            ,$result[0].Parameters | Should Not Be $null

            $result[0].Arguments.GetType() | Should Be ([object[]])
            $result[0].Arguments.Count | Should Be 0

            $result[0].Parameters.GetType() | Should Be ([hashtable])
            $result[0].Parameters.PSBase.Count | Should Be 0
        }

        Context 'Passing in Dictionaries instead of Strings' {
            It 'Allows the use of a "P" key instead of "Path"' {
                $result = @(ResolveTestScripts @{ P = (Join-Path $TestDrive 'SomeFile.ps1') })

                $result.Count | Should Be 1
                $result[0].Path | Should Be (Join-Path $TestDrive 'SomeFile.ps1')
            }

            $testArgs = @('I am a string')
            It 'Allows the use of an "Arguments" key in the dictionary' {
                $result = @(ResolveTestScripts @{ Path = (Join-Path $TestDrive 'SomeFile.ps1'); Arguments = $testArgs })

                $result.Count | Should Be 1
                $result[0].Path | Should Be (Join-Path $TestDrive 'SomeFile.ps1')

                $result[0].Arguments.Count | Should Be 1
                $result[0].Arguments[0] | Should Be 'I am a string'
            }

            It 'Allows the use of an "Args" key in the dictionary' {
                $result = @(ResolveTestScripts @{ Path = (Join-Path $TestDrive 'SomeFile.ps1'); Args = $testArgs })

                $result.Count | Should Be 1
                $result[0].Path | Should Be (Join-Path $TestDrive 'SomeFile.ps1')

                $result[0].Arguments.Count | Should Be 1
                $result[0].Arguments[0] | Should Be 'I am a string'
            }

            It 'Allows the use of an "A" key in the dictionary' {
                $result = @(ResolveTestScripts @{ Path = (Join-Path $TestDrive 'SomeFile.ps1'); A = $testArgs })

                $result.Count | Should Be 1
                $result[0].Path | Should Be (Join-Path $TestDrive 'SomeFile.ps1')

                $result[0].Arguments.Count | Should Be 1
                $result[0].Arguments[0] | Should Be 'I am a string'
            }

            $testParams = @{ MyKey = 'MyValue' }
            It 'Allows the use of a "Parameters" key in the dictionary' {
                $result = @(ResolveTestScripts @{ Path = (Join-Path $TestDrive 'SomeFile.ps1'); Parameters = $testParams })

                $result.Count | Should Be 1
                $result[0].Path | Should Be (Join-Path $TestDrive 'SomeFile.ps1')

                $result[0].Parameters.PSBase.Count | Should Be 1
                $result[0].Parameters['MyKey'] | Should Be 'MyValue'
            }

            It 'Allows the use of a "Params" key in the dictionary' {
                $result = @(ResolveTestScripts @{ Path = (Join-Path $TestDrive 'SomeFile.ps1'); Params = $testParams })

                $result.Count | Should Be 1
                $result[0].Path | Should Be (Join-Path $TestDrive 'SomeFile.ps1')

                $result[0].Parameters.PSBase.Count | Should Be 1
                $result[0].Parameters['MyKey'] | Should Be 'MyValue'
            }

            It 'Throws an error if no Path is specified' {
                { ResolveTestScripts @{} } | Should Throw
            }

            It 'Throws an error if a Parameters key is used, but does not contain an IDictionary object' {
                { ResolveTestScripts @{ P='P'; Params = 'A string' } } | Should Throw
            }
        }
    }
}
