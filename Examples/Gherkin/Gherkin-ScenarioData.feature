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
      | PropNames                                   |
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
