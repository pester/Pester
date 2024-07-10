Set-StrictMode -Version Latest
BeforeAll {
    $manifestPath = (Join-Path $PSScriptRoot 'Pester.psd1')
    $changeLogPath = (Join-Path $PSScriptRoot 'CHANGELOG.md')
}

# DO NOT CHANGE THIS TAG NAME; IT AFFECTS THE CI BUILD.
Describe -Tags 'VersionChecks' "Pester manifest and changelog" {
    BeforeAll {
        $script:manifest = $null
        $script:tagVersion = $null
        $script:tagVersionShort = $null
        $script:changelogVersion = $null
        $script:changelogVersionShort = $null
        $script:tagPrerelease = $null
    }

    It "has a valid manifest" {
        {
            $script:manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop -WarningAction SilentlyContinue
        } | Should -Not -Throw
    }

    It "has a valid name in the manifest" {
        $script:manifest.Name | Should -Be Pester
    }

    It "has a valid guid in the manifest" {
        $script:manifest.Guid | Should -Be 'a699dea5-2c73-4616-a270-1f7abb777e71'
    }

    if ((Get-Command -Name git -ErrorAction SilentlyContinue) -and (Get-Item ".git" -ErrorAction Ignore)) {
        if ([bool]((git remote -v 2>&1) -match "github.com/Pester/")) {
            It "is tagged with a valid version" {
                $thisCommit = git log --decorate --oneline HEAD~1..HEAD

                if ($thisCommit -match 'tag:\s*(.*?)[,)]') {
                    $script:tagVersion = $matches[1]
                    $script:tagVersionShort, $script:tagPrerelease = $script:tagVersion -split "-", 2
                }

                $script:tagVersion                  | Should -Not -BeNullOrEmpty
                $script:tagVersionShort -as [Version]    | Should -Not -BeNullOrEmpty
            }

            It "has valid release notes in the manifest" {
                $script:manifest.PrivateData.PSData.ReleaseNotes | Should -Be "https://github.com/pester/Pester/releases/tag/$script:tagVersion"
            }

            It "tag and changelog versions are the same" {

                foreach ($line in (Get-Content $changeLogPath)) {
                    if ($line -match "^\s*##\s+(?<Version>.*?)\s") {
                        $script:changelogVersion = $matches.Version
                        $script:changelogVersionShort = $script:changelogVersion -replace "-.*$", ''
                        break
                    }
                }

                $script:changelogVersion      | Should -Be $script:tagVersion
                $script:changelogVersionShort | Should -Be $script:tagVersionShort
            }

            It "tag and changelog versions are the same" {
                $script:changelogVersion | Should -Be $script:tagVersion
            }

            It "all short versions are the same" {
                $script:changelogVersionShort -as [Version] | Should -Be ( $script:manifest.Version -as [Version] )
                $script:manifest.Version -as [Version] | Should -Be ( $script:tagVersionShort -as [Version] )
            }
        }
    }

    It "has valid pre-release suffix in manifest (empty for stable version)" {
        # might be empty or null, as well as the tagPrerelase. we need empty string to eq $null but not to eq any other value
        $prereleaseFromManifest = $script:manifest.PrivateData.PSData.Prerelease | where { $_ }
        $prereleaseFromManifest | Should -Be $script:tagPrerelease
    }
}

