Set-StrictMode -Version Latest
BeforeAll {
    $PSDefaultParameterValues = @{ 'Should:ErrorAction' = 'Stop' }
    function FunctionUnderTest {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $false)]
            [string]
            $param1
        )

        return "I am a real world test"
    }

    function FunctionUnderTestWithoutParams([string]$param1) {
        return "I am a real world test with no params"
    }

    filter FilterUnderTest {
        $_
    }

    function CommonParamFunction (
        [string] ${Uncommon},
        [switch]
        ${Verbose},
        [switch]
        ${Debug},
        [System.Management.Automation.ActionPreference]
        ${ErrorAction},
        [System.Management.Automation.ActionPreference]
        ${WarningAction},
        [System.String]
        ${ErrorVariable},
        [System.String]
        ${WarningVariable},
        [System.String]
        ${OutVariable},
        [System.Int32]
        ${OutBuffer} ) {
        return "Please strip me of my common parameters. They are far too common."
    }

    function PipelineInputFunction {
        param(
            [Parameter(ValueFromPipeline = $True)]
            [int]$PipeInt1,
            [Parameter(ValueFromPipeline = $True)]
            [int[]]$PipeInt2,
            [Parameter(ValueFromPipeline = $True)]
            [string]$PipeStr,
            [Parameter(ValueFromPipelineByPropertyName = $True)]
            [int]$PipeIntProp,
            [Parameter(ValueFromPipelineByPropertyName = $True)]
            [int[]]$PipeArrayProp,
            [Parameter(ValueFromPipelineByPropertyName = $True)]
            [string]$PipeStringProp
        )
        begin {
            $p = 0
        }
        process {
            foreach ($i in $input) {
                $p += 1
                write-output @{
                    index          = $p;
                    val            = $i;
                    PipeInt1       = $PipeInt1;
                    PipeInt2       = $PipeInt2;
                    PipeStr        = $PipeStr;
                    PipeIntProp    = $PipeIntProp;
                    PipeArrayProp  = $PipeArrayProp;
                    PipeStringProp = $PipeStringProp;
                }
            }
        }
    }
}

Describe "When the caller mocks a command Pester uses internally" {
    Context "Context run when Write-Host is mocked" {
        BeforeAll {
            Mock Write-Host { }
        }

        It "does not make extra calls to the mocked command" {
            Write-Host 'Some String'
            Should -Invoke 'Write-Host' -Exactly 1
        }

        It "retains the correct mock count after the first test completes" {
            Should -Invoke 'Write-Host' -Exactly 1 -Scope Context
        }
    }
}

Describe "When calling Mock on existing cmdlet" {
    BeforeAll {
        Mock Get-Process { return "I am not Get-Process" }
        $result = Get-Process
    }

    It "Should Invoke the mocked script" {
        $result | Should -Be "I am not Get-Process"
    }

    It 'Should not resolve $args to the parent scope' {
        { $args = 'From', 'Parent', 'Scope'; Get-Process SomeName } | Should -Not -Throw
    }
}

