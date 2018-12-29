

$null = Describe "does not run" { 
   
}

$r = Describe "runs" { 
    it "passes" {
        
    }

    it "fails" {
        throw "this is expected errror"
    }
}

