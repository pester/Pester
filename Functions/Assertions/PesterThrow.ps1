function PesterThrow([scriptblock] $ActualValue, $ExpectedMessage, $ErrorId, [type]$ExceptionType, [switch] $Negate, [string] $Because, [switch] $PassThru) {
    $actualExceptionMessage = ""
    $actualExceptionWasThrown = $false
    $actualError = $null
    $actualException = $null
    $actualExceptionLine = $null

    if ($null -eq $ActualValue) {
        throw (New-Object -TypeName ArgumentNullException -ArgumentList "ActualValue","Scriptblock not found. Input to 'Throw' and 'Not Throw' must be enclosed in curly braces.")
    }

    try {
        do {
            $null = & $ActualValue
        } until ($true)
    } catch {
        $actualExceptionWasThrown = $true
        $actualError = $_
        $actualException = $_.Exception
        $actualExceptionMessage = $_.Exception.Message
        $actualErrorId = $_.FullyQualifiedErrorId
        $actualExceptionLine = (Get-ExceptionLineInfo $_.InvocationInfo) -replace [System.Environment]::NewLine,"$([System.Environment]::NewLine)    "
    }

    [bool] $succeeded = $false

    if ($Negate) {
        # this is for Should -Not -Throw. Once *any* exception was thrown we should fail the assertion
        # there is no point in filtering the exception, because there should be none
        $succeeded = -not $actualExceptionWasThrown
        if (-not $succeeded) {
            $failureMessage = "Expected no exception to be thrown,$(Format-Because $Because) but an exception `"$actualExceptionMessage`" was thrown $actualExceptionLine."
            return New-Object psobject -Property @{
                Succeeded      = $succeeded
                FailureMessage = $failureMessage
            }
        } else {
            return New-Object psobject -Property @{
                Succeeded      = $true
            }
        }
    }

    # the rest is for Should -Throw, we must fail the assertion when no exception is thrown
    # or when the exception does not match our filter

    function Join-And ($Items, $Threshold=2) {

        if ($null -eq $items -or $items.count -lt $Threshold)
        {
            $items -join ', '
        }
        else
        {
            $c = $items.count
            ($items[0..($c-2)] -join ', ') + ' and ' + $items[-1]
        }
    }

    function Add-SpaceToNonEmptyString ([string]$Value) {
        if ($Value)
        {
            " $Value"
        }
    }

    $buts = @()
    $filters = @()

    $filterOnExceptionType = $null -ne $ExceptionType
    if ($filterOnExceptionType) {
        $filters += "with type $(Format-Nicely $ExceptionType)"

        if ($actualExceptionWasThrown -and $actualException -isnot $ExceptionType) {
            $buts += "the exception type was $(Format-Nicely ($actualException.GetType()))"
        }
    }

    $filterOnMessage = -not [string]::IsNullOrEmpty($ExpectedMessage -replace "\s")
    if ($filterOnMessage) {
        $filters += "with message $(Format-Nicely $ExpectedMessage)"
        if ($actualExceptionWasThrown -and (-not (Get-DoValuesMatch $actualExceptionMessage $ExpectedMessage))) {
            $buts += "the message was $(Format-Nicely $actualExceptionMessage)"
        }
    }

    $filterOnId = -not [string]::IsNullOrEmpty($ErrorId -replace "\s")
    if ($filterOnId) {
        $filters += "with FullyQualifiedErrorId $(Format-Nicely $ErrorId)"
        if ($actualExceptionWasThrown -and (-not (Get-DoValuesMatch $actualErrorId $ErrorId))) {
            $buts += "the FullyQualifiedErrorId was $(Format-Nicely $actualErrorId)"
        }
    }

    if (-not $actualExceptionWasThrown)
    {
        $buts += "no exception was thrown"
    }

    if ($buts.Count -ne 0) {
        $filter = Add-SpaceToNonEmptyString ( Join-And $filters -Threshold 3 )
        $but = Join-And $buts
        $failureMessage = "Expected an exception,$filter to be thrown,$(Format-Because $Because) but $but. $actualExceptionLine".Trim()

        return New-Object psobject -Property @{
            Succeeded      = $false
            FailureMessage = $failureMessage
        }
    }

    $result = New-Object psobject -Property @{
        Succeeded      = $true
    }

    if ($PassThru) {
        $result | Add-Member -MemberType NoteProperty -Name 'Data' -Value $actualError
    }

    return $result
}

function Get-DoValuesMatch($ActualValue, $ExpectedValue) {
    #user did not specify any message filter, so any message matches
    if ($null -eq $ExpectedValue ) { return $true }

    return $ActualValue.ToString().IndexOf($ExpectedValue, [System.StringComparison]::InvariantCultureIgnoreCase) -ge 0
}

function Get-ExceptionLineInfo($info) {
    # $info.PositionMessage has a leading blank line that we need to account for in PowerShell 2.0
    $positionMessage = $info.PositionMessage -split '\r?\n' -match '\S' -join [System.Environment]::NewLine
    return ($positionMessage -replace "^At ","from ")
}

function PesterThrowFailureMessage {
    # to make the should tests happy, for now
}

function NotPesterThrowFailureMessage {
    # to make the should tests happy, for now
}

Add-AssertionOperator -Name Throw `
                      -Test $function:PesterThrow