Describe 'When calling Mock on an alias' {

    BeforeAll {
        (Get-Item Env:PATH).Value

        $originalPath = $env:path

        # Our TeamCity server has a dir.exe on the system path, and PowerShell v2 apparently finds that instead of the PowerShell alias first.
        # This annoying bit of code makes sure our test works as intended even when this is the case.

        $dirExe = Get-Command dir -CommandType Application -ErrorAction SilentlyContinue
        if ($null -ne $dirExe) {
            foreach ($app in $dirExe) {
                $parent = (Split-Path $app.Path -Parent).TrimEnd('\')
                $pattern = "^$([regex]::Escape($parent))\\?"

                $env:path = $env:path -split ';' -notmatch $pattern -join ';'
            }
        }

        Mock dir { return 'I am not dir' }

        $result = dir
    }

    It 'Should Invoke the mocked script' {
        $result | Should -Be 'I am not dir'
    }

    AfterAll {
        $env:path = $originalPath
    }
}

Describe 'When calling Mock on an alias that refers to a function Pester can''t see' {
    It 'Mocks the aliased command successfully' {
        # This function is defined in a non-global scope; code inside the Pester module can't see it directly.
        function orig {
            'orig'
        }
        New-Alias 'ali' orig

        ali | Should -Be 'orig'

        { mock ali { 'mck' } } | Should -Not -Throw

        ali | Should -Be 'mck'
    }
}

Describe 'When calling Mock on a filter' {
    BeforeAll {
        Mock FilterUnderTest { return 'I am not FilterUnderTest' }
        $result = 'Yes I am' | FilterUnderTest
    }

    It 'Should Invoke the mocked script' {
        $result | Should -Be 'I am not FilterUnderTest'
    }
}

Describe 'When calling Mock on an external script' {
    BeforeAll {
        $ps1File = New-Item 'TestDrive:\tempExternalScript.ps1' -ItemType File -Force
        $ps1File | Set-Content -Value "'I am tempExternalScript.ps1'"

        Mock 'TestDrive:\tempExternalScript.ps1' { return 'I am not tempExternalScript.ps1' }

        <#
        # Invoking the script using its absolute path is not supported

        $result = TestDrive:\tempExternalScript.ps1
        It 'Should Invoke the absolute-path-qualified mocked script using just the script name' {
            $result | Should -Be 'I am not tempExternalScript.ps1'
        }

        $result = & TestDrive:\tempExternalScript.ps1
        It 'Should Invoke the absolute-path-qualified mocked script using the command-invocation operator (&)' {
            $result | Should -Be 'I am not tempExternalScript.ps1'
        }

        $result = . TestDrive:\tempExternalScript.ps1
        It 'Should Invoke the absolute-path-qualified mocked script using dot source notation' {
            $result | Should -Be 'I am not tempExternalScript.ps1'
        }
    #>

        Push-Location TestDrive:\

        $result = tempExternalScript.ps1
    }

    It 'Should Invoke the mocked script using just the script name' {
        $result | Should -Be 'I am not tempExternalScript.ps1'
    }


    It 'Should Invoke the mocked script using the command-invocation operator' {
        #the command invocation operator is (&). Moved this to comment because it breaks the continuous builds.
        #there is issue for this on GH
        $result = & tempExternalScript.ps1
        $result | Should -Be 'I am not tempExternalScript.ps1'
    }


    It 'Should Invoke the mocked script using dot source notation' {
        $result = . tempExternalScript.ps1
        $result | Should -Be 'I am not tempExternalScript.ps1'
    }

    <#
        # Invoking the script using only its relative path is not supported

        $result = .\tempExternalScript.ps1
        It 'Should Invoke the relative-path-qualified mocked script' {
            $result | Should -Be 'I am not tempExternalScript.ps1'
        }
    #>

    AfterAll {
        Pop-Location

        Remove-Item $ps1File -Force -ErrorAction SilentlyContinue
    }
}

InModuleScope -ModuleName Pester {
    Describe 'When calling Mock on an application command' {

        if ((GetPesterOs) -ne 'Windows') {
            It 'Should Invoke the mocked script' {
                Mock id { return "I am not 'id'" }
                $result = id
                $result | Should -Be "I am not 'id'"
            }

        }
        else {
            It 'Should Invoke the mocked script' {
                Mock schtasks.exe { return 'I am not schtasks.exe' }
                $result = schtasks.exe
                $result | Should -Be 'I am not schtasks.exe'
            }
        }
    }
}

Describe "When calling Mock in the Describe block" {
    It "Should mock Out-File successfully" {
        Mock Out-File { return "I am not Out-File" }
        $outfile = "test" | Out-File "TestDrive:\testfile.txt"
        $outfile | Should -Be "I am not Out-File"
    }
}

Describe "When calling Mock on existing cmdlet to handle pipelined input" {
    It "Should process the pipeline in the mocked script" {
        Mock Get-ChildItem {
            if ($_ -eq 'a') {
                return "AA"
            }
            if ($_ -eq 'b') {
                return "BB"
            }
        }

        $result = ''
        "a", "b" | Get-ChildItem | ForEach { $result += $_ }

        $result | Should -Be "AABB"
    }
}

Describe "When calling Mock on existing cmdlet with Common params" {
    BeforeAll {
        Mock CommonParamFunction
        $result = [string](Get-Alias CommonParamFunction).ResolvedCommand.ScriptBlock
    }

    It "Should strip verbose" {
        $result.contains("`${Verbose}") | Should -Be $false
    }
    It "Should strip Debug" {
        $result.contains("`${Debug}") | Should -Be $false
    }
    It "Should strip ErrorAction" {
        $result.contains("`${ErrorAction}") | Should -Be $false
    }
    It "Should strip WarningAction" {
        $result.contains("`${WarningAction}") | Should -Be $false
    }
    It "Should strip ErrorVariable" {
        $result.contains("`${ErrorVariable}") | Should -Be $false
    }
    It "Should strip WarningVariable" {
        $result.contains("`${WarningVariable}") | Should -Be $false
    }
    It "Should strip OutVariable" {
        $result.contains("`${OutVariable}") | Should -Be $false
    }
    It "Should strip OutBuffer" {
        $result.contains("`${OutBuffer}") | Should -Be $false
    }
    It "Should not strip an Uncommon param" {
        $result.contains("`${Uncommon}") | Should -Be $true
    }
}

Describe "When calling Mock on non-existing function" {


    It "Should throw correct error" {
        try {
            Mock NotFunctionUnderTest { return }
        }
        catch {
            $result = $_
        }
        $result.Exception.Message | Should -Be "Could not find command NotFunctionUnderTest"
    }
}

Describe "When calling Mock on non existent module" {

    It "Should throw correct error" {
        $params = @{
            CommandName = 'Invoke-MyMethod'
            ModuleName  = 'MyNonExistentModule'
        }

        { Mock @params -MockWith { write-host "my mock called!" } } | Should -Throw "No modules named 'MyNonExistentModule' are currently loaded."
    }

}

Describe 'When calling Mock, StrictMode is enabled, and variables are used in the ParameterFilter' {
    BeforeAll {
        Set-StrictMode -Version Latest

        $result = $null
        $testValue = 'test'

        try {
            Mock FunctionUnderTest { 'I am the mock' } -ParameterFilter { $param1 -eq $testValue }
        }
        catch {
            $result = $_
        }
    }

    It 'Does not throw an error when testing the parameter filter' {
        $result | Should -Be $null
    }

    It 'Calls the mock properly' {
        FunctionUnderTest $testValue | Should -Be 'I am the mock'
    }

    It 'Properly asserts the mock was called when there is a variable in the parameter filter' {
        Should -Invoke FunctionUnderTest -Exactly 1 -ParameterFilter { $param1 -eq $testValue } -Scope Describe
    }
}

Describe "When calling Mock on existing function without matching bound params" {
    It "Should redirect to real function" {
        Mock FunctionUnderTest { return "fake results" } -parameterFilter { $param1 -eq "test" }
        $result = FunctionUnderTest "badTest"
        $result | Should -Be "I am a real world test"
    }
}

Describe "When calling Mock on existing function with matching bound params" {
    It "Should return mocked result" {
        Mock FunctionUnderTest { return "fake results" } -parameterFilter { $param1 -eq "badTest" }
        $result = FunctionUnderTest "badTest"
        $result | Should -Be "fake results"
    }
}

Describe  "When calling Mock on existing function without matching unbound arguments" {
    It "Should redirect to real function" {
        Mock FunctionUnderTestWithoutParams { return "fake results" } -parameterFilter { $param1 -eq "test" -and $args[0] -eq 'notArg0' }
        $result = FunctionUnderTestWithoutParams -param1 "test" "arg0"
        $result | Should -Be "I am a real world test with no params"
    }
}

Describe "When calling Mock on existing function with matching unbound arguments" {
    It "Should return mocked result" {
        Mock FunctionUnderTestWithoutParams { return "fake results" } -parameterFilter { $param1 -eq "badTest" -and $args[0] -eq 'arg0' }
        $result = FunctionUnderTestWithoutParams "badTest" "arg0"
        $result | Should -Be "fake results"
    }
}

Describe 'When calling Mock on a function that has no parameters' {
    BeforeAll {
        function Test-Function { }
        Mock Test-Function { return $args.Count }
    }
    It 'Sends the $args variable properly with 2+ elements' {
        Test-Function 1 2 3 4 5 | Should -Be 5
    }

    It 'Sends the $args variable properly with 1 element' {
        Test-Function 1 | Should -Be 1
    }

    It 'Sends the $args variable properly with 0 elements' {
        Test-Function | Should -Be 0
    }
}

Describe "When calling Mock on cmdlet Used by Mock" {
    It "Should Invoke the mocked script" {
        Mock Set-Item { return "I am not Set-Item" }
        Mock Set-Item { return "I am not Set-Item" }

        $result = Set-Item "mypath" -value "value"
        $result | Should -Be "I am not Set-Item"
    }
}

Describe "When calling Mock on More than one command" {
    BeforeAll {
        Mock Invoke-Command { return "I am not Invoke-Command" }
        Mock FunctionUnderTest { return "I am the mock test" }

        $result = Invoke-Command { return "yes I am" }
        $result2 = FunctionUnderTest
    }

    It "Should Invoke the mocked script for the first Mock" {
        $result | Should -Be "I am not Invoke-Command"
    }
    It "Should Invoke the mocked script for the second Mock" {
        $result2 | Should -Be "I am the mock test"
    }
}

Describe 'When calling Mock on a module-internal function.' {
    BeforeAll {
        New-Module -Name TestModule {
            function InternalFunction {
                'I am the internal function'
            }
            function PublicFunction {
                InternalFunction
            }
            function PublicFunctionThatCallsExternalCommand {
                Start-Sleep 0
            }

            function FuncThatOverwritesExecutionContext {
                param ($ExecutionContext)

                InternalFunction
            }

            Export-ModuleMember -Function PublicFunction, PublicFunctionThatCallsExternalCommand, FuncThatOverwritesExecutionContext
        } | Import-Module -Force

        New-Module -Name TestModule2 {
            function InternalFunction {
                'I am the second module internal function'
            }
            function InternalFunction2 {
                'I am the second module, second function'
            }
            function PublicFunction {
                InternalFunction
            }
            function PublicFunction2 {
                InternalFunction2
            }

            function FuncThatOverwritesExecutionContext {
                param ($ExecutionContext)

                InternalFunction
            }

            function ScopeTest {
                return Get-CallerModuleName
            }

            function Get-CallerModuleName {
                [CmdletBinding()]
                param ( )

                return $PSCmdlet.SessionState.Module.Name
            }

            Export-ModuleMember -Function PublicFunction, PublicFunction2, FuncThatOverwritesExecutionContext, ScopeTest
        } | Import-Module -Force
    }

    It 'Should fail to call the internal module function' {
        { TestModule\InternalFunction } | Should -Throw
    }

    It 'Should call the actual internal module function from the public function' {
        TestModule\PublicFunction | Should -Be 'I am the internal function'
    }

    Context 'Using Mock -ModuleName "ModuleName" "CommandName" syntax' {
        BeforeAll {
            Mock -ModuleName TestModule InternalFunction { 'I am the mock test' }
            Mock -ModuleName TestModule Start-Sleep { }
            Mock -ModuleName TestModule2 InternalFunction -ParameterFilter { $args[0] -eq 'Test' } {
                "I'm the mock who's been passed parameter Test"
            }
            # Mock -ModuleName TestModule2 InternalFunction2 {
            #     # this does not work in v5 because we are running the mock in the test scope
            #     # so this module internal function is not accessible to the mock body
            #     InternalFunction 'Test'
            # }
            Mock -ModuleName TestModule2 Get-CallerModuleName -ParameterFilter { $false }
            Mock -ModuleName TestModule2 Get-Content { }
        }

        It 'Should call the mocked InternalFunction' {
            TestModule\PublicFunction | Should -Be 'I am the mock test'
        }

        It 'Should be able to count the call to the InternalFunction' {
            # using fully qualified call because PublicFunction resolves to TestModule2 and
            # that is not mocked
            TestModule\PublicFunction # that calls InternalFunction

            Should -Invoke -ModuleName TestModule -CommandName InternalFunction -Exactly 1
        }

        It 'Should mock calls to external functions from inside the module' {
            PublicFunctionThatCallsExternalCommand

            Should -Invoke -ModuleName TestModule -CommandName Start-Sleep -Exactly 1
        }

        It 'Should only call mocks within the same module' {
            TestModule2\PublicFunction | Should -Be 'I am the second module internal function'
        }


        # this does not work because mock bodies are now run in test scope
        # and so the internal function hidden in the mock body is not accessible
        # It 'Should call mocks from inside another mock' {
        #     TestModule2\PublicFunction2 | Should -Be "I'm the mock who's been passed parameter Test"
        # }

        It 'Should work even if the function is weird and steps on the automatic $ExecutionContext variable.' {
            TestModule2\FuncThatOverwritesExecutionContext | Should -Be 'I am the second module internal function'
            TestModule\FuncThatOverwritesExecutionContext | Should -Be 'I am the mock test'
        }

        It 'Should call the original command from the proper scope if no parameter filters match' {
            TestModule2\ScopeTest | Should -Be 'TestModule2'
        }

        It 'Does not trigger the mocked Get-Content from Pester internals' {
            Mock -ModuleName TestModule2 Get-CallerModuleName -ParameterFilter { $false }
            Should -Invoke -ModuleName TestModule2 -CommandName Get-Content -Times 0 -Scope It
        }
    }

    AfterAll {
        Remove-Module TestModule -Force
        Remove-Module TestModule2 -Force
    }
}

Describe "When Applying multiple Mocks on a single command" {
    BeforeAll {
        Mock FunctionUnderTest { return "I am the first mock test" } -parameterFilter { $param1 -eq "one" }
        Mock FunctionUnderTest { return "I am the Second mock test" } -parameterFilter { $param1 -eq "two" }

        $result = FunctionUnderTest "one"
        $result2 = FunctionUnderTest "two"
    }

    It "Should Invoke the mocked script for the first Mock" {
        $result | Should -Be "I am the first mock test"
    }
    It "Should Invoke the mocked script for the second Mock" {
        $result2 | Should -Be "I am the Second mock test"
    }
}

Describe "When Applying multiple Mocks with filters on a single command where both qualify" {
    BeforeAll {
        Mock FunctionUnderTest { return "I am the first mock test" } -parameterFilter { $param1.Length -gt 0 }
        Mock FunctionUnderTest { return "I am the Second mock test" } -parameterFilter { $param1 -gt 1 }

        $result = FunctionUnderTest "one"
    }

    It "The last Mock should win" {
        $result | Should -Be "I am the Second mock test"
    }
}

Describe "When Applying multiple Mocks on a single command where one has no filter" {
    BeforeAll {
        Mock FunctionUnderTest { return "I am the first mock test" } -parameterFilter { $param1 -eq "one" }
        Mock FunctionUnderTest { return "I am the paramless mock test" }
        Mock FunctionUnderTest { return "I am the Second mock test" } -parameterFilter { $param1 -eq "two" }

        $result = FunctionUnderTest "one"
        $result2 = FunctionUnderTest "three"
    }

    It "The parameterless mock is evaluated last" {
        $result | Should -Be "I am the first mock test"
    }

    It "The parameterless mock will be applied if no other wins" {
        $result2 | Should -Be "I am the paramless mock test"
    }
}

Describe "When Creating Verifiable Mock that is not called" {
    Context "In the test script's scope" {
        It "Should throw" {
            Mock FunctionUnderTest { return "I am a verifiable test" } -Verifiable -parameterFilter { $param1 -eq "one" }
            FunctionUnderTest "three" | Out-Null
            $result = $null
            try {
                Should -InvokeVerifiable
            }
            catch {
                $result = $_
            }

            $result.Exception.Message | Should -Be "$([System.Environment]::NewLine)Expected all verifiable mocks to be called, but these were not:$([System.Environment]::NewLine) Command FunctionUnderTest with { `$param1 -eq `"one`" }"
        }
    }

    Context "In a module's scope" {
        BeforeAll {
            New-Module -Name TestModule -ScriptBlock {
                function ModuleFunctionUnderTest {
                    return 'I am the function under test in a module'
                }
            } | Import-Module -Force

            Mock -ModuleName TestModule ModuleFunctionUnderTest { return "I am a verifiable test" } -Verifiable -parameterFilter { $param1 -eq "one" }
            TestModule\ModuleFunctionUnderTest "three" | Out-Null

            try {
                Should -InvokeVerifiable
            }
            Catch {
                $result = $_
            }
        }

        It "Should throw" {
            $result.Exception.Message | Should -Be "$([System.Environment]::NewLine)Expected all verifiable mocks to be called, but these were not:$([System.Environment]::NewLine) Command ModuleFunctionUnderTest from inside module TestModule with { `$param1 -eq `"one`" }"
        }

        AfterAll {
            Remove-Module TestModule -Force
        }
    }
}

Describe "When Creating multiple Verifiable Mocks that are not called" {
    BeforeAll {
        Mock FunctionUnderTest { return "I am a verifiable test" } -Verifiable -ParameterFilter { $param1 -eq "one" }
        Mock FunctionUnderTest { return "I am another verifiable test" } -Verifiable -ParameterFilter { $param1 -eq "two" }
        Mock FunctionUnderTest { return "I am probably called" } -Verifiable -ParameterFilter { $param1 -eq "three" }
        FunctionUnderTest "three" | Out-Null
        $result = $null
        try {
            Should -InvokeVerifiable
        }
        catch {
            $result = $_
        }
    }

    It "Should throw and list all commands" {
        $result.Exception.Message | Should -Be "$([System.Environment]::NewLine)Expected all verifiable mocks to be called, but these were not:$([System.Environment]::NewLine) Command FunctionUnderTest with { `$param1 -eq `"one`" }$([System.Environment]::NewLine) Command FunctionUnderTest with { `$param1 -eq `"two`" }"
    }

    It 'Should include reason when -Because is used' {
        try {
            Should -InvokeVerifiable -Because 'of reasons'
        }
        Catch {
            $failure = $_
        }
        $failure.Exception.Message | Should -Be "$([System.Environment]::NewLine)Expected all verifiable mocks to be called, because of reasons, but these were not:$([System.Environment]::NewLine) Command FunctionUnderTest with { `$param1 -eq `"one`" }$([System.Environment]::NewLine) Command FunctionUnderTest with { `$param1 -eq `"two`" }"
    }
}

Describe "When Creating a Verifiable Mock that is called" {
    BeforeAll {
        Mock FunctionUnderTest -Verifiable -parameterFilter { $param1 -eq "one" }
        FunctionUnderTest "one"
    }

    It "Should -InvokeVerifiable Should not throw" {
        { Should -InvokeVerifiable } | Should -Not -Throw
    }
}

Describe "When calling Should -Not -InvokeVerifiable" {
    Context 'All Verifiable Mocks are called' {
        BeforeAll {
            Mock FunctionUnderTest -Verifiable -parameterFilter { $param1 -eq "one" }
            FunctionUnderTest "one"

            try {
                Should -Not -InvokeVerifiable
            }
            Catch {
                $result = $_
            }
        }

        It "Should throw" {
            $result.Exception.Message | Should -Be "$([System.Environment]::NewLine)Expected no verifiable mocks to be called, but these were:$([System.Environment]::NewLine) Command FunctionUnderTest with { `$param1 -eq `"one`" }"
        }

        It 'Should include reason when -Because is used' {
            try {
                Should -Not -InvokeVerifiable -Because 'of reasons'
            }
            Catch {
                $failure = $_
            }
            $failure.Exception.Message | Should -Be "$([System.Environment]::NewLine)Expected no verifiable mocks to be called, because of reasons, but these were:$([System.Environment]::NewLine) Command FunctionUnderTest with { `$param1 -eq `"one`" }"
        }
    }

    Context 'Some Verifiable Mocks are called' {
        BeforeAll {
            Mock FunctionUnderTest -Verifiable -parameterFilter { $param1 -eq "one" }
            Mock FunctionUnderTest -Verifiable
            FunctionUnderTest "one"

            try {
                Should -Not -InvokeVerifiable
            }
            Catch {
                $result = $_
            }
        }

        It "Should throw" {
            $result.Exception.Message | Should -Be "$([System.Environment]::NewLine)Expected no verifiable mocks to be called, but these were:$([System.Environment]::NewLine) Command FunctionUnderTest with { `$param1 -eq `"one`" }"
        }
    }

    Context 'No Verifiable Mocks exists' {
        BeforeAll {
            Mock FunctionUnderTest -Verifiable -parameterFilter { $param1 -eq "one" }
        }

        It "Should not throw" {
            { Should -Not -InvokeVerifiable } | Should -Not -Throw
        }
    }

    Context 'None of the Verifiable Mocks is called' {
        BeforeAll {
            Mock FunctionUnderTest -Verifiable -parameterFilter { $param1 -eq "one" }
        }

        It "Should not throw" {
            { Should -Not -InvokeVerifiable } | Should -Not -Throw
        }
    }
}

Describe "When Calling Should -Invoke 0 without exactly" {
    BeforeAll {
        Mock FunctionUnderTest {}
        FunctionUnderTest "one"

        try {
            Should -Invoke FunctionUnderTest 0
        }
        Catch {
            $result = $_
        }
    }

    It "Should throw if mock was called" {
        $result.Exception.Message | Should -Be 'Expected FunctionUnderTest to be called 0 times exactly, but was called 1 times'
    }

    It "Should not throw if mock was not called" {
        Should -Invoke FunctionUnderTest 0 -ParameterFilter { $param1 -eq "stupid" }
    }

    It 'Should include reason when -Because is used' {
        try {
            Should -Invoke FunctionUnderTest 0  -Scope Describe -Because 'of reasons'
        }
        Catch {
            $failure = $_
        }
        $failure.Exception.Message | Should -Be 'Expected FunctionUnderTest to be called 0 times exactly, because of reasons, but was called 1 times'
    }
}

Describe "When Calling Should -Not -Invoke without exactly" {
    BeforeAll {
        Mock FunctionUnderTest {}
        FunctionUnderTest "one"

        try {
            Should -Not -Invoke FunctionUnderTest
        }
        Catch {
            $result = $_
        }
    }

    It "Should throw if mock was called once" {
        $result.Exception.Message | Should -Be "Expected FunctionUnderTest not to be called exactly 1 times, but it was"
    }

    It "Should not throw if mock was not called" {
        Should -Not -Invoke FunctionUnderTest -ParameterFilter { $param1 -eq "stupid" }
    }
}

Describe "When Calling Should -Not -Invoke [Times] without exactly" {
    BeforeEach {
        Mock FunctionUnderTest {}
    }

    It "Should not throw if the mock was called less (<MockCalls>) than the number of times specified (<Times>)" -TestCases @(
        @{ MockCalls = 3; Times = 15 }
        @{ MockCalls = 2; Times = 5 }
        @{ MockCalls = 0; Times = 1 }
    ) {
        for ($i = 0; $i -lt $MockCalls; $i++) {
            FunctionUnderTest "one"
        }

        Should -Not -Invoke FunctionUnderTest $Times
    }

    It "Should throw if the mock was called (<MockCalls>) at least the number of times specified (<Times>)" -TestCases @(
        @{ MockCalls = 15; Times = 3 }
        @{ MockCalls = 3; Times = 3 }
        @{ MockCalls = 1; Times = 1 }
        @{ MockCalls = 0; Times = 0 }
    ) {
        for ($i = 0; $i -lt $MockCalls; $i++) {
            FunctionUnderTest "one"
        }

        try {
            Should -Not -Invoke FunctionUnderTest $Times
        }
        Catch {
            $result = $_
        }

        $result.Exception.Message | Should -Be "Expected FunctionUnderTest to be called less than $Times times, but was called $MockCalls times"
    }

    It 'Should include reason when -Because is used' {
        FunctionUnderTest
        FunctionUnderTest

        try {
            Should -Not -Invoke FunctionUnderTest -Times 1 -Because 'of reasons'
        }
        Catch {
            $failure = $_
        }
        $failure.Exception.Message | Should -Be 'Expected FunctionUnderTest to be called less than 1 times, because of reasons, but was called 2 times'
    }
}

Describe "When Calling Should -Invoke with exactly" {
    BeforeAll {
        Mock FunctionUnderTest {}
        FunctionUnderTest "one"
        FunctionUnderTest "one"

        try {
            Should -Invoke FunctionUnderTest -exactly 3
        }
        catch {
            $result = $_
        }
    }

    It "Should throw if mock was not called the number of times specified" {
        $result.Exception.Message | Should -Be "Expected FunctionUnderTest to be called 3 times exactly, but was called 2 times"
    }

    It "Should not throw if mock was called the number of times specified" {
        Should -Invoke FunctionUnderTest -Exactly 2 -ParameterFilter { $param1 -eq "one" } -Scope Describe
    }
}

Describe "When Calling Should -Not -Invoke with exactly" {
    BeforeAll {
        Mock FunctionUnderTest {}
        FunctionUnderTest "one"

        try {
            Should -Not -Invoke FunctionUnderTest -Exactly
        }
        Catch {
            $result = $_
        }
    }

    It "Should throw if mock was called" {
        $result.Exception.Message | Should -Be "Expected FunctionUnderTest not to be called exactly 1 times, but it was"
    }

    It "Should not throw if mock was not called" {
        Should -Not -Invoke FunctionUnderTest -ParameterFilter { $param1 -eq "stupid" }
    }

    It 'Should include reason when -Because is used' {
        try {
            Should -Not -Invoke FunctionUnderTest -Exactly -Scope Describe -Because 'of reasons'
        }
        Catch {
            $failure = $_
        }
        $failure.Exception.Message | Should -Be 'Expected FunctionUnderTest not to be called exactly 1 times, because of reasons, but it was'
    }
}

Describe "When Calling Should -Not -Invoke [Times] with exactly" {
    BeforeEach {
        Mock FunctionUnderTest {}
    }

    It "Should not throw if the mock is called (<MockCalls>) less or more than the number of times specified (<Times>)" -TestCases @(
        @{ MockCalls = 3; Times = 15 }
        @{ MockCalls = 15; Times = 3 }
        @{ MockCalls = 2; Times = 5 }
        @{ MockCalls = 0; Times = 1 }
        @{ MockCalls = 1; Times = 0 }
    ) {
        for ($i = 0; $i -lt $MockCalls; $i++) {
            FunctionUnderTest "one"
        }

        Should -Not -Invoke FunctionUnderTest $Times -Exactly
    }

    It "Should throw if mock was called at exactly the number of times specified (<Times>)" -TestCases @(
        @{ MockCalls = 3; Times = 3 }
        @{ MockCalls = 1; Times = 1 }
        @{ MockCalls = 0; Times = 0 }
    ) {
        for ($i = 0; $i -lt $MockCalls; $i++) {
            FunctionUnderTest "one"
        }

        try {
            Should -Not -Invoke FunctionUnderTest $Times -Exactly
        }
        Catch {
            $result = $_
        }

        $result.Exception.Message | Should -Be "Expected FunctionUnderTest not to be called exactly $Times times, but it was"
    }
}

Describe "When Calling Should -Invoke without exactly" {
    BeforeAll {
        Mock FunctionUnderTest {}
        FunctionUnderTest "one"
        FunctionUnderTest "one"
        FunctionUnderTest "two"
    }

    It "Should throw if mock was not called at least the number of times specified" {
        $scriptBlock = { Should -Invoke FunctionUnderTest 4 -Scope Describe }
        $scriptBlock | Should -Throw "Expected FunctionUnderTest to be called at least 4 times, but was called 3 times"
    }

    It "Should not throw if mock was called at least the number of times specified" {
        Should -Invoke FunctionUnderTest -Scope Describe
    }

    It "Should not throw if mock was called at exactly the number of times specified" {
        Should -Invoke FunctionUnderTest 2 -ParameterFilter { $param1 -eq "one" } -Scope Describe
    }

    It "Should throw an error if any non-matching calls to the mock are made, and the -ExclusiveFilter parameter is used" {
        $scriptBlock = { Should -Invoke FunctionUnderTest -ExclusiveFilter { $param1 -eq 'one' } -Scope Describe }
        $scriptBlock | Should -Throw '*1 non-matching calls were made*'
    }

    It 'Should include reason when -Because is used' {
        try {
            Should -Invoke FunctionUnderTest 4 -Scope Describe -Because 'of reasons'
        }
        Catch {
            $failure = $_
        }
        $failure.Exception.Message | Should -Be 'Expected FunctionUnderTest to be called at least 4 times, because of reasons, but was called 3 times'
    }

    It 'Should include reason when -Because is used with -ExclusiveFilter' {
        try {
            Should -Invoke FunctionUnderTest -ExclusiveFilter { $param1 -eq 'one' } -Scope Describe -Because 'of reasons'
        }
        Catch {
            $failure = $_
        }
        $failure.Exception.Message | Should -Be 'Expected FunctionUnderTest to only be called with with parameters matching the specified filter, because of reasons, but 1 non-matching calls were made'
    }
}

Describe "When Calling Should -Not -Invoke -ExclusiveFilter" {
    BeforeAll {
        Mock FunctionUnderTest {}
        FunctionUnderTest "one"
    }

    It "Should throw an error" {
        $scriptBlock = { Should -Not -Invoke FunctionUnderTest -ExclusiveFilter { $param1 -eq 'one' } -Scope Describe }
        $scriptBlock | Should -Throw 'Cannot use -ExclusiveFilter when -Not is specified. Use -ParameterFilter instead.'
    }
}

Describe 'When Calling Should -Invoke with invalid -Scope' {
    Context 'Using -Scope It outside of It block' {
        BeforeAll {
            Mock FunctionUnderTest {}

            try {
                Should -Not -Invoke FunctionUnderTest -Scope It
            }
            Catch {
                $result = $_
            }
        }
        It 'Should throw' {
            $result.Exception.Message | Should -Be 'Assertion is placed outside of an It block, but -Scope It is specified.'
        }
    }

    It 'Should throw when negative number' {
        $scriptBlock = { Should -Not -Invoke FunctionUnderTest -Scope -1 }
        $scriptBlock | Should -Throw "Parameter Scope must be one of 'Describe', 'Context', 'It' or a non-negative number."
    }

    It 'Should throw when unknown named block' {
        $scriptBlock = { Should -Not -Invoke FunctionUnderTest -Scope SomethingElse }
        $scriptBlock | Should -Throw "Parameter Scope must be one of 'Describe', 'Context', 'It' or a non-negative number."
    }
}

Context 'When Calling Should -Invoke -Scope Describe while not inside Describe' {
    BeforeAll {
        Mock FunctionUnderTest {}
    }
    It 'Should throw' {
        $scriptBlock = { Should -Not -Invoke FunctionUnderTest -Scope Describe }
        $scriptBlock | Should -Throw 'Assertion is not placed directly nor nested inside a Describe block, but -Scope Describe is specified.'
    }
}

Describe 'When Calling Should -Invoke -Scope Context while not inside Context' {
    BeforeAll {
        Mock FunctionUnderTest {}
    }
    It 'Should throw' {
        $scriptBlock = { Should -Not -Invoke FunctionUnderTest -Scope Context }
        $scriptBlock | Should -Throw 'Assertion is not placed directly nor nested inside a Context block, but -Scope Context is specified.'
    }
}

Describe "When Calling Should -Invoke with pipeline-input or -ActualValue" {
    It "Should throw an error on pipeline-input" {
        $scriptBlock = { "value" | Should -Invoke -CommandName "ABC" -Scope Describe }
        $scriptBlock | Should -Throw 'Should -Invoke does not take pipeline input or ActualValue.'
    }

    It "Should throw an error on ActualInput-value" {
        $scriptBlock = { Should -Invoke -CommandName "ABC" -ActualValue "value" -Scope Describe }
        $scriptBlock | Should -Throw 'Should -Invoke does not take pipeline input or ActualValue.'
    }
}

Describe "Using Pester Scopes (Describe,Context,It)" {
    BeforeAll {
        Mock FunctionUnderTest { return "I am the first mock test" } -parameterFilter { $param1 -eq "one" }
        Mock FunctionUnderTest { return "I am the paramless mock test" }
    }

    Context "When in the first context" {
        It "should mock Describe scoped paramless mock" {
            FunctionUnderTest | should -be "I am the paramless mock test"
        }
        It "should mock Describe scoped single param mock" {
            FunctionUnderTest "one" | should -be "I am the first mock test"
        }
    }

    Context "When in the second context" {
        It "should mock Describe scoped paramless mock again" {
            FunctionUnderTest | should -be "I am the paramless mock test"
        }
        It "should mock Describe scoped single param mock again" {
            FunctionUnderTest "one" | should -be "I am the first mock test"
        }
    }

    Context "When using mocks in both scopes" {
        BeforeAll {
            Mock FunctionUnderTestWithoutParams { return "I am the other function" }
        }

        It "should mock Describe scoped mock." {
            FunctionUnderTest | should -be "I am the paramless mock test"
        }
        It "should mock Context scoped mock." {
            FunctionUnderTestWithoutParams | should -be "I am the other function"
        }
    }

    Context "When context hides a describe mock" {
        BeforeAll {
            Mock FunctionUnderTest { return "I am the context mock" }
            Mock FunctionUnderTest { return "I am the parameterized context mock" } -parameterFilter { $param1 -eq "one" }
        }

        It "should use the context paramless mock" {
            FunctionUnderTest | should -be "I am the context mock"
        }
        It "should use the context parameterized mock" {
            FunctionUnderTest "one" | should -be "I am the parameterized context mock"
        }
    }

    Context  "When context no longer hides a describe mock" {
        It "should use the describe mock" {
            FunctionUnderTest | should -be "I am the paramless mock test"
        }

        It "should use the describe parameterized mock" {
            FunctionUnderTest "one" | should -be "I am the first mock test"
        }
    }

    Context 'When someone calls Mock from inside an It block' {
        BeforeAll {
            Mock FunctionUnderTest { return 'I am the context mock' }
        }

        It 'Sets the mock' {
            Mock FunctionUnderTest { return 'I am the It mock' }
        }

        It 'Does not leave the mock active in the parent scope' {
            FunctionUnderTest | Should -Be 'I am the context mock'
        }
    }
}

Describe 'Testing mock history behavior from each scope' {
    BeforeAll {
        function MockHistoryChecker { }
        Mock MockHistoryChecker { 'I am the describe mock.' }
    }

    Context 'Without overriding the mock in lower scopes' {
        It "Reports that zero calls have been made to in the describe scope" {
            Should -Invoke MockHistoryChecker -Exactly 0 -Scope Describe
        }

        It 'Calls the describe mock' {
            MockHistoryChecker | Should -Be 'I am the describe mock.'
        }

        It "Reports that zero calls have been made in an It block, after a context-scoped call" {
            Should -Invoke MockHistoryChecker -Exactly 0 -Scope It
        }

        It "Reports one Context-scoped call" {
            Should -Invoke MockHistoryChecker -Exactly 1 -Scope Context
        }

        It "Reports one Describe-scoped call" {
            Should -Invoke MockHistoryChecker -Exactly 1 -Scope Describe
        }
    }

    Context 'After exiting the previous context' {
        It 'Reports zero context-scoped calls in the new context.' {
            Should -Invoke MockHistoryChecker -Exactly 0
        }

        It 'Reports one describe-scoped call from the previous context' {
            Should -Invoke MockHistoryChecker -Exactly 1 -Scope Describe
        }
    }

    Context 'While overriding mocks in lower scopes' {
        BeforeAll {
            Mock MockHistoryChecker { 'I am the context mock.' }
        }

        It 'Calls the context mock' {
            MockHistoryChecker | Should -Be 'I am the context mock.'
        }

        It 'Reports one context-scoped call' {
            Should -Invoke MockHistoryChecker -Exactly 1 -Scope Context
        }

        It 'Reports two describe-scoped calls, even when one is an override mock in a lower scope' {
            Should -Invoke MockHistoryChecker -Exactly 2 -Scope Describe
        }

        It 'Calls an It-scoped mock' {
            Mock MockHistoryChecker { 'I am the It mock.' }
            MockHistoryChecker | Should -Be 'I am the It mock.'
        }

        It 'Reports 2 context-scoped calls' {
            Should -Invoke MockHistoryChecker -Exactly 2 -Scope Context
        }

        It 'Reports 3 describe-scoped calls' {
            Should -Invoke MockHistoryChecker -Exactly 3 -Scope Describe
        }
    }

    It 'Reports 3 describe-scoped calls using the default scope in a Describe block' {
        Should -Invoke MockHistoryChecker -Exactly 3  -Scope Describe
    }
}

Describe "Using a single no param Describe" {
    BeforeAll {
        Mock FunctionUnderTest { return "I am the describe mock test" }
    }

    Context "With a context mocking the same function with no params" {
        BeforeAll {
            Mock FunctionUnderTest { return "I am the context mock test" }
        }

        It "Should use the context mock" {
            FunctionUnderTest | should -be "I am the context mock test"
        }
    }
}

Describe 'Dot Source Test' {
    # This test is only meaningful if this test file is dot-sourced in the global scope.  If it's executed without
    # dot-sourcing or run by Invoke-Pester, there's no problem.

    BeforeAll {
        function TestFunction {
            Test-Path -Path 'Test'
        }
        Mock Test-Path { }

        $null = TestFunction
    }

    It "Calls the mock with parameter 'Test'" {
        Should -Invoke Test-Path -Exactly 1 -ParameterFilter { $Path -eq 'Test' } -Scope Describe
    }

    It "Doesn't call the mock with any other parameters" {
        Should -Invoke Test-Path -Exactly 0 -ParameterFilter { $Path -ne 'Test' } -Scope Describe
    }
}


Describe 'Mocking Cmdlets with dynamic parameters' {

    if ((InPesterModuleScope { GetPesterOs }) -ne 'Windows') {
        BeforeAll {
            $mockWith = { if (-not $Hidden) {
                    throw 'Hidden variable not found, or set to false!'
                } }
            Mock Get-ChildItem -MockWith $mockWith -ParameterFilter { [bool]$Hidden }
        }

        It 'Allows calls to be made with dynamic parameters (including parameter filters)' {
            { Get-ChildItem -Path / -Hidden } | Should -Not -Throw
            Should -Invoke Get-ChildItem
        }
    }
    else {
        BeforeAll {
            $mockWith = { if (-not $CodeSigningCert) {
                    throw 'CodeSigningCert variable not found, or set to false!'
                } }
            Mock Get-ChildItem -MockWith $mockWith -ParameterFilter { [bool]$CodeSigningCert }
        }

        It 'Allows calls to be made with dynamic parameters (including parameter filters)' {
            Get-ChildItem -Path Cert:\ -CodeSigningCert
            Should -Invoke Get-ChildItem
        }
    }
}

Describe 'Mocking functions with dynamic parameters' {
    Context 'Dynamicparam block that uses the variables of static parameters in its logic' {
        # Get-Greeting sample function borrowed and modified from Bartek Bielawski's
        # blog at http://becomelotr.wordpress.com/2012/05/10/using-and-abusing-dynamic-parameters/

        BeforeAll {
            function Get-Greeting {
                [CmdletBinding()]
                param (
                    [string] $Name
                )

                DynamicParam {
                    if ($Name -cmatch '\b[a-z]') {
                        $Attributes = New-Object Management.Automation.ParameterAttribute
                        $Attributes.ParameterSetName = "__AllParameterSets"
                        $Attributes.Mandatory = $false

                        $AttributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
                        $AttributeCollection.Add($Attributes)

                        $Dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter('Capitalize', [switch], $AttributeCollection)

                        $ParamDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                        $ParamDictionary.Add("Capitalize", $Dynamic)
                        $ParamDictionary
                    }
                }

                end {
                    if ($PSBoundParameters.Capitalize) {
                        $Name = [regex]::Replace(
                            $Name,
                            '\b\w',
                            { $args[0].Value.ToUpper() }
                        )
                    }

                    "Welcome $Name!"
                }
            }

            $mockWith = { if (-not $Capitalize) {
                    throw 'Capitalize variable not found, or set to false!'
                } }
            Mock Get-Greeting -MockWith $mockWith -ParameterFilter { [bool]$Capitalize }
        }

        It 'Allows calls to be made with dynamic parameters (including parameter filters)' {
            { Get-Greeting -Name lowercase -Capitalize } | Should -Not -Throw
            Should -Invoke Get-Greeting
        }

        It 'Sets the dynamic parameter variable properly' {
            $Capitalize = $false
            { Get-Greeting -Name lowercase -Capitalize } | Should -Not -Throw
            Should -Invoke Get-Greeting -Scope It
        }
    }

    Context 'When the mocked command is in a module' {
        BeforeAll {
            New-Module -Name TestModule {
                function PublicFunction {
                    Get-Greeting -Name lowercase -Capitalize
                }

                $script:DoDynamicParam = $true

                # Get-Greeting sample function borrowed and modified from Bartek Bielawski's
                # blog at http://becomelotr.wordpress.com/2012/05/10/using-and-abusing-dynamic-parameters/

                function script:Get-Greeting {
                    [CmdletBinding()]
                    param (
                        [string] $Name
                    )

                    DynamicParam {
                        # This check is here to make sure the mocked version can still work if the
                        # original function's dynamicparam block relied on script-scope variables.
                        if (-not $script:DoDynamicParam) {
                            return
                        }

                        if ($Name -cmatch '\b[a-z]') {
                            $Attributes = New-Object Management.Automation.ParameterAttribute
                            $Attributes.ParameterSetName = "__AllParameterSets"
                            $Attributes.Mandatory = $false

                            $AttributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
                            $AttributeCollection.Add($Attributes)

                            $Dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter('Capitalize', [switch], $AttributeCollection)

                            $ParamDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                            $ParamDictionary.Add("Capitalize", $Dynamic)
                            $ParamDictionary
                        }
                    }

                    end {
                        if ($PSBoundParameters.Capitalize) {
                            $Name = [regex]::Replace(
                                $Name,
                                '\b\w',
                                { $args[0].Value.ToUpper() }
                            )
                        }

                        "Welcome $Name!"
                    }
                }
            } | Import-Module -Force

            $mockWith = { if (-not $Capitalize) {
                    throw 'Capitalize variable not found, or set to false!'
                } }
            Mock Get-Greeting -MockWith $mockWith -ModuleName TestModule -ParameterFilter { [bool]$Capitalize }
        }

        It 'Allows calls to be made with dynamic parameters (including parameter filters)' {
            { TestModule\PublicFunction } | Should -Not -Throw
            Should -Invoke Get-Greeting -ModuleName TestModule -Scope Describe
        }

        AfterAll {
            Remove-Module TestModule -Force
        }
    }

    Context 'When the mocked command has mandatory parameters that are passed in via the pipeline' {
        BeforeAll {
            # Get-Greeting sample function borrowed and modified from Bartek Bielawski's
            # blog at http://becomelotr.wordpress.com/2012/05/10/using-and-abusing-dynamic-parameters/

            function Get-Greeting2 {
                [CmdletBinding()]
                param (
                    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
                    [string] $MandatoryParam,

                    [string] $Name
                )

                DynamicParam {
                    if ($Name -cmatch '\b[a-z]') {
                        $Attributes = New-Object Management.Automation.ParameterAttribute
                        $Attributes.ParameterSetName = "__AllParameterSets"
                        $Attributes.Mandatory = $false

                        $AttributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
                        $AttributeCollection.Add($Attributes)

                        $Dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter('Capitalize', [switch], $AttributeCollection)

                        $ParamDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                        $ParamDictionary.Add("Capitalize", $Dynamic)
                        $ParamDictionary
                    }
                }

                end {
                    if ($PSBoundParameters.Capitalize) {
                        $Name = [regex]::Replace(
                            $Name,
                            '\b\w',
                            { $args[0].Value.ToUpper() }
                        )
                    }

                    "Welcome $Name!"
                }
            }

            Mock Get-Greeting2 { 'Mocked' } -ParameterFilter { [bool]$Capitalize }
            $hash = @{ Result = $null }
            $scriptBlock = { $hash.Result = 'Mandatory' | Get-Greeting2 -Name test -Capitalize }
        }

        It 'Should successfully call the mock and generate the dynamic parameters' {
            $scriptBlock | Should -Not -Throw
            $hash.Result | Should -Be 'Mocked'
        }
    }

    Context 'When the mocked command has parameter sets that are ambiguous at the time the dynamic param block is executed' {
        BeforeAll {
            # Get-Greeting sample function borrowed and modified from Bartek Bielawski's
            # blog at http://becomelotr.wordpress.com/2012/05/10/using-and-abusing-dynamic-parameters/

            function Get-Greeting3 {
                [CmdletBinding()]
                param (
                    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'One')]
                    [string] $One,

                    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'Two')]
                    [string] $Two,

                    [string] $Name
                )

                DynamicParam {
                    if ($Name -cmatch '\b[a-z]') {
                        $Attributes = New-Object Management.Automation.ParameterAttribute
                        $Attributes.ParameterSetName = "__AllParameterSets"
                        $Attributes.Mandatory = $false

                        $AttributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
                        $AttributeCollection.Add($Attributes)

                        $Dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter('Capitalize', [switch], $AttributeCollection)

                        $ParamDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                        $ParamDictionary.Add("Capitalize", $Dynamic)
                        $ParamDictionary
                    }
                }

                end {
                    if ($PSBoundParameters.Capitalize) {
                        $Name = [regex]::Replace(
                            $Name,
                            '\b\w',
                            { $args[0].Value.ToUpper() }
                        )
                    }

                    "Welcome $Name!"
                }
            }

            Mock Get-Greeting3 { 'Mocked' } -ParameterFilter { [bool]$Capitalize }
            $hash = @{ Result = $null }
            $scriptBlock = { $hash.Result = New-Object psobject -Property @{ One = 'One' } | Get-Greeting3 -Name test -Capitalize }
        }

        It 'Should successfully call the mock and generate the dynamic parameters' {
            $scriptBlock | Should -Not -Throw
            $hash.Result | Should -Be 'Mocked'
        }
    }

    Context 'When the mocked command''s dynamicparam block depends on the contents of $PSBoundParameters' {
        BeforeAll {
            # Get-Greeting sample function borrowed and modified from Bartek Bielawski's
            # blog at http://becomelotr.wordpress.com/2012/05/10/using-and-abusing-dynamic-parameters/

            function Get-Greeting4 {
                [CmdletBinding()]
                param (
                    [string] $Name
                )

                DynamicParam {
                    if ($PSBoundParameters['Name'] -cmatch '\b[a-z]') {
                        $Attributes = New-Object Management.Automation.ParameterAttribute
                        $Attributes.ParameterSetName = "__AllParameterSets"
                        $Attributes.Mandatory = $false

                        $AttributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
                        $AttributeCollection.Add($Attributes)

                        $Dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter('Capitalize', [switch], $AttributeCollection)

                        $ParamDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                        $ParamDictionary.Add("Capitalize", $Dynamic)
                        $ParamDictionary
                    }
                }

                end {
                    if ($PSBoundParameters.Capitalize) {
                        $Name = [regex]::Replace(
                            $Name,
                            '\b\w',
                            { $args[0].Value.ToUpper() }
                        )
                    }

                    "Welcome $Name!"
                }
            }

            Mock Get-Greeting4 { 'Mocked' } -ParameterFilter { [bool]$Capitalize }
            $hash = @{ Result = $null }
            $scriptBlock = { $hash.Result = Get-Greeting4 -Name test -Capitalize }
        }

        It 'Should successfully call the mock and generate the dynamic parameters' {
            $scriptBlock | Should -Not -Throw
            $hash.Result | Should -Be 'Mocked'
        }
    }

    Context 'When the mocked command''s dynamicparam block depends on the contents of $PSCmdlet.ParameterSetName' {
        BeforeAll {
            # Get-Greeting sample function borrowed and modified from Bartek Bielawski's
            # blog at http://becomelotr.wordpress.com/2012/05/10/using-and-abusing-dynamic-parameters/

            function Get-Greeting5 {
                [CmdletBinding(DefaultParameterSetName = 'One')]
                param (
                    [string] $Name,

                    [Parameter(ParameterSetName = 'Two')]
                    [string] $Two
                )

                DynamicParam {
                    if ($PSCmdlet.ParameterSetName -eq 'Two' -and $Name -cmatch '\b[a-z]') {
                        $Attributes = New-Object Management.Automation.ParameterAttribute
                        $Attributes.ParameterSetName = "__AllParameterSets"
                        $Attributes.Mandatory = $false

                        $AttributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
                        $AttributeCollection.Add($Attributes)

                        $Dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter('Capitalize', [switch], $AttributeCollection)

                        $ParamDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                        $ParamDictionary.Add("Capitalize", $Dynamic)
                        $ParamDictionary
                    }
                }

                end {
                    if ($PSBoundParameters.Capitalize) {
                        $Name = [regex]::Replace(
                            $Name,
                            '\b\w',
                            { $args[0].Value.ToUpper() }
                        )
                    }

                    "Welcome $Name!"
                }
            }

            Mock Get-Greeting5 { 'Mocked' } -ParameterFilter { [bool]$Capitalize }
            $hash = @{ Result = $null }
            $scriptBlock = { $hash.Result = Get-Greeting5 -Two 'Two' -Name test -Capitalize }
        }

        It 'Should successfully call the mock and generate the dynamic parameters' {
            $scriptBlock | Should -Not -Throw
            $hash.Result | Should -Be 'Mocked'
        }
    }
}


Describe 'Mocking Cmdlets with dynamic parameters in a module' {
    BeforeAll {
        if ((InPesterModuleScope { GetPesterOs }) -ne 'Windows') {
            New-Module -Name TestModule {
                function PublicFunction {
                    Get-ChildItem -Path \ -Hidden
                }
            } | Import-Module -Force

            $mockWith = { if (-not $Hidden) {
                    throw 'Hidden variable not found, or set to false!'
                } }
            Mock Get-ChildItem -MockWith $mockWith -ModuleName TestModule -ParameterFilter { [bool]$Hidden }
        }
        else {
            New-Module -Name TestModule {
                function PublicFunction {
                    Get-ChildItem -Path Cert:\ -CodeSigningCert
                }
            } | Import-Module -Force

            $mockWith = { if (-not $CodeSigningCert) {
                    throw 'CodeSigningCert variable not found, or set to false!'
                } }
            Mock Get-ChildItem -MockWith $mockWith -ModuleName TestModule -ParameterFilter { [bool]$CodeSigningCert }
        }
    }

    It 'Allows calls to be made with dynamic parameters (including parameter filters)' {
        { TestModule\PublicFunction } | Should -Not -Throw
        Should -Invoke Get-ChildItem -ModuleName TestModule
    }

    AfterAll {
        Remove-Module TestModule -Force
    }
}

Describe 'DynamicParam blocks in other scopes' {
    BeforeAll {
        if ((InPesterModuleScope { GetPesterOs }) -ne 'Windows') {
            New-Module -Name TestModule1 {
                $script:DoDynamicParam = $true

                function DynamicParamFunction {
                    [CmdletBinding()]
                    param ( )

                    DynamicParam {
                        if ($script:DoDynamicParam) {

                            $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
                            $params = $PSBoundParameters.GetType().GetConstructor($flags, $null, @(), $null).Invoke(@())

                            $params['Path'] = [string[]]'/'
                            $gmdp = InPesterModuleScope { Get-Command Get-MockDynamicParameter }
                            & $gmdp -CmdletName Get-ChildItem -Parameters $params
                        }
                    }

                    end {
                        'I am the original function'
                    }
                }
            } | Import-Module -Force

            New-Module -Name TestModule2 {
                function CallingFunction {
                    DynamicParamFunction -Hidden
                }

                function CallingFunction2 {
                    [CmdletBinding()]
                    param (
                        [ValidateScript( { [bool](DynamicParamFunction -Hidden) })]
                        [string]
                        $Whatever
                    )
                }
            } | Import-Module -Force

            Mock DynamicParamFunction { if ($Hidden) {
                    'I am the mocked function'
                } } -ModuleName TestModule2
        }
        else {
            New-Module -Name TestModule1 {
                $script:DoDynamicParam = $true

                function DynamicParamFunction {
                    [CmdletBinding()]
                    param ( )

                    DynamicParam {
                        if ($script:DoDynamicParam) {
                            if ($PSVersionTable.PSVersion.Major -ge 3) {
                                # -Parameters needs to be a PSBoundParametersDictionary object to work properly, due to internal
                                # details of the PS engine in v5.  Naturally, this is an internal type and we need to use reflection
                                # to make a new one.

                                $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
                                $params = $PSBoundParameters.GetType().GetConstructor($flags, $null, @(), $null).Invoke(@())
                            }
                            else {
                                $params = @{}
                            }

                            $params['Path'] = [string[]]'Cert:\'
                            $gmdp = InPesterModuleScope { Get-Command Get-MockDynamicParameter }
                            & $gmdp -CmdletName Get-ChildItem -Parameters $params
                        }
                    }

                    end {
                        'I am the original function'
                    }
                }
            } | Import-Module -Force

            New-Module -Name TestModule2 {
                function CallingFunction {
                    DynamicParamFunction -CodeSigningCert
                }

                function CallingFunction2 {
                    [CmdletBinding()]
                    param (
                        [ValidateScript( { [bool](DynamicParamFunction -CodeSigningCert) })]
                        [string]
                        $Whatever
                    )
                }
            } | Import-Module -Force

            Mock DynamicParamFunction { if ($CodeSigningCert) {
                    'I am the mocked function'
                } } -ModuleName TestModule2
        }
    }

    It 'Properly evaluates dynamic parameters when called from another scope' {
        CallingFunction | Should -Be 'I am the mocked function'
    }

    It 'Properly evaluates dynamic parameters when called from another scope when the call is from a ValidateScript block' {
        CallingFunction2 -Whatever 'Whatever'
    }

    AfterAll {
        Remove-Module TestModule1 -Force
        Remove-Module TestModule2 -Force
    }
}

Describe 'Parameter Filters and Common Parameters' {
    & {
        BeforeAll {
            # set this setting in this scope in case the preference
            # around is different
            $VerbosePreference = 'Continue'

            function Test-Function {
                [CmdletBinding()] param ( )
            }

            Mock Test-Function { } -ParameterFilter { $VerbosePreference -eq 'Continue' }
        }

        It 'Applies common parameters correctly when testing the parameter filter' {
            { Test-Function -Verbose } | Should -Not -Throw
            Should -Invoke Test-Function
            Should -Invoke Test-Function -ParameterFilter { $VerbosePreference -eq 'Continue' }
        }
    }
}

Describe "Mocking Get-ItemProperty" {
    BeforeAll {
        Mock Get-ItemProperty { New-Object -typename psobject -property @{ Name = "fakeName" } }
    }

    It "Does not fail with NotImplementedException" {
        Get-ItemProperty -Path "HKLM:\Software\Key\" -Name "Property" | Select-Object -ExpandProperty Name | Should -Be fakeName
    }
}

Describe 'When mocking a command with parameters that match internal variable names' {

    BeforeAll {
        function Test-Function {
            [CmdletBinding()]
            param (
                [string] $ArgumentList,
                [int] $FunctionName,
                [double] $ModuleName
            )
        }

        Mock Test-Function { return 'Mocked!' }
    }

    It 'Should execute the mocked command successfully' {
        { Test-Function } | Should -Not -Throw
        Test-Function | Should -Be 'Mocked!'
    }
}

Describe 'Mocking commands with potentially ambiguous parameter sets' {
    BeforeAll {
        function SomeFunction {
            [CmdletBinding()]
            param
            (
                [parameter(ParameterSetName = 'ps1',
                    ValueFromPipelineByPropertyName = $true)]
                [string]
                $p1,

                [parameter(ParameterSetName = 'ps2',
                    ValueFromPipelineByPropertyName = $true)]
                [string]
                $p2
            )
            process {
                return $true
            }
        }

        Mock SomeFunction { }
    }

    It 'Should call the function successfully, even with delayed parameter binding' {
        $object = New-Object psobject -Property @{ p1 = 'Whatever' }
        { $object | SomeFunction } | Should -Not -Throw
        Should -Invoke SomeFunction -ParameterFilter { $p1 -eq 'Whatever' }
    }
}

Describe 'When mocking a command that has an ArgumentList parameter with validation' {
    BeforeAll {
        Mock Start-Process { return 'mocked' }
    }

    It 'Calls the mock properly' {
        $hash = @{ Result = $null }
        $scriptBlock = { $hash.Result = Start-Process -FilePath cmd.exe -ArgumentList '/c dir c:\' }

        $scriptBlock | Should -Not -Throw
        $hash.Result | Should -Be 'mocked'
    }
}

# These assertions won't actually "fail"; we had an infinite recursion bug in Get-DynamicParametersForCmdlet
# if the caller mocked New-Object.  It should be fixed by making that call to New-Object module-qualified,
# and this test will make sure it's working properly.  If this test fails, it'll take a really long time
# to execute, and then will throw a stack overflow error.

Describe 'Mocking New-Object' {
    It 'Works properly' {
        Mock New-Object

        $result = New-Object -TypeName Object
        $result | Should -Be $null
        Should -Invoke New-Object
    }
}

Describe 'Mocking a function taking input from pipeline' {
    BeforeAll {
        $psobj = New-Object -TypeName psobject -Property @{'PipeIntProp' = '1'; 'PipeArrayProp' = 1; 'PipeStringProp' = 1 }
        $psArrayobj = New-Object -TypeName psobject -Property @{'PipeArrayProp' = @(1) }
        $noMockArrayResult = @(1, 2) | PipelineInputFunction
        $noMockIntResult = 1 | PipelineInputFunction
        $noMockStringResult = '1' | PipelineInputFunction
        $noMockResultByProperty = $psobj | PipelineInputFunction -PipeStr 'val'
        $noMockArrayResultByProperty = $psArrayobj | PipelineInputFunction -PipeStr 'val'

        Mock PipelineInputFunction { write-output 'mocked' } -ParameterFilter { $PipeStr -eq 'blah' }
    }
    context 'when calling original function with an array' {
        BeforeAll {
            $result = @(1, 2) | PipelineInputFunction
        }

        it 'Returns actual implementation' {
            $result[0].keys | ForEach {
                $result[0][$_] | Should -Be $noMockArrayResult[0][$_]
                $result[1][$_] | Should -Be $noMockArrayResult[1][$_]
            }
        }
    }

    context 'when calling original function with an int' {
        BeforeAll {
            $result = 1 | PipelineInputFunction
        }
        it 'Returns actual implementation' {
            $result.keys | ForEach {
                $result[$_] | Should -Be $noMockIntResult[$_]
            }
        }
    }

    context 'when calling original function with a string' {
        BeforeAll {
            $result = '1' | PipelineInputFunction
        }
        it 'Returns actual implementation' {
            $result.keys | ForEach {
                $result[$_] | Should -Be $noMockStringResult[$_]
            }
        }
    }

    context 'when calling original function and pipeline is bound by property name' {
        BeforeAll {
            $result = $psobj | PipelineInputFunction -PipeStr 'val'
        }

        it 'Returns actual implementation' {
            $result.keys | ForEach {
                $result[$_] | Should -Be $noMockResultByProperty[$_]
            }
        }
    }

    context 'when calling original function and forcing a parameter binding exception' {
        BeforeAll {
            Mock PipelineInputFunction {
                if ($MyInvocation.ExpectingInput) {
                    throw New-Object -TypeName System.Management.Automation.ParameterBindingException
                }
                write-output $MyInvocation.ExpectingInput
            }
            $result = $psobj | PipelineInputFunction
        }

        it 'falls back to no pipeline input' {
            $result | Should -Be $false
        }
    }

    context 'when calling original function and pipeline is bound by property name with array values' {
        BeforeAll {
            $result = $psArrayobj | PipelineInputFunction -PipeStr 'val'
        }

        it 'Returns actual implementation' {
            $result.keys | ForEach {
                $result[$_] | Should -Be $noMockArrayResultByProperty[$_]
            }
        }
    }

    context 'when calling the mocked function' {
        BeforeAll {
            $result = 'blah' | PipelineInputFunction
        }

        it 'Returns mocked implementation' {
            $result | Should -Be 'mocked'
        }
    }
}

Describe 'Mocking module-qualified calls' {

    BeforeAll {
        $alias = Get-Alias -Name 'Microsoft.PowerShell.Management\Get-Content' -ErrorAction SilentlyContinue

        $mockFile = 'TestDrive:\TestFile'
        $mockResult = 'Mocked'

        Mock Get-Content { return $mockResult } -ParameterFilter { $Path -eq $mockFile }
        'The actual file' | Set-Content TestDrive:\TestFile
    }

    It 'Mock alias should not exist before the mock is defined' {
        $alias | Should -Be $null
    }

    It 'Creates the alias while the mock is in effect' {
        $alias = Get-Alias -Name 'Microsoft.PowerShell.Management\Get-Content' -ErrorAction SilentlyContinue
        $alias | Should -Not -Be $null
    }

    It 'Calls the mock properly even if the call is module-qualified' {
        $result = Microsoft.PowerShell.Management\Get-Content -Path $mockFile
        $result | Should -Be $mockResult
    }
}

Describe 'After a mock goes out of scope' {
    It 'Removes the alias after the mock goes out of scope' {
        $alias = Get-Alias -Name 'Microsoft.PowerShell.Management\Get-Content' -ErrorAction SilentlyContinue
        $alias | Should -Be $null
    }
}

Describe 'Should -Invoke with Aliases' {
    AfterEach {
        if (Test-Path alias:PesterTF) {
            Remove-Item Alias:PesterTF
        }
    }

    It 'Allows calls to Should -Invoke to use both aliases and the original command name' {
        function TestFunction {
        }
        Set-Alias -Name PesterTF -Value TestFunction
        Mock PesterTF
        $null = PesterTF

        { Should -Invoke PesterTF } | Should -Not -Throw
        { Should -Invoke TestFunction } | Should -Not -Throw
    }
}

Describe 'Mocking Get-Command' {
    # This was reported as a bug in 3.3.12; we were relying on Get-Command to safely invoke other commands.
    # Mocking Get-Command, though, would result in infinite recursion.

    It 'Does not break when Get-Command is mocked' {
        { Mock Get-Command } | Should -Not -Throw
    }
}

Describe 'Mocks with closures' {
    BeforeAll {
        $closureVariable = 'from closure'
        $scriptBlock = { "Variable resolved $closureVariable" }
        $closure = $scriptBlock.GetNewClosure()
        $closureVariable = 'from script'

        function TestClosure([switch] $Closure) {
            'Not mocked'
        }

        Mock TestClosure $closure -ParameterFilter { $Closure }
        Mock TestClosure $scriptBlock
    }

    It 'Resolves variables in the closure rather than Pester''s current scope' {
        TestClosure | Should -Be 'Variable resolved from script'
        TestClosure -Closure | Should -Be 'Variable resolved from closure'
    }
}

Describe '$args handling' {
    BeforeAll {
        function AdvancedFunction {
            [CmdletBinding()]
            param()
            'orig'
        }
        function SimpleFunction {
            . AdvancedFunction
        }
        function AdvancedFunctionWithArgs {
            [CmdletBinding()]
            param($Args)
            'orig'
        }
        Add-Type -TypeDefinition '
            using System.Management.Automation;
            [Cmdlet(VerbsLifecycle.Invoke, "CmdletWithArgs")]
            public class InvokeCmdletWithArgs : Cmdlet {
                public InvokeCmdletWithArgs() { }
                [Parameter]
                public object Args {
                    set { }
                }
                protected override void EndProcessing() {
                    WriteObject("orig");
                }
            }
        ' -PassThru | Select-Object -ExpandProperty Assembly | Import-Module

        Mock AdvancedFunction { 'mock' }
        Mock AdvancedFunctionWithArgs { 'mock' }
        Mock Invoke-CmdletWithArgs { 'mock' }
    }

    It 'Advanced function mock should be callable with dot operator' {
        SimpleFunction garbage | Should -Be mock
    }
    It 'Advanced function with Args parameter should be mockable' {
        AdvancedFunctionWithArgs -Args garbage | Should -Be mock
    }
    It 'Cmdlet with Args parameter should be mockable' {
        Invoke-CmdletWithArgs -Args garbage | Should -Be mock
    }

    AfterAll {
        Get-Command Invoke-CmdletWithArgs -CommandType Cmdlet |
            Select-Object -ExpandProperty Module |
            Remove-Module
    }
}

Describe 'Mocking advanced function' {
    It 'Avanced functions can be mocked with advanced function' {
        # https://github.com/pester/Pester/issues/1554
        function Get-Something {
            [CmdletBinding()]
            param
            (
                $MyParam1
            )
        }

        Mock Get-Something -MockWith {
            param(
                [Parameter()]
                [System.String]
                $MyParam1
            )

            return $MyParam1
        }

        Get-Something -MyParam1 'SomeValue' | Should -Be 'SomeValue'
    }
}

Describe 'Single quote in command/module name' {
    BeforeAll {
        $module = New-Module "Module '‘’‚‛" {
            Function NormalCommandName {
                'orig'
            }
            New-Item "Function::Command '‘’‚‛" -Value { 'orig' }
        } | Import-Module -PassThru
    }

    AfterAll {
        if ($module) {
            Remove-Module $module; $module = $null
        }
    }

    It 'Command with single quote in module name should be mockable' {
        Mock NormalCommandName { 'mock' }
        NormalCommandName | Should -Be mock
    }

    It 'Command with single quote in name should be mockable' {
        Mock "Command '‘’‚‛" { 'mock' }
        & "Command '‘’‚‛" | Should -Be mock
    }

}


Describe 'Mocking cmdlet without positional parameters' {
    BeforeAll {

        Add-Type -TypeDefinition '
            using System.Management.Automation;
            [Cmdlet(VerbsLifecycle.Invoke, "CmdletWithoutPositionalParameters")]
            public class InvokeCmdletWithoutPositionalParameters : Cmdlet {
                public InvokeCmdletWithoutPositionalParameters() { }
                [Parameter]
                public object Parameter {
                    set { }
                }
            }
            [Cmdlet(VerbsLifecycle.Invoke, "CmdletWithValueFromRemainingArguments")]
            public class InvokeCmdletWithValueFromRemainingArguments : Cmdlet {
                private string parameter;
                private string[] remainings;
                public InvokeCmdletWithValueFromRemainingArguments() { }
                [Parameter]
                public string Parameter {
                    set {
                        parameter=value;
                    }
                }
                [Parameter(ValueFromRemainingArguments=true)]
                public string[] Remainings {
                    set {
                        remainings=value;
                    }
                }
                protected override void EndProcessing() {
                    WriteObject(string.Concat(parameter, "; ", string.Join(", ", remainings)));
                }
            }
        ' -PassThru | Select-Object -First 1 -ExpandProperty Assembly | Import-Module
    }

    It 'Original cmdlet does not have positional parameters' {
        { Invoke-CmdletWithoutPositionalParameters garbage } | Should -Throw
    }

    It 'Mock of cmdlet should not make parameters to be positional' {
        Mock Invoke-CmdletWithoutPositionalParameters
        { Invoke-CmdletWithoutPositionalParameters garbage } | Should -Throw
    }

    It 'Original cmdlet bind all to Remainings' {
        Invoke-CmdletWithValueFromRemainingArguments asd fgh jkl | Should -Be '; asd, fgh, jkl'
    }
    It 'Mock of cmdlet should bind all to Remainings' {
        Mock Invoke-CmdletWithValueFromRemainingArguments { -join ($Parameter, '; ', ($Remainings -join ', ')) }
        Invoke-CmdletWithValueFromRemainingArguments asd fgh jkl | Should -Be '; asd, fgh, jkl'
    }

}

Describe 'Nested Mock calls' {
    BeforeAll {
        $testDate = New-Object DateTime(2012, 6, 13)

        Mock Get-Date -ParameterFilter { $null -eq $Date } {
            Get-Date -Date $testDate -Format o
        }
    }

    It 'Properly handles nested mocks' {
        $result = @(Get-Date)
        $result.Count | Should -Be 1
        $result[0] | Should -Be '2012-06-13T00:00:00.0000000'
    }
}

Describe 'Globbing characters in command name' {
    BeforeAll {
        function f[f]f {
            'orig1'
        }
        function f?f {
            'orig2'
        }
        function f*f {
            'orig3'
        }
        function fff {
            'orig4'
        }
    }

    It 'Command with globbing characters in name should be mockable' {
        Mock f[f]f { 'mock1' }
        Mock f?f { 'mock2' }
        Mock f*f { 'mock3' }
        f[f]f | Should -Be mock1
        f?f | Should -Be mock2
        f*f | Should -Be mock3
        fff | Should -Be orig4
    }

}

Describe 'Naming conflicts in mocked functions' {
    Context 'parameter named Metadata' {
        BeforeAll {
            function Sample {
                param( [string] ${Metadata} )
            }
            function Wrapper {
                Sample -Metadata 'test'
            }

            Mock Sample { 'mocked' }
        }

        It 'Works with commands with parameter named Metadata' {
            Wrapper | Should -Be 'mocked'
        }
    }
    Context 'parameter named Keys' {
        BeforeAll {
            function g {
                [CmdletBinding()] param($Keys, $H)
            }
            function Wrapper {
                g -Keys 'value'
            }

            Mock g { $Keys }
        }

        It 'Works with command with parameter named Keys' {
            $r = Wrapper
            $r | Should -be 'value'
        }
    }
}

Describe 'Passing unbound script blocks as mocks' {
    BeforeAll {
        function TestMe {
            'Original'
        }
    }
    It 'Does not produce an error' {
        $scriptBlock = [scriptblock]::Create('"Mocked"')

        { Mock TestMe $scriptBlock } | Should -Not -Throw
        TestMe | Should -Be Mocked
    }

    It 'Should not execute in Pester internal state' {
        $filter = [scriptblock]::Create('if ("pester" -eq $ExecutionContext.SessionState.Module) { throw "executed parameter filter in internal state" } else { $true }')
        $scriptBlock = [scriptblock]::Create('if ("pester" -eq $ExecutionContext.SessionState.Module) { throw "executed mock in internal state" } else { "Mocked" }')

        { Mock -CommandName TestMe -ParameterFilter $filter -MockWith $scriptBlock } | Should -Not -Throw
        TestMe -SomeParam | Should -Be Mocked
    }
}

Describe 'Should -Invoke when mock called outside of It block' {
    BeforeAll {
        function TestMe {
            'Original '
        }
        mock TestMe { 'Mocked' }

        $null = TestMe
    }

    Context 'Context' {
        BeforeAll {
            $null = TestMe
        }

        It 'Should log the correct number of calls' {
            TestMe | Should -Be Mocked
            Should -Invoke TestMe -Scope It -Exactly -Times 1
            Should -Invoke TestMe -Scope Context -Exactly -Times 2
            Should -Invoke TestMe -Scope Describe -Exactly -Times 3
        }

        It 'Should log the correct number of calls (second test)' {
            TestMe | Should -Be Mocked
            Should -Invoke TestMe -Scope It -Exactly -Times 1
            Should -Invoke TestMe -Scope Context -Exactly -Times 3
            Should -Invoke TestMe -Scope Describe -Exactly -Times 4
        }
    }
}

Describe "Restoring original commands when mock scopes exit" {
    BeforeAll {
        function a () { }
    }
    Context "first context" {
        BeforeAll {
            Mock a { "mock" }
        }

        # Deliberately not using "Should Exist" here because that executes in
        # Pester's module scope, where function:\a does not exist
        It "original function exists" {
            $function:a | Should -Not -Be $null
        }

        It "passes in first context" {
            a | Should -Be "mock"
        }
    }

    Context "second context" {
        BeforeAll {
            Mock a { "mock" }
        }

        It "original function exists" {
            $function:a | Should -Not -Be $null
        }

        It "passes in second context" {
            a | Should -Be "mock"
        }
    }
}

Describe "Mocking Set-Variable" {
    It "sets variable correctly when mocking Set-Variable without -Scope parameter" {

        Set-Variable -Name v1 -Value 1
        $v1 | Should -Be 1 -Because "we defined it without mocking Set-Variable"

        # we mock the command but the mock will never be triggered because
        # the filter will never pass, so this mock will always call through
        # to the real Set-Variable
        Mock Set-Variable -ParameterFilter { $false }

        Set-Variable -Name v2 -Value 10

        # if mock works correctly then then we should see
        # 10 here because calling through to the Set-Variable
        # should work the same as calling it directly
        $v2 | Should -Be 10
    }

    It "sets variable correctly when mocking Set-Variable without -Scope 0 parameter" {

        Set-Variable -Name v1 -Value 1
        $v1 | Should -Be 1 -Because "we defined it without mocking Set-Variable"

        Mock Set-Variable -ParameterFilter { $false }

        Set-Variable -Name v2 -Value 11 -Scope 0
        $v2 | Should -Be 11
    }

    It "sets variable correctly when mocking Set-Variable without -Scope Local parameter" {

        Set-Variable -Name v1 -Value 1
        $v1 | Should -Be 1 -Because "we defined it without mocking Set-Variable"

        Mock Set-Variable -ParameterFilter { $false }

        Set-Variable -Name v2 -Value 12 -Scope Local

        $v2 | Should -Be 12
    }

    It "sets variable correctly when mocking Set-Variable with -Scope 3 parameter" {
        & {
            # scope 3
            & {
                # scope 2
                & {
                    # scope 1
                    & {
                        Set-Variable -Name v1 -Value 2 -Scope 3
                    }
                }
            }

            $v1 | Should -Be 2 -Because "we defined it without mocking Set-Variable"
        }


        & {
            # scope 3
            & {
                # scope 2
                & {
                    # scope 1
                    & {
                        Mock Set-Variable -ParameterFilter { $false }
                        Set-Variable -Name v2 -Value 11 -Scope 3
                    }
                }
            }
            $v2 | Should -Be 11
        }
    }

}

Describe "Mocking functions with conflicting parameters" {
    InPesterModuleScope {
        Context "Faked conflicting parameter" {
            BeforeAll {
                Mock Get-ConflictingParameterNames { @("ParamToAvoid") }

                function Get-ExampleTest {
                    param(
                        [Parameter(Mandatory = $true)]
                        [string]
                        $ParamToAvoid
                    )

                    $ParamToAvoid
                }

                Mock Get-ExampleTest { "World" } -ParameterFilter { $_ParamToAvoid -eq "Hello" }
            }

            It 'executes the mock' {
                Get-ExampleTest -ParamToAvoid "Hello" | Should -Be "World"
            }

            It 'defaults to the original function' {
                Get-ExampleTest -ParamToAvoid "Bye" | Should -Be "Bye"
            }

            Context "Should -Invoke" {

                It 'simple Should -Invoke' {
                    Get-ExampleTest -ParamToAvoid "Hello"

                    Should -Invoke Get-ExampleTest -Exactly 1 -Scope It
                }

                It 'with parameterfilter' {
                    Get-ExampleTest -ParamToAvoid "Another"
                    Get-ExampleTest -ParamToAvoid "Hello"

                    Should -Invoke Get-ExampleTest -ParameterFilter { $_ParamToAvoid -eq "Hello" } -Exactly 1 -Scope It
                }
            }
        }
    }

    Context "Get-Module" {
        BeforeAll {
            function f { Get-Module foo }
        }
        It 'mocks Get-Module properly' {
            Mock Get-Module -Verifiable { 'mocked' }
            f
            Should -Invoke Get-Module
        }
    }
}

if ($PSVersionTable.PSVersion.Major -ge 3) {
    Describe "Usage of Alias in Parameter Filters" {
        Context 'Mock definition' {

            Context 'Get-Content' {
                BeforeAll {
                    Mock Get-Content { "default-get-content" }
                    Mock Get-Content -ParameterFilter {
                        # -Last is alias of -Tail so they should both have the same value
                        $Last -eq 100 -and $Tail -eq 100
                    } -MockWith { "aliased-parameter-name" }
                }

                It "returns mock that matches parameter filter block when using alias in the call" {
                    Get-Content -Path "c:\temp.txt" -Last 100 | Should -Be "aliased-parameter-name"
                }

                It "returns mock that matches parameter filter block when using the real parameter name in call" {
                    Get-Content -Path "c:\temp.txt" -Tail 100 | Should -Be "aliased-parameter-name"
                }

                It 'returns default mock' {
                    Get-Content -Path "c:\temp.txt" | Should -Be "default-get-content"
                }
            }

            Context "Alias rewriting works when alias and parameter name differ in length" {

                It 'calls the mock' {
                    Mock New-Item { throw "default mock should not run" }
                    Mock New-Item { return "nic" } -ParameterFilter { $Type -ne $null -and $Type.StartsWith("nic") }
                    New-Item -Path 'Hello' -Type "nic" | Should -Be "nic"
                }
            }

            if ($PSVersionTable.PSVersion -ge 5.1) {
                Context 'Get-Module' {
                    It 'works with read-only/constant automatic variables' {

                        function f { Get-Module foo -ListAvailable -PSEdition 'Desktop' }
                        Mock Get-Module -Verifiable { 'mocked' } -ParameterFilter { $_PSEdition -eq 'Desktop' }

                        f

                        Should -Invoke Get-Module
                    }
                }
            }
        }

        Context 'Should -Invoke' {
            It "Uses parameter aliases in ParameterFilter" {
                function f { Get-Content -Path 'temp.txt' -Tail 10 }
                Mock Get-Content { }

                f

                Should -Invoke Get-Content -ParameterFilter { $Last -eq 10 } -Exactly 1 -Scope It
            }
        }

    }
}


InPesterModuleScope {
    Describe 'Alias for external commands' {
        Context 'Without extensions' {
            $case = @(
                @{Command = 'notepad' }
            )

            if ((GetPesterOs) -ne 'Windows') {
                $case = @(
                    @{Command = 'ls' }
                )
            }

            It 'mocks <Command> command' -TestCases $case {
                Mock $Command { 'I am being mocked' }

                & $Command | Should -Be 'I am being mocked'

                Should -Invoke $Command -Scope It -Exactly 1
            }
        }

        if ((GetPesterOs) -eq 'Windows') {
            Context 'With extensions' {
                It 'mocks notepad command with extension' {
                    Mock notepad.exe { 'I am being mocked' }

                    notepad.exe | Should -Be 'I am being mocked'

                    Should -Invoke notepad.exe -Scope It -Exactly 1
                }
            }

            Context 'Mixed usage' {
                It 'mocks with extension and calls it without ext' {
                    Mock notepad.exe { 'I am being mocked' }

                    notepad | Should -Be 'I am being mocked'

                    Should -Invoke notepad.exe -Scope It -Exactly 1
                }

                It 'mocks without extension and calls with extension' {
                    Mock notepad { 'I am being mocked' }

                    notepad.exe | Should -Be 'I am being mocked'
                }

                It 'assert that alias to mock works' {
                    Set-Alias note notepad

                    Mock notepad.exe { 'I am being mocked' }

                    notepad | Should -Be 'I am being mocked'

                    Should -Invoke note -Scope It -Exactly 1
                }
            }
        }
    }
}

Describe "Mock definition output" {
    It "Outputs nothing" {

        function a () {}
        $output = Mock a { }
        $output | Should -Be $null
    }
}

Describe 'Mocking using ParameterFilter' {

    Context 'Scriptblock [Scriptblock]::Create() passed to ParameterFilter as var' {
        BeforeAll {
            $filter = [scriptblock]::Create( ('$Path -eq ''C:\Windows''') )
            Mock Test-Path { $True }
            Mock Test-Path -ParameterFilter $filter -MockWith { $False }
        }

        It "Returns default mock" {
            Test-Path -Path C:\AwesomePath | Should -Be $True
        }

        It "returns mock that matches parameter filter block" {
            Test-Path -Path C:\Windows | Should -Be $false
        }
    }

    Context 'Scriptblock expression $( [Scriptblock]::Create() ) passed to ParameterFilter' {
        BeforeAll {
            $filter = [scriptblock]::Create( ('$Path -eq ''C:\Windows''') )
            Mock Test-Path { $True }
            Mock Test-Path -ParameterFilter $( [scriptblock]::Create(('$Path -eq ''C:\Windows''')) ) -MockWith { $False }
        }

        It "Returns default mock" {
            Test-Path -Path C:\AwesomePath | Should -Be $True
        }

        It "returns mock that matches parameter filter block" {
            Test-Path -Path C:\Windows | Should -Be $false
        }
    }

    Context 'Scriptblock {} passed to ParameterFilter' {
        BeforeAll {
            Mock Test-Path { $True }
            Mock Test-Path -ParameterFilter { $Path -eq "C:\Windows" } -MockWith { $False }
        }

        It "Returns default mock" {
            Test-Path -Path C:\AwesomePath | Should -Be $True
        }

        It "returns mock that matches parameter filter block" {
            Test-Path -Path C:\Windows | Should -Be $false
        }
    }
    Context 'Scriptblock {} passed to ParameterFilter as var' {
        BeforeAll {
            $filter = {
                $Path -eq "C:\Windows"
            }
            Mock Test-Path { $True }
            Mock Test-Path -ParameterFilter $filter -MockWith { $False }
        }

        It "Returns default mock" {
            Test-Path -Path C:\AwesomePath | Should -Be $True
        }

        It "returns mock that matches parameter filter block" {
            Test-Path -Path C:\Windows | Should -Be $false
        }
    }

    Context 'Function Definition ${} passed to ParameterFilter' {
        BeforeAll {
            Function ParamFilter {
                $Path -eq "C:\Windows"
            }
            Mock Test-Path { $True }
            Mock Test-Path -ParameterFilter ${function:ParamFilter} -MockWith { $False }
        }

        It "Returns default mock" {
            Test-Path -Path C:\AwesomePath | Should -Be $True
        }

        It "returns mock that matches parameter filter block" {
            Test-Path -Path C:\Windows | Should -Be $false
        }
    }
}


if ($PSVersionTable.PSVersion.Major -ge 3) {
    Describe "-RemoveParameterType" {

        It 'removes parameter type for simple function' {
            function f ([int]$Count, [string]$Name) {
                $Count + 1
            }

            Mock f { "result" } -RemoveParameterType 'Count'
            [Diagnostics.Process] $currentProcess = Get-Process -id $pid

            $currentProcess -as [int] -eq $null | Should -BeTrue -Because "Process is not convertible to int"
            f -Name 'Hello' -Count $currentProcess | Should -Be "result" -Because "we successfuly provided a process to parameter defined as int"
        }

        if ($PSVersionTable.PSVersion.Major -eq 5) {
            Context 'NetAdapter example' {
                It 'passes pscustomobject to a parameter defined as CimSession[]' {
                    Mock Get-NetAdapter { [pscustomobject]@{ Name = 'Mocked' } }
                    Mock Set-NetAdapter -RemoveParameterType 'InputObject'

                    $adapter = Get-NetAdapter
                    $adapter | Set-NetAdapter

                    Should -Invoke Set-NetAdapter -ParameterFilter { $InputObject.Name -eq 'Mocked' }
                }
            }

            Context "Get-PhysicalDisk example" {
                It "should return 'hello'" {
                    Mock Get-PhysicalDisk -RemoveParameterType Usage, HealthStatus { return "hello" }
                    Get-PhysicalDisk | Should -Be "hello"
                }
            }
        }
    }
}

Describe 'RemoveParameterValidation' {
    BeforeAll {
        function Test-Validation {
            param(
                [Parameter()]
                [ValidateRange(1, 10)]
                [int]
                $Count
            )
            $Count
        }
    }

    It 'throws when number is not in the valid range' {
        { Test-Validation -Count -1 } | Should -Throw -ErrorId '*ParameterArgumentValidationError*'
    }

    It 'passes when mock removes the validation' {
        Mock Test-Validation -RemoveParameterValidation Count { "mock" }

        Test-Validation -Count -1 | Should -Be "mock"
    }
}

Describe 'Removing multiple attributes for same parameter' {
    It 'Removes parameter type and validation for simple function' {
        # Making sure attributes are removed correctly regardless of order
        function t {
            param(
                [Alias('Number2')]
                [ValidateSet(1)]
                [PSTypeName('SomeType')]
                $Number1
            )
            $Number1
        }
        Mock t -RemoveParameterType 'Number1' -RemoveParameterValidation 'Number1'
        { t -Number1 2 } | Should -Not -Throw
    }
}

Describe 'Mocking command with ValidateRange-attributes' {
    # https://github.com/pester/Pester/issues/1496
    # https://github.com/PowerShell/PowerShell/issues/17546
    # Bug in PowerShell. ProxyCommand-generation breaks ValidateRange-attributes for enum-parameters

    It 'mocked function does not throw when param is <Name>' -TestCases @(
        @{
            # min and max are enum-values -> affected by bug, needs Repair-EnumParameters
            Name      = 'typed using enum min max'
            Attribute = '[ValidateRange([Microsoft.PowerShell.ExecutionPolicy]::Unrestricted, [Microsoft.PowerShell.ExecutionPolicy]::Undefined)]'
            Parameter = '[Microsoft.PowerShell.ExecutionPolicy]$TypedBroken'
        },
        @{
            # min and max are enum-values -> affected by bug, needs Repair-EnumParameters
            Name      = 'untyped using enum min max'
            Attribute = '[ValidateRange([Microsoft.PowerShell.ExecutionPolicy]::Unrestricted, [Microsoft.PowerShell.ExecutionPolicy]::Undefined)]'
            Parameter = '$UntypedBroken'
        },
        @{
            # min and max are enum-values -> affected by bug, needs Repair-EnumParameters. make sure regex didn't match partial (Clear)
            Name      = 'untyped using enum min max with similar valuenames'
            Attribute = '[ValidateRange([System.ConsoleKey]::Clear, [System.ConsoleKey]::OemClear)]'
            Parameter = '[Parameter()][System.ConsoleKey]$TypedBrokenWithSimilarAttributeArgNames'
        },
        @{
            # int Min, enum Max -> Both are set as int in command metadata -> unaffected by bug
            Name      = 'typed using int min enum max'
            Attribute = '[ValidateRange(0, [Microsoft.PowerShell.ExecutionPolicy]::Undefined)]'
            Parameter = '[Microsoft.PowerShell.ExecutionPolicy]$Works'
        },
        @{
            # enum Min, int Max -> Both are set as int in command metadata -> unaffected by bug
            Name      = 'typed using enum min max'
            Attribute = '[ValidateRange([Microsoft.PowerShell.ExecutionPolicy]::Unrestricted, 0)]'
            Parameter = '[Microsoft.PowerShell.ExecutionPolicy]$Works2'
        }
    ) {
        Set-Item -Path 'function:Test-EnumValidation' -Value ('param ( {0}{1} )' -f $Attribute, $Parameter)

        Mock -CommandName 'Test-EnumValidation' -MockWith { 'mock' }
        Test-EnumValidation | Should -Be 'mock'
    }

    if ($PSVersionTable.PSVersion.Major -ge '7') {
        # ValidateRangeKind -> unaffected by bug but verify nothing broke
        It 'mocked function does not throw when param is type using ValidateRangeKind' {
            $Name = 'typed using RangeKind'
            $Attribute = '[ValidateRange([System.Management.Automation.ValidateRangeKind]::Positive)]'
            $Parameter = '[int]$Works2'

            Set-Item -Path 'function:Test-EnumValidation' -Value ('param ( {0}{1} )' -f $Attribute, $Parameter)

            Mock -CommandName 'Test-EnumValidation' -MockWith { 'mock' }
            Test-EnumValidation | Should -Be 'mock'
        }
    }

    # Only built-in cmdlet with affected parameters are Start/Set-BitsTransfer. Only available on Windows
    if ((Get-Module BitsTransfer -ErrorAction SilentlyContinue)) {
        It 'mocked cmdlet does not throw' {
            Mock -CommandName 'Start-BitsTransfer' -MockWith { 'mock' }
            Start-BitsTransfer -Source "/nonexistingpath" | Should -Be 'mock'
        }
    }
}

Describe "Running Mock with ModuleName in test scope" {
    BeforeAll {
        Get-Module "test" -ErrorAction SilentlyContinue | Remove-Module
        New-Module -Name "test" -ScriptBlock {
            $script:v = "module variable"
            function f () { a }
            function a () { "module" }

            Export-ModuleMember -Function f
        } -PassThru | Import-Module
    }

    AfterAll {
        Get-Module "test" -ErrorAction SilentlyContinue | Remove-Module
    }

    It "can mock internal function of the module" {
        Mock -ModuleName test a { "mock" }
        f | Should -Be "mock"
    }

    It "runs the body in the current scope" {
        Mock -ModuleName test a {
            $ExecutionContext.SessionState
        }
        $actual = f
        $actual | Should -BeOfType ([Management.Automation.SessionState])
        $actual.Module | Should -Be $null -Because "we are not running inside of the 'test' module"
    }

    It "runs the parameter filter in the current scope" {
        $script:ss = $null
        Mock -ModuleName test a { } -ParameterFilter { $script:ss = $ExecutionContext.SessionState ; $true }

        $null = f
        $script:ss | Should -BeOfType ([Management.Automation.SessionState])
        $script:ss.Module | Should -Be $null -Because "we are not running inside of the 'test' module"
    }
}

Describe "Mocks can be defined outside of BeforeAll" {

    BeforeAll {
        # this is discouraged but useful for v4 to v5 migration
        function a () { "a" }
        Mock a { "mock" }
    }

    It "Finds the mock" {
        a | Should -Be "mock"
    }
}

Describe "Debugging mocks" {
    It "Hits breakpoints in mock related scriptblocks" {
        try {
            $line = {}.StartPosition.StartLine
            $sb = @(
                Set-PSBreakpoint -Script $PSCommandPath -Line ($line + 9) -Action { } # mock parameter filter
                Set-PSBreakpoint -Script $PSCommandPath -Line ($line + 11) -Action { } # mock with
                Set-PSBreakpoint -Script $PSCommandPath -Line ($line + 17) -Action { } # should invoke parameter filter
            )
            function f ($Name) { }

            Mock f -ParameterFilter {
                $Name -eq "Jakub"
            } -MockWith {
                [PSCustomObject]@{ Name = "Jakub"; Age = 31 }
            }

            f "Jakub"

            Should -Invoke f -ParameterFilter {
                $Name -eq "Jakub"
            }

            $sb[0].HitCount | Should -Be 1 -Because "breakpoint on line $($sb[0].Line) is hit"
            $sb[1].HitCount | Should -Be 1 -Because "breakpoint on line $($sb[1].Line) is hit"
            $sb[2].HitCount | Should -Be 1 -Because "breakpoint on line $($sb[2].Line) is hit"
        }
        finally {
            $sb | Remove-PSBreakpoint
        }
    }
}

Describe "When inherited variables conflicts with parameters" {
    BeforeAll {
        Mock FunctionUnderTest { 'default' }
        Mock FunctionUnderTest { 'filtered' } -ParameterFilter { $param1 -eq 'abc' } -Verifiable
    }

    It "parameterized mock should not be called due to inherited variable" {
        $param1 = 'abc'
        FunctionUnderTest | Should -Be 'default'
    }

    It "InvokeVerifiable should not pass due to test variable" {
        # Uses same logic as mock execution, so should not be tricked
        $param1 = 'abc'
        FunctionUnderTest | Should -Be 'default'
        { Should -InvokeVerifiable } | Should -Throw
    }

    It "Should Invoke ParameterFilter will count false positive for the first FunctionUnderTest call" {
        # https://github.com/pester/Pester/issues/1873
        # this will pass the parameter filter because we define a variable param1 with the same name and value as the expected parameter value
        FunctionUnderTest | Should -Be 'default'
        FunctionUnderTest -param1 'abc' | Should -Be 'filtered'
        $param1 = 'abc'

        # This should show warning about conflict when in Diagnostic output (Mock debug message)
        # about already having a variable in the scope that is the same as parameter name
        Should -Invoke FunctionUnderTest -ParameterFilter { $param1 -eq 'abc' } -Times 2 -Exactly
    }

    It "Invoke ParameterFilter works as expected when PesterBoundParamters is used" {
        # Workaround mentioned in debug message warning mentioned in previous test
        FunctionUnderTest | Should -Be 'default'
        FunctionUnderTest -param1 'abc' | Should -Be 'filtered'
        $param1 = 'abc'

        # No warning will be shown in debug as there's no conflict
        Should -Invoke FunctionUnderTest -ParameterFilter { $PesterBoundParameters.param1 -eq 'abc' } -Times 1 -Exactly
    }

    It "Calling mock with parameter overrides inherited variable in filter" {
        FunctionUnderTest -param1 '123' | Should -Be 'default'
        $param1 = 'abc'

        # This should show warning about conflict when in Diagnostic output (Mock debug message)
        Should -Invoke FunctionUnderTest -ParameterFilter { $param1 -eq 'abc' } -Times 0 -Exactly
        Should -Invoke FunctionUnderTest -ParameterFilter { $param1 -eq 123 } -Times 1 -Exactly
    }
}

Describe 'Mocking in manifest modules' {
    BeforeAll {
        $moduleName = 'MockManifestModule'
        $moduleManifestPath = "TestDrive:/$moduleName.psd1"
        $scriptPath = "TestDrive:/$moduleName-functions.ps1"
        Set-Content -Path $scriptPath -Value {
            function myManifestPublicFunction {
                myManifestPrivateFunction
            }

            function myManifestPrivateFunction {
                'real'
            }
        }
        New-ModuleManifest -Path $moduleManifestPath -NestedModules "$moduleName-functions.ps1" -FunctionsToExport 'myManifestPublicFunction'
        Import-Module $moduleManifestPath -Force
    }

    AfterAll {
        Get-Module $moduleName -ErrorAction SilentlyContinue | Remove-Module
        Remove-Item $moduleManifestPath, $scriptPath -Force -ErrorAction SilentlyContinue
    }

    It 'Should be able to mock public function' {
        Mock -CommandName 'myManifestPublicFunction' -MockWith { 'mocked public' }
        myManifestPublicFunction | Should -Be 'mocked public'
        Should -Invoke -CommandName 'myManifestPublicFunction' -Exactly -Times 1
    }

    It 'Should be able to mock private function' {
        Mock -CommandName 'myManifestPrivateFunction' -ModuleName $moduleName -MockWith { 'mocked private' }
        myManifestPublicFunction | Should -Be 'mocked private'
        Should -Invoke -CommandName 'myManifestPrivateFunction' -ModuleName $moduleName -Exactly -Times 1
    }
}

Describe 'Mocking with nested Pester runs' {
    BeforeAll {
        Mock Get-Date { 1 }

        $innerRun = Invoke-Pester -Container (New-PesterContainer -ScriptBlock {
                Describe 'inner' {
                    It 'local mock works' {
                        Mock Get-Command { 2 }
                        Get-Command | Should -Be 2
                    }

                    It 'outer mock is not available' {
                        Get-Date | Should -Not -Be 1
                    }
                }
            }) -Output None -PassThru
    }

    It 'Mocks in outer run works after nested Invoke-Pester' {
        # https://github.com/pester/Pester/issues/2074
        Get-Date | Should -Be 1
        # Outer mock should not have been called from nested run
        Should -Invoke Get-Date -Exactly -Times 1
    }

    It 'Mocking works in nested run' {
        $innerRun.Result | Should -Be 'Passed'
        $innerRun.PassedCount | Should -Be 2
    }

    It 'Mocks in nested run do not leak to outside' {
        Get-Command Get-ChildItem | Should -Not -Be 2
    }
}
