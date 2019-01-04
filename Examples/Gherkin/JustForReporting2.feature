Feature: A test feature for reporting 2

  Scenario: Scenario 4

    Given step_401
    When step_402
    Then step_403

  Scenario Outline: Scenario 5

    Given step_<given>
    When step_<when>
    Then step_<then>

    Examples: Examples 1
      | given | when | then |
      | 501   | 502  | 503  |

    Examples: Examples 2
      | given | when | then |
      | 601   | 602  | 603  |
