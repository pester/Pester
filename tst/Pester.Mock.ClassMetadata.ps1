using namespace System.Management.Automation;

Describe 'Use class with custom attribute' {
    BeforeAll {
        class ValidateClassAttribute : ValidateArgumentsAttribute {
            [void] Validate([object]$arguments, [EngineIntrinsics]$engineIntrinsics) {

            }
        }
        function Test-Foo {
            param([ValidateClass()]
                $Test)

            $Test
        }

    }

    It 'should be able to mock Test-Foo' {
        # without resolving the metadata in the correct scope this would throw because
        # ValidateClassAttribute would be missing
        Mock Test-Foo
        Test-Foo
        Should -Invoke Test-Foo
    }

    It 'should be able to run Test-Foo' {
        Test-Foo -Test 'Foo'
    }
}
