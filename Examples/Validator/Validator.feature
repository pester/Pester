Feature: A string validator function called MyValidator

    Just a description of the feature
    The second line

    @Mockery
    Scenario: When something uses MyValidator

        Just a description of the scenario
        The second line

        Given MyValidator is mocked to return True
        When Someone calls something that uses MyValidator
        Then MyValidator gets called once

    @Examples
    Scenario Outline: MyValidator should return true only for words that start with lowercase s
        When MyValidator is called with <word>
        Then MyValidator should return <StartsWithS>

        @Example1
        Examples: Some s words and expected results
            | word   | StartsWithS |
            | sandy  | True        |
            | sears  | True        |

        @Example2
        Examples: Some other words that will all fail
            | word   | StartsWithS |
            | Super  | False       |
            | Breath | False       |
            | test   | False       |

    @Scenarios
    Scenario Template: MyValidator should return true only for words that start with lowercase s (using Scenario Template)
        When MyValidator is called with <word>
        Then MyValidator should return <StartsWithS>

        Scenarios: Some s words and expected results
            | word   | StartsWithS |
            | sandy  | True        |
            | sears  | True        |
