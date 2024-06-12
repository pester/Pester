using namespace System.Management.Automation;

Describe 'Use class with custom attribute' {
    BeforeAll {
        class ValidateClassAttribute : ValidateArgumentsAttribute {

            ValidateClassAttribute () {} # without default ctor we fail in Profiler / Code Coverage https://github.com/nohwnd/Profiler/issues/63#issuecomment-1465181134
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
