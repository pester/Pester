Given "this feature and scenario" { }
When "(it|the scenario) is executed" { }
Then "the feature name is displayed in the test report" { }

Given "this is a '(?<Outcome>(Passed|Failed))' scenario" {
    param($Outcome)
}

Then "the scenario name is displayed in the '(?<Status>(Passed|Failed)Scenarios)' array of the PesterResults object" {
    param($Status)

    # Forcing a failure on FailedScenarios to ensure that the FailedScenarios array
    # of the PesterResult object has a value.
    $Status | Should -Be "PassedScenarios"
}
