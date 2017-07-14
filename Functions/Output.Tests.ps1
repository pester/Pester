InModuleScope -ModuleName Pester -ScriptBlock {
    Describe 'Has-Flag' -Fixture {
        It 'Returns true when setting and value are the same' {
            $setting = [Pester.OutputTypes]::Passed
            $value = [Pester.OutputTypes]::Passed

            $value | Has-Flag $setting | Should Be $true
        }

        It 'Returns false when setting and value are the different' {
            $setting = [Pester.OutputTypes]::Passed
            $value = [Pester.OutputTypes]::Failed

            $value | Has-Flag $setting | Should Be $false
        }

        It 'Returns true when setting contains value' {
            $setting = [Pester.OutputTypes]::Passed -bor [Pester.OutputTypes]::Failed
            $value = [Pester.OutputTypes]::Passed

            $value | Has-Flag $setting | Should Be $true
        }

        It 'Returns false when setting does not contain the value' {
            $setting = [Pester.OutputTypes]::Passed -bor [Pester.OutputTypes]::Failed
            $value = [Pester.OutputTypes]::Summary

            $value | Has-Flag $setting | Should Be $false
        }

        It 'Returns true when at least one setting is contained in value' {
            $setting = [Pester.OutputTypes]::Passed -bor [Pester.OutputTypes]::Failed
            $value = [Pester.OutputTypes]::Summary -bor [Pester.OutputTypes]::Failed

            $value | Has-Flag $setting | Should Be $true
        }

        It 'Returns false when none of settings is contained in value' {
            $setting = [Pester.OutputTypes]::Passed -bor [Pester.OutputTypes]::Failed
            $value = [Pester.OutputTypes]::Summary -bor [Pester.OutputTypes]::Describe

            $value | Has-Flag $setting | Should Be $false
        }
    }

    Describe 'Default OutputTypes' -Fixture {
        It 'Fails output type contains all except passed' {
            $expected = [Pester.OutputTypes]'Default, Failed, Pending, Skipped, Inconclusive, Describe, Context, Summary, Header'
            [Pester.OutputTypes]::Fails | Should Be $expected
        }

        It 'All output type contains all flags' {
            $expected = [Pester.OutputTypes]'Default, Passed, Failed, Pending, Skipped, Inconclusive, Describe, Context, Summary, Header'
            [Pester.OutputTypes]::All | Should Be $expected
        }
    }
}

$thisScriptRegex = [regex]::Escape($MyInvocation.MyCommand.Path)

Describe 'ConvertTo-PesterResult' {
    $getPesterResult = InModuleScope Pester { ${function:ConvertTo-PesterResult} }

    Context 'failed tests in Tests file' {
        #the $script scriptblock below is used as a position marker to determine
        #on which line the test failed.
        $errorRecord = $null
        try{'something' | should be 'nothing'}catch{ $errorRecord=$_} ; $script={}
        $result = & $getPesterResult 0 $errorRecord
        It 'records the correct stack line number' {
            $result.Stacktrace | should match "${thisScriptRegex}: line $($script.startPosition.StartLine)"
        }
        It 'records the correct error record' {
            $result.ErrorRecord -is [System.Management.Automation.ErrorRecord] | Should be $true
            $result.ErrorRecord.Exception.Message | Should match 'Expected: {nothing}'
        }
    }
    It 'Does not modify the error message from the original exception' {
        $object = New-Object psobject
        $message = 'I am an error.'
        Add-Member -InputObject $object -MemberType ScriptMethod -Name ThrowSomething -Value { throw $message }

        $errorRecord = $null
        try { $object.ThrowSomething() } catch { $errorRecord = $_ }

        $pesterResult = & $getPesterResult 0 $errorRecord

        $pesterResult.FailureMessage | Should Be $errorRecord.Exception.Message
    }
    Context 'failed tests in another file' {
        $errorRecord = $null

        $testPath = Join-Path $TestDrive test.ps1
        $escapedTestPath = [regex]::Escape($testPath)

        Set-Content -Path $testPath -Value "`r`n'One' | Should Be 'Two'"

        try
        {
            & $testPath
        }
        catch
        {
            $errorRecord = $_
        }

        $result = & $getPesterResult 0 $errorRecord


        It 'records the correct stack line number' {
            $result.Stacktrace | should match "${escapedTestPath}: line 2"
        }
        It 'records the correct error record' {
            $result.ErrorRecord -is [System.Management.Automation.ErrorRecord] | Should be $true
            $result.ErrorRecord.Exception.Message | Should match 'Expected: {Two}'
        }
    }
}

InModuleScope -Module Pester {
    Describe 'Write-PesterStart' {
        $TemporaryFile = Join-Path -Path $env:Temp -ChildPath "WritePesterStart_Test.txt"
        Context 'StartMessage' {
            $StartMessage = $ReportStrings.StartMessage
            $TestCases = @(
                @{
                    Name = "a single string"
                    Value = "C:\TestPath"
                },
                @{
                    Name = "an array of strings"
                    Value = ("C:\TestPath","C:\TestPath2")
                },
                @{
                    Name = "a hashtable"
                    Value = @{
                        Path = "C:\TestPath"
                    }
                }
                @{
                    Name = "an array of hashtables"
                    Value = (
                        @{
                            Path = "C:\TestPath"
                        },
                        @{
                            Path = "C:\TestPath2"
                        }
                    )
                }
            )

            It 'Accepts <Name> with correct output' -TestCases $TestCases {
                param($Name,$Value)
                Start-Transcript -Path $TemporaryFile
                Write-PesterStart -PesterState @{} -Path $Value
                $LastLine = (Get-Content $TemporaryFile)[-1]
                Stop-Transcript

                $LastLine | Should Match $StartMessage
                $LastLine | Should Not Match "System.Collections.Hashtable"
            }
        }
        Context 'FilterMessage' {
            $FilterMessage = $ReportStrings.FilterMessage
            It 'Displays FilterMessage if included in $PesterState' {
                Start-Transcript -Path $TemporaryFile
                Write-PesterStart -PesterState @{TestNameFilter='Test'} -Path 'Test'
                $LastLine = (Get-Content $TemporaryFile)[-1]
                Stop-Transcript

                $LastLine | Should Match ("$StartMessage$FilterMessage" -f 'Test')
            }
        }
        Context 'TagMessage' {
            $TagMessage = $ReportStrings.TagMessage
            It 'Displays TagMessage[s] if included in $PesterState' {
                Start-Transcript -Path $TemporaryFile
                Write-PesterStart -PesterState @{TagFilter='Test'} -Path 'Test'
                $LastLine = (Get-Content $TemporaryFile)[-1]
                Stop-Transcript

                $LastLine | Should Match ("$StartMessage$TagMessage" -f 'Test')
            }
        }
        Remove-Item -Path $TemporaryFile
    }
}