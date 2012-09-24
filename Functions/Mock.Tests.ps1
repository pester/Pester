$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

function FunctionUnderTest {
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
}

Describe "When calling Mock on non-existing function" {
    try{
        Mock NotFunctionUnderTest {return}
    } Catch {
        $result=$_
    }

    It "Should throw correct error" {
        $result.Exception.Message.should.be("Could not find function NotFunctionUnderTest")
    }
}
