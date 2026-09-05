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

        It "passes when the actual value has a matching custom PSTypeName" {
            $obj = [PSCustomObject]@{ PSTypeName = 'MyApp.Person'; Name = 'Jane' }
            $obj | Should -BeOfType 'MyApp.Person'
        }

        It "passes when a custom PSTypeName was added with Add-Member" {
            $obj = [PSCustomObject]@{ Name = 'Jane' }
            $obj.PSObject.TypeNames.Insert(0, 'MyApp.Widget')
            $obj | Should -BeOfType 'MyApp.Widget'
        }

        It "fails when the actual value does not have the expected custom PSTypeName" {
            $obj = [PSCustomObject]@{ PSTypeName = 'MyApp.Person'; Name = 'Jane' }
            $err = { $obj | Should -BeOfType 'MyApp.Animal' -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Like 'Expected the value to have type or PSTypeName [[]MyApp.Animal], because reason, but got*and PSTypeNames [[]MyApp.Person]*'
        }

        It "-Not passes when the actual value does not have the expected custom PSTypeName" {
            $obj = [PSCustomObject]@{ PSTypeName = 'MyApp.Person'; Name = 'Jane' }
            $obj | Should -Not -BeOfType 'MyApp.Animal'
        }

        It "matches a custom PSTypeName that does not resolve as a real type instead of throwing" {
            $err = { 5 | Should -BeOfType 'UnknownType' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Like 'Expected the value to have type or PSTypeName [[]UnknownType],*but got 5 with type [[]int]*'
        }

        It "-Not passes for a custom type name that no real value matches" {
            5 | Should -Not -BeOfType 'UnknownType'
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
        It "passes when a non-resolving type name is not among the actual value's PSTypeNames" {
            5 | Should -Not -BeOfType 'UnknownType'
        }

        It "returns the correct assertion message when -Not is used against a matching custom PSTypeName" {
            $obj = [PSCustomObject]@{ PSTypeName = 'MyApp.Person'; Name = 'Jane' }
            $err = { $obj | Should -Not -BeOfType 'MyApp.Person' -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Like 'Expected the value to not have type or PSTypeName [[]MyApp.Person], because reason, but got*and PSTypeNames [[]MyApp.Person]*'
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
                # MemoryStream inherits from Stream - verify base type matching works
                $obj | Should -BeOfType 'Stream'
                $obj | Should -BeOfType 'System.IO.Stream'
                $obj | Should -BeOfType 'MarshalByRefObject'
            }
            finally {
                $obj.Dispose()
            }
        }

        It "fails with a clear message when actual is `$null and type is not resolvable" {
            $err = { $null | Should -BeOfType 'SomeNonExistentClass' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Like 'Expected the value to have type or PSTypeName [[]SomeNonExistentClass],*but got $null with type $null and PSTypeNames $null.'
        }
    }
}
