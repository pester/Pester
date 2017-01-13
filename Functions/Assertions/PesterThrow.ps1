
$ActualExceptionMessage = ""
$ActualExceptionWasThrown = $false

# because this is a script block, the user will have to
# wrap the code they want to assert on in { }
function PesterThrow([scriptblock] $script, $expectedErrorMessage) {

    if ($null -eq $script) {
        throw (New-Object -TypeName ArgumentNullException -ArgumentList "script","Scriptblock not found. Input to 'Throw' and 'Not Throw' must be enclosed in curly braces.")
    }

    $Script:ActualExceptionMessage = ""
    $Script:ActualExceptionWasThrown = $false

    try {
        # Assign to $null so script output does not enter the pipeline
        # Script block is dot-sourced so callers may do things like this:
        # { $result = Do-Something } | Should Not Throw
        # $result | Should Be 'Successful output test'

        $null = . $script
    } catch {
        $Script:ActualExceptionWasThrown = $true
        $Script:ActualExceptionMessage = $_.Exception.Message
        $Script:ActualExceptionLine = Get-ExceptionLineInfo $_.InvocationInfo
    }

    if ($ActualExceptionWasThrown) {
        return Get-DoMessagesMatch $ActualExceptionMessage $expectedErrorMessage
    }
    return $false
}

function Get-DoMessagesMatch($value, $expected) {
    if ($expected -eq "") { return $false }
    return $value.Contains($expected)
}

function Get-ExceptionLineInfo($info) {
    # $info.PositionMessage has a leading blank line that we need to account for in PowerShell 2.0
    $positionMessage = $info.PositionMessage -split '\r?\n' -match '\S' -join "`r`n"
    return ($positionMessage -replace "^At ","from ")
}

function PesterThrowFailureMessage($value, $expected) {
    if ($expected) {
        return "Expected: the expression to throw an exception with message {{{0}}}, an exception was {2}raised, message was {{{1}}}`n    {3}" -f
               $expected, $ActualExceptionMessage,(@{$true="";$false="not "}[$ActualExceptionWasThrown]),($ActualExceptionLine  -replace "`n","`n    ")
    } else {
      return "Expected: the expression to throw an exception"
    }
}

function NotPesterThrowFailureMessage($value, $expected) {
    if ($expected) {
        return "Expected: the expression not to throw an exception with message {{{0}}}, an exception was {2}raised, message was {{{1}}}`n    {3}" -f
               $expected, $ActualExceptionMessage,(@{$true="";$false="not "}[$ActualExceptionWasThrown]),($ActualExceptionLine  -replace "`n","`n    ")
    } else {
        return "Expected: the expression not to throw an exception. Message was {{{0}}}`n    {1}" -f $ActualExceptionMessage,($ActualExceptionLine  -replace "`n","`n    ")
    }
}
