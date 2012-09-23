$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

function FunctionUnderTest {
    return "I am a real world test"
}

Describe "When calling Mock" {
    Mock FunctionUnderTest {return}

    It "Should rename function under test" {
        $rename = gci function:PesterIsMocking_FunctionUnderTest
        $rename.Count.should.be(1)
    }
}
