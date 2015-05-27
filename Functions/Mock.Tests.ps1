Set-StrictMode -Version Latest

function FunctionUnderTest
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]
        $param1
    )

    return "I am a real world test"
}

function FunctionUnderTestWithoutParams([string]$param1) {
    return "I am a real world test with no params"
}

filter FilterUnderTest { $_ }

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
    ${OutBuffer} ){
    return "Please strip me of my common parameters. They are far too common."
}

Describe "When calling Mock on existing function" {
    Mock FunctionUnderTest { return "I am the mock test that was passed $param1"}

    $result = FunctionUnderTest "boundArg"

    It "Should rename function under test" {
        $renamed = (Test-Path function:PesterIsMocking_FunctionUnderTest)
        $renamed | Should Be $true
    }

    It "Should Invoke the mocked script" {
        $result | Should Be "I am the mock test that was passed boundArg"
    }
}

Describe "When the caller mocks a command Pester uses internally" {
    Mock Write-Host { }

    Context "Context run when Write-Host is mocked" {
        It "does not make extra calls to the mocked command" {
            Write-Host 'Some String'
            Assert-MockCalled 'Write-Host' -Exactly 1
        }

        It "retains the correct mock count after the first test completes" {
            Assert-MockCalled 'Write-Host' -Exactly 1
        }
    }
}

Describe "When calling Mock on existing cmdlet" {
    Mock Get-Process {return "I am not Get-Process"}

    $result=Get-Process

    It "Should Invoke the mocked script" {
        $result | Should Be "I am not Get-Process"
    }

    It 'Should not resolve $args to the parent scope' {
        { $args = 'From', 'Parent', 'Scope'; Get-Process SomeName } | Should Not Throw
    }
}

