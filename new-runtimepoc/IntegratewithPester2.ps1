

$null = Describe "does not run" { 
   
}

$r = Describe "runs" { 
    it "passes" {
        
    }

    it "fails" {
        throw "this is expected errror"
    }

    Write-Host "the describe that follows should not run"
    Describe "does not run" { 
       
    }
    
    Write-Host "after describe"
}