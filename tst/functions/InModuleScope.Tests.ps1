Set-StrictMode -Version Latest

Describe "Module scope separation" {
    Context "When users define variables with the same name as Pester parameters" {
        BeforeAll {
            $test = "This is a test."
        }

        It "does not hide user variables" {
            $test | Should -Be 'This is a test.'
        }
    }

    It "Does not expose Pester implementation details to the SUT" {
        # Changing the ConvertTo-PesterResult function's name would cause this test to pass artificially.
        # TODO: : come up with a better way of verifying that only the desired commands from the Pester
        # module are visible to the SUT.

        (Get-Item function:\ConvertTo-PesterResult -ErrorAction SilentlyContinue) | Should -Be $null
    }
}

Describe "Executing test code inside a module" {
    # do not put this into BeforeAll this needs to be imported before calling InModuleScope
    # that is below, because it requires the module to be loaded
    Get-Module TestModule | Remove-Module
    New-Module -Name TestModule {
        function InternalFunction {
            'I am the internal function'
        }
        function PublicFunction {
            InternalFunction
        }
        Export-ModuleMember -Function PublicFunction
    } | Import-Module -Force

    It "Cannot call module internal functions, by default" {
        { InternalFunction } | Should -Throw
    }

    InModuleScope TestModule {
        It "Can call module internal functions using InModuleScope" {
            InternalFunction | Should -Be 'I am the internal function'
        }

        It "Can mock functions inside the module without using Mock -ModuleName" {
            Mock InternalFunction { 'I am the mock function.' }
            InternalFunction | Should -Be 'I am the mock function.'
        }
    }

    It "Can execute bound ScriptBlock inside the module scope" {
        $ScriptBlock = { Write-Output "I am a bound ScriptBlock" }
        InModuleScope TestModule $ScriptBlock | Should -BeExactly "I am a bound ScriptBlock"
    }

    It "Can execute unbound ScriptBlock inside the module scope" {
        $ScriptBlockString = 'Write-Output "I am an unbound ScriptBlock"'
        $ScriptBlock = [ScriptBlock]::Create($ScriptBlockString)
        InModuleScope TestModule $ScriptBlock | Should -BeExactly "I am an unbound ScriptBlock"
    }

    AfterAll {
        # keep this in AfterAll so we remove the module after tests are invoked
        # and not while the tests are discovered
        Remove-Module TestModule -Force
    }
}

Describe "Get-ScriptModule behavior" {

    Context "When attempting to mock a command in a non-existent module" {

        It "should throw an exception" {
            {
                Mock -CommandName "Invoke-MyMethod" `
                    -ModuleName  "MyNonExistentModule" `
                    -MockWith { write-host "my mock called!" }
            } | Should -Throw "No modules named 'MyNonExistentModule' are currently loaded."
        }

    }

}

Describe 'InModuleScope parameter binding' {
    # do not put this into BeforeAll this needs to be imported before calling InModuleScope
    # that is below, because it requires the module to be loaded

    Get-Module TestModule2 | Remove-Module
    New-Module -Name TestModule2 { } | Import-Module -Force

    It 'Works with parameters while using advanced function/script' {
        # https://github.com/pester/Pester/issues/1809
        $inModuleScopeParameters = @{
            SomeParam = 'SomeValue'
        }

        $sb = {
            param
            (
                [Parameter()]
                [System.String]
                $SomeParam
            )
            "$SomeParam"
        }

        InModuleScope -ModuleName TestModule2 -Parameters $inModuleScopeParameters -ScriptBlock $sb | Should -Be $inModuleScopeParameters.SomeParam
    }

    It 'Works with parameters and arguments while using advanced function/script' {
        # https://github.com/pester/Pester/issues/1809
        $inModuleScopeParameters = @{
            SomeParam = 'SomeValue'
        }

        $myArgs = "foo", 123

        $sb = {
            param
            (
                [Parameter()]
                [System.String]
                $SomeParam,

                [Parameter(ValueFromRemainingArguments = $true)]
                $RemainingArgs
            )
            "$SomeParam"
            $RemainingArgs.Count
        }

        InModuleScope -ModuleName TestModule2 -Parameters $inModuleScopeParameters -ScriptBlock $sb -ArgumentList $myArgs | Should -Be @($inModuleScopeParameters.SomeParam, $myArgs.Count)
    }

    It 'Automatically imports parameters as variables in module scope' {
        # https://github.com/pester/Pester/issues/1603
        $inModuleScopeParameters = @{
            SomeParam2 = 'MyValue'
        }

        $sb = {
            "$SomeParam2"
        }

        $sb2 = {
            # Should return nothing. Making sure dynamic variable isn't persisted in module state.
            "$SomeParam2"
        }

        InModuleScope -ModuleName TestModule2 -ScriptBlock $sb -Parameters $inModuleScopeParameters | Should -Be $inModuleScopeParameters.SomeParam2
        InModuleScope -ModuleName TestModule2 -ScriptBlock $sb2 | Should -BeNullOrEmpty
    }

    AfterAll {
        # keep this in AfterAll so we remove the module after tests are invoked
        # and not while the tests are discovered
        Remove-Module TestModule2 -Force
    }
}

Describe "Using variables within module scope" {
    # do not put this into BeforeAll this needs to be imported before calling InModuleScope
    # that is below, because it requires the module to be loaded
    Get-Module TestModule | Remove-Module
    New-Module -Name TestModule { } | Import-Module -Force

    It 'Only script-scoped variables should persist across InModuleScope calls' {
        $setup = {
            $script:myVar = 'bar'
            $myVar2 = 'bar'
        }
        InModuleScope -ModuleName TestModule2 -ScriptBlock $setup

        InModuleScope -ModuleName TestModule2 -ScriptBlock { $script:myVar } | Should -Be 'bar'
        InModuleScope -ModuleName TestModule2 -ScriptBlock { $myVar2 } | Should -BeNullOrEmpty
    }

    AfterAll {
        # keep this in AfterAll so we remove the module after tests are invoked
        # and not while the tests are discovered
        Remove-Module TestModule2 -Force
    }
}