if ($PSVersionTable.PSVersion.Major -ge 3) {
    Describe 'Clean treatment of the $error variable' {
        BeforeAll {
            $error.Clear()
        }
        Context 'A Context' {
            It 'Performs a successful test' {
                $true | Should -Be $true
            }
        }

        It 'Did not add anything to the $error variable' {
            $error.Count | Should -Be 0
        }
    }

    InPesterModuleScope {
        Describe 'SafeCommands table' {
            BeforeAll {
                $path = $ExecutionContext.SessionState.Module.ModuleBase
                $filesToCheck = Get-ChildItem -Path $path -Recurse -Include *.ps1, *.psm1 -Exclude *.Tests.ps1
                $callsToSafeCommands = @(
                    foreach ($file in $filesToCheck) {
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
                # Also add the two possible commands uname and id which would be found on non-Windows platforms
                $missingSafeCommands = $missingSafeCommands | Where { @('Get-WmiObject', 'Get-CimInstance', 'uname', 'id') -notcontains $_ }
            }

            It 'The SafeCommands table contains all commands that are called from the module' {
                $missingSafeCommands | Should -Be $null
            }
        }
    }
}

Describe 'Public API' {
    It 'all non-deprecated, non-internal public commands use CmdletBinding' {
        $r = Get-Command -Module Pester |
            ? { $_.CommandType -ne 'Alias' } | # Get-Command outputs aliases in PowerShell 2
            ? { -not $_.CmdletBinding } |
            % { $_.Name }
        $r | Should -beNullOrEmpty
    }
}

Describe 'Style rules' -Tag StyleRules {
    BeforeAll {
        $pesterRoot = (Get-Module Pester).ModuleBase

        $files = @(
            Get-ChildItem $pesterRoot\* -Include *.ps1, *.psm1, *.psd1
            Get-ChildItem (Join-Path $pesterRoot 'en-US') -Include *.ps1, *.psm1, *.psd1, *.txt -Recurse
            Get-ChildItem (Join-Path $pesterRoot 'Functions') -Include *.ps1, *.psm1, *.psd1 -Recurse
            Get-ChildItem (Join-Path $pesterRoot 'Dependencies') -Include *.ps1, *.psm1, *.psd1 -Recurse
        )
    }

    It 'Pester source files contain no trailing whitespace' {
        $badLines = @(
            foreach ($file in $files) {
                $lines = [System.IO.File]::ReadAllLines($file.FullName)
                $lineCount = $lines.Count

                for ($i = 0; $i -lt $lineCount; $i++) {
                    if ($lines[$i] -match '\s+$') {
                        'File: {0}, Line: {1}' -f $file.FullName, ($i + 1)
                    }
                }
            }
        )

        if ($badLines.Count -gt 0) {
            throw "The following $($badLines.Count) lines contain trailing whitespace: $([System.Environment]::NewLine)$([System.Environment]::NewLine)$($badLines -join "$([System.Environment]::NewLine)")"
        }
    }
    It 'Spaces are used for indentation in all code files, not tabs' {
        $badLines = @(
            foreach ($file in $files) {
                $lines = [System.IO.File]::ReadAllLines($file.FullName)
                $lineCount = $lines.Count

                for ($i = 0; $i -lt $lineCount; $i++) {
                    if ($lines[$i] -match '^[  ]*\t|^\t|^\t[  ]*') {
                        'File: {0}, Line: {1}' -f $file.FullName, ($i + 1)
                    }
                }
            }
        )

        if ($badLines.Count -gt 0) {
            throw "The following $($badLines.Count) lines start with a tab character: $([System.Environment]::NewLine)$([System.Environment]::NewLine)$($badLines -join "$([System.Environment]::NewLine)")"
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
            throw "The following files do not end with a newline: $([System.Environment]::NewLine)$([System.Environment]::NewLine)$($badFiles -join "$([System.Environment]::NewLine)")"
        }
    }
}

InPesterModuleScope {
    Describe 'Find-File' {
        BeforeAll {
            New-Item -ItemType File 'TestDrive:\SomeFile.ps1'
            New-Item -ItemType File 'TestDrive:\SomeFile.Tests.ps1'
            New-Item -ItemType File 'TestDrive:\SomeOtherFile.ps1'
            New-Item -ItemType File 'TestDrive:\SomeOtherFile.Tests.ps1'
        }

        It 'Resolves non-wildcarded file paths regardless of whether the file ends with Tests.ps1' {
            $result = @(Find-File 'TestDrive:\SomeOtherFile.ps1' -Extension ".Tests.ps1")
            $result.Count | Should -Be 1
            $result[0].UnresolvedPath | Should -Be 'TestDrive:\SomeOtherFile.ps1'
        }

        It 'Finds only *.Tests.ps1 files when the path contains wildcards' {
            $result = @(Find-File 'TestDrive:\*.ps1' -Extension ".Tests.ps1")
            $result.Count | Should -Be 2

            $paths = $result | Select-Object -ExpandProperty FullName
            $testDrive = (Get-PSDrive TestDrive).Root
            ($paths -contains (Join-Path $testDrive "SomeFile.Tests.ps1")) | Should -Be $true
            ($paths -contains (Join-Path $testDrive "SomeOtherFile.Tests.ps1")) | Should -Be $true
        }

        It 'Finds only *.Tests.ps1 files when the path refers to a directory and does not contain wildcards' {
            $result = @(Find-File 'TestDrive:\' -Extension ".Tests.ps1")

            $result.Count | Should -Be 2

            $paths = $result | Select-Object -ExpandProperty FullName
            $testDrive = (Get-PSDrive TestDrive).Root
            ($paths -contains (Join-Path $testDrive "SomeFile.Tests.ps1")) | Should -Be $true
            ($paths -contains (Join-Path $testDrive "SomeOtherFile.Tests.ps1")) | Should -Be $true
        }

        It 'Deduplicates filepaths when the provided paths overlaps' {
            $result = @(Find-File 'TestDrive:\*.ps1','TestDrive:\*.ps1' -Extension '.Tests.ps1')
            $result.Count | Should -Be 2
        }

        # It 'Assigns empty array and hashtable to the Arguments and Parameters properties when none are specified by the caller' {
        #     $result = @(Find-File 'TestDrive:\SomeFile.ps1' -Extension ".Tests.ps1")

        #     $result.Count | Should -Be 1
        #     $result[0].UnresolvedPath | Should -Be 'TestDrive:\SomeFile.ps1'

        #     , $result[0].Arguments | Should -Not -Be $null
        #     , $result[0].Parameters | Should -Not -Be $null

        #     $result[0].Arguments.GetType() | Should -Be ([object[]])
        #     $result[0].Arguments.Count | Should -Be 0

        #     $result[0].Parameters.GetType() | Should -Be ([hashtable])
        #     $result[0].Parameters.PSBase.Count | Should -Be 0
        # }

        # Context 'Passing in Dictionaries instead of Strings' {
        #     It 'Allows the use of a "p" key instead of "Path"' {
        #         $result = @(Find-RSpecTestFile @{ p = 'TestDrive:\SomeFile.ps1' })

        #         $result.Count | Should -Be 1
        #         $result[0].Path | Should -Be 'TestDrive:\SomeFile.ps1'
        #     }

        #     $testArgs = @('I am a string')
        #     It 'Allows the use of an "Arguments" key in the dictionary' {
        #         $result = @(Find-RSpecTestFile @{ Path = 'TestDrive:\SomeFile.ps1'; Arguments = $testArgs })

        #         $result.Count | Should -Be 1
        #         $result[0].Path | Should -Be 'TestDrive:\SomeFile.ps1'

        #         $result[0].Arguments.Count | Should -Be 1
        #         $result[0].Arguments[0] | Should -Be 'I am a string'
        #     }

        #     It 'Allows the use of an "args" key in the dictionary' {
        #         $result = @(Find-RSpecTestFile @{ Path = 'TestDrive:\SomeFile.ps1'; args = $testArgs })

        #         $result.Count | Should -Be 1
        #         $result[0].Path | Should -Be 'TestDrive:\SomeFile.ps1'

        #         $result[0].Arguments.Count | Should -Be 1
        #         $result[0].Arguments[0] | Should -Be 'I am a string'
        #     }

        #     It 'Allows the use of an "a" key in the dictionary' {
        #         $result = @(Find-RSpecTestFile @{ Path = 'TestDrive:\SomeFile.ps1'; a = $testArgs })

        #         $result.Count | Should -Be 1
        #         $result[0].Path | Should -Be 'TestDrive:\SomeFile.ps1'

        #         $result[0].Arguments.Count | Should -Be 1
        #         $result[0].Arguments[0] | Should -Be 'I am a string'
        #     }

        #     $testParams = @{ MyKey = 'MyValue' }
        #     It 'Allows the use of a "Parameters" key in the dictionary' {
        #         $result = @(Find-RSpecTestFile @{ Path = 'TestDrive:\SomeFile.ps1'; Parameters = $testParams })

        #         $result.Count | Should -Be 1
        #         $result[0].Path | Should -Be 'TestDrive:\SomeFile.ps1'

        #         $result[0].Parameters.PSBase.Count | Should -Be 1
        #         $result[0].Parameters['MyKey'] | Should -Be 'MyValue'
        #     }

        #     It 'Allows the use of a "params" key in the dictionary' {
        #         $result = @(Find-RSpecTestFile @{ Path = 'TestDrive:\SomeFile.ps1'; params = $testParams })

        #         $result.Count | Should -Be 1
        #         $result[0].Path | Should -Be 'TestDrive:\SomeFile.ps1'

        #         $result[0].Parameters.PSBase.Count | Should -Be 1
        #         $result[0].Parameters['MyKey'] | Should -Be 'MyValue'
        #     }

        #     It 'Allows to pass test script string' {
        #         $result = @(Find-RSpecTestFile @{ Script = "Test script string" })

        #         $result.Count | Should -Be 1
        #         $result[0].Script | Should -Be "Test script string"

        #         $result[0].Path | Should -BeNullOrEmpty
        #         $result[0].Parameters | Should -BeNullOrEmpty
        #         $result[0].Arguments |  Should -BeNullOrEmpty
        #     }

        # It 'Throws an error if no Path is specified' {
        #     { Find-RSpecTestFile @{} } | Should -Throw
        # }

        # It 'Throws an error if a Parameters key is used, but does not contain an IDictionary object' {
        #     { Find-RSpecTestFile @{ P = 'P'; Params = 'A string' } } | Should -Throw
        # }
        #}
    }
}

Describe 'Set-StrictMode for all tests files' {
    It 'Pester tests files start with explicit declaration of StrictMode set to Latest' {

        $files = Get-ChildItem $PSScriptRoot\../tst/ -Include *.Tests.ps1 -Recurse

        $UnstrictTests = @(
            foreach ($file in $files) {
                $lines = [System.IO.File]::ReadAllLines($file.FullName)
                $lineCount = $lines.Count
                if ($lineCount -lt 3) {
                    $linesToRead = $lineCount
                }
                else {
                    $linestoRead = 3
                }
                $n = 0
                for ($i = 0; $i -lt $linestoRead; $i++) {
                    if ($lines[$i] -match '^\s*Set-StrictMode\s+-Version\s+Latest') {
                        $n++
                    }
                }
                if ( $n -eq 0 ) {
                    $file.FullName
                }
            }
        )
        if ($UnstrictTests.Count -gt 0) {
            throw "The following $($UnstrictTests.Count) tests files doesn't contain strict mode declaration in the first three lines: $([System.Environment]::NewLine)$([System.Environment]::NewLine)$($UnstrictTests -join "$([System.Environment]::NewLine)")"
        }
    }
}

InModuleScope -ModuleName Pester {
    Describe "Contain-AnyStringLike" {

        It 'Given a filter <filter> that does not match any items in collection <collection> it returns $false' -TestCases @(
            @{ Filter = "Unit"; Collection = "Integration" }
            @{ Filter = "*Unit*"; Collection = "Integration" }
            @{ Filter = "*Unit*", "IntegrationTest"; Collection = "Integration" }
            @{ Filter = "Unit"; Collection = "Low", "Medium", "High" }
            @{ Filter = "*Unit*"; Collection = "Low", "Medium", "High" }
        ) {
            Contain-AnyStringLike -Filter $Filter -Collection $Collection |
                Should -BeFalse
        }

        It 'Given a filter <filter> that matches one or more items in collection <collection> it returns $true' -TestCases @(
            @{ Filter = "Unit"; Collection = "Unit" }
            @{ Filter = "*Unit*"; Collection = "UnitTest" }
            @{ Filter = "UnitTest", "IntegrationTest"; Collection = "UnitTest" }
            @{ Filter = "Low"; Collection = "Low", "Medium", "High" }
            @{ Filter = "Low", "Medium"; Collection = "Low", "Medium", "High" }
            @{ Filter = "l*"; Collection = "Low", "Medium", "High" }
        ) {
            Contain-AnyStringLike -Filter $Filter -Collection $Collection |
                Should -BeTrue
        }
    }
}
