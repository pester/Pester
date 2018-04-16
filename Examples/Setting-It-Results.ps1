#sSet-StrictMode -Version Latest

Describe "Examples of setting it results" {
    It "This test passes" {
        $true | Should -BeTrue
    }

    It "This test is inconclusive the old way" {
        Set-TestInconclusive -Message "we are testing deprecation"
    }

    It "This test is inconclusive the old way, too" {
        Set-TestInconclusive -Message "we don't want too many big deprecation messages"
    }

    It "This test is inconclusive without a reason" {
        Set-ItResult -Inconclusive 
    }

    It "This test is inconclusive" {
        Set-ItResult -Inconclusive -Because "we want it to be inconclusive"
    }

    It "This test is pending without a reason" {
        Set-ItResult -Pending 
    }

    It "This test is pending" {
        Set-ItResult -Pending -Because "we want it to be pending"
    }

    It "This test is skipped without a reason" {
        Set-ItResult -Skipped 
    }

    It "This test is skipped" {
        Set-ItResult -Skipped -Because "we want it to be skipped"
    }

    It "This test should fail" {
        $false | Should -BeTrue -Because "it is a fake failing test"
    }
}
