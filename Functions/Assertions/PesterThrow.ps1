function PesterThrow([scriptblock] $ActualValue, $ExpectedMessage, $ErrorId, [switch] $Negate) {
    $script:ActualExceptionMessage = ""
    $script:ActualExceptionWasThrown = $false

    if ($null -eq $ActualValue) {
        throw (New-Object -TypeName ArgumentNullException -ArgumentList "ActualValue","Scriptblock not found. Input to 'Throw' and 'Not Throw' must be enclosed in curly braces.")
    }

    # This is superfluous, here for now.
    $ExpectedErrorId = $ErrorId

    try {
        do {
            $null = & $ActualValue
        } until ($true)
    } catch {
        $script:ActualExceptionWasThrown = $true
        $script:ActualExceptionMessage = $_.Exception.Message
        $script:ActualErrorId = $_.FullyQualifiedErrorId
        $script:ActualExceptionLine = Get-ExceptionLineInfo $_.InvocationInfo
    }

    [bool] $succeeded = $false

    if ($ActualExceptionWasThrown) {
        $succeeded = (Get-DoValuesMatch $script:ActualExceptionMessage $ExpectedMessage) -and
                     (Get-DoValuesMatch $script:ActualErrorId $ExpectedErrorId)
    }

    if ($Negate) { $succeeded = -not $succeeded }

    $failureMessage = ''

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = NotPesterThrowFailureMessage -ActualValue $ActualValue -ExpectedMessage $ExpectedMessage -ExpectedErrorId $ExpectedErrorId
        }
        else
        {
            $failureMessage = PesterThrowFailureMessage -ActualValue $ActualValue -ExpectedMessage $ExpectedMessage -ExpectedErrorId $ExpectedErrorId
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function Get-DoValuesMatch($ActualValue, $ExpectedValue) {
    #user did not specify any message filter, so any message matches
    if ($null -eq $ExpectedValue ) { return $true }

    return $ActualValue.ToString().IndexOf($ExpectedValue, [System.StringComparison]::InvariantCultureIgnoreCase) -ge 0
}

function Get-ExceptionLineInfo($info) {
    # $info.PositionMessage has a leading blank line that we need to account for in PowerShell 2.0
    $positionMessage = $info.PositionMessage -split "$([System.Environment]::NewLine)" -match '\S' -join "$([System.Environment]::NewLine)"
    return ($positionMessage -replace "^At ","from ")
}

function PesterThrowFailureMessage($ActualValue, $ExpectedMessage, $ExpectedErrorId) {
    $StringBuilder = Microsoft.PowerShell.Utility\New-Object System.Text.StringBuilder
    $null = $StringBuilder.Append('Expected: the expression to throw an exception')

    if ($ExpectedMessage -or $ExpectedErrorId)
    {
        $null = $StringBuilder.Append(' with ')
        $Expected = switch ($null)
        {
            { $ExpectedMessage } { 'message {{{0}}}' -f $ExpectedMessage }
            { $ExpectedErrorId } { 'error id {{{0}}}' -f $ExpectedErrorId }
        }
        $Actual = switch ($null)
        {
            { $ExpectedMessage } { 'message was {{{0}}}' -f $ActualExceptionMessage }
            { $ExpectedErrorId } { 'error id was {{{0}}}' -f $ActualErrorId }
        }
        $null = $StringBuilder.Append(("{0}, an exception was {1}raised, {2}$([System.Environment]::NewLine)    {3}" -f
            ($Expected -join ' and '),
            @{$true="";$false="not "}[$ActualExceptionWasThrown],
            ($Actual -join ' and '),
            ($ActualExceptionLine  -replace "$([System.Environment]::NewLine)","$([System.Environment]::NewLine)    ")
        ))
    }

    return $StringBuilder.ToString()
}

function NotPesterThrowFailureMessage($ActualValue, $ExpectedMessage, $ExpectedErrorId) {
    $StringBuilder = New-Object System.Text.StringBuilder
    $null = $StringBuilder.Append('Expected: the expression not to throw an exception')

    if ($ExpectedMessage -or $ExpectedErrorId)
    {
        $null = $StringBuilder.Append(' with ')
        $Expected = switch ($null)
        {
            { $ExpectedMessage } { 'message {{{0}}}' -f $ExpectedMessage }
            { $ExpectedErrorId } { 'error id {{{0}}}' -f $ExpectedErrorId }
        }
        $Actual = switch ($null)
        {
            { $ExpectedMessage } { 'message was {{{0}}}' -f $ActualExceptionMessage }
            { $ExpectedErrorId } { 'error id was {{{0}}}' -f $ActualErrorId }
        }
        $null = $StringBuilder.Append(("{0}, an exception was {1}raised, {2}$([System.Environment]::NewLine)    {3}" -f
            ($Expected -join ' and '),
            (@{$true="";$false="not "}[$ActualExceptionWasThrown]),
            ($Actual -join ' and '),
            ($ActualExceptionLine  -replace "$([System.Environment]::NewLine)","$([System.Environment]::NewLine)    ")
        ))
    }
    else
    {
      $null = $StringBuilder.Append((". Message was {{{0}}}$([System.Environment]::NewLine)    {1}" -f $ActualExceptionMessage, ($ActualExceptionLine -replace "$([System.Environment]::NewLine)","$([System.Environment]::NewLine)    ")))
    }

    return $StringBuilder.ToString()
}

Add-AssertionOperator -Name Throw `
                      -Test $function:PesterThrow
