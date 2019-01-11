Feature: PesterResult shows executed feature names

    As a PowerShell Pester Gherkin test author
    I want the feature names to be displayed in the PesterResults
    So that I know what features were executed during the test run.

  Scenario: The PesterResult object shows the executed feature names

    Given this feature and scenario
     When it is executed
     Then the feature name is displayed in the test report

  Scenario Outline: The Pester test report shows scenario names with examples

    Given this is a '<Outcome>' scenario
     When the scenario is executed
     Then the scenario name is displayed in the '<Status>' array of the PesterResults object

      Examples: A Passing Scenario
        | Outcome         | Status               |
        | Passed          | PassedScenarios      |

      Examples: Failing Scenario (later)
        | Outcome         | Status               |
        # The following example fails in the Then code block
        | FailedLater     | FailedLaterScenarios |

      Examples: Failing Scenario (early)
        | Outcome         | Status               |
        # The following example fails in the Given code block
        | FailedEarly     | FailedEarlyScenarios |

      Examples: Failing Scenario (inconclusive)
        | Outcome         | Status               |
        # In PesterResult.Steps.ps1 we do not implement anything for the following example
        # to produce an inconclusive test result
        | Does not matter | Does not matter      |
