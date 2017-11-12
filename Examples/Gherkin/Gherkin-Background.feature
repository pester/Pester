Feature: Background
    Gherkin has a background feature which is like a scenario...
    Except that it runs before each scenario (after any "Before" hooks)

  Background: Backgrounds are run for each Scenario
    Given there is a background
    And it sets x to 20

  Scenario: A minimal scenario
    Given it sets y to 10
    When we add y to x
    Then x should be 30

  Scenario: A second scenario
    Given it sets y to 20
    When we add y to x
    Then x should be 40
