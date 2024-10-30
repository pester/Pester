function Should-All {
    <#
    .SYNOPSIS
    Compares all items in a collection to a filter script. If the filter returns true, or does not throw for all the items in the collection, the assertion passes.

    .PARAMETER FilterScript
    A script block that filters the input collection. The script block can use Should-* assertions or throw exceptions to indicate failure.

    .PARAMETER Actual
    A collection of items to filter.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    1, 2, 3 | Should-All { $_ -gt 0 }
    1, 2, 3 | Should-All { $_ | Should-BeGreaterThan 0 }
    ```

    This assertion will pass, because all items pass the filter.

    .EXAMPLE
    ```powershell
    1, 2, 3 | Should-All { $_ -gt 1 }
    1, 2, 3 | Should-All { $_ | Should-BeGreaterThan 1 }
    ```

    The assertions will fail because not all items in the array are greater than 1.

    .LINK
    https://pester.dev/docs/commands/Should-All

    .LINK
    https://pester.dev/docs/assertions

    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, Position = 1)]
        $Actual,
        [Parameter(Position = 0, Mandatory)]
        [scriptblock]$FilterScript,
        [String]$Because
    )

    Assert-BoundScriptBlockInput -ScriptBlock $FilterScript

    $Expected = $FilterScript
    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput
    $Actual = $collectedInput.Actual

    if ($null -eq $Actual -or 0 -eq @($Actual).Count) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Data $data -Because $Because -DefaultMessage "Expected all items in collection to pass filter <expected>, but <actualType> <actual> contains no items to compare."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }

    $failReasons = $null
    $appendMore = $false
    # we are jumping between modules so I need to explicitly pass the _ variable
    # simply using '&' won't work
    # see: https://blogs.msdn.microsoft.com/sergey_babkins_blog/2014/10/30/calling-the-script-blocks-in-powershell/
    $actualFiltered = foreach ($item in $Actual) {
        $underscore = [PSVariable]::new('_', $item)
        try {
            $pass = $FilterScript.InvokeWithContext($null, $underscore, $null)
        }
        catch {
            if ($null -eq $failReasons) {
                $failReasons = [System.Collections.Generic.List[string]]::new(10)
            }
            if ($failReasons.Count -lt 10) {
                $failReasons.Add($_.Exception.InnerException.Message)
            }
            else {
                $appendMore = $true
            }

            $pass = @($false)
        }

        # The API returns a collection and user can return anything from their script
        # or there can be no output when assertion is used, so we are checking if the first item
        # in the output is a boolean $false. The scriptblock should not fail in $null for example,
        # hence the explicit type check
        if (($pass.Count -ge 1) -and ($pass[0] -is [bool]) -and ($false -eq $pass[0])) {
            $item
        }
    }

    # Make sure are checking the count of the filtered items, not just truthiness of a single item.
    $actualFiltered = @($actualFiltered)
    if (0 -lt $actualFiltered.Count) {
        $data = @{
            actualFiltered      = if (1 -eq $actualFiltered.Count) { $actualFiltered[0] } else { $actualFiltered }
            actualFilteredCount = $actualFiltered.Count
        }

        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Data $data -Because $Because -DefaultMessage "Expected all items in collection <actual> to pass filter <expected>, but <actualFilteredCount> of them <actualFiltered> did not pass the filter."
        if ($null -ne $failReasons) {
            $failReasons = $failReasons -join "`n"
            if ($appendMore) {
                $failReasons += "`nand more..."
            }
            $Message += "`nReasons :`n$failReasons"
        }
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
