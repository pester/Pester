Set-StrictMode -Version Latest

Describe 'Testing Describe' {
    It 'Has a non-mandatory fixture parameter which throws the proper error message if missing' {
        $command = Get-Command Describe -Module Pester
        $command | Should Not Be $null

        $parameter = $command.Parameters['Fixture']
        $parameter | Should Not Be $null

        # Some environments (Nano/CoreClr) don't have all the type extensions
        $attribute = $parameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
        $isMandatory = $null -ne $attribute -and $attribute.Mandatory

        $isMandatory | Should Be $false

        { Describe Bogus } | Should Throw 'No test script block is provided'
    }
    Context 'Testing Describe with an error in AfterAll' {
        BeforeAll {
            $Content1 = @"
Describe "describe 1" {
    AfterAll { throw "badness" }
    It "test 1" { 1 | should be 1 }
    It "test 2" { 1 | should be 1 }
}
"@
            $Content2 = @"
Describe "describe 2" {
    It "test 3" { 1 | should be 1 }
    It "test 4" { 1 | should be 1 }
}
"@
            Setup -d ptest
            setup -f ptest/t1.tests.ps1 -content $Content1
            setup -f ptest/t2.tests.ps1 -content $Content2
            $pesterBase = (get-module pester).modulebase
            # isolate this in a new runspace because we're running
            # invoke-pester, which will create a new TESTDRIVE
            $ps = [powershell]::Create([System.Management.Automation.RunspaceMode]::NewRunspace)
        }
        AfterAll {
            $ps.dispose()
        }
        It "Pester should return a failure in the case of a error in AfterAll" {
            $r = $ps.AddScript("import-module $pesterBase; invoke-pester '$TESTDRIVE/ptest' -quiet -pass").Invoke()
            $r.TotalCount  | should be 5
            $r.PassedCount | should be 4
            $r.FailedCount | should be 1
        }
    }
}
