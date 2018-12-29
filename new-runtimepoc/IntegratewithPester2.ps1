Get-MOdule Pester | Remove-Module
Import-Module $PSScriptRoot\..\Pester.psd1 



$null = Describe "does not run" { 
   
}

$r = Describe "runs" { 
    it "passes" {
        
    }

    it "fails" {
        throw "a"
    }
}

