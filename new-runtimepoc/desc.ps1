describe "a" {

    $a = 1
    beforeEach { Write-Host $a }
    describe "b" {
        
        describe "b" {

            $a = 10    
            it "a" {
                "hooooooo"
            }
        }
        it 'smoula' {
            "sddd"
        }
    }
}