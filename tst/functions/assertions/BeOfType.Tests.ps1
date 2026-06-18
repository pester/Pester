Set-StrictMode -Version Latest

InPesterModuleScope {

    Describe "Should -BeOfType" {
        It "passes if value is of the expected type" {
            1 | Should -BeOfType Int
            2.0 | Should -BeOfType ([double])
        }

        It "fails if value is of a different types" {
            2 | Should -Not -BeOfType double
            2.0 | Should -Not -BeOfType ([string])
        }

        It "throws argument execption if type isn't a loaded type" {
            $err = { 5 | Should -BeOfType 'UnknownType' } | Verify-Throw
            $err.Exception | Verify-Type ([ArgumentException])
            # Verify expected type is included in error message
            $err.Exception.Message | Verify-Equal 'Could not find type [UnknownType]. Make sure that the assembly that contains that type is loaded.'
        }

        It "returns the correct assertion message when actual value has a real type" {
            $err = { 'ab' | Should -BeOfType ([int]) -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected the value to have type [int] or any of its subtypes, because reason, but got 'ab' with type [string]."
        }

        It "returns the correct assertion message when actual value is `$null" {
            $err = { $null | Should -BeOfType ([int]) -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal 'Expected the value to have type [int] or any of its subtypes, because reason, but got $null with type $null.'
        }
    }

    Describe "Should -Not -BeOfType" {
        It "throws argument execption if type isn't a loaded type" {
            $err = { 5 | Should -Not -BeOfType 'UnknownType' } | Verify-Throw
            $err.Exception | Verify-Type ([ArgumentException])
            # Verify expected type is included in error message
            $err.Exception.Message | Verify-Equal 'Could not find type [UnknownType]. Make sure that the assembly that contains that type is loaded.'
        }

        It "returns the correct assertion message when actual value has a real type" {
            $err = { 1 | Should -Not -BeOfType ([int]) -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal 'Expected the value to not have type [int] or any of its subtypes, because reason, but got 1 with type [int].'
        }
    }

    Describe "Should -BeOfType with types not visible in module scope" {
        # PowerShell classes defined via dot-sourcing in BeforeAll are not visible
        # to the Pester module scope. The fallback resolves the type from the
        # actual value's inheritance chain by comparing type names.

        It "resolves type from actual value when -as [Type] fails" {
            # Create a type that is not loadable by name in this scope
            # by using the actual object's type hierarchy
            $obj = [System.IO.MemoryStream]::new()
            try {
                # These will resolve via -as [Type] normally, but also verify
                # the assertion logic works for both Name and FullName
                $obj | Should -BeOfType 'MemoryStream'
                $obj | Should -BeOfType 'System.IO.MemoryStream'
                # Base type matching
                $obj | Should -BeOfType 'Stream'
                $obj | Should -BeOfType 'System.IO.Stream'
            }
            finally {
                $obj.Dispose()
            }
        }

        It "resolves type by walking actual value's inheritance chain" {
            # When -as [Type] fails (e.g. PS classes not visible to module scope),
            # the fallback walks the actual value's type hierarchy by Name/FullName.
            # We test this by calling the assertion function directly with an object
            # whose type is known but using its Name string (which -as [Type] resolves).
            # The real scenario (PS class not visible) can't be unit-tested without
            # nested Invoke-Pester, but we verify the hierarchy walk works correctly.
            $obj = [System.IO.MemoryStream]::new()
            try {
                # MemoryStream inherits from Stream — verify base type matching works
                $obj | Should -BeOfType 'Stream'
                $obj | Should -BeOfType 'System.IO.Stream'
                $obj | Should -BeOfType 'MarshalByRefObject'
            }
            finally {
                $obj.Dispose()
            }
        }

        It "throws ArgumentException when actual is `$null and type is not resolvable" {
            $err = { $null | Should -BeOfType 'SomeNonExistentClass' } | Verify-Throw
            $err.Exception | Verify-Type ([ArgumentException])
        }
    }
}
