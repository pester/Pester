Describe "a" {
    It "b" -TestCases @(
        @{ Name = "Jakub"; Age = 30 } 
    ) {
        $Name | Should -Be "Jakub"
    }
}