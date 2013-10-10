$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\Test-Assertion.ps1"
. "$here\PesterThrow.ps1"


Describe "PesterThrow" {

    It "returns true if the statement throws an exception" {
        Test-PositiveAssertion (PesterThrow { throw })
    }

    It "returns false if the statement does not throw an exception" {
        Test-NegativeAssertion (PesterThrow { 1 + 1 })
    }
    
    It "returns true if the statement throws an exception and the actual error text matches the expected error text" {
        Test-PositiveAssertion (PesterThrow { throw "expected error"} "expected error")
    }    

    It "returns false if the statement throws an exception and the actual error does not match the case of the expected error text" {
        Test-NegativeAssertion (PesterThrow { throw "expected error"} "EXPECTED ERROR")
    }     
    
    It "returns true if the statement throws an exception and the actual error text matches the expected error pattern" {
        Test-PositiveAssertion (PesterThrow { throw "expected error"} "expected*")
    }     
    
    It "returns false if the statement throws an exception but the actual error text does not match the expected error text" {
        Test-NegativeAssertion (PesterThrow { throw "expected error"} "will not match")
    }        
}

