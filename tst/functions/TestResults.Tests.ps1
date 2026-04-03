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
            $Result | Should -Be "3.5"
        }
        It "Time is measured in seconds with 0,1 millisecond as lowest value" {
            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]1000 }
            Get-TestTime -Tests $TestResult | Should -Be 0.0001
            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]100 }
            Get-TestTime -Tests $TestResult | Should -Be 0
            $TestResult = New-Object -TypeName psObject -Property @{ Time = [timespan]1234567 }
            Get-TestTime -Tests $TestResult | Should -Be 0.1235
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
            $p | Should -Be (Join-Path $TestDrive notexistingfile.txt)
        }

        It "Resolves non existing path correctly - PSDrive" {
            Push-Location -Path TestDrive:\
            $p = GetFullPath TestDrive:\notexistingfile.txt
            Pop-Location
            $p | Should -Be (Join-Path $TestDrive notexistingfile.txt)
        }

        It "Resolves existing path correctly" {
            Push-Location -Path TestDrive:\
            New-Item -ItemType File -Name existingfile1.txt
            $p = GetFullPath existingfile1.txt
            Pop-Location
            $p | Should -Be (Join-Path $TestDrive existingfile1.txt)
        }

        It "Resolves existing path correctly - PSDrive" {
            Push-Location -Path TestDrive:\
            New-Item -ItemType File -Name existingfile2.txt
            $p = GetFullPath existingfile2.txt
            Pop-Location
            $p | Should -Be (Join-Path $TestDrive existingfile2.txt)
        }

        It "Resolves full path correctly" {
            $powershellPath = Get-Command -Name $CommandToTest | Select-Object -ExpandProperty 'Definition'
            $powershellPath | Should -Not -BeNullOrEmpty

            GetFullPath $powershellPath | Should -Be $powershellPath
        }

        Pop-Location

    }

    # Regression test for https://github.com/pester/Pester/issues/2678
    # Get-CimInstance can fail with access denied when not running as Administrator.
    # The fix adds -ErrorAction Ignore and a fallback to prevent the entire test report
    # from failing just because OS info is unavailable.
    Describe "Get-RunTimeEnvironment" {
        It "Returns a hashtable with expected keys without throwing" {
            $result = Get-RunTimeEnvironment
            $result | Should -BeOfType [hashtable]
            $result.Keys | Should -Contain 'os-version'
            $result.Keys | Should -Contain 'platform'
            $result.Keys | Should -Contain 'machine-name'
            $result.Keys | Should -Contain 'user'
            $result.Keys | Should -Contain 'cwd'
            $result.Keys | Should -Contain 'clr-version'
        }

        It "Returns non-null os-version and platform values" {
            # Even with access denied, the fallback should provide 'Unknown' / '0.0.0.0'
            $result = Get-RunTimeEnvironment
            $result['os-version'] | Should -Not -BeNullOrEmpty
            $result['platform'] | Should -Not -BeNullOrEmpty
        }
    }
}
