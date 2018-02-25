Feature: Import a Feature File
Pester should be able to ingest a feature file and write test stubs.

    Scenario Outline: Import a parameterize scenario
        Given An '<entity>' to test
        When An '<entity>' exists
        Then '<entity>' should have the correct '<value>'

        Examples:
            | entity  | value   |
            | Entity1 | Value 1 |
            | Entity2 | Value 2 |
