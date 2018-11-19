Feature: Pester displays scenario data in the console

  Scenario: Pester outputs the DocString content when writing Pester step results

    Given the following DocString:
      """
      This is an example Gherkin DocString
      that should be displayed underneath the
      step definition when the step is
      printed to the console during the test run.
      """
     When this scenario is run
     Then the DocString is displayed in the console

  Scenario: Pester outputs step definition table content when writing Pester step results

    Given a square data table:
      | fruit  | vegetable       |
      | apple  | cucumber        |
      | banana | brussel sprouts |
    And a rectangular data table:
      | x | y | result |
      | 1 | 1 | 2      |
      | 2 | 2 | 4      |
    And a single column data table:
      | PropertyNames                               |
      | ModuleVersion                               |
      | GUID                                        |
      | Author                                      |
      | CompanyName                                 |
      | Copyright                                   |
      | Description                                 |
      | PrivateData.PSData.ProjectUri               |
      | PrivateData.PSData.RequireLicenseAcceptance |
      | PrivateData.PSData.ReleaseNotes             |
      | PrivateData.PSData.Tags                     |
    When this scenario is run
    Then the tables are displayed correctly in the console

  Scenario: Can classify steps as undefined
    Given this step definition does not have an implementation
     When this scenario is run
     Then all of these steps are classified as undefined

Scenario Outline: Pester can display scenario example tables to the console

  Given a number '<x>' and a numbxer '<y>'
  When I add them together
  Then I should get '<result>'

  Examples: Elementary, my dear Watson
    | x | y | result |
    | 1 | 1 | 2      |
    | 2 | 2 | 4      |

  Scenario: Now for something a little bit different
    | x | y | result |
    | 1 | 2 | 3      |
    | 2 | 3 | 5      |
