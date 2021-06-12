Set-StrictMode -Version Latest

BeforeAll {
    $PSDefaultParameterValues = @{ 'Should:ErrorAction' = 'Stop' }
}

InModuleScope -ModuleName Pester -ScriptBlock {
    Describe 'Has-Flag' -Fixture {
        It 'Returns true when setting and value are the same' {
            $setting = [Pester.OutputTypes]::Passed
            $value = [Pester.OutputTypes]::Passed

            $value | Has-Flag $setting | Should -Be $true
        }

        It 'Returns false when setting and value are the different' {
            $setting = [Pester.OutputTypes]::Passed
            $value = [Pester.OutputTypes]::Failed

            $value | Has-Flag $setting | Should -Be $false
        }

        It 'Returns true when setting contains value' {
            $setting = [Pester.OutputTypes]::Passed -bor [Pester.OutputTypes]::Failed
            $value = [Pester.OutputTypes]::Passed

            $value | Has-Flag $setting | Should -Be $true
        }

        It 'Returns false when setting does not contain the value' {
            $setting = [Pester.OutputTypes]::Passed -bor [Pester.OutputTypes]::Failed
            $value = [Pester.OutputTypes]::Summary

            $value | Has-Flag $setting | Should -Be $false
        }

        It 'Returns true when at least one setting is contained in value' {
            $setting = [Pester.OutputTypes]::Passed -bor [Pester.OutputTypes]::Failed
            $value = [Pester.OutputTypes]::Summary -bor [Pester.OutputTypes]::Failed

            $value | Has-Flag $setting | Should -Be $true
        }

        It 'Returns false when none of settings is contained in value' {
            $setting = [Pester.OutputTypes]::Passed -bor [Pester.OutputTypes]::Failed
            $value = [Pester.OutputTypes]::Summary -bor [Pester.OutputTypes]::Describe

            $value | Has-Flag $setting | Should -Be $false
        }
    }

    Describe 'Default OutputTypes' -Fixture {
        It 'Fails output type contains all except passed' {
            $expected = [Pester.OutputTypes]'Default, Failed, Pending, Skipped, Inconclusive, Describe, Context, Summary, Header'
            [Pester.OutputTypes]::Fails | Should -Be $expected
        }

        It 'All output type contains all flags' {
            $expected = [Pester.OutputTypes]'Default, Passed, Failed, Pending, Skipped, Inconclusive, Describe, Context, Summary, Header'
            [Pester.OutputTypes]::All | Should -Be $expected
        }
    }
}

BeforeAll {
    $thisScriptRegex = [regex]::Escape((Get-Item $PSCommandPath).FullName)
}

# not used but might be useful for future reference
# Describe 'ConvertTo-PesterResult' {
#     BeforeAll {
#         $getPesterResult = InPesterModuleScope { ${function:ConvertTo-PesterResult} }
#     }

#     Context 'failed tests in Tests file' {
#         BeforeAll {
#             #the $script scriptblock below is used as a position marker to determine
#             #on which line the test failed.
#             $errorRecord = $null
#             try {
#                 $script = {}; 'something' | Should -Be 'nothing' -ErrorAction Stop
#             }
#             catch {
#                 $errorRecord = $_
#             }
#             $result = & $getPesterResult -Time 0 -ErrorRecord $errorRecord
#         }

#         It 'records the correct stack line number' {
#             $result.StackTrace | should -match "${thisScriptRegex}: line $($script.startPosition.StartLine)"
#         }
#         It 'records the correct error record' {
#             $result.ErrorRecord -is [System.Management.Automation.ErrorRecord] | Should -be $true
#             $result.ErrorRecord.Exception.Message | Should -match "Expected: 'nothing'"
#         }
#     }

#     It 'Does not modify the error message from the original exception' {
#         $object = New-Object psobject
#         $message = 'I am an error.'
#         Add-Member -InputObject $object -MemberType ScriptMethod -Name ThrowSomething -Value { throw $message }

#         $errorRecord = $null
#         try {
#             $object.ThrowSomething()
#         }
#         catch {
#             $errorRecord = $_
#         }

#         $pesterResult = & $getPesterResult -Time 0 -ErrorRecord $errorRecord

#         $pesterResult.FailureMessage | Should -Be $errorRecord.Exception.Message
#     }

#     Context 'failed tests in another file' {
#         BeforeAll {
#             $errorRecord = $null

#             $testPath = Join-Path $TestDrive test.ps1
#             Set-Content -Path $testPath -Value "$([System.Environment]::NewLine)'One' | Should -Be 'Two' -ErrorAction Stop"

#             $escapedTestPath = [regex]::Escape((Get-Item $testPath).FullName)

#             try {
#                 & $testPath
#             }
#             catch {
#                 $errorRecord = $_
#             }

#             $result = & $getPesterResult -Time 0 -ErrorRecord $errorRecord
#         }


#         It 'records the correct stack line number' {
#             $result.StackTrace | should -match "${escapedTestPath}: line 2"
#         }

#         It 'records the correct error record' {
#             $result.ErrorRecord -is [System.Management.Automation.ErrorRecord] | Should -be $true
#             $result.ErrorRecord.Exception.Message | Should -match "Expected: 'Two'"
#         }
#     }
# }

