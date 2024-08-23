function Should-ThrowAssertion {
    <#
    .SYNOPSIS
    Checks if an exception was thrown. Enclose input in a script block.

    Warning: The input object must be a ScriptBlock, otherwise it is processed outside of the assertion.

    .EXAMPLE
    { foo } | Should -Throw

    Because "foo" isn't a known command, PowerShell throws an error.
    Throw confirms that an error occurred, and successfully passes the test.

    .EXAMPLE
    { foo } | Should -Not -Throw

    By using -Not with -Throw, the opposite effect is achieved.
    "Should -Not -Throw" expects no error, but one occurs, and the test fails.

    .EXAMPLE
    { $foo = 1 } | Should -Throw

    Assigning a variable does not throw an error.
    If asserting "Should -Throw" but no error occurs, the test fails.

    .EXAMPLE
    { $foo = 1 } | Should -Not -Throw

    Assert that assigning a variable should not throw an error.
    It does not throw an error, so the test passes.
    #>
    param (
        $ActualValue,
        [string] $ExpectedMessage,
        [string] $ErrorId,
        [type] $ExceptionType,
        [switch] $Negate,
        [string] $Because,
        [switch] $PassThru
    )

    $actualExceptionMessage = ""
    $actualExceptionWasThrown = $false
    $actualError = $null
    $actualException = $null
    $actualExceptionLine = $null

    if ($null -eq $ActualValue -or $ActualValue -isnot [ScriptBlock]) {
        throw [ArgumentException] "Input is missing or not a ScriptBlock. Input to '-Throw' and '-Not -Throw' must be enclosed in curly braces."
    }

    try {
        do {
            Write-ScriptBlockInvocationHint -Hint "Should -Throw" -ScriptBlock $ActualValue
            $null = & $ActualValue
        } until ($true)
    }
    catch {
        $actualExceptionWasThrown = $true
        $actualError = $_
        $actualException = $_.Exception
        $actualExceptionMessage = $_.Exception.Message
        $actualErrorId = $_.FullyQualifiedErrorId
        $actualExceptionLine = (Get-ExceptionLineInfo $_.InvocationInfo) -replace [System.Environment]::NewLine, "$([System.Environment]::NewLine)    "
    }

    [bool] $succeeded = $false

    if ($Negate) {
        # this is for Should -Not -Throw. Once *any* exception was thrown we should fail the assertion
        # there is no point in filtering the exception, because there should be none
        $succeeded = -not $actualExceptionWasThrown
        if ($true -eq $succeeded) {
            return [Pester.ShouldResult]@{Succeeded = $succeeded }
        }

        $failureMessage = "Expected no exception to be thrown,$(Format-Because $Because) but an exception `"$actualExceptionMessage`" was thrown $actualExceptionLine."
        return [Pester.ShouldResult] @{
            Succeeded      = $succeeded
            FailureMessage = $failureMessage
        }
    }

    # the rest is for Should -Throw, we must fail the assertion when no exception is thrown
    # or when the exception does not match our filter

    $buts = @()
    $filters = @()

    $filterOnExceptionType = $null -ne $ExceptionType
    if ($filterOnExceptionType) {
        $filters += "type $(Format-Nicely $ExceptionType)"

        if ($actualExceptionWasThrown -and $actualException -isnot $ExceptionType) {
            $buts += "the exception type was $(Format-Nicely ($actualException.GetType()))"
        }
    }

    $filterOnMessage = -not [string]::IsNullOrWhitespace($ExpectedMessage)
    if ($filterOnMessage) {
        $unescapedExpectedMessage = [System.Management.Automation.WildcardPattern]::Unescape($ExpectedMessage)
        $filters += "message like $(Format-Nicely $unescapedExpectedMessage)"
        if ($actualExceptionWasThrown -and (-not (Get-DoValuesMatch $actualExceptionMessage $ExpectedMessage))) {
            $buts += "the message was $(Format-Nicely $actualExceptionMessage)"
        }
    }

    $filterOnId = -not [string]::IsNullOrWhitespace($ErrorId)
    if ($filterOnId) {
        $filters += "FullyQualifiedErrorId $(Format-Nicely $ErrorId)"
        if ($actualExceptionWasThrown -and (-not (Get-DoValuesMatch $actualErrorId $ErrorId))) {
            $buts += "the FullyQualifiedErrorId was $(Format-Nicely $actualErrorId)"
        }
    }

    if (-not $actualExceptionWasThrown) {
        $buts += 'no exception was thrown'
    }

    if ($buts.Count -ne 0) {
        $filter = Join-And $filters
        $but = Join-And $buts
        $failureMessage = "Expected an exception$(if($filter) { " with $filter" }) to be thrown,$(Format-Because $Because) but $but. $actualExceptionLine".Trim()

        $ActualValue = $actualExceptionMessage
        $ExpectedValue = if ($filterOnExceptionType) {
            "type $(Format-Nicely $ExceptionType)"
        }
        else {
            'any exception'
        }

        return [Pester.ShouldResult] @{
            Succeeded      = $false
            FailureMessage = $failureMessage
            ExpectResult   = @{
                Actual   = Format-Nicely $ActualValue
                Expected = Format-Nicely $ExpectedValue
                Because  = $Because
            }
        }
    }

    $result = [Pester.ShouldResult] @{
        Succeeded = $true
    }

    if ($PassThru) {
        $result | & $SafeCommands['Add-Member'] -MemberType NoteProperty -Name 'Data' -Value $actualError
    }

    return $result
}

function Get-DoValuesMatch($ActualValue, $ExpectedValue) {
    #user did not specify any message filter, so any message matches
    if ($null -eq $ExpectedValue) {
        return $true
    }

    return $ActualValue.ToString() -like $ExpectedValue
}

function Get-ExceptionLineInfo($info) {
    # $info.PositionMessage has a leading blank line that we need to account for in PowerShell 2.0
    $positionMessage = $info.PositionMessage -split '\r?\n' -match '\S' -join [System.Environment]::NewLine
    return ($positionMessage -replace "^At ", "from ")
}

function ShouldThrowFailureMessage {
    # to make the should tests happy, for now
}

function NotShouldThrowFailureMessage {
    # to make the should tests happy, for now
}

& $script:SafeCommands['Add-ShouldOperator'] -Name Throw `
    -InternalName Should-ThrowAssertion `
    -Test         ${function:Should-ThrowAssertion}

Set-ShouldOperatorHelpMessage -OperatorName Throw `
    -HelpMessage 'Checks if an exception was thrown. Enclose input in a scriptblock.'
