function Set-AssertionPassResult {
    if (& $SafeCommands['Get-Variable'] -Name '______isInMockParameterFilter' -Scope Script -ValueOnly -ErrorAction Ignore) {
        $true
    }
}