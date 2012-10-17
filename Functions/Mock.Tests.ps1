$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

function FunctionUnderTest ([string]$param1=""){
    return "I am a real world test"
}

Describe "When calling Mock on existing function" {
    Mock FunctionUnderTest {return "I am the mock test that was passed $param1"}

    $result=FunctionUnderTest "yoyo"

    It "Should rename function under test" {
        $renamed = (Test-Path function:PesterIsMocking_FunctionUnderTest)
        $renamed.should.be($true)
    }

    It "Should Invoke the mocked script" {
        $result.should.be("I am the mock test that was passed yoyo")
    }
}

Describe "When calling Mock on existing cmdlet" {
    Mock Get-Process {return "I am not Get-Process"}

    $result=Get-Process

    It "Should Invoke the mocked script" {
        $result.should.be("I am not Get-Process")
    }
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
}

Describe "When calling Mock on existing function without matching params" {
    Mock FunctionUnderTest {return "fake results"} -parameterFilter {$param1 -eq "test"}

    $result=FunctionUnderTest "badTest"

    It "Should redirect to real function" {
        $result.should.be("I am a real world test")
    }
}

Describe "When calling Mock on existing function with matching params" {
    Mock FunctionUnderTest {return "fake results"} -parameterFilter {$param1 -eq "badTest"}

    $result=FunctionUnderTest "badTest"

    It "Should return mocked result" {
        $result.should.be("fake results")
    }
}

Describe "When calling Mock on cmdlet Used by Mock" {
    Mock Invoke-Command {return "I am not Invoke-Command"}

    $result = Invoke-Command {return "yes I am"}

    It "Should Invoke the mocked script" {
        $result.should.be("I am not Invoke-Command")
    }
}

Describe "When calling Mock on More than one command" {
    Mock Invoke-Command {return "I am not Invoke-Command"}
    Mock FunctionUnderTest {return "I am the mock test"}

    $result = Invoke-Command {return "yes I am"}
    $result2=FunctionUnderTest

    It "Should Invoke the mocked script for the first Mock" {
        $result.should.be("I am not Invoke-Command")
    }
    It "Should Invoke the mocked script for the second Mock" {
        $result2.should.be("I am the mock test")
    }
}

Describe "When Applying multiple Mocks on a single command" {
    Mock FunctionUnderTest {return "I am the first mock test"} -parameterFilter {$param1 -eq "one"}
    Mock FunctionUnderTest {return "I am the Second mock test"} -parameterFilter {$param1 -eq "two"}

    $result = FunctionUnderTest "one"
    $result2= FunctionUnderTest "two"

    It "Should Invoke the mocked script for the first Mock" {
        $result.should.be("I am the first mock test")
    }
    It "Should Invoke the mocked script for the second Mock" {
        $result2.should.be("I am the Second mock test")
    }
}

Describe "When Applying multiple Mocks with filters on a single command where both qualify" {
    Mock FunctionUnderTest {return "I am the first mock test"} -parameterFilter {$param1.Length -gt 0 }
    Mock FunctionUnderTest {return "I am the Second mock test"} -parameterFilter {$param1 -gt 1 }

    $result = FunctionUnderTest "one"

    It "The last Mock should win" {
        $result.should.be("I am the Second mock test")
    }
}

Describe "When Applying multiple Mocks on a single command where one has no filter" {
    Mock FunctionUnderTest {return "I am the first mock test"} -parameterFilter {$param1 -eq "one"}
    Mock FunctionUnderTest {return "I am the paramless mock test"}
    Mock FunctionUnderTest {return "I am the Second mock test"} -parameterFilter {$param1 -eq "two"}

    $result = FunctionUnderTest "one"
    $result2= FunctionUnderTest "three"

    It "The parameterless mock is evaluated last" {
        $result.should.be("I am the first mock test")
    }

    It "The parameterless mock will be applied if no other wins" {
        $result2.should.be("I am the paramless mock test")
    }
}

Describe "When Creaing a Verifiable Mock that is not called" {
    Mock FunctionUnderTest {return "I am a verifiable test"} -Verifiable -parameterFilter {$param1 -eq "one"}
    FunctionUnderTest "three"
    
    try {
        Assert-VerifiableMocks
    } Catch {
        $result=$_
    }

    It "Should throw" {
        $result.Exception.Message.should.be("`r`n Expected FunctionUnderTest to be called with `$param1 -eq `"one`"")
    }
}

Describe "When Creaing a Verifiable Mock that is called" {
    Mock FunctionUnderTest {return "I am a verifiable test"} -Verifiable -parameterFilter {$param1 -eq "one"}
    FunctionUnderTest "one"
    $result=""
    
    try {
        Assert-VerifiableMocks
    } Catch {
        $result=$_
    }

    It "Should not throw" {
        $result.should.be("")
    }
}

Describe "When Creaing a Verifiable Mock with a filter that does not return a boolean" {
    $result=""

    try{
        Mock FunctionUnderTest {return "I am a verifiable test"} -parameterFilter {"one"}
    } Catch {
        $result=$_
    }

    It "Should throw" {
        $result.should.be("The Parameter Filter must return a boolean")
    }
}
