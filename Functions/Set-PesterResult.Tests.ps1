Describe "Example" {
    It "This test should pass" {
        $true | Should -BeTrue
    }

    It "This test should have inconclusive result" {
        Set-PesterResult -Inconclusive -Because "we want it to be inconclusive"
    }

    It "This test should be skipped" {
        Set-PesterResult -Skipped -Because "we want it to be skipped"
    }

    It "This test should fail" {
        $fast | Should -BeTrue -Because "it is a fake failing test"
    }
}

