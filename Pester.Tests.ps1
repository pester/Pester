Set-StrictMode -Version Latest

[string]$here = Split-Path -Parent $MyInvocation.MyCommand.Path
[string]$manifestPath  = (Join-Path $here 'Pester.psd1')
[string]$changeLogPath = (Join-Path $here 'CHANGELOG.md')

# DO NOT CHANGE THIS TAG NAME; IT AFFECTS THE CI BUILD.

Describe -Tags 'VersionChecks' 'Pester manifest and changelog' {
    $script:manifest              = $null
    $script:tagVersion            = $null
    $script:tagVersionShort       = $null
    $script:changelogVersion      = $null
    $script:changelogVersionShort = $null
    $script:tagPrerelease         = $null

    It 'has a valid manifest' {
        {
            $script:manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop -WarningAction SilentlyContinue
        } | Should -Not -Throw
    }

    It 'has a valid name in the manifest' {
        $script:manifest.Name | Should -Be 'Pester'
    }

    It 'has a valid guid in the manifest' {
        $script:manifest.Guid | Should -Be 'a699dea5-2c73-4616-a270-1f7abb777e71'
    }

    If (Get-Command -Name git -ErrorAction SilentlyContinue) {
        $skipVersionTest = -not [bool]((git remote -v 2>&1) -match 'github.com/Pester/')

        It 'is tagged with a valid version' -Skip $skipVersionTest {
            $thisCommit = git log --decorate --oneline HEAD~1..HEAD

            If ($thisCommit -match 'tag:\s*(.*?)[,)]') {
                $script:tagVersion = $matches[1]
                $script:tagVersionShort, $script:tagPrerelease = $script:tagVersion -split '-', 2
            }

            $script:tagVersion      -as [Version] | Should -Not -BeNullOrEmpty
            $script:tagVersionShort -as [Version] | Should -Not -BeNullOrEmpty
        }
    }

    It 'has valid release notes in the manifest' {
        $script:manifest.PrivateData.PSData.ReleaseNotes | Should -Be "https://github.com/pester/Pester/releases/tag/$script:tagVersion"
    }

    It 'has valid pre-release suffix in manifest (empty for stable version)' {
        # might be empty or null, as well as the tagPrerelase. we need empty string to eq $null but not to eq any other value
        $prereleaseFromManifest = $script:manifest.PrivateData.PSData.Prerelease | Where-Object { $_ }
        $prereleaseFromManifest | Should -Be $script:tagPrerelease
    }

    It 'tag and changelog versions are the same' {

        ForEach ($line in (Get-Content $changeLogPath)) {
            If ($line -match '^\s*##\s+(?<Version>.*?)\s') {
                $script:changelogVersion = $matches.Version
                $script:changelogVersionShort = $script:changelogVersion -replace '-.*$', ''
                Break
            }
        }

        $script:changelogVersion      -as [Version] | Should -Be $script:tagVersion
        $script:changelogVersionShort -as [Version] | Should -Be $script:tagVersionShort
    }

    It 'tag and changelog versions are the same' {
        $script:changelogVersion | Should -Be $script:tagVersion
    }

    It 'all short versions are the same' -Skip $skipVersionTest {
        $script:changelogVersionShort -as [Version] | Should -Be ( $script:manifest.Version -as [Version] )
        $script:manifest.Version      -as [Version] | Should -Be ( $script:tagVersionShort  -as [Version] )
    }
}

