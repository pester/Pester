Set-StrictMode -Version Latest

BeforeAll {
    $PSDefaultParameterValues = @{ 'Should:ErrorAction' = 'Stop' }
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
            $r.Message.Count | Should -be 6

            $r.Trace[0] | Should -match "'One' | Should -be 'Two'"
            $r.Trace[1] | Should -be "at <ScriptBlock>, ${PSCommandPath}:172"
            $r.Trace.Count | Should -be 2
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
                        $r.Trace[3] | Should -be "at <ScriptBlock>, ${PSCommandPath}:248"
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
                        $r.Trace[3] | Should -be "at <ScriptBlock>, ${PSCommandPath}:248"
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
                        $r.Trace[1] | Should -be "at <ScriptBlock>, $PSCommandPath`:314"
                        $r.Trace.Count | Should -be 2
                    }
                }
            }
            else {
                It 'produces correct trace line.' {
                    if ($hasStackTrace) {
                        $r.Trace[0] | Should -be "at <ScriptBlock>, $testPath`:10"
                        $r.Trace[1] | Should -be "at <ScriptBlock>, $PSCommandPath`:314"
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

    Describe Format-ErrorMessage {
        Context "Formats error messages for one error" {
            BeforeEach {
                try {
                    1 / 0
                }
                catch [System.DivideByZeroException] {
                    $errorRecord = $_
                }
                $errorRecord | Add-Member -Name "DisplayErrorMessage" -MemberType NoteProperty -Value "Failed to divide 1/0"

                $stackTraceText = $errorRecord.Exception.ToString() + "$([Environment]::NewLine)at <ScriptBlock>, ${PSCommandPath}:230"
                $errorRecord | Add-Member -Name "DisplayStackTrace" -MemberType NoteProperty -Value $stackTraceText
            }

            It "When StackTraceVerbosity is None, it has only one error message in output" {
                $errorMessage = Format-ErrorMessage -Err $errorRecord -StackTraceVerbosity "None"
                $messages = $errorMessage -split [Environment]::NewLine
                $messages[0] | Should -BeExactly "Failed to divide 1/0"
                $messages | Should -HaveCount 1
            }

            It "When StackTraceVerbosity is FirstLine, it has error message and first line of stack trace in output" {
                $errorMessage = Format-ErrorMessage -Err $errorRecord -StackTraceVerbosity "FirstLine"
                $messages = $errorMessage -split [Environment]::NewLine
                $messages[0] | Should -BeExactly "Failed to divide 1/0"
                $messages[1] | Should -BeExactly "System.DivideByZeroException: Attempted to divide by zero."
                $messages | Should -HaveCount 2
            }

            It "When StackTraceVerbosity is Filtered, it has error message and two lines of stacktrace output" {
                $errorMessage = Format-ErrorMessage -Err $errorRecord -StackTraceVerbosity "Filtered"
                $messages = $errorMessage -split [Environment]::NewLine
                $messages[0] | Should -BeExactly "Failed to divide 1/0"
                $messages[1] | Should -BeExactly "System.DivideByZeroException: Attempted to divide by zero."
                $messages[2] | Should -BeExactly "at <ScriptBlock>, ${PSCommandPath}:230"
                $messages.Count | Should -BeGreaterThan 2
            }

            It "When StackTraceVerbosity is Full, it has error message and two lines of stacktrace output" {
                $errorMessage = Format-ErrorMessage -Err $errorRecord -StackTraceVerbosity "Full"
                $messages = $errorMessage -split [Environment]::NewLine
                $messages[0] | Should -BeExactly "Failed to divide 1/0"
                $messages[1] | Should -BeExactly "System.DivideByZeroException: Attempted to divide by zero."
                $messages[2] | Should -BeExactly "at <ScriptBlock>, ${PSCommandPath}:230"
                $messages.Count | Should -BeGreaterThan 2
            }

            It "When StackTraceVerbosity is '<_>' and DisplayErrorMessage is `$null, it has execption message with script stack trace" -ForEach @('None', 'FirstLine', 'Filtered', 'Full') {
                $errorRecord.DisplayErrorMessage = $null
                $errorMessage = Format-ErrorMessage -Err $errorRecord -StackTraceVerbosity $_
                $messages = $errorMessage -split [Environment]::NewLine
                $messages[0] | Should -BeExactly "System.DivideByZeroException: Attempted to divide by zero."
                $messages[1] | Should -BeExactly "at <ScriptBlock>, ${PSCommandPath}: line 389"
                $messages.Count | Should -BeGreaterThan 1
            }

            It "When StackTraceVerbosity is '<_>' and DisplayStackTrace is `$null, it has only one error message in output" -ForEach @('None', 'FirstLine', 'Filtered', 'Full') {
                $errorRecord.DisplayStackTrace = $null
                $errorMessage = Format-ErrorMessage -Err $errorRecord -StackTraceVerbosity $_
                $messages = $errorMessage -split [Environment]::NewLine
                $messages[0] | Should -BeExactly "Failed to divide 1/0"
                $messages | Should -HaveCount 1
            }
        }

        Context "Formats error messages for multiple errors" {
            BeforeEach {
                $errorRecords = @()
                for ($i = 1; $i -lt 3; $i++) {
                    try {
                        $i / 0
                    }
                    catch [System.DivideByZeroException] {
                        $errorRecord = $_
                    }
                    $errorRecord | Add-Member -Name "DisplayErrorMessage" -MemberType NoteProperty -Value "Failed to divide $i/0"
                    $stackTraceText = $errorRecord.Exception.ToString() + "$([Environment]::NewLine)at <ScriptBlock>, ${PSCommandPath}:230"
                    $errorRecord | Add-Member -Name "DisplayStackTrace" -MemberType NoteProperty -Value $stackTraceText
                    $errorRecords += $errorRecord
                }
            }

            It "When StackTraceVerbosity is None, it has only one error message in output" {
                $errorMessage = Format-ErrorMessage -Err $errorRecords -StackTraceVerbosity "None"
                $messages = $errorMessage -split [Environment]::NewLine
                $messages[0] | Should -BeExactly "[0] Failed to divide 1/0"
                $messages[1] | Should -BeExactly "[1] Failed to divide 2/0"
                $messages | Should -HaveCount 2
            }

            It "When StackTraceVerbosity is FirstLine, it has error message and first line of stack trace in output" {
                $errorMessage = Format-ErrorMessage -Err $errorRecords -StackTraceVerbosity "FirstLine"
                $messages = $errorMessage -split [Environment]::NewLine
                $messages[0] | Should -BeExactly "[0] Failed to divide 1/0"
                $messages[1] | Should -BeExactly "System.DivideByZeroException: Attempted to divide by zero."
                $messages[2] | Should -BeExactly "[1] Failed to divide 2/0"
                $messages[3] | Should -BeExactly "System.DivideByZeroException: Attempted to divide by zero."
                $messages | Should -HaveCount 4
            }

            It "When StackTraceVerbosity is Filtered, it has two error messages and four lines stacktrace output" {
                $errorMessage = Format-ErrorMessage -Err $errorRecords -StackTraceVerbosity "Filtered"
                $messages = $errorMessage -split [Environment]::NewLine
                $messages[0] | Should -BeExactly "[0] Failed to divide 1/0"
                $messages[1] | Should -BeExactly "System.DivideByZeroException: Attempted to divide by zero."
                $messages[2] | Should -BeExactly "at <ScriptBlock>, ${PSCommandPath}:230"
                $messages[3] | Should -BeExactly "[1] Failed to divide 2/0"
                $messages[4] | Should -BeExactly "System.DivideByZeroException: Attempted to divide by zero."
                $messages[5] | Should -BeExactly "at <ScriptBlock>, ${PSCommandPath}:230"
                $messages.Count | Should -BeGreaterThan 4
            }

            It "When StackTraceVerbosity is Full, it has two error messages and four lines stacktrace output" {
                $errorMessage = Format-ErrorMessage -Err $errorRecords -StackTraceVerbosity "Full"
                $messages = $errorMessage -split [Environment]::NewLine
                $messages[0] | Should -BeExactly "[0] Failed to divide 1/0"
                $messages[1] | Should -BeExactly "System.DivideByZeroException: Attempted to divide by zero."
                $messages[2] | Should -BeExactly "at <ScriptBlock>, ${PSCommandPath}:230"
                $messages[3] | Should -BeExactly "[1] Failed to divide 2/0"
                $messages[4] | Should -BeExactly "System.DivideByZeroException: Attempted to divide by zero."
                $messages[5] | Should -BeExactly "at <ScriptBlock>, ${PSCommandPath}:230"
                $messages.Count | Should -BeGreaterThan 4
            }

            It "When StackTraceVerbosity is '<_>' and DisplayErrorMessage is `$null, it has execption message with script stack trace" -ForEach @('None', 'FirstLine', 'Filtered', 'Full') {
                foreach ($errorRecord in $errorRecords) {
                    $errorRecord.DisplayErrorMessage = $null
                    $errorMessage = Format-ErrorMessage -Err $errorRecord -StackTraceVerbosity $_
                    $messages = $errorMessage -split [Environment]::NewLine
                    $messages[0] | Should -BeExactly "System.DivideByZeroException: Attempted to divide by zero."
                    $messages | Should -BeGreaterThan 1
                }
            }

            It "When StackTraceVerbosity is '<_>' and DisplayStackTrace is `$null, it has only one error message in output" -ForEach @('None', 'FirstLine', 'Filtered', 'Full') {
                for ($i = 0; $i -lt $errorRecords.Count; $i++) {
                    $errorRecords[$i].DisplayStackTrace = $null
                    $errorMessage = Format-ErrorMessage -Err $errorRecords[$i] -StackTraceVerbosity $_
                    $messages = $errorMessage -split [Environment]::NewLine
                    $messages[0] | Should -BeExactly "Failed to divide $($i + 1)/0"
                    $messages | Should -HaveCount 1
                }
            }
        }
    }

    Describe Write-ErrorToScreen {
        BeforeAll {
            try {
                1 / 0
            }
            catch [System.DivideByZeroException] {
                $errorRecord = $_
            }
            $errorRecord | Add-Member -Name "DisplayErrorMessage" -MemberType NoteProperty -Value "Failed to divide 1/0"
            $errorRecord | Add-Member -Name "DisplayStackTrace" -MemberType NoteProperty -Value $errorRecord.Exception.ToString()
        }
        It "Throw error message" {
            { Write-ErrorToScreen -Err $errorRecord -Throw } | Should -Throw
        }
    }

    Describe Format-CIErrorMessage {
        Context "Azure Devops Error Format" {
            It "Header '<header>' and Message '<message>' returns '<expected>'" -TestCases @(
                @{
                    Header   = 'header'
                    Message  = 'message'
                    Expected = @(
                        '##vso[task.logissue type=error] header',
                        '##[error] message'
                    )
                }
                @{
                    Header   = 'header'
                    Message  = @('message1', 'message2')
                    Expected = @(
                        '##vso[task.logissue type=error] header',
                        '##[error] message1',
                        '##[error] message2'
                    )
                }
            ) {
                Format-CIErrorMessage -CIFormat 'AzureDevops' -CILogLevel 'Error' -Header $Header -Message $Message | Should -Be $Expected
            }
        }

        Context "Azure Devops Warning Format" {
            It "Header '<header>' and Message '<message>' returns '<expected>'" -TestCases @(
                @{
                    Header   = 'header'
                    Message  = 'message'
                    Expected = @(
                        '##vso[task.logissue type=warning] header',
                        '##[warning] message'
                    )
                }
                @{
                    Header   = 'header'
                    Message  = @('message1', 'message2')
                    Expected = @(
                        '##vso[task.logissue type=warning] header',
                        '##[warning] message1',
                        '##[warning] message2'
                    )
                }
            ) {
                Format-CIErrorMessage -CIFormat 'AzureDevops' -CILogLevel 'Warning' -Header $Header -Message $Message | Should -Be $Expected
            }
        }

        Context 'Github Actions Error Format' {
            It "Header '<header>' and Message '<message>' returns '<expected>'" -TestCases @(
                @{
                    Header   = 'header'
                    Message  = 'message'
                    Expected = @(
                        '::error::header',
                        '::group::Message',
                        'message',
                        '::endgroup::'
                    )
                }
                @{
                    Header   = 'header'
                    Message  = @('message1', 'message2')
                    Expected = @(
                        '::error::header',
                        '::group::Message',
                        'message1',
                        'message2',
                        '::endgroup::'
                    )
                }
                @{
                    Header   = 'header'
                    Message  = @('  message1', '  message2')
                    Expected = @(
                        '::error::header',
                        '::group::Message',
                        'message1',
                        'message2',
                        '::endgroup::'
                    )
                }
            ) {
                Format-CIErrorMessage -CIFormat 'GithubActions' -CILogLevel 'Error' -Header $Header -Message $Message | Should -Be $Expected
            }
        }

        Context 'Github Actions Warning Format' {
            It "Header '<header>' and Message '<message>' returns '<expected>'" -TestCases @(
                @{
                    Header   = 'header'
                    Message  = 'message'
                    Expected = @(
                        '::warning::header',
                        '::group::Message',
                        'message',
                        '::endgroup::'
                    )
                }
                @{
                    Header   = 'header'
                    Message  = @('message1', 'message2')
                    Expected = @(
                        '::warning::header',
                        '::group::Message',
                        'message1',
                        'message2',
                        '::endgroup::'
                    )
                }
                @{
                    Header   = 'header'
                    Message  = @('  message1', '  message2')
                    Expected = @(
                        '::warning::header',
                        '::group::Message',
                        'message1',
                        'message2',
                        '::endgroup::'
                    )
                }
            ) {
                Format-CIErrorMessage -CIFormat 'GithubActions' -CILogLevel 'Warning' -Header $Header -Message $Message | Should -Be $Expected
            }
        }
    }
}

# Can't run inside InModuleScope Pester { } because variables defined in BeforeDiscovery will be lost due to same module state as scriptblock = no testcases
Describe 'Write-PesterHostMessage' {
    Context 'Is syntax-compatible with Write-Host' {
        BeforeDiscovery {
            # Using internal code as [System.Management.Automation.Cmdlet]::CommonParameters is unavailable in PSv3
            $CommonParameters = [System.Management.Automation.Internal.CommonParameters].DeclaredProperties.Name
            $WriteHostParam = @(Get-Command 'Write-Host' -Module 'Microsoft.PowerShell.Utility' -CommandType Cmdlet).Parameters.Values |
                Where-Object Name -NotIn $CommonParameters
        }
        BeforeAll {
            $WritePesterHostMessageParam = & (Get-Module Pester) { (Get-Command 'Write-PesterHostMessage' -Module Pester).Parameters }
        }
        It 'Parameter <_.Name> is equal' -TestCases $WriteHostParam {
            $param = $_
            $param.Name | Should -BeIn $WritePesterHostMessageParam.Keys
            $WritePesterHostMessageParam[$param.Name].ParameterType | Should -Be $param.ParameterType
            if ($param.Aliases) { $param.Aliases | Should -BeIn $WritePesterHostMessageParam[$param.Name].Aliases }
        }
    }
}
