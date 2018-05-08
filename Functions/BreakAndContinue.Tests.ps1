Set-StrictMode -Version Latest

Describe 'Clean handling of break and continue' {
    # If this test 'fails', it'll just cause most of the rest of the tests to never execute (and we won't see any actual failures.)
    # The CI job monitors metrics, though, and will fail the build if the number of tests drops too much.

    Context 'Break' {
        break
    }

    Context 'Continue' {
        continue
    }

    It 'Did not abort the whole test run' { $null = $null }
}
