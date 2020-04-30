Set-StrictMode -Version Latest

Describe "describe filterable tests" {
    It "untagged it" {

    }

    It "slow it" -Tag 'slow' {

    }

    It "skipped it" -Skip {

    }
}
