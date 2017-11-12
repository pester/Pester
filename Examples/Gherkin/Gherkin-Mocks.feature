Feature: Pester's Gherkin implementation mock scope
    As a PowerShell gherkin author
    I want mocks to work within each scenario
    So that writing tests will be simple

    Scenario: Mocks Should Be Easy
        Given we mock Write-Error
        When we call a function that writes an error
        Then we can verify the mock

    Scenario: Mocks Should Not Affect Other Scenarios
        When we call a function that writes an error
        Then we cannot verify the mock

    Scenario: Mocks Should Be Easy Too
        Given we mock Write-Error
        When we call a function that writes an error
        Then we can verify the mock
