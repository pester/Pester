Feature: A string validator function called MyValidator
    
    Scenario: When something uses MyValidator
        Given MyValidator is mocked to return True
        When Someone calls something that uses MyValidator
        Then MyValidator gets called once

    Scenario Outline: MyValidator should return true for words that start with s
        When MyValidator is called with <word>
        Then MyValidator should return <StartsWithS>

        Examples: Some words and expected results
            | word   | StartsWithS |
            | Super  | False       |
            | sandy  | True        |
            | Breath | False       |
            | sears  | True        |
            | test   | False       |
