﻿function Verify-Equal {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Mandatory = $true, Position = 0)]
        $Expected
    )
    END {
        if ($Expected -ne $Actual) {
            $message = "Expected and actual values differ!`n" +
            "Expected: '$Expected'`n" +
            "Actual  : '$Actual'"
            if ($Expected -is [string] -and $Actual -is [string]) {
                $message += "`nExpected length: $($Expected.Length)`nActual length: $($Actual.Length)"
            }
            $message += "`n$($PSCmdlet.MyInvocation.PositionMessage)"
            throw [Exception]$message
        }

        $Actual
    }
}
