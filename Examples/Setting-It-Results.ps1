Describe "Examples of setting it results" {
    It "This test passes" {
        $true | Should -BeTrue
    }

    It "This test is inconclusive without a reason" {
        Set-ItResult -Inconclusive 
    }

    It "This test is inconclusive" {
        Set-ItResult -Inconclusive -Because "we want it to be inconclusive"
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
