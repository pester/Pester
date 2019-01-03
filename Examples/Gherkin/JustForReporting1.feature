Feature: A test feature for reporting 1

  Scenario: Scenario 1

    Given step_001
    When step_002
    Then step_003

  Scenario Outline: Scenario 2

    Given step_<given>
      And and_<given>
    When step_<when>
      And and_<when>
    Then step_<then>
      And and_<then>

    Examples: Examples 1
      | given | when | then |
      | 101   | 102  | 103  |

    Examples: Examples 2
      | given | when | then |
      | 201   | 202  | 203  |

  Scenario: Scenario 3

    Given step_301
    When step_302
    Then step_303
    When step_302
    Then step_304
