
Invoke-Pester -ScriptBlock {
    Describe "a" {
        $b = 100
        BeforeAll {
            $a = 10
            Write-Host aa
        }
        AfterAll {
            Write-Host aa
        }
        BeforeEach {
            $b = 12
            Write-Host gggg
        }
        AfterEach { write-host "fff" }
        Describe "abc" {
            AfterAll {
                throw
            }
            BeforeAll {
                $b = 12
                Write-Host bb
            }
            it "abc" {
                Write-Host  $a $b
            }
            it "abc" {
                Write-Host  $a $b
            }
            it "abc" {
                Write-Host  $a $b
            }
        }


    }

}
