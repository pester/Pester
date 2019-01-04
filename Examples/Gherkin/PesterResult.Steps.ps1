Given "this feature and scenario" { }
When "(it|the scenario) is executed" { }
Then "the feature name is displayed in the test report" { }

Given "this is a '(?<Outcome>(Passed|Failed(?:Early|Later)))' scenario" {
    param($Outcome)
    if ($Outcome -eq 'FailedEarly') {
        throw "We fail for test by intention in the Given code block"
    }
}

Then "the scenario name is displayed in the '(?<Status>(Passed|Failed(?:Early|Later))Scenarios)' array of the PesterResults object" {
    param($Status)

    # Forcing a failure on FailedScenarios to ensure that the FailedScenarios array
    # of the PesterResult object has a value.
    if ($Status -match "Failed") {
        throw "We fail for test by intention in the Then code block"
    }
}
