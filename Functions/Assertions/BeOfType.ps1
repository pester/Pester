
function Should-BeOfType($ActualValue, $ExpectedType, [switch] $Negate, [string]$Because) {
    <#
.SYNOPSIS
Asserts that the actual value should be an object of a specified type
(or a subclass of the specified type) using PowerShell's -is operator.

.EXAMPLE
$actual = Get-Item $env:SystemRoot
PS C:\>$actual | Should -BeOfType System.IO.DirectoryInfo

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
        $parsedType = ($ExpectedType -replace '^\[(.*)\]$', '$1') -as [Type]
        if ($null -eq $parsedType) {
            throw [ArgumentException]"Could not find type [$ParsedType]. Make sure that the assembly that contains that type is loaded."
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

    if (-not $succeded) {
        if ($Negate) {
            $failureMessage = "Expected the value to not have type $(Format-Nicely $ExpectedType) or any of its subtypes,$(Format-Because $Because) but got $(Format-Nicely $ActualValue) with type $(Format-Nicely $actualType)."
        }
        else {
            $failureMessage = "Expected the value to have type $(Format-Nicely $ExpectedType) or any of its subtypes,$(Format-Because $Because) but got $(Format-Nicely $ActualValue) with type $(Format-Nicely $actualType)."
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeded
        FailureMessage = $failureMessage
    }
}


Add-AssertionOperator -Name         BeOfType `
    -InternalName Should-BeOfType `
    -Test         ${function:Should-BeOfType} `
    -Alias        'HaveType'

function ShouldBeOfTypeFailureMessage() {
}

function NotShouldBeOfTypeFailureMessage() {
}
