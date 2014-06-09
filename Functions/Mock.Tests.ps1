$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

function FunctionUnderTest (  [Parameter(Mandatory=$false)][string] $param1){
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
    Mock FunctionUnderTest {return "I am the mock test that was passed $param1"}

    $result=FunctionUnderTest "boundArg"

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
}

Describe 'When calling Mock on existing cmdlet using fully qualified command name' {
    Mock Microsoft.PowerShell.Management\Get-Process {return 'I am not Microsoft.PowerShell.Management\Get-Process'}

    <#
        # Mocking a module-qualified cmdlet is not supported
         
        $result = Microsoft.PowerShell.Management\Get-Process

        It 'Should Invoke the mocked script using its module-qualified name' {
            $result | Should Be 'I am not Microsoft.PowerShell.Management\Get-Process'
        }
    #>

    $result = Get-Process

    It 'Should Invoke the mocked script' {
        $result | Should Be 'I am not Microsoft.PowerShell.Management\Get-Process'
    }
}

Describe 'When calling Mock on an alias' {
    Mock ps {return 'I am not ps'}

    $result = ps

    It 'Should Invoke the mocked script' {
        $result | Should Be 'I am not ps'
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
        $outfile = "test" | Out-File "..\testfile.txt"
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
    $result2=FunctionUnderTest

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
        Export-ModuleMember -Function PublicFunction
    } | Import-Module -Force

    It 'Should fail to call the internal module function' {
        { InternalFuncTion } | Should Throw
    }

    It 'Should call the actual internal module function' {
        PublicFunction | Should Be 'I am the internal function'
    }

    It 'Should call the mocked function using only the function name' {
        Mock InternalFunction { 'I am the mock test' } -moduleName TestModule
        PublicFunction | Should Be 'I am the mock test'
    }

    It 'Should call the mocked function using its fully qualified name' {
        Mock InternalFunction { 'I am the mock test' } -moduleName TestModule
        TestModule\PublicFunction | Should Be 'I am the mock test'
    }

    Remove-Module TestModule -Force
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

Describe "When Creating a Verifiable Mock that is called" {
    Mock FunctionUnderTest -Verifiable -parameterFilter {$param1 -eq "one"}
    FunctionUnderTest "one"
    It "Assert-VerifiableMocks Should not throw" {
        { Assert-VerifiableMocks } | Should Not Throw
    }
}

Describe "When Creating a Verifiable Mock with a filter that does not return a boolean" {
    $result=""

    try{
        Mock FunctionUnderTest {return "I am a verifiable test"} -parameterFilter {"one"}
    } Catch {
        $result=$_
    }

    It "Should throw" {
        $result | Should Be "The Parameter Filter must return a boolean"
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

    try {
        Assert-MockCalled FunctionUnderTest 3
    } Catch {
        $result=$_
    }

    It "Should throw if mock was not called atleast the number of times specified" {
        $result.Exception.Message | Should Be "Expected FunctionUnderTest to be called at least 3 times but was called 2 times"
    }
    It "Should not throw if mock was called at least the number of times specified" {
        Assert-MockCalled FunctionUnderTest
    }
    It "Should not throw if mock was called at exactly the number of times specified" {
        Assert-MockCalled FunctionUnderTest 2 { $param1 -eq "one" }
    }
}

Describe "Using Contexts" {
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