If ($PSVersionTable.PSVersion.Major -ge 3) {
    $error.Clear()
    Describe 'Clean treatment of the $error variable' {
        Context 'A Context' {
            It 'Performs a successful test' {
                $true | Should -Be $true
            }
        }

        It 'Did not add anything to the $error variable' {
            $error.Count | Should -Be 0
        }
    }

    InModuleScope Pester {
        Describe 'SafeCommands table' {
            $path = $ExecutionContext.SessionState.Module.ModuleBase
            $filesToCheck = Get-ChildItem -Path $path -Recurse -Include *.ps1, *.psm1 -Exclude *.Tests.ps1
            $callsToSafeCommands = @(
                ForEach ($file in $filesToCheck) {
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

            $uniqueSafeCommands  = $callsToSafeCommands | ForEach-Object { $_.CommandElements[0].Index.Value } | Select-Object -Unique
            $missingSafeCommands = $uniqueSafeCommands  | Where-Object   { -not $script:SafeCommands.ContainsKey($_) }

            # These commands are conditionally added to the safeCommands table due to Nano / Core versus PSv2 compatibility;
            # one will always be missing, and can be ignored.
            $missingSafeCommands = $missingSafeCommands | Where-Object   { @('Get-WmiObject', 'Get-CimInstance') -notcontains $_ }

            It 'The SafeCommands table contains all commands that are called from the module' {
                $missingSafeCommands | Should -Be $null
            }
        }
    }
}

Describe 'Public API' {
    It 'all non-deprecated, non-internal public commands use CmdletBinding' {
        $r = Get-Command -Module Pester |
            Where-Object { $_.CommandType -ne 'Alias' } | # Get-Command outputs aliases in PowerShell 2
            Where-Object { -not $_.CmdletBinding } |
            ForEach      { $_.Name } |
            Where-Object {
                @(
                    'Get-TestDriveItem' # deprecated in 4.0
                    'SafeGetCommand' # Pester internal
                    'Setup' # deprecated
                ) -notcontains $_
            }
        $r | Should -BeNullOrEmpty
    }
}

Describe 'Style rules' -Tag StyleRules {
    $pesterRoot = (Get-Module Pester).ModuleBase

    $files = @(
        Get-ChildItem            "$pesterRoot\*"               -Include *.ps1,*.psm1, *.psd1
        Get-ChildItem (Join-Path "$pesterRoot" 'en-US')        -Include *.ps1,*.psm1, *.psd1, *.txt -Recurse
        Get-ChildItem (Join-Path "$pesterRoot" 'Functions')    -Include *.ps1,*.psm1, *.psd1        -Recurse
        Get-ChildItem (Join-Path "$pesterRoot" 'Dependencies') -Include *.ps1,*.psm1, *.psd1        -Recurse
    )

    It 'Pester source files contain no trailing whitespace' {
        $badLines = @(
            ForEach ($file in $files) {
                $lines = [System.IO.File]::ReadAllLines($file.FullName)
                $lineCount = $lines.Count

                For ($i = 0; $i -lt $lineCount; $i++) {
                    If ($lines[$i] -match '\s+$') {
                        'File: {0}, Line: {1}' -f $file.FullName, ($i + 1)
                    }
                }
            }
        )

        If ($badLines.Count -gt 0) {
            Throw "The following $($badLines.Count) lines contain trailing whitespace: $([System.Environment]::NewLine)$([System.Environment]::NewLine)$($badLines -join $([System.Environment]::NewLine))"
        }
    }
    It 'Spaces are used for indentation in all code files, not tabs' {
        $badLines = @(
            ForEach ($file in $files) {
                $lines = [System.IO.File]::ReadAllLines($file.FullName)
                $lineCount = $lines.Count

                For ($i = 0; $i -lt $lineCount; $i++) {
                    If ($lines[$i] -match '^[  ]*\t|^\t|^\t[  ]*') {
                        'File: {0}, Line: {1}' -f $file.FullName, ($i + 1)
                    }
                }
            }
        )

        If ($badLines.Count -gt 0) {
            Throw "The following $($badLines.Count) lines start with a tab character: $([System.Environment]::NewLine)$([System.Environment]::NewLine)$($badLines -join $([System.Environment]::NewLine))"
        }
    }

    It 'Pester Source Files all end with a newline' {
        $badFiles = @(
            ForEach ($file in $files) {
                $string = [System.IO.File]::ReadAllText($file.FullName)
                If ($string.Length -gt 0 -and $string[-1] -ne "`n") {
                    $file.FullName
                }
            }
        )

        If ($badFiles.Count -gt 0) {
            Throw "The following files do not end with a newline: $([System.Environment]::NewLine)$([System.Environment]::NewLine)$($badFiles -join $([System.Environment]::NewLine))"
        }
    }
}

InModuleScope Pester {
    Describe 'ResolveTestScripts' {
        Setup -File 'SomeFile.ps1'
        Setup -File 'SomeFile.Tests.ps1'
        Setup -File 'SomeOtherFile.ps1'
        Setup -File 'SomeOtherFile.Tests.ps1'

        It 'Resolves non-wildcarded file paths regardless of whether the file ends with Tests.ps1' {
            $result = @(ResolveTestScripts (Join-Path $TestDrive 'SomeOtherFile.ps1'))
            $result.Count   | Should -Be 1
            $result[0].Path | Should -Be (Join-Path $TestDrive 'SomeOtherFile.ps1')
        }

        It 'Finds only *.Tests.ps1 files when the path contains wildcards' {
            $result = @(ResolveTestScripts (Join-Path $TestDrive '*.ps1'))
            $result.Count | Should -Be 2

            $paths = $result | Select-Object -ExpandProperty Path

            ($paths -contains (Join-Path $TestDrive 'SomeFile.Tests.ps1'))      | Should -Be $true
            ($paths -contains (Join-Path $TestDrive 'SomeOtherFile.Tests.ps1')) | Should -Be $true
        }

        It 'Finds only *.Tests.ps1 files when the path refers to a directory and does not contain wildcards' {
            $result = @(ResolveTestScripts $TestDrive)

            $result.Count | Should -Be 2

            $paths = $result | Select-Object -ExpandProperty Path

            ($paths -contains ( Join-Path $TestDrive 'SomeFile.Tests.ps1'))      | Should -Be $true
            ($paths -contains ( Join-Path $TestDrive 'SomeOtherFile.Tests.ps1')) | Should -Be $true
        }

        It 'Assigns empty array and hashtable to the Arguments and Parameters properties when none are specified by the caller' {
            $result = @(ResolveTestScripts (Join-Path $TestDrive 'SomeFile.ps1'))

            $result.Count   | Should -Be 1
            $result[0].Path | Should -Be (Join-Path $TestDrive 'SomeFile.ps1')

            ,$result[0].Arguments  | Should -Not -Be $null
            ,$result[0].Parameters | Should -Not -Be $null

            $result[0].Arguments.GetType() | Should -Be ([object[]])
            $result[0].Arguments.Count     | Should -Be 0

            $result[0].Parameters.GetType()    | Should -Be ([hashtable])
            $result[0].Parameters.PSBase.Count | Should -Be 0
        }

        Context 'Passing in Dictionaries instead of Strings' {
            It 'Allows the use of a "P" key instead of "Path"' {
                $result = @(ResolveTestScripts @{ P = (Join-Path $TestDrive 'SomeFile.ps1') })

                $result.Count   | Should -Be 1
                $result[0].Path | Should -Be (Join-Path $TestDrive 'SomeFile.ps1')
            }

            $testArgs = @('I am a string')
            It 'Allows the use of an "Arguments" key in the dictionary' {
                $result = @(ResolveTestScripts @{ Path = (Join-Path $TestDrive 'SomeFile.ps1'); Arguments = $testArgs })

                $result.Count   | Should -Be 1
                $result[0].Path | Should -Be (Join-Path $TestDrive 'SomeFile.ps1')

                $result[0].Arguments.Count | Should -Be 1
                $result[0].Arguments[0]    | Should -Be 'I am a string'
            }

            It 'Allows the use of an "Args" key in the dictionary' {
                $result = @(ResolveTestScripts @{ Path = (Join-Path $TestDrive 'SomeFile.ps1'); Args = $testArgs })

                $result.Count   | Should -Be 1
                $result[0].Path | Should -Be (Join-Path $TestDrive 'SomeFile.ps1')

                $result[0].Arguments.Count | Should -Be 1
                $result[0].Arguments[0]    | Should -Be 'I am a string'
            }

            It 'Allows the use of an "A" key in the dictionary' {
                $result = @(ResolveTestScripts @{ Path = (Join-Path $TestDrive 'SomeFile.ps1'); A = $testArgs })

                $result.Count   | Should -Be 1
                $result[0].Path | Should -Be (Join-Path $TestDrive 'SomeFile.ps1')

                $result[0].Arguments.Count | Should -Be 1
                $result[0].Arguments[0]    | Should -Be 'I am a string'
            }

            $testParams = @{ MyKey = 'MyValue' }
            It 'Allows the use of a "Parameters" key in the dictionary' {
                $result = @(ResolveTestScripts @{ Path = (Join-Path $TestDrive 'SomeFile.ps1'); Parameters = $testParams })

                $result.Count   | Should -Be 1
                $result[0].Path | Should -Be (Join-Path $TestDrive 'SomeFile.ps1')

                $result[0].Parameters.PSBase.Count | Should -Be 1
                $result[0].Parameters['MyKey']     | Should -Be 'MyValue'
            }

            It 'Allows the use of a "Params" key in the dictionary' {
                $result = @(ResolveTestScripts @{ Path = (Join-Path $TestDrive 'SomeFile.ps1'); Params = $testParams })

                $result.Count   | Should -Be 1
                $result[0].Path | Should -Be (Join-Path $TestDrive 'SomeFile.ps1')

                $result[0].Parameters.PSBase.Count | Should -Be 1
                $result[0].Parameters['MyKey']     | Should -Be 'MyValue'
            }

            It 'Throws an error if no Path is specified' {
                { ResolveTestScripts @{} } | Should -Throw
            }

            It 'Throws an error if a Parameters key is used, but does not contain an IDictionary object' {
                { ResolveTestScripts @{ P='P'; Params = 'A string' } } | Should -Throw
            }
        }
    }
}

Describe 'Assertion operators' {
    It 'Allows an operator with an identical name and test to be re-registered' {
        Function SameNameAndScript {$true}
        Add-AssertionOperator -Name SameNameAndScript -Test $function:SameNameAndScript
        { Add-AssertionOperator -Name SameNameAndScript -Test {$true} } | Should -Not -Throw
    }
    It 'Allows an operator with an identical name, test, and alias to be re-registered' {
        Function SameNameAndScriptAndAlias {$true}
        Add-AssertionOperator -Name SameNameAndScriptAndAlias -Test $function:SameNameAndScriptAndAlias -Alias SameAlias
        { Add-AssertionOperator -Name SameNameAndScriptAndAlias -Test {$true} -Alias SameAlias } | Should -Not -Throw
    }
    It 'Does not allow an operator with a different test to be registered using an existing name' {
        Function DifferentScriptBlockA {$true}
        Function DifferentScriptBlockB {$false}
        Add-AssertionOperator -Name DifferentScriptBlock -Test $function:DifferentScriptBlockA
        { Add-AssertionOperator -Name DifferentScriptBlock -Test $function:DifferentScriptBlockB } | Should -Throw
    }
    It 'Does not allow an operator with a different test to be registered using an existing alias' {
        Function DifferentAliasA { $true }
        Function DifferentAliasB { $true }
        Add-AssertionOperator -Name DifferentAliasA -Test $function:DifferentAliasA -Alias DifferentAliasTest
        { Add-AssertionOperator -Name DifferentAliasB -Test $function:DifferentAliasB -Alias DifferentAliasTest } | Should -Throw
    }
}

Describe 'Set-StrictMode for all tests files' {
    $pesterRoot = (Get-Module Pester).ModuleBase

    $files = @(
        Get-ChildItem            "$pesterRoot\*"               -Include *.Tests.ps1
        Get-ChildItem (Join-Path "$pesterRoot" 'en-US')        -Include *.Tests.ps1 -Recurse
        Get-ChildItem (Join-Path "$pesterRoot" 'Functions')    -Include *.Tests.ps1 -Recurse
        Get-ChildItem (Join-Path "$pesterRoot" 'Dependencies') -Include *.Tests.ps1 -Recurse
    )

    It 'Pester tests files start with explicit declaration of StrictMode set to Latest' {
        $UnstrictTests = @(
            ForEach ($file in $files) {
                $lines = [System.IO.File]::ReadAllLines($file.FullName)
                $lineCount = $lines.Count
                If ($lineCount -lt 3){ $linesToRead = $lineCount} else { $linestoRead = 3 }
                $n = 0
                For ($i = 0; $i -lt $linestoRead; $i++) {
                    If ($lines[$i] -match '\s+Set-StrictMode\ -Version\ Latest' -or $lines[$i] -match 'Set-StrictMode\ -Version\ Latest' ) { $n++  }
                }
                If ( $n -eq 0 ) {
                    $file.FullName
                }
            }
        )
        If ($UnstrictTests.Count -gt 0) {
            Throw "The following $($UnstrictTests.Count) tests files doesn't contain strict mode declaration in the first three lines: $([System.Environment]::NewLine)$([System.Environment]::NewLine)$($UnstrictTests -join $([System.Environment]::NewLine))"
        }
    }
}

# Tests mostly based on the blog post http://www.lazywinadmin.com/2016/05/using-pester-to-test-your-comment-based.html
# Author: Francois-Xavier Cat fxcat[at]lazywinadmin[dot]com
# AST is not available in PowerShell < 3
If ($PSVersionTable.PSVersion.Major -gt 2) {
    #Please don't run that section InModuleScope - too much internal functions don't have help
    Describe 'Module Pester functions help' -Tags 'Help' {

        [String[]]$AcceptEmptyHelp              = @()
        [String[]]$AcceptMissedHelpSynopsis     = @()
        [String[]]$FunctionsList                = (Get-Command -Module Pester | Where-Object -FilterScript { $_.CommandType -eq 'Function' })
        [String[]]$FilteredFunctionList         = $($FunctionsList | Where-Object -FilterScript { $AcceptEmptyHelp -notcontains $_ })

        [String[]]$AcceptMissedHelpParameters   = @('Get-MockDynamicParameter', 'Invoke-Mock','Should', 'Set-DynamicParameterVariable', 'Setup')
        [String[]]$AccepteMissedHelpDescription = @('AfterAll', 'AfterEach', 'BeforeAll', 'BeforeEach', 'Get-MockDynamicParameter', 'Invoke-Mock',
                                                    'SafeGetCommand', 'Set-DynamicParameterVariable', 'Setup')
        [String[]]$AcceptMissedHelpExamples     = @('AfterAll', 'AfterEach', 'AfterEachFeature', 'AfterEachScenario', 'Assert-VerifiableMocks',
                                                    'BeforeAll', 'BeforeEach', 'BeforeEachFeature', 'BeforeEachScenario',
                                                    'Get-MockDynamicParameter', 'In', 'Invoke-Mock', 'SafeGetCommand',
                                                    'Set-DynamicParameterValue', 'Set-DynamicParameterVariable', 'Setup', 'Should')

        ForEach ($Function In $FilteredFunctionList) {
            # Retrieve the Help of the function
            $FunctionHelp = Get-Help -Name $Function -Full

            # Parse the function using AST
            $AST = [System.Management.Automation.Language.Parser]::ParseInput((Get-Content function:$Function), [ref]$null, [ref]$null)

            Context "The function [$Function] - Help" {
                If ($AcceptMissedHelpSynopsis -notcontains $Function) {
                    $HelpSynopsis = ($FunctionHelp.Synopsis).Trim()
                    If ( -not [String]::IsNullOrEmpty($HelpSynopsis) ) {
                        $HelpSynopsisBegin = $HelpSynopsis.SubString(0, $HelpSynopsis.IndexOf('[') + 2)
                        $HelpSynopsisEnd   = $HelpSynopsis.SubString(   $HelpSynopsis.length-1, 1     )
                    }

                    It 'Synopsis for the function is filled up' {
                        $HelpSynopsis      | Should -Not -BeNullOrEmpty
                        $HelpSynopsisBegin | Should -Not -Be "$Function [["
                        $HelpSynopsisEnd   | Should -Not -Be ']'
                        $HelpSynopsis      | Should -Not -Be $Function
                    }
                }

                If ($AccepteMissedHelpDescription -notcontains $Function) {
                    It 'Description for the function is filled up' {
                        $FunctionDescription = $FunctionHelp.Description
                        $FunctionDescription | Should -Not -BeNullOrEmpty
                    }
                }

                # Get the parameters declared in the Comment Based Help
                $RiskMitigationParameters = 'Whatif', 'Confirm'
                Try { $ParametersCount =  $(Measure-Object -InputObject $FunctionHelp.Parameters.Parameter).Count }
                Catch { $ParametersCount = 0 }
                If ( $ParametersCount -gt 0 ) {
                    $HelpParameters = $FunctionHelp.Parameters.Parameter | Where-Object Name -NotIn $RiskMitigationParameters
                }

                # Get the parameters declared in the AST PARAM() Block
                Try { [string[]]$ASTParameters = $AST.ParamBlock.Parameters.Name.VariablePath.UserPath | Sort-Object }
                Catch { $ASTParameters = $Null }
                If (-not [string]::IsNullOrEmpty($ASTParameters) -and $AcceptMissedHelpParameters -notcontains $Function ) {
                    $HelpParameters | ForEach-Object {
                        It "The parameter [$($_.Name)] contains description" {
                            $ParameterDescription = $_.Description
                            $ParameterDescription | Should -Not -BeNullOrEmpty
                        }
                    }
                }

                # Examples
                If ($AcceptMissedHelpExamples -notcontains $Function) {
                    Try   { $ExamplesCount =  $(Measure-Object -InputObject $FunctionHelp.examples.example).Count }
                    Catch { $ExamplesCount = 0 }
                    It 'Example - At least one example exist' {
                        #$ExamplesCount = $FunctionHelp.Examples.Example.Code.Count
                        $ExamplesCount | Should -BeGreaterThan 0
                    }

                    If ( $ExamplesCount -gt 0 ) {
                        # Examples - Remarks (small description that comes with the example)
                        ForEach ($Example in $FunctionHelp.Examples.Example) {
                            $StrippedExampleTitle = ($Example.Title).Replace('--------------------------', '')
                            It "Example - remarks on [$StrippedExampleTitle] are filled up" {
                                $Example.Remarks | Should -Not -BeNullOrEmpty
                            }
                        }
                    }
                }
            }
        }
    }
}

InModuleScope -ModuleName Pester {
    Describe 'Contain-AnyStringLike' {

        It 'Given a filter <filter> that does not match any items in collection <collection> it returns $false' -TestCases @(
            @{ Filter = 'Unit';                      Collection = 'Integration' }
            @{ Filter = '*Unit*';                    Collection = 'Integration' }
            @{ Filter = '*Unit*', 'IntegrationTest'; Collection = 'Integration' }
            @{ Filter = 'Unit';                      Collection = 'Low', 'Medium', 'High' }
            @{ Filter = '*Unit*';                    Collection = 'Low', 'Medium', 'High' }
        ) {
            Param ($Filter, $Collection)
            Contain-AnyStringLike -Filter $Filter -Collection $Collection | Should -BeFalse
        }

        It 'Given a filter <filter> that matches one or more items in collection <collection> it returns $true' -TestCases @(
            @{ Filter = 'Unit';                        Collection = 'Unit'     }
            @{ Filter = '*Unit*';                      Collection = 'UnitTest' }
            @{ Filter = 'UnitTest', 'IntegrationTest'; Collection = 'UnitTest' }
            @{ Filter = 'Low';                         Collection = 'Low', 'Medium', 'High' }
            @{ Filter = 'Low', 'Medium';               Collection = 'Low', 'Medium', 'High' }
            @{ Filter = 'l*';                          Collection = 'Low', 'Medium', 'High' }
        ) {
            Param ($Filter, $Collection)

            Contain-AnyStringLike -Filter $Filter -Collection $Collection | Should -BeTrue
        }
    }
}

Describe 'Invoke-Pester happy path returns only test results' {
    Set-Content -Path 'TestDrive:\Invoke-MyFunction.ps1' -Value @'
        Function Invoke-MyFunction {
            Return $true
        }
'@

    Set-Content -Path 'TestDrive:\Invoke-MyFunction.Tests.ps1' -Value @'
        . 'TestDrive:\Invoke-MyFunction.ps1'
        Describe 'Invoke-MyFunction Tests' {
            It 'Should not throw' {
                Invoke-MyFunction
            }
        }
'@

    It 'Should swallow test output with -PassThru' {
        $results = Invoke-Pester -Script 'TestDrive:\Invoke-MyFunction.Tests.ps1' -PassThru -Show 'None'

        # note - the pipe command unrolls enumerable objects, so we have to wrap
        #        results in a sacrificial array to retain its original structure
        #        when passed to Should
        @(,$results) | Should -BeOfType [PSCustomObject]
        $results.TotalCount | Should -Be 1

        # or, we could do this instead:
        # ($results -is [PSCustomObject]) | Should -Be $true;
        # $results.TotalCount | Should -Be 1;

    }

    It 'Should swallow test output without -PassThru' {
        $results = Invoke-Pester -Script 'TestDrive:\Invoke-MyFunction.Tests.ps1' -Show 'None'
        $results | Should -Be $null
    }
}

Describe 'Invoke-Pester swallows pipeline output from system-under-test'  {
    Set-Content -Path 'TestDrive:\Invoke-MyFunction.ps1' -Value @'
        Write-Output 'my system-under-test output'
        Function Invoke-MyFunction {
            Return $true
        }
'@

    Set-Content -Path 'TestDrive:\Invoke-MyFunction.Tests.ps1' -Value @'
        . 'TestDrive:\Invoke-MyFunction.ps1'
        Describe 'Invoke-MyFunction Tests' {
            It 'Should not throw' {
                Invoke-MyFunction
            }
        }
'@

    It 'Should swallow test output with -PassThru' {
        $results = Invoke-Pester -Script 'TestDrive:\Invoke-MyFunction.Tests.ps1' -PassThru -Show 'None'

        # Note - the pipe command unrolls enumerable objects, so we have to wrap
        #        results in a sacrificial array to retain its original structure
        #        when passed to Should
        @(,$results) | Should -BeOfType [PSCustomObject]
        $results.TotalCount | Should -Be 1

        # or, we could do this instead:
        # ($results -is [PSCustomObject]) | Should -Be $true
        # $results.TotalCount | Should -Be 1
    }

    It 'Should swallow test output without -PassThru' {
        $results = Invoke-Pester -Script 'TestDrive:\Invoke-MyFunction.Tests.ps1' -Show 'None'
        $results | Should -Be $null
    }
}

Describe 'Invoke-Pester swallows pipeline output from test script'  {
    Set-Content -Path 'TestDrive:\Invoke-MyFunction.ps1' -Value @'
        Function Invoke-MyFunction {
            Return $true
        }
'@;

    Set-Content -Path 'TestDrive:\Invoke-MyFunction.Tests.ps1' -Value @'
        . 'TestDrive:\Invoke-MyFunction.ps1'
        Write-Output 'my test script output'
        Describe 'Invoke-MyFunction Tests' {
            It 'Should not throw' {
                Invoke-MyFunction
            }
        }
'@;

    It 'Should swallow test output with -PassThru' {
        $results = Invoke-Pester -Script 'TestDrive:\Invoke-MyFunction.Tests.ps1' -PassThru -Show 'None'

        # note - the pipe command unrolls enumerable objects, so we have to wrap
        #        results in a sacrificial array to retain its original structure
        #        when passed to Should
        @(,$results) | Should -BeOfType [PSCustomObject]
        $results.TotalCount | Should -Be 1

        # or, we could do this instead:
        # ($results -is [PSCustomObject]) | Should -Be $true
        # $results.TotalCount | Should -Be 1

    }

    It 'Should swallow test output without -PassThru' {
        $results = Invoke-Pester -Script 'TestDrive:\Invoke-MyFunction.Tests.ps1' -Show 'None'
        $results | Should -Be $null
    }
}
