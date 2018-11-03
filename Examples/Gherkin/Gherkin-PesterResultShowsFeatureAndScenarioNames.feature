Feature: PesterResult shows executed feature names

    As a PowerShell Pester Gherkin test author
    I want the feature names to be displayed in the PesterResults
    So that I know what features were executed during the test run.

  Scenario: The PesterResult object shows the executed feature names

    Given this feature and scenario
     When it is executed
     Then the feature name is displayed in the test report
