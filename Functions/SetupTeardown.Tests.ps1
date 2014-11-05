Describe 'Describe-Scoped setup' {
    BeforeEach {
        $testVariable = 'From BeforeEach'
    }

    $testVariable = 'Set in Describe'

    It 'Assigns the correct value in first test' {
        $testVariable | Should Be 'From BeforeEach'
        $testVariable = 'Set in It'
    }

    It 'Assigns the correct value in subsequent tests' {
        $testVariable | Should Be 'From BeforeEach'
    }
}

Describe 'Context-scoped setup' {
    $testVariable = 'Set in Describe'

    Context 'The context' {
        BeforeEach {
            $testVariable = 'From BeforeEach'
        }

        It 'Assigns the correct value inside the context' {
            $testVariable | Should Be 'From BeforeEach'
        }
    }

    It 'Reports the original value after the Context' {
        $testVariable | Should Be 'Set in Describe'
    }
}

Describe 'Multiple setup blocks' {
    $testVariable = 'Set in Describe'

    BeforeEach {
        $testVariable = 'Set in Describe BeforeEach'
    }

    Context 'The context' {
        It 'Executes Describe setup blocks first, then Context blocks in the order they were defined (even if they are defined after the It block.)' {
            $testVariable | Should Be 'Set in the second Context BeforeEach'
        }

        BeforeEach {
            $testVariable = 'Set in the first Context BeforeEach'
        }

        BeforeEach {
            $testVariable = 'Set in the second Context BeforeEach'
        }
    }

    It 'Continues to execute Describe setup blocks after the Context' {
        $testVariable | Should Be 'Set in Describe BeforeEach'
    }
}

Describe 'Describe-scoped teardown' {
    $testVariable = 'Set in Describe'

    AfterEach {
        $testVariable = 'Set in AfterEach'
    }

    It 'Does not modify the variable before the first test' {
        $testVariable | Should Be 'Set in Describe'
    }

    It 'Modifies the variable after the first test' {
        $testVariable | Should Be 'Set in AfterEach'
    }
}

Describe 'Multiple teardown blocks' {
    $testVariable = 'Set in Describe'

    AfterEach {
        $testVariable = 'Set in Describe AfterEach'
    }

    Context 'The context' {
        AfterEach {
            $testVariable = 'Set in the first Context AfterEach'
        }

        It 'Performs a test in Context' { "some output to prevent the It being marked as Pending and failing because of Strict mode"}

        It 'Executes Describe teardown blocks after Context teardown blocks' {
            $testVariable | Should Be 'Set in the second Describe AfterEach'
        }
    }

    AfterEach {
        $testVariable = 'Set in the second Describe AfterEach'
    }
}
