function Should-HaveParameter($ActualValue, [String]$ParameterName, $OfType, [String]$Default, [Switch]$IsMandatory, [Switch]$HasArgumentCompleter, [Switch]$Negate, [String]$Because ) {
    <#
    .SYNOPSIS
        Asserts that a collection has the expected amount of items.

    .EXAMPLE
        1,2,3 | Should -HaveCount 3
        This test passes, because it expected three objects, and received three.
        This is like running `@(1,2,3).Count` in PowerShell.
    #>

    if ($null -eq $ActualValue -or $ActualValue -isnot [Management.Automation.CommandInfo]) {
        throw "Input value must be non-null CommandInfo object. You can get one by calling Get-Command."
    }

    if ($null -eq $ParameterName) {
        throw "The ParameterName can't be empty"
    }

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

    if ($OfType -is [string]) {
        # parses type that is provided as a string in brackets (such as [int])
        $parsedType = ($OfType -replace '^\[(.*)\]$', '$1') -as [Type]
        if ($null -eq $parsedType) {
            throw [ArgumentException]"Could not find type [$ParsedType]. Make sure that the assembly that contains that type is loaded."
        }

        $OfType = $parsedType
    }

    $buts = @()
    $filters = @()

    $hasKey = $ActualValue.Parameters.ContainsKey($ParameterName)
    $filters += "to$(if ($Negate) {" not"}) have a parameter $ParameterName"

    if (-not $Negate -and -not $hasKey) {
        $buts += "the parameter is missing"
    }
    elseif ($Negate -and -not $hasKey) {
        return [PSCustomObject]@{ Succeeded = $true }
    }
    elseif ($Negate -and $hasKey -and -not ($IsMandatory -or $OfType -or $Default -or $HasArgumentCompleter)) {
        $buts += "the parameter exists"
    }
    else {
        $attributes = $ActualValue.Parameters[$ParameterName].Attributes

        if ($IsMandatory) {
            $testMandatory = $attributes | Where-Object { $_.Mandatory }
            $filters += "which is$(if ($Negate) {" not"}) mandatory"

            if (-not $Negate -and -not $testMandatory) {
                $buts += "it wasn't mandatory"
            }
            elseif ($Negate -and $testMandatory) {
                $buts += "it was mandatory"
            }
        }

        if ($OfType) {
            $actualType = $ActualValue.Parameters[$ParameterName].ParameterType
            $testOfType = ($OfType.FullName -match [Regex]::Escape($actualType)) -or ([Regex]::Escape($OfType.Name) -match [Regex]::Escape($actualType))
            $filters += "$(if ($Negate) {"not "})of type $(Format-Nicely $OfType)"

            if (-not $Negate -and -not $testOfType) {
                $buts += "it was of type $(Format-Nicely $actualType)"
            }
            elseif ($Negate -and $testOfType) {
                $buts += "it was of type $(Format-Nicely $OfType)"
            }
        }

        if ($Default) {
            $parameterMetadata = $ActualValue.ScriptBlock.Ast.Body.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq $ParameterName }
            $actualDefault = $parameterMetadata.DefaultValue.Extent -replace "^`"(.*)`"$", "`$1"
            $testDefault = ($actualDefault.ToString() -eq $Default)
            $filters += "the default value$(if ($Negate) {" not"}) to be $(Format-Nicely $Default)"

            if (-not $Negate -and -not $testDefault) {
                $buts += "the default value was $(Format-Nicely $actualDefault)"
            }
            elseif ($Negate -and $testDefault) {
                $buts += "the default value was $(Format-Nicely $Default)"
            }
        }

        if ($HasArgumentCompleter) {
            $testArgumentCompleter = $attributes | Where-Object {$_ -is [ArgumentCompleter]}
            $filters += "has ArgumentCompletion"

            if (-not $Negate -and -not $testArgumentCompleter) {
                $buts += "has no ArgumentCompletion"
            }
            elseif ($Negate -and $testArgumentCompleter) {
                $buts += "has ArgumentCompletion"
            }
        }
    }

    if ($buts.Count -ne 0) {
        $filter = Add-SpaceToNonEmptyString ( Join-And $filters -Threshold 3 )
        $but = Join-And $buts
        $failureMessage = "Expected command $($ActualValue.Name)$filter,$(Format-Because $Because) but $but."

        return [PSCustomObject]@{
            Succeeded      = $false
            FailureMessage = $failureMessage
        }
    }
    else {
        return [PSCustomObject]@{ Succeeded = $true }
    }
}

Add-AssertionOperator -Name         HaveParameter `
                      -InternalName Should-HaveParameter `
                      -Test         ${function:Should-HaveParameter}
