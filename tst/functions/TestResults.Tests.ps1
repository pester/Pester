Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe "Get-TestTime" {
        BeforeAll {
            function Using-Culture {
                param (
                    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
                    [ScriptBlock]$ScriptBlock,
                    [System.Globalization.CultureInfo]$Culture = 'en-US'
                )

                $oldCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
                try {
                    [System.Threading.Thread]::CurrentThread.CurrentCulture = $Culture
                    $ExecutionContext.InvokeCommand.InvokeScript($ScriptBlock)
                }
                finally {
                    [System.Threading.Thread]::CurrentThread.CurrentCulture = $oldCulture
                }
            }
        }

        It "output is culture agnostic" {
            #on cs-CZ, de-DE and other systems where decimal separator is ",". value [double]3.5 is output as 3,5
            #this makes some of the tests fail, it could also leak to the nUnit report if the time was output

            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]35000000 } #3.5 seconds

            #using the string formatter here to know how the string will be output to screen
            $Result = { Get-TestTime -Tests $TestResult | Out-String -Stream } | Using-Culture -Culture de-DE
            $Result | Should-BeString "3.5"
        }
        It "Time is measured in seconds with 0,1 millisecond as lowest value" {
            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]1000 }
            Get-TestTime -Tests $TestResult | Should-Be 0.0001
            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]100 }
            Get-TestTime -Tests $TestResult | Should-Be 0
            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]1234567 }
            Get-TestTime -Tests $TestResult | Should-Be 0.1235
        }
    }

    Describe "GetFullPath" {
        BeforeAll {
            If (($PSVersionTable.ContainsKey('PSEdition')) -and ($PSVersionTable.PSEdition -eq 'Core')) {
                $CommandToTest = "pwsh"
            }
            Else {
                $CommandToTest = "powershell"
            }
        }

        It "Resolves non existing path correctly" {
            Push-Location -Path TestDrive:\
            $p = GetFullPath notexistingfile.txt
            Pop-Location
            $p | Should-Be (Join-Path $TestDrive notexistingfile.txt)
        }

        It "Resolves non existing path correctly - PSDrive" {
            Push-Location -Path TestDrive:\
            $p = GetFullPath TestDrive:\notexistingfile.txt
            Pop-Location
            $p | Should-Be (Join-Path $TestDrive notexistingfile.txt)
        }

        It "Resolves existing path correctly" {
            Push-Location -Path TestDrive:\
            New-Item -ItemType File -Name existingfile1.txt
            $p = GetFullPath existingfile1.txt
            Pop-Location
            $p | Should-Be (Join-Path $TestDrive existingfile1.txt)
        }

        It "Resolves existing path correctly - PSDrive" {
            Push-Location -Path TestDrive:\
            New-Item -ItemType File -Name existingfile2.txt
            $p = GetFullPath existingfile2.txt
            Pop-Location
            $p | Should-Be (Join-Path $TestDrive existingfile2.txt)
        }

        It "Resolves full path correctly" {
            $powershellPath = Get-Command -Name $CommandToTest | Select-Object -ExpandProperty 'Definition'
            $powershellPath | Should-NotBeEmptyString

            GetFullPath $powershellPath | Should-BeString $powershellPath
        }

        Pop-Location

    }

    # Regression tests for https://github.com/pester/Pester/issues/2678
    # Get-CimInstance can fail with access denied when not running as Administrator.
    # The fix adds -ErrorAction Ignore and a fallback to Unknown values so the report
    # is not broken just because OS info is unavailable.
    Describe "Get-RunTimeEnvironment" {
        It "Returns a hashtable with expected keys without throwing" {
            $result = Get-RunTimeEnvironment
            $result | Should-HaveType ([hashtable])
            $result.Keys | Should-ContainCollection 'os-version'
            $result.Keys | Should-ContainCollection 'platform'
            $result.Keys | Should-ContainCollection 'machine-name'
            $result.Keys | Should-ContainCollection 'user'
            $result.Keys | Should-ContainCollection 'cwd'
            $result.Keys | Should-ContainCollection 'clr-version'
            $result['os-version'] | Should-NotBeEmptyString
            $result['platform']   | Should-NotBeEmptyString
        }

        It "Falls back to Unknown OS info when Get-CimInstance returns null (access denied)" -Skip:(-not $IsWindows) {
            # Simulate -ErrorAction Ignore swallowing an access-denied error: the call returns $null.
            # Before the fix, $osSystemInformation stayed $null and $osSystemInformation.Version
            # silently produced $null fields in the report; an ugly access-denied error was also
            # printed because -ErrorAction Ignore was missing.
            $originalCim = $SafeCommands['Get-CimInstance']
            $originalWmi = $SafeCommands['Get-WmiObject']
            try {
                $SafeCommands['Get-CimInstance'] = { param($Class) }
                if ($null -ne $originalWmi) {
                    $SafeCommands['Get-WmiObject'] = { param($Class) }
                }

                $result = Get-RunTimeEnvironment

                $result['platform']   | Should-BeString 'Unknown'
                $result['os-version'] | Should-BeString '0.0.0.0'
            }
            finally {
                $SafeCommands['Get-CimInstance'] = $originalCim
                if ($null -ne $originalWmi) {
                    $SafeCommands['Get-WmiObject'] = $originalWmi
                }
            }
        }
    }
}
