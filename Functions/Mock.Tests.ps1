$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

function FunctionUnderTest ([string]$param1=""){
    return "I am a real world test"
}

Describe "When calling Mock on existing function" {
    Mock FunctionUnderTest {return "I am the mock test"}

    $result=FunctionUnderTest

    It "Should rename function under test" {
        $renamed = (Test-Path function:PesterIsMocking_FunctionUnderTest)
        $renamed.should.be($true)
    }

    It "Should Invoke the mocked script" {
        $result.should.be("I am the mock test")
    }
    Clear-Mocks
}

Describe "When calling Mock on existing cmdlet" {
    Mock Get-Process {return "I am not Get-Process"}

    $result=Get-Process

    It "Should Invoke the mocked script" {
        $result.should.be("I am not Get-Process")
    }
    Clear-Mocks
}

Describe "When calling Mock on cmdlet Used by Mock" {
    Mock Invoke-Command {return "I am not Invoke-Command"}
    $result = Invoke-Command {return "yes I am"}

    It "Should Invoke the mocked script" {
        $result.should.be("I am not Invoke-Command")
    }
    Clear-Mocks
}


Describe "When calling Mock on non-existing function" {
    try{
        Mock NotFunctionUnderTest {return}
    } Catch {
        $result=$_
    }

    It "Should throw correct error" {
        $result.Exception.Message.should.be("Could not find command NotFunctionUnderTest")
    }
    Clear-Mocks
}

Describe "When calling Mock on existing function without matching params" {
    Mock FunctionUnderTest {return "fake results"} -parameterFilter {$param1 -eq "test"}

    $result=FunctionUnderTest "badTest"

    It "Should redirect to real function" {
        $result.should.be("I am a real world test")
    }
    Clear-Mocks
}

Describe "When calling Mock on existing function with matching params" {
    Mock FunctionUnderTest {return "fake results"} -parameterFilter {$param1 -eq "badTest"}

    $result=FunctionUnderTest "badTest"

    It "Should return mocked result" {
        $result.should.be("fake results")
    }
    Clear-Mocks
}
