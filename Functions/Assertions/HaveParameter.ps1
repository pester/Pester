function Should-HaveParameter($ActualValue, [String]$ParameterName, $OfType, [String]$Default, [Switch]$IsMandatory, [Switch]$HasArgumentCompleter, [Switch]$Negate, [String]$Because ) {
    <#
    .SYNOPSIS
        Asserts that a command has the expected parameter.

    .EXAMPLE
        Get-Command "Invoke-WebRequest" | Should -HaveParameter Uri -IsMandatory
        This test passes, because it expected the parameter URI to exist and to
        be mandatory.
    #>

    if ($null -eq $ActualValue -or $ActualValue -isnot [Management.Automation.CommandInfo]) {
        throw "Input value must be non-null CommandInfo object. You can get one by calling Get-Command."
    }

    if ($null -eq $ParameterName) {
        throw "The ParameterName can't be empty"
    }

    #region HelperFunctions
    function Join-And ($Items, $Threshold = 2) {

        if ($null -eq $items -or $items.count -lt $Threshold) {
            $items -join ', '
        }
        else {
            $c = $items.count
            ($items[0..($c - 2)] -join ', ') + ' and ' + $items[-1]
        }
    }

    function Add-SpaceToNonEmptyString ([string]$Value) {
        if ($Value) {
            " $Value"
        }
    }

    function Get-ParameterInfo {
        param(
            [Parameter( Mandatory = $true )]
            [Management.Automation.CommandInfo]$Command
        )
        <#
        .SYNOPSIS
            Use Tokenize to get information about the parameter block of a command
        .DESCRIPTION
            In order to get information about the parameter block of a command,
            several tools can be used (Get-Command, AST, etc).
            In order to get the default value of a parameter, AST is the easiest
            way to go; but AST was only introduced with PSv3.
            This function creates an object with information about parameters
            using the Tokenize
        .NOTES
            Author: Chris Dent
        #>

        function Get-TokenGroup {
            param(
                [Parameter( Mandatory = $true )]
                [System.Management.Automation.PSToken[]]$tokens
            )
            $i = $j = 0
            do {
                $token = $tokens[$i]
                if ($token.Type -eq 'GroupStart') { $j++ }
                if ($token.Type -eq 'GroupEnd') { $j-- }
                if ($null -eq $token.Depth) {
                    $token | Add-Member Depth -MemberType NoteProperty -Value $j
                }
                $token

                $i++
            } until ($j -eq 0 -or $i -ge $tokens.Count)
        }

        $errors = $null
        $tokens = [System.Management.Automation.PSParser]::Tokenize($Command.Definition, [Ref]$errors)

        # Find param block
        $start = $tokens.IndexOf(($tokens | Where-Object { $_.Content -eq 'param' })[0]) + 1
        $paramBlock = Get-TokenGroup $tokens[$start..($tokens.Count - 1)]

        for ($i = 0; $i -lt $paramBlock.Count; $i++) {
            $token = $paramBlock[$i]

            if ($token.Depth -eq 1 -and $token.Type -eq 'Variable') {
                $paramInfo = New-Object PSObject -Property @{
                    Name = $token.Content
                } | Select-Object Name, Type, DefaultValue, DefaultValueType

                if ($paramBlock[$i + 1].Content -ne ',') {
                    $value = $paramBlock[$i + 2]
                    if ($value.Type -eq 'GroupStart') {
                        $tokenGroup = Get-TokenGroup $paramBlock[($i + 2)..($paramBlock.Count - 1)]
                        $paramInfo.DefaultValue = [String]::Join('', ($tokenGroup | ForEach-Object { $_.Content }))
                        $paramInfo.DefaultValueType = 'Expression'
                    }
                    else {
                        $paramInfo.DefaultValue = $value.Content
                        $paramInfo.DefaultValueType = $value.Type
                    }
                }
                if ($paramBlock[$i - 1].Type -eq 'Type') {
                    $paramInfo.Type = $paramBlock[$i - 1].Content
                }
                $paramInfo
            }
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
    #endregion HelperFunctions

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
            $parameterMetadata = Get-ParameterInfo $ActualValue | Where-Object { $_.Name -eq $ParameterName }
            $actualDefault = $parameterMetadata.DefaultValue
            $testDefault = ($actualDefault -eq $Default)
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
