
function Should-BeOfTypeAssertion($ActualValue, $ExpectedType, [switch] $Negate, [string]$Because) {
    <#
    .SYNOPSIS
    Asserts that the actual value should be an object of a specified type
    (or a subclass of the specified type) using PowerShell's -is operator.
    Expected type can be provided using full type name strings or a type wrapped in parentheses.

    When the expected type name does not resolve to a loaded .NET type, the assertion falls
    back to matching against the actual value's PSTypeNames. This allows asserting against
    PowerShell custom types, such as objects tagged with a PSTypeName or extended with
    Add-Member -TypeName.

    .EXAMPLE
    $actual = Get-Item $env:SystemRoot
    $actual | Should -BeOfType System.IO.DirectoryInfo

    This test passes, as $actual is a DirectoryInfo object.

    .EXAMPLE
    $actual | Should -BeOfType System.IO.FileSystemInfo

    This test passes, as DirectoryInfo's base class is FileSystemInfo.

    .EXAMPLE
    $actual | Should -HaveType System.IO.FileSystemInfo

    This test passes for the same reason, but uses the -HaveType alias instead.

    .EXAMPLE
    $actual | Should -BeOfType System.IO.FileInfo

    This test will fail, as FileInfo is not a base class of DirectoryInfo.

    .EXAMPLE
    $actual | Should -BeOfType ([System.IO.DirectoryInfo])

    Test using a type-object. Remember to use parentheses for consistent behavior with PowerShell classes.

    .EXAMPLE
    $actual = [PSCustomObject]@{ PSTypeName = 'MyApp.Person'; Name = 'Jane' }
    $actual | Should -BeOfType 'MyApp.Person'

    This test passes, because 'MyApp.Person' is not a loaded .NET type, so the assertion
    checks the actual value's PSTypeNames instead.
    #>

    # When the expected type is given as a name that does not resolve to a loaded .NET type,
    # we fall back to matching the actual value's type names instead of using the -is operator.
    $isNameCheck = $false
    $expectedName = $null

    if ($ExpectedType -is [string]) {
        # parses type that is provided as a string in brackets (such as [int])
        $trimmedType = $ExpectedType -replace '^\[(.*)\]$', '$1'
        $parsedType = $trimmedType -as [Type]
        if ($null -eq $parsedType) {
            # The expected type name does not resolve to a loaded .NET type. Instead of
            # throwing, match it against the actual value's type names (#1315):
            #  - PowerShell custom types exposed through PSTypeNames (e.g. a [PSCustomObject]
            #    tagged with a PSTypeName, or Add-Member -TypeName 'MyType'), and
            #  - the actual value's inheritance chain by short Name/FullName, which also
            #    covers PowerShell classes that are not visible in the module scope (#2701).
            $isNameCheck = $true
            $expectedName = $trimmedType
        }
        else {
            $ExpectedType = $parsedType
        }
    }

    if ($isNameCheck) {
        $succeeded = $false
        if ($null -ne $ActualValue) {
            if ($ActualValue.PSTypeNames -contains $expectedName) {
                $succeeded = $true
            }
            else {
                $t = $ActualValue.GetType()
                while ($null -ne $t) {
                    if ($t.Name -eq $expectedName -or $t.FullName -eq $expectedName) {
                        $succeeded = $true
                        break
                    }
                    $t = $t.BaseType
                }
            }
        }
    }
    else {
        $succeeded = $ActualValue -is $ExpectedType
    }

    if ($Negate) {
        $succeeded = -not $succeeded
    }

    $failureMessage = ''

    if ($null -ne $ActualValue) {
        $actualType = $ActualValue.GetType()
    }
    else {
        $actualType = $null
    }

    if ($true -eq $succeeded) { return [Pester.ShouldResult]@{Succeeded = $succeeded } }

    if ($isNameCheck) {
        if ($null -ne $ActualValue) {
            $actualTypeNames = ($ActualValue.PSTypeNames -replace '^(.*)$', '[$1]') -join ', '
        }
        else {
            $actualTypeNames = Format-Nicely $null
        }

        if ($Negate) {
            $failureMessage = "Expected the value to not have type or PSTypeName [$expectedName],$(Format-Because $Because) but got $(Format-Nicely $ActualValue) with type $(Format-Nicely $actualType) and PSTypeNames $actualTypeNames."
        }
        else {
            $failureMessage = "Expected the value to have type or PSTypeName [$expectedName],$(Format-Because $Because) but got $(Format-Nicely $ActualValue) with type $(Format-Nicely $actualType) and PSTypeNames $actualTypeNames."
        }

        $ExpectedValue = if ($Negate) { "not type or PSTypeName [$expectedName]" } else { "type or PSTypeName [$expectedName]" }

        return [Pester.ShouldResult] @{
            Succeeded      = $succeeded
            FailureMessage = $failureMessage
            ExpectResult   = @{
                Actual   = Format-Nicely $ActualValue
                Expected = Format-Nicely $ExpectedValue
                Because  = $Because
            }
        }
    }

    if ($Negate) {
        $failureMessage = "Expected the value to not have type $(Format-Nicely $ExpectedType) or any of its subtypes,$(Format-Because $Because) but got $(Format-Nicely $ActualValue) with type $(Format-Nicely $actualType)."
    }
    else {
        $failureMessage = "Expected the value to have type $(Format-Nicely $ExpectedType) or any of its subtypes,$(Format-Because $Because) but got $(Format-Nicely $ActualValue) with type $(Format-Nicely $actualType)."
    }

    $ExpectedValue = if ($Negate) { "not $(Format-Nicely $ExpectedType) or any of its subtypes" } else { "a $(Format-Nicely $ExpectedType) or any of its subtypes" }

    return [Pester.ShouldResult] @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
        ExpectResult   = @{
            Actual   = Format-Nicely $ActualValue
            Expected = Format-Nicely $ExpectedValue
            Because  = $Because
        }
    }
}

& $script:SafeCommands['Add-ShouldOperator'] -Name BeOfType `
    -InternalName Should-BeOfTypeAssertion `
    -Test         ${function:Should-BeOfTypeAssertion} `
    -Alias        'HaveType'

Set-ShouldOperatorHelpMessage -OperatorName BeOfType `
    -HelpMessage "Asserts that the actual value should be an object of a specified type (or a subclass of the specified type) using PowerShell's -is operator."