Describe 'When calling Mock on an alias' {
    $originalPath = $env:path

    try
    {
        # Our TeamCity server has a dir.exe on the system path, and PowerShell v2 apparently finds that instead of the PowerShell alias first.
        # This annoying bit of code makes sure our test works as intended even when this is the case.

        $dirExe = Get-Command dir -CommandType Application -ErrorAction SilentlyContinue
        if ($null -ne $dirExe)
        {
            foreach ($app in $dirExe)
            {
                $parent = (Split-Path $app.Path -Parent).TrimEnd('\')
                $pattern = "^$([regex]::Escape($parent))\\?"

                $env:path = $env:path -split ';' -notmatch $pattern -join ';'
            }
        }

        Mock dir {return 'I am not dir'}

        $result = dir

        It 'Should Invoke the mocked script' {
            $result | Should Be 'I am not dir'
        }
    }
    finally
    {
        $env:path = $originalPath
    }
}

Describe 'When calling Mock on an alias that refers to a function Pester can''t see' {
    It 'Mocks the aliased command successfully' {
        # This function is defined in a non-global scope; code inside the Pester module can't see it directly.
        function orig {'orig'}
        New-Alias 'ali' orig

        ali | Should Be 'orig'

        { mock ali {'mck'} } | Should Not Throw

        ali | Should Be 'mck'
    }
}

Describe 'When calling Mock on a filter' {
    Mock FilterUnderTest {return 'I am not FilterUnderTest'}

    $result = 'Yes I am' | FilterUnderTest

    It 'Should Invoke the mocked script' {
        $result | Should Be 'I am not FilterUnderTest'
    }
}

Describe 'When calling Mock on an external script' {
    $ps1File = New-Item 'TestDrive:\tempExternalScript.ps1' -ItemType File -Force
    $ps1File | Set-Content -Value "'I am tempExternalScript.ps1'"

    Mock 'TestDrive:\tempExternalScript.ps1' {return 'I am not tempExternalScript.ps1'}

    <#
        # Invoking the script using its absolute path is not supported

        $result = TestDrive:\tempExternalScript.ps1
        It 'Should Invoke the absolute-path-qualified mocked script using just the script name' {
            $result | Should Be 'I am not tempExternalScript.ps1'
        }

        $result = & TestDrive:\tempExternalScript.ps1
        It 'Should Invoke the absolute-path-qualified mocked script using the command-invocation operator (&)' {
            $result | Should Be 'I am not tempExternalScript.ps1'
        }

        $result = . TestDrive:\tempExternalScript.ps1
        It 'Should Invoke the absolute-path-qualified mocked script using dot source notation' {
            $result | Should Be 'I am not tempExternalScript.ps1'
        }
    #>

    Push-Location TestDrive:\

    try
    {
        $result = tempExternalScript.ps1
        It 'Should Invoke the mocked script using just the script name' {
            $result | Should Be 'I am not tempExternalScript.ps1'
        }

        $result = & tempExternalScript.ps1
        It 'Should Invoke the mocked script using the command-invocation operator' {
            #the command invocation operator is (&). Moved this to comment because it breaks the contionuous builds.
            #there is issue for this on GH

            $result | Should Be 'I am not tempExternalScript.ps1'
        }

        $result = . tempExternalScript.ps1
        It 'Should Invoke the mocked script using dot source notation' {
            $result | Should Be 'I am not tempExternalScript.ps1'
        }

        <#
            # Invoking the script using only its relative path is not supported

            $result = .\tempExternalScript.ps1
            It 'Should Invoke the relative-path-qualified mocked script' {
                $result | Should Be 'I am not tempExternalScript.ps1'
            }
        #>

    }
    finally
    {
        Pop-Location
    }

    Remove-Item $ps1File -Force -ErrorAction SilentlyContinue
}

Describe 'When calling Mock on an application command' {
    Mock schtasks.exe {return 'I am not schtasks.exe'}

    $result = schtasks.exe

    It 'Should Invoke the mocked script' {
        $result | Should Be 'I am not schtasks.exe'
    }
}

Describe "When calling Mock in the Describe block" {
    Mock Out-File {return "I am not Out-File"}

    It "Should mock Out-File successfully" {
        $outfile = "test" | Out-File "TestDrive:\testfile.txt"
        $outfile | Should Be "I am not Out-File"
    }
}

Describe "When calling Mock on existing cmdlet to handle pipelined input" {
    Mock Get-ChildItem {
        if($_ -eq 'a'){
            return "AA"
        }
        if($_ -eq 'b'){
            return "BB"
        }
    }

    $result = ''
    "a", "b" | Get-ChildItem | % { $result += $_ }

    It "Should process the pipeline in the mocked script" {
        $result | Should Be "AABB"
    }
}

Describe "When calling Mock on existing cmdlet with Common params" {
    Mock CommonParamFunction

    $result=[string](Get-Content function:\CommonParamFunction)

    It "Should strip verbose" {
        $result.contains("`${Verbose}") | Should Be $false
    }
    It "Should strip Debug" {
        $result.contains("`${Debug}") | Should Be $false
    }
    It "Should strip ErrorAction" {
        $result.contains("`${ErrorAction}") | Should Be $false
    }
    It "Should strip WarningAction" {
        $result.contains("`${WarningAction}") | Should Be $false
    }
    It "Should strip ErrorVariable" {
        $result.contains("`${ErrorVariable}") | Should Be $false
    }
    It "Should strip WarningVariable" {
        $result.contains("`${WarningVariable}") | Should Be $false
    }
    It "Should strip OutVariable" {
        $result.contains("`${OutVariable}") | Should Be $false
    }
    It "Should strip OutBuffer" {
        $result.contains("`${OutBuffer}") | Should Be $false
    }
    It "Should not strip an Uncommon param" {
        $result.contains("`${Uncommon}") | Should Be $true
    }
}

Describe "When calling Mock on non-existing function" {
    try{
        Mock NotFunctionUnderTest {return}
    } Catch {
        $result=$_
    }

    It "Should throw correct error" {
        $result.Exception.Message | Should Be "Could not find command NotFunctionUnderTest"
    }
}

Describe 'When calling Mock, StrictMode is enabled, and variables are used in the ParameterFilter' {
    Set-StrictMode -Version Latest

    $result = $null
    $testValue = 'test'

    try
    {
        Mock FunctionUnderTest { 'I am the mock' } -ParameterFilter { $param1 -eq $testValue }
    }
    catch
    {
        $result = $_
    }

    It 'Does not throw an error when testing the parameter filter' {
        $result | Should Be $null
    }

    It 'Calls the mock properly' {
        FunctionUnderTest $testValue | Should Be 'I am the mock'
    }

    It 'Properly asserts the mock was called when there is a variable in the parameter filter' {
        Assert-MockCalled FunctionUnderTest -Exactly 1 -ParameterFilter { $param1 -eq $testValue }
    }
}

Describe "When calling Mock on existing function without matching bound params" {
    Mock FunctionUnderTest {return "fake results"} -parameterFilter {$param1 -eq "test"}

    $result=FunctionUnderTest "badTest"

    It "Should redirect to real function" {
        $result | Should Be "I am a real world test"
    }
}

Describe "When calling Mock on existing function with matching bound params" {
    Mock FunctionUnderTest {return "fake results"} -parameterFilter {$param1 -eq "badTest"}

    $result=FunctionUnderTest "badTest"

    It "Should return mocked result" {
        $result | Should Be "fake results"
    }
}

Describe "When calling Mock on existing function without matching unbound arguments" {
    Mock FunctionUnderTestWithoutParams {return "fake results"} -parameterFilter {$param1 -eq "test" -and $args[0] -eq 'notArg0'}

    $result=FunctionUnderTestWithoutParams -param1 "test" "arg0"

    It "Should redirect to real function" {
        $result | Should Be "I am a real world test with no params"
    }
}

Describe "When calling Mock on existing function with matching unbound arguments" {
    Mock FunctionUnderTestWithoutParams {return "fake results"} -parameterFilter {$param1 -eq "badTest" -and $args[0] -eq 'arg0'}

    $result=FunctionUnderTestWithoutParams "badTest" "arg0"

    It "Should return mocked result" {
        $result | Should Be "fake results"
    }
}

Describe 'When calling Mock on a function that has no parameters' {
    function Test-Function { }
    Mock Test-Function { return $args.Count }

    It 'Sends the $args variable properly with 2+ elements' {
        Test-Function 1 2 3 4 5 | Should Be 5
    }

    It 'Sends the $args variable properly with 1 element' {
        Test-Function 1 | Should Be 1
    }

    It 'Sends the $args variable properly with 0 elements' {
        Test-Function | Should Be 0
    }
}

Describe "When calling Mock on cmdlet Used by Mock" {
    Mock Set-Item {return "I am not Set-Item"}
    Mock Set-Item {return "I am not Set-Item"}

    $result = Set-Item "mypath" -value "value"

    It "Should Invoke the mocked script" {
        $result | Should Be "I am not Set-Item"
    }
}

Describe "When calling Mock on More than one command" {
    Mock Invoke-Command {return "I am not Invoke-Command"}
    Mock FunctionUnderTest {return "I am the mock test"}

    $result = Invoke-Command {return "yes I am"}
    $result2 = FunctionUnderTest

    It "Should Invoke the mocked script for the first Mock" {
        $result | Should Be "I am not Invoke-Command"
    }
    It "Should Invoke the mocked script for the second Mock" {
        $result2 | Should Be "I am the mock test"
    }
}

Describe 'When calling Mock on a module-internal function.' {
    New-Module -Name TestModule {
        function InternalFunction { 'I am the internal function' }
        function PublicFunction   { InternalFunction }
        function PublicFunctionThatCallsExternalCommand { Start-Sleep 0 }

        function FuncThatOverwritesExecutionContext {
            param ($ExecutionContext)

            InternalFunction
        }

        Export-ModuleMember -Function PublicFunction, PublicFunctionThatCallsExternalCommand, FuncThatOverwritesExecutionContext
    } | Import-Module -Force

    New-Module -Name TestModule2 {
        function InternalFunction { 'I am the second module internal function' }
        function InternalFunction2 { 'I am the second module, second function' }
        function PublicFunction   { InternalFunction }
        function PublicFunction2 { InternalFunction2 }

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

    It 'Should fail to call the internal module function' {
        { TestModule\InternalFunction } | Should Throw
    }

    It 'Should call the actual internal module function from the public function' {
        TestModule\PublicFunction | Should Be 'I am the internal function'
    }

    Context 'Using Mock -ModuleName "ModuleName" "CommandName" syntax' {
        Mock -ModuleName TestModule InternalFunction { 'I am the mock test' }

        It 'Should call the mocked function' {
            TestModule\PublicFunction | Should Be 'I am the mock test'
        }

        Mock -ModuleName TestModule Start-Sleep { }

        It 'Should mock calls to external functions from inside the module' {
            PublicFunctionThatCallsExternalCommand

            Assert-MockCalled -ModuleName TestModule Start-Sleep -Exactly 1
        }

        Mock -ModuleName TestModule2 InternalFunction -ParameterFilter { $args[0] -eq 'Test' } {
            "I'm the mock who's been passed parameter Test"
        }

        It 'Should only call mocks within the same module' {
            TestModule2\PublicFunction | Should Be 'I am the second module internal function'
        }

        Mock -ModuleName TestModule2 InternalFunction2 {
            InternalFunction 'Test'
        }

        It 'Should call mocks from inside another mock' {
            TestModule2\PublicFunction2 | Should Be "I'm the mock who's been passed parameter Test"
        }

        It 'Should work even if the function is weird and steps on the automatic $ExecutionContext variable.' {
            TestModule2\FuncThatOverwritesExecutionContext | Should Be 'I am the second module internal function'
            TestModule\FuncThatOverwritesExecutionContext | Should Be 'I am the mock test'
        }

        Mock -ModuleName TestModule2 Get-CallerModuleName -ParameterFilter { $false }

        It 'Should call the original command from the proper scope if no parameter filters match' {
            TestModule2\ScopeTest | Should Be 'TestModule2'
        }

        Mock -ModuleName TestModule2 Get-Content { }

        It 'Does not trigger the mocked Get-Content from Pester internals' {
            Mock -ModuleName TestModule2 Get-CallerModuleName -ParameterFilter { $false }
            Assert-MockCalled -ModuleName TestModule2 Get-Content -Times 0 -Scope It
        }
    }

    AfterAll {
        Remove-Module TestModule -Force
        Remove-Module TestModule2 -Force
    }
}

Describe "When Applying multiple Mocks on a single command" {
    Mock FunctionUnderTest {return "I am the first mock test"} -parameterFilter {$param1 -eq "one"}
    Mock FunctionUnderTest {return "I am the Second mock test"} -parameterFilter {$param1 -eq "two"}

    $result = FunctionUnderTest "one"
    $result2= FunctionUnderTest "two"

    It "Should Invoke the mocked script for the first Mock" {
        $result | Should Be "I am the first mock test"
    }
    It "Should Invoke the mocked script for the second Mock" {
        $result2 | Should Be "I am the Second mock test"
    }
}

Describe "When Applying multiple Mocks with filters on a single command where both qualify" {
    Mock FunctionUnderTest {return "I am the first mock test"} -parameterFilter {$param1.Length -gt 0 }
    Mock FunctionUnderTest {return "I am the Second mock test"} -parameterFilter {$param1 -gt 1 }

    $result = FunctionUnderTest "one"

    It "The last Mock should win" {
        $result | Should Be "I am the Second mock test"
    }
}

Describe "When Applying multiple Mocks on a single command where one has no filter" {
    Mock FunctionUnderTest {return "I am the first mock test"} -parameterFilter {$param1 -eq "one"}
    Mock FunctionUnderTest {return "I am the paramless mock test"}
    Mock FunctionUnderTest {return "I am the Second mock test"} -parameterFilter {$param1 -eq "two"}

    $result = FunctionUnderTest "one"
    $result2= FunctionUnderTest "three"

    It "The parameterless mock is evaluated last" {
        $result | Should Be "I am the first mock test"
    }

    It "The parameterless mock will be applied if no other wins" {
        $result2 | Should Be "I am the paramless mock test"
    }
}

Describe "When Creating a Verifiable Mock that is not called" {
    Context "In the test script's scope" {
        Mock FunctionUnderTest {return "I am a verifiable test"} -Verifiable -parameterFilter {$param1 -eq "one"}
        FunctionUnderTest "three" | Out-Null

        try {
            Assert-VerifiableMocks
        } Catch {
            $result=$_
        }

        It "Should throw" {
            $result.Exception.Message | Should Be "`r`n Expected FunctionUnderTest to be called with `$param1 -eq `"one`""
        }
    }

    Context "In a module's scope" {
        New-Module -Name TestModule -ScriptBlock {
            function ModuleFunctionUnderTest { return 'I am the function under test in a module' }
        } | Import-Module -Force

        Mock -ModuleName TestModule ModuleFunctionUnderTest {return "I am a verifiable test"} -Verifiable -parameterFilter {$param1 -eq "one"}
        TestModule\ModuleFunctionUnderTest "three" | Out-Null

        try {
            Assert-VerifiableMocks
        } Catch {
            $result=$_
        }

        It "Should throw" {
            $result.Exception.Message | Should Be "`r`n Expected ModuleFunctionUnderTest in module TestModule to be called with `$param1 -eq `"one`""
        }

        AfterAll {
            Remove-Module TestModule -Force
        }
    }
}

Describe "When Creating a Verifiable Mock that is called" {
    Mock FunctionUnderTest -Verifiable -parameterFilter {$param1 -eq "one"}
    FunctionUnderTest "one"
    It "Assert-VerifiableMocks Should not throw" {
        { Assert-VerifiableMocks } | Should Not Throw
    }
}

Describe "When Calling Assert-MockCalled 0 without exactly" {
    Mock FunctionUnderTest {}
    FunctionUnderTest "one"

    try {
        Assert-MockCalled FunctionUnderTest 0
    } Catch {
        $result=$_
    }

    It "Should throw if mock was called" {
        $result.Exception.Message | Should Be "Expected FunctionUnderTest to be called 0 times exactly but was called 1 times"
    }

    It "Should not throw if mock was not called" {
        Assert-MockCalled FunctionUnderTest 0 { $param1 -eq "stupid" }
    }
}

Describe "When Calling Assert-MockCalled with exactly" {
    Mock FunctionUnderTest {}
    FunctionUnderTest "one"
    FunctionUnderTest "one"

    try {
        Assert-MockCalled FunctionUnderTest -exactly 3
    } Catch {
        $result=$_
    }

    It "Should throw if mock was not called the number of times specified" {
        $result.Exception.Message | Should Be "Expected FunctionUnderTest to be called 3 times exactly but was called 2 times"
    }

    It "Should not throw if mock was called the number of times specified" {
        Assert-MockCalled FunctionUnderTest -exactly 2 { $param1 -eq "one" }
    }
}

Describe "When Calling Assert-MockCalled without exactly" {
    Mock FunctionUnderTest {}
    FunctionUnderTest "one"
    FunctionUnderTest "one"
    FunctionUnderTest "two"

    It "Should throw if mock was not called atleast the number of times specified" {
        $scriptBlock = { Assert-MockCalled FunctionUnderTest 4 }
        $scriptBlock | Should Throw "Expected FunctionUnderTest to be called at least 4 times but was called 3 times"
    }

    It "Should not throw if mock was called at least the number of times specified" {
        Assert-MockCalled FunctionUnderTest
    }

    It "Should not throw if mock was called at exactly the number of times specified" {
        Assert-MockCalled FunctionUnderTest 2 { $param1 -eq "one" }
    }

    It "Should throw an error if any non-matching calls to the mock are made, and the -ExclusiveFilter parameter is used" {
        $scriptBlock = { Assert-MockCalled FunctionUnderTest -ExclusiveFilter { $param1 -eq 'one' } }
        $scriptBlock | Should Throw '1 non-matching calls were made'
    }
}

Describe "Using Pester Scopes (Describe,Context,It)" {
    Mock FunctionUnderTest {return "I am the first mock test"} -parameterFilter {$param1 -eq "one"}
    Mock FunctionUnderTest {return "I am the paramless mock test"}

    Context "When in the first context" {
        It "should mock Describe scoped paramles mock" {
            FunctionUnderTest | should be "I am the paramless mock test"
        }
        It "should mock Describe scoped single param mock" {
            FunctionUnderTest "one" | should be "I am the first mock test"
        }
    }

    Context "When in the second context" {
        It "should mock Describe scoped paramles mock again" {
            FunctionUnderTest | should be "I am the paramless mock test"
        }
        It "should mock Describe scoped single param mock again" {
            FunctionUnderTest "one" | should be "I am the first mock test"
        }
    }

    Context "When using mocks in both scopes" {
        Mock FunctionUnderTestWithoutParams {return "I am the other function"}

        It "should mock Describe scoped mock." {
            FunctionUnderTest | should be "I am the paramless mock test"
        }
        It "should mock Context scoped mock." {
            FunctionUnderTestWithoutParams | should be "I am the other function"
        }
    }

    Context "When context hides a describe mock" {
        Mock FunctionUnderTest {return "I am the context mock"}
        Mock FunctionUnderTest {return "I am the parameterized context mock"} -parameterFilter {$param1 -eq "one"}

        It "should use the context paramles mock" {
            FunctionUnderTest | should be "I am the context mock"
        }
        It "should use the context parameterized mock" {
            FunctionUnderTest "one" | should be "I am the parameterized context mock"
        }
    }

    Context "When context no longer hides a describe mock" {
        It "should use the describe mock" {
            FunctionUnderTest | should be "I am the paramless mock test"
        }

        It "should use the describe parameterized mock" {
            FunctionUnderTest "one" | should be "I am the first mock test"
        }
    }

    Context 'When someone calls Mock from inside an It block' {
        Mock FunctionUnderTest { return 'I am the context mock' }

        It 'Sets the mock' {
            Mock FunctionUnderTest { return 'I am the It mock' }
        }

        It 'Leaves the mock active in the parent scope' {
            FunctionUnderTest | Should Be 'I am the It mock'
        }
    }
}

Describe 'Testing mock history behavior from each scope' {
    function MockHistoryChecker { }
    Mock MockHistoryChecker { 'I am the describe mock.' }

    Context 'Without overriding the mock in lower scopes' {
        It "Reports that zero calls have been made to in the describe scope" {
            Assert-MockCalled MockHistoryChecker -Exactly 0 -Scope Describe
        }

        It 'Calls the describe mock' {
            MockHistoryChecker | Should Be 'I am the describe mock.'
        }

        It "Reports that zero calls have been made in an It block, after a context-scoped call" {
            Assert-MockCalled MockHistoryChecker -Exactly 0 -Scope It
        }

        It "Reports one Context-scoped call" {
            Assert-MockCalled MockHistoryChecker -Exactly 1
        }

        It "Reports one Describe-scoped call" {
            Assert-MockCalled MockHistoryChecker -Exactly 1 -Scope Describe
        }
    }

    Context 'After exiting the previous context' {
        It 'Reports zero context-scoped calls in the new context.' {
            Assert-MockCalled MockHistoryChecker -Exactly 0
        }

        It 'Reports one describe-scoped call from the previous context' {
            Assert-MockCalled MockHistoryChecker -Exactly 1 -Scope Describe
        }
    }

    Context 'While overriding mocks in lower scopes' {
        Mock MockHistoryChecker { 'I am the context mock.' }

        It 'Calls the context mock' {
            MockHistoryChecker | Should Be 'I am the context mock.'
        }

        It 'Reports one context-scoped call' {
            Assert-MockCalled MockHistoryChecker -Exactly 1
        }

        It 'Reports two describe-scoped calls, even when one is an override mock in a lower scope' {
            Assert-MockCalled MockHistoryChecker -Exactly 2 -Scope Describe
        }

        It 'Calls an It-scoped mock' {
            Mock MockHistoryChecker { 'I am the It mock.' }
            MockHistoryChecker | Should Be 'I am the It mock.'
        }

        It 'Reports 2 context-scoped calls' {
            Assert-MockCalled MockHistoryChecker -Exactly 2
        }

        It 'Reports 3 describe-scoped calls' {
            Assert-MockCalled MockHistoryChecker -Exactly 3 -Scope Describe
        }
    }

    It 'Reports 3 describe-scoped calls using the default scope in a Describe block' {
        Assert-MockCalled MockHistoryChecker -Exactly 3
    }
}

Describe "Using a single no param Describe" {
    Mock FunctionUnderTest {return "I am the describe mock test"}

    Context "With a context mocking the same function with no params"{
        Mock FunctionUnderTest {return "I am the context mock test"}
        It "Should use the context mock" {
            FunctionUnderTest | should be "I am the context mock test"
        }
    }
}

Describe 'Dot Source Test' {
    # This test is only meaningful if this test file is dot-sourced in the global scope.  If it's executed without
    # dot-sourcing or run by Invoke-Pester, there's no problem.

    function TestFunction { Test-Path -Path 'Test' }
    Mock Test-Path { }

    $null = TestFunction

    It "Calls the mock with parameter 'Test'" {
        Assert-MockCalled Test-Path -Exactly 1 -ParameterFilter { $Path -eq 'Test' }
    }

    It "Doesn't call the mock with any other parameters" {
        Assert-MockCalled Test-Path -Exactly 0 -ParameterFilter { $Path -ne 'Test' }
    }
}

Describe 'Mocking Cmdlets with dynamic parameters' {
    $mockWith = { if (-not $CodeSigningCert) { throw 'CodeSigningCert variable not found, or set to false!' } }
    Mock Get-ChildItem -MockWith $mockWith -ParameterFilter { [bool]$CodeSigningCert }

    It 'Allows calls to be made with dynamic parameters (including parameter filters)' {
        { Get-ChildItem -Path Cert:\ -CodeSigningCert } | Should Not Throw
        Assert-MockCalled Get-ChildItem
    }
}

Describe 'Mocking functions with dynamic parameters' {
    Context 'Dynamicparam block that uses the variables of static parameters in its logic' {
        # Get-Greeting sample function borrowed and modified from Bartek Bielawski's
        # blog at http://becomelotr.wordpress.com/2012/05/10/using-and-abusing-dynamic-parameters/

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

            end
            {
                if($PSBoundParameters.Capitalize) {
                    $Name = [regex]::Replace(
                        $Name,
                        '\b\w',
                        { $args[0].Value.ToUpper() }
                    )
                }

                "Welcome $Name!"
            }
        }

        $mockWith = { if (-not $Capitalize) { throw 'Capitalize variable not found, or set to false!' } }
        Mock Get-Greeting -MockWith $mockWith -ParameterFilter { [bool]$Capitalize }

        It 'Allows calls to be made with dynamic parameters (including parameter filters)' {
            { Get-Greeting -Name lowercase -Capitalize } | Should Not Throw
            Assert-MockCalled Get-Greeting
        }

        $Capitalize = $false

        It 'Sets the dynamic parameter variable properly' {
            { Get-Greeting -Name lowercase -Capitalize } | Should Not Throw
            Assert-MockCalled Get-Greeting -Scope It
        }
    }

    Context 'When the mocked command is in a module' {
        New-Module -Name TestModule {
            function PublicFunction { Get-Greeting -Name lowercase -Capitalize }

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
                    if (-not $script:DoDynamicParam) { return }

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

                end
                {
                    if($PSBoundParameters.Capitalize) {
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

        $mockWith = { if (-not $Capitalize) { throw 'Capitalize variable not found, or set to false!' } }
        Mock Get-Greeting -MockWith $mockWith -ModuleName TestModule -ParameterFilter { [bool]$Capitalize }

        It 'Allows calls to be made with dynamic parameters (including parameter filters)' {
            { TestModule\PublicFunction } | Should Not Throw
            Assert-MockCalled Get-Greeting -ModuleName TestModule
        }

        AfterAll {
            Remove-Module TestModule -Force
        }
    }

    Context 'When the mocked command has mandatory parameters that are passed in via the pipeline' {
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

            end
            {
                if($PSBoundParameters.Capitalize) {
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

        It 'Should successfully call the mock and generate the dynamic parameters' {
            $scriptBlock | Should Not Throw
            $hash.Result | Should Be 'Mocked'
        }
    }

    Context 'When the mocked command has parameter sets that are ambiguous at the time the dynamic param block is executed' {
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

            end
            {
                if($PSBoundParameters.Capitalize) {
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

        It 'Should successfully call the mock and generate the dynamic parameters' {
            $scriptBlock | Should Not Throw
            $hash.Result | Should Be 'Mocked'
        }
    }

    Context 'When the mocked command''s dynamicparam block depends on the contents of $PSBoundParameters' {
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

            end
            {
                if($PSBoundParameters.Capitalize) {
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

        It 'Should successfully call the mock and generate the dynamic parameters' {
            $scriptBlock | Should Not Throw
            $hash.Result | Should Be 'Mocked'
        }
    }

    Context 'When the mocked command''s dynamicparam block depends on the contents of $PSCmdlet.ParameterSetName' {
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

            end
            {
                if($PSBoundParameters.Capitalize) {
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

        It 'Should successfully call the mock and generate the dynamic parameters' {
            $scriptBlock | Should Not Throw
            $hash.Result | Should Be 'Mocked'
        }
    }
}

Describe 'Mocking Cmdlets with dynamic parameters in a module' {
    New-Module -Name TestModule {
        function PublicFunction   { Get-ChildItem -Path Cert:\ -CodeSigningCert }
    } | Import-Module -Force

    $mockWith = { if (-not $CodeSigningCert) { throw 'CodeSigningCert variable not found, or set to false!' } }
    Mock Get-ChildItem -MockWith $mockWith -ModuleName TestModule -ParameterFilter { [bool]$CodeSigningCert }

    It 'Allows calls to be made with dynamic parameters (including parameter filters)' {
        { TestModule\PublicFunction } | Should Not Throw
        Assert-MockCalled Get-ChildItem -ModuleName TestModule
    }

    AfterAll {
        Remove-Module TestModule -Force
    }
}

Describe 'DynamicParam blocks in other scopes' {
    New-Module -Name TestModule1 {
        $script:DoDynamicParam = $true

        function DynamicParamFunction {
            [CmdletBinding()]
            param ( )

            DynamicParam {
                if ($script:DoDynamicParam)
                {
                    Get-MockDynamicParameters -CmdletName Get-ChildItem -Parameters @{ Path = [string[]]'Cert:\' }
                }
            }

            end
            {
                'I am the original function'
            }
        }
    } | Import-Module -Force

    New-Module -Name TestModule2 {
        function CallingFunction
        {
            DynamicParamFunction -CodeSigningCert
        }

        function CallingFunction2 {
            [CmdletBinding()]
            param (
                [ValidateScript({ [bool](DynamicParamFunction -CodeSigningCert) })]
                [string]
                $Whatever
            )
        }
    } | Import-Module -Force

    Mock DynamicParamFunction { if ($CodeSigningCert) { 'I am the mocked function' } } -ModuleName TestModule2

    It 'Properly evaluates dynamic parameters when called from another scope' {
        CallingFunction | Should Be 'I am the mocked function'
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
    function Test-Function { [CmdletBinding()] param ( ) }

    Mock Test-Function { } -ParameterFilter { $VerbosePreference -eq 'Continue' }

    It 'Applies common parameters correctly when testing the parameter filter' {
        { Test-Function -Verbose } | Should Not Throw
        Assert-MockCalled Test-Function
        Assert-MockCalled Test-Function -ParameterFilter { $VerbosePreference -eq 'Continue' }
    }
}

Describe "Mocking Get-ItemProperty" {
    Mock Get-ItemProperty { New-Object -typename psobject -property @{ Name = "fakeName" } }
    It "Does not fail with NotImplementedException" {
        Get-ItemProperty -Path "HKLM:\Software\Key\" -Name "Property" | Select -ExpandProperty Name | Should Be fakeName
    }
}

Describe 'When mocking a command with parameters that match internal variable names' {
    function Test-Function
    {
        [CmdletBinding()]
        param (
            [string] $ArgumentList,
            [int] $FunctionName,
            [double] $ModuleName
        )
    }

    Mock Test-Function { return 'Mocked!' }

    It 'Should execute the mocked command successfully' {
        { Test-Function } | Should Not Throw
        Test-Function | Should Be 'Mocked!'
    }
}

Describe 'Mocking commands with potentially ambigious parameter sets' {
    function SomeFunction
    {
        [CmdletBinding()]
        param
        (
            [parameter(ParameterSetName                = 'ps1',
                       ValueFromPipelineByPropertyName = $true)]
            [string]
            $p1,

            [parameter(ParameterSetName                = 'ps2',
                       ValueFromPipelineByPropertyName = $true)]
            [string]
            $p2
        )
        process
        {
            return $true
        }
    }

    Mock SomeFunction { }

    It 'Should call the function successfully, even with delayed parameter binding' {
        $object = New-Object psobject -Property @{ p1 = 'Whatever' }
        { $object | SomeFunction } | Should Not Throw
        Assert-MockCalled SomeFunction -ParameterFilter { $p1 -eq 'Whatever' }
    }
}

Describe 'When mocking a command that has an ArgumentList parameter with validation' {
    Mock Start-Process { return 'mocked' }

    It 'Calls the mock properly' {
        $hash = @{ Result = $null }
        $scriptBlock = { $hash.Result = Start-Process -FilePath cmd.exe -ArgumentList '/c dir c:\' }

        $scriptBlock | Should Not Throw
        $hash.Result | Should Be 'mocked'
    }
}