InModuleScope -ModuleName Pester -ScriptBlock {
    Describe "Format-PesterPath" {

        It "Writes path correctly when it is given `$null" {
            Format-PesterPath -Path $null | Should -Be $null
        }

        if ((GetPesterOS) -ne 'Windows') {

            It "Writes path correctly when it is provided as string" {
                Format-PesterPath -Path "/home/username/folder1" | Should -Be "/home/username/folder1"
            }

            It "Writes path correctly when it is provided as string[]" {
                Format-PesterPath -Path @("/home/username/folder1", "/home/username/folder2") -Delimiter ', ' | Should -Be "/home/username/folder1, /home/username/folder2"
            }

            It "Writes path correctly when provided through hashtable" {
                Format-PesterPath -Path @{ Path = "/home/username/folder1" } | Should -Be "/home/username/folder1"
            }

            It "Writes path correctly when provided through array of hashtable" {
                Format-PesterPath -Path @{ Path = "/home/username/folder1" }, @{ Path = "/home/username/folder2" } -Delimiter ', ' | Should -Be "/home/username/folder1, /home/username/folder2"
            }
        }
        else {

            It "Writes path correctly when it is provided as string" {
                Format-PesterPath -Path "C:\path" | Should -Be "C:\path"
            }

            It "Writes path correctly when it is provided as string[]" {
                Format-PesterPath -Path @("C:\path1", "C:\path2") -Delimiter ', ' | Should -Be "C:\path1, C:\path2"
            }

            It "Writes path correctly when provided through hashtable" {
                Format-PesterPath -Path @{ Path = "C:\path" } | Should -Be "C:\path"
            }

            It "Writes path correctly when provided through array of hashtable" {
                Format-PesterPath -Path @{ Path = "C:\path1" }, @{ Path = "C:\path2" } -Delimiter ', ' | Should -Be "C:\path1, C:\path2"
            }

        }
    }

    Describe ConvertTo-FailureLines {
        BeforeAll {

            $showFullErrors = & (Get-Module Pester) {
                # disable the debugging prefrerence inside of pester module
                # otherwise this wouldm never pass. This might obscure some of
                # our own errors because it shortens the stack trace, use $error[0]
                # to debug suff around here not just the screen output
                $PesterPreference.Debug.ShowFullErrors # <- outputs the value
                $PesterPreference.Debug.ShowFullErrors = $false # <- sets the value
            }

        }

        AfterAll {
            & (Get-Module Pester) {
                param ($p)
                $PesterPreference.Debug.ShowFullErrors = $p
            } $showFullErrors
        }

        It 'produces correct message lines.' {
            try {
                throw 'message'
            }
            catch {
                $e = $_
            }

            $r = $e | ConvertTo-FailureLines

            $r.Message[0] | Should -be 'RuntimeException: message'
            $r.Message.Count | Should -be 1
        }

        It 'failed should produces correct message lines.' {
            try {
                'One' | Should -be 'Two' -ErrorAction Stop
            }
            catch {
                $e = $_
            }

            $r = $e | ConvertTo-FailureLines

            $r.Message[0] | Should -be 'Expected strings to be the same, but they were different.'
            $r.message[1] | Should -be 'String lengths are both 3.'
            $r.message[2] | Should -be 'Strings differ at index 0.'
            $r.Message[3] | Should -be "Expected: 'Two'"
            $r.Message[4] | Should -be "But was:  'One'"
            $r.Message[5] | Should -be "           ^"
            $r.Message[6] | Should -match "'One' | Should -be 'Two'"
            $r.Message.Count | Should -be 7
        }
        # TODO: should fails with a very weird error, probably has something to do with dynamic params...
        #         Context 'Should fails in file' {
        #             BeforeAll {
        #                 $testPath = Join-Path $TestDrive test.ps1

        #                 Set-Content -Path $testPath -Value @'
        #                 $script:IgnoreErrorPreference = 'SilentlyContinue'
        #                 'One' | Should -Be 'Two'
        # '@

        #                 try { & $testPath } catch { $e = $_ }
        #                 $r = $e | ConvertTo-FailureLines
        #                 $hasStackTrace = $e | Get-Member -Name ScriptStackTrace
        #                 $escapedTestPath = [regex]::Escape((Get-Item $testPath).FullName)
        #             }

        #             It 'produces correct message lines.' {
        #                 $r.Message[0] | Should -be 'String lengths are both 3. Strings differ at index 0.'
        #                 $r.Message[1] | Should -be 'Expected: {Two}'
        #                 $r.Message[2] | Should -be 'But was:  {One}'
        #                 $r.Message[3] | Should -be '-----------^'
        #                 $r.Message[4] | Should -be "2:                 'One' | Should -be 'Two'"
        #                 $r.Message.Count | Should -be 5
        #             }

        #             It 'produces correct trace lines.' {
        #                 if ($hasStackTrace) {
        #                     $r.Trace[0] | Should -be "at <ScriptBlock>, $testPath`: line 2"
        #                     $r.Trace[1] -match 'at <ScriptBlock>, .*\\functions\\Output.Tests.ps1: line [0-9]*$' |
        #                         Should -be $true
        #                     $r.Trace.Count | Should -be 3
        #                 }
        #             }

        #             It 'produces correct trace lines.' {
        #                 if (-not $hasStackTrace) {
        #                     $r.Trace[0] | Should -be "at line: 2 in $testPath"
        #                     $r.Trace.Count | Should -be 1
        #                 }
        #             }
        #         }

        Context 'exception thrown in nested functions in file' {
            BeforeAll {
                $testPath = Join-Path $TestDrive test.ps1
                Set-Content -Path $testPath -Value @'
                    function f1 {
                        throw 'f1 message'
                    }
                    function f2 {
                        f1
                    }
                    f2
'@

                try {
                    & $testPath
                }
                catch {
                    $e = $_
                }

                $r = $e | ConvertTo-FailureLines
                $hasStackTrace = $e | Get-Member -Name ScriptStackTrace
            }

            It 'produces correct message lines.' {
                $r.Message[0] | Should -be 'RuntimeException: f1 message'
            }

            if ((GetPesterOS) -ne 'Windows') {
                It 'produces correct trace lines.' {
                    if ($hasStackTrace) {
                        $r.Trace[0] | Should -be "at f1, ${testPath}:2"
                        $r.Trace[1] | Should -be "at f2, ${testPath}:5"
                        $r.Trace[2] | Should -be "at <ScriptBlock>, ${testPath}:7"
                        $r.Trace[3] | Should -be "at <ScriptBlock>, ${PSCommandPath}:303"
                        $r.Trace.Count | Should -be 4
                    }
                }
            }
            else {
                It 'produces correct trace lines.' {
                    if ($hasStackTrace) {
                        $r.Trace[0] | Should -be "at f1, ${testPath}:2"
                        $r.Trace[1] | Should -be "at f2, ${testPath}:5"
                        $r.Trace[2] | Should -be "at <ScriptBlock>, ${testPath}:7"
                        $r.Trace[3] | Should -be "at <ScriptBlock>, ${PSCommandPath}:303"
                        $r.Trace.Count | Should -be 4
                    }
                }
            }

            It 'produces correct trace lines.' {
                if (-not $hasStackTrace) {
                    $r.Trace[0] | Should -be "at line: 2 in $testPath"
                    $r.Trace.Count | Should -be 1
                }
            }
        }

        Context 'nested exceptions thrown in file' {
            BeforeAll {
                $testPath = Join-Path $TestDrive test.ps1
                Set-Content -Path $testPath -Value @'
                    try
                    {
                        throw New-Object System.ArgumentException(
                            'inner message',
                            'param_name'
                        )
                    }
                    catch
                    {
                        throw New-Object System.FormatException(
                            'outer message',
                            $_.Exception
                        )
                    }
'@

                try {
                    & $testPath
                }
                catch {
                    $e = $_
                }

                $r = $e | ConvertTo-FailureLines
                $hasStackTrace = $e | Get-Member -Name ScriptStackTrace
            }

            It 'produces correct message lines.' {
                if (6 -ge $PSVersionTable.PSVersion.Major) {
                    $r.Message[0] | Should -be 'ArgumentException: inner message'
                    $r.Message[1] | Should -be 'Parameter name: param_name'
                    $r.Message[2] | Should -be 'FormatException: outer message'
                }
                else {
                    $r.Message[0] | Should -be "ArgumentException: inner message (Parameter 'param_name')"
                    $r.Message[1] | Should -be 'FormatException: outer message'
                }
            }

            if ((GetPesterOS) -ne 'Windows') {
                It 'produces correct trace line.' {
                    if ($hasStackTrace) {
                        $r.Trace[0] | Should -be "at <ScriptBlock>, $testPath`:10"
                        $r.Trace[1] | Should -be "at <ScriptBlock>, $PSCommandPath`:369"
                        $r.Trace.Count | Should -be 2
                    }
                }
            }
            else {
                It 'produces correct trace line.' {
                    if ($hasStackTrace) {
                        $r.Trace[0] | Should -be "at <ScriptBlock>, $testPath`:10"
                        $r.Trace[1] | Should -be "at <ScriptBlock>, $PSCommandPath`:369"
                        $r.Trace.Count | Should -be 2
                    }
                }
            }
            It 'produces correct trace line.' {
                if (-not $hasStackTrace) {
                    $r.Trace[0] | Should -be "at line: 10 in $testPath"
                    $r.Trace.Count | Should -be 1
                }
            }
        }

        Context 'Exceptions with no error message property set' {
            BeforeAll {
                try {
                    $exceptionWithNullMessage = New-Object -TypeName "System.Management.Automation.ParentContainsErrorRecordException"
                    throw $exceptionWithNullMessage
                }
                catch {
                    $exception = $_
                }
                $r = $exception | ConvertTo-FailureLines
            }


            It 'produces correct message lines' {
                $r.Message.Length | Should -Be 0
            }

            It 'produces correct trace line' {
                $r.Trace.Count | Should -Be 1
            }
        }
    }
}
