Feature: Pester's Gherkin implementation test scope
    As a PowerShell test author
    I want variables to work across step implementations
    So that writing tests will be simple

    Scenario: Scope Should Be Easy Part 0
        Given I initialize the variable One to "Uno"
        When I set the variable One to "Hello World"
        Then the variable One should be "Hello World"

    Scenario: Scope Should Still Be Easy
        Given I initialize the variable Script:Two to "Uno"
        When I set the variable Script:Two to "Hello World"
        Then the variable Script:Two should be "Hello World"

    Scenario: Scope Should Be Easy Part 1
        Given I initialize variables One and Script:Two to "Uno" and "Dos"
        When I set the variable One to "Hello World"
        Then the variable One should be "Hello World"
        And the variable Script:Two should be "Dos"

    Scenario: Scope Should Be Easy Part 2
        Given I initialize variables One and Two to "Uno" and "Dos"
        When I set the variable Two to "Goodbye"
        Then the variable Two should be "Goodbye"
        And the variable One should be "Uno"

    Scenario: Scope Should Not Bleed
        Then the variable Script:Two should not exist
        And the variable One should not exist
