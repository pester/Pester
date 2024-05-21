
function Should-BeOfTypeAssertion($ActualValue, $ExpectedType, [switch] $Negate, [string]$Because) {
    <#
    .SYNOPSIS
    Asserts that the actual value should be an object of a specified type
    (or a subclass of the specified type) using PowerShell's -is operator.

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
    #>
    if ($ExpectedType -is [string]) {
        # parses type that is provided as a string in brackets (such as [int])
        $trimmedType = $ExpectedType -replace '^\[(.*)\]$', '$1'
        $parsedType = $trimmedType -as [Type]
        if ($null -eq $parsedType) {
            throw [ArgumentException]"Could not find type [$trimmedType]. Make sure that the assembly that contains that type is loaded."
        }

        $ExpectedType = $parsedType
    }

    $succeded = $ActualValue -is $ExpectedType
    if ($Negate) {
        $succeded = -not $succeded
    }

    $failureMessage = ''

    if ($null -ne $ActualValue) {
        $actualType = $ActualValue.GetType()
    }
    else {
        $actualType = $null
    }

    if ($true -eq $succeeded) { return [Pester.ShouldResult]@{Succeeded = $succeeded } }


    if ($Negate) {
        $failureMessage = "Expected the value to not have type $(Format-Nicely $ExpectedType) or any of its subtypes,$(Format-Because $Because) but got $(Format-Nicely $ActualValue) with type $(Format-Nicely $actualType)."
    }
    else {
        $failureMessage = "Expected the value to have type $(Format-Nicely $ExpectedType) or any of its subtypes,$(Format-Because $Because) but got $(Format-Nicely $ActualValue) with type $(Format-Nicely $actualType)."
    }

    $ExpectedValue = if ($Negate) { "not $(Format-Nicely $ExpectedType) or any of its subtypes" } else { "a $(Format-Nicely $ExpectedType) or any of its subtypes" }

    return [Pester.ShouldResult] @{
        Succeeded      = $succeded
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

function ShouldBeOfTypeFailureMessage() {
}

function NotShouldBeOfTypeFailureMessage() {
}
