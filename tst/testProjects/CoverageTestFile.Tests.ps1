Set-StrictMode -Version Latest

Describe 'Testing CodeCoverage' {
    It 'Single error' {
        . "$PSScriptRoot/../CoverageTestFile.ps1"
    }
}
