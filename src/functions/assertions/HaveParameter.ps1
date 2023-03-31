﻿function Should-HaveParameter (
    $ActualValue,
    [String] $ParameterName,
    $Type,
    [String]$DefaultValue,
    [Switch]$Mandatory,
    [Switch]$HasArgumentCompleter,
    [String[]]$Alias,
    [Switch]$Negate,
    [String]$Because ) {
    <#
    .SYNOPSIS
        Asserts that a command has the expected parameter.

    .EXAMPLE
        Get-Command "Invoke-WebRequest" | Should -HaveParameter Uri -Mandatory

        This test passes, because it expected the parameter URI to exist and to
        be mandatory.
    .NOTES
        The attribute [ArgumentCompleter] was added with PSv5. Previouse this
        assertion will not be able to use the -HasArgumentCompleter parameter
        if the attribute does not exist.
    #>
    if ($null -eq $ActualValue -or $ActualValue -isnot [Management.Automation.CommandInfo]) {
        throw "Input value must be non-null CommandInfo object. You can get one by calling Get-Command."
    }

    if ($null -eq $ParameterName) {
        throw "The ParameterName can't be empty"
    }

    function Get-ParameterInfo {
        param (
            [Parameter(Mandatory = $true)]
            [Management.Automation.CommandInfo]$Command
        )
        <#
        .SYNOPSIS
            Use AST to get information about the parameter block of a command
        .DESCRIPTION
            In order to get information about the parameter block of a command,
            several tools can be used (Get-Command, AST, etc).
            In order to get the default value of a parameter, AST is the easiest
            way to go
        .NOTES
            Author: Brian West
        #>

        # Find parameters
        $ast = $Command.ScriptBlock.Ast

        if ($null -ne $ast) {
            if ($null -ne $ast.Parameters) {
                $parameters = $ast.Parameters
            }
            elseif ($null -ne $ast.Body.ParamBlock) {
                $parameters = $ast.Body.ParamBlock.Parameters
            }
            else {
                return
            }

            foreach ($parameter in $parameters) {
                $paramInfo = & $SafeCommands['New-Object'] PSObject -Property @{
                    Name             = $parameter.Name.VariablePath.UserPath
                    DefaultValueType = $parameter.StaticType.Name
                    Type             = "[$($parameter.StaticType.Name.ToLower())]"
                } | & $SafeCommands['Select-Object'] Name, Type, DefaultValue, DefaultValueType

                if ($null -ne $parameter.DefaultValue) {
                    if ($parameter.DefaultValue.PSObject.Properties['Value']) {
                        $paramInfo.DefaultValue = $parameter.DefaultValue.Value
                    }
                    else {
                        $paramInfo.DefaultValue = $parameter.DefaultValue.Extent.Text
                    }
                }

                $paramInfo
            }
        }
    }

    function Get-ArgumentCompleter {
        <#
        .SYNOPSIS
            Get custom argument completers registered in the current session.
        .DESCRIPTION
            Get custom argument completers registered in the current session.

            By default Get-ArgumentCompleter lists all of the completers registered in the session.
        .EXAMPLE
            Get-ArgumentCompleter

            Get all of the argument completers for PowerShell commands in the current session.
        .EXAMPLE
            Get-ArgumentCompleter -CommandName Invoke-ScriptAnalyzer

            Get all of the argument completers used by the Invoke-ScriptAnalyzer command.
        .EXAMPLE
            Get-ArgumentCompleter -Native

            Get all of the argument completers for native commands in the current session.
        .NOTES
            Author: Chris Dent
        #>
        [CmdletBinding()]
        param (
            # Filter results by command name.
            [Parameter(Mandatory = $true)]
            [String]$CommandName,

            # Filter results by parameter name.
            [Parameter(Mandatory = $true)]
            [String]$ParameterName
        )

        $getExecutionContextFromTLS = [PowerShell].Assembly.GetType('System.Management.Automation.Runspaces.LocalPipeline').GetMethod(
            'GetExecutionContextFromTLS',
            [System.Reflection.BindingFlags]'Static, NonPublic'
        )
        $internalExecutionContext = $getExecutionContextFromTLS.Invoke(
            $null,
            [System.Reflection.BindingFlags]'Static, NonPublic',
            $null,
            $null,
            $PSCulture
        )

        $argumentCompletersProperty = $internalExecutionContext.GetType().GetProperty(
            'CustomArgumentCompleters',
            [System.Reflection.BindingFlags]'NonPublic, Instance'
        )
        $argumentCompleters = $argumentCompletersProperty.GetGetMethod($true).Invoke(
            $internalExecutionContext,
            [System.Reflection.BindingFlags]'Instance, NonPublic, GetProperty',
            $null,
            @(),
            $PSCulture
        )

        $completerName = '{0}:{1}' -f $CommandName, $ParameterName
        if ($argumentCompleters.ContainsKey($completerName)) {
            [PSCustomObject]@{
                CommandName   = $CommandName
                ParameterName = $ParameterName
                Definition    = $argumentCompleters[$completerName]
            }
        }
    }

    if ($Type -is [string]) {
        # parses type that is provided as a string in brackets (such as [int])
        $trimmedType = $Type -replace '^\[(.*)\]$', '$1'
        $parsedType = $trimmedType -as [Type]
        if ($null -eq $parsedType) {
            throw [ArgumentException]"Could not find type [$trimmedType]. Make sure that the assembly that contains that type is loaded."
        }

        $Type = $parsedType
    }
    #endregion HelperFunctions

    $buts = @()
    $filters = @()

    $null = $ActualValue.Parameters # necessary for PSv2. Keeping just in case
    if ($null -eq $ActualValue.Parameters -and $ActualValue -is [System.Management.Automation.AliasInfo]) {
        # PowerShell doesn't resolve alias parameters properly in Get-Command when function is defined in a local scope in a different session state.
        # https://github.com/pester/Pester/issues/1431 and https://github.com/PowerShell/PowerShell/issues/17629
        if ($ActualValue.Definition -match '^PesterMock_') {
            $type = 'mock'
            $suggestion = "'Get-Command $($ActualValue.Name) | Where-Object Parameters | Should -HaveParameter ...'"
        } else {
            $type = 'alias'
            $suggestion = "using the actual command name. For example: 'Get-Command $($ActualValue.Definition) | Should -HaveParameter ...'"
        }

        throw "Could not retrieve parameters for $type $($ActualValue.Name). This is a known issue with Get-Command in PowerShell. Try $suggestion"
    }

    $hasKey = $ActualValue.Parameters.PSBase.ContainsKey($ParameterName)
    $filters += "to$(if ($Negate) {" not"}) have a parameter $ParameterName"

    if (-not $Negate -and -not $hasKey) {
        $buts += "the parameter is missing"
    }
    elseif ($Negate -and -not $hasKey) {
        return & $SafeCommands['New-Object'] PSObject -Property @{ Succeeded = $true }
    }
    elseif ($Negate -and $hasKey -and -not ($Mandatory -or $Type -or $DefaultValue -or $HasArgumentCompleter)) {
        $buts += "the parameter exists"
    }
    else {
        $attributes = $ActualValue.Parameters[$ParameterName].Attributes

        if ($Mandatory) {
            $testMandatory = $attributes | & $SafeCommands['Where-Object'] { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $filters += "which is$(if ($Negate) {" not"}) mandatory"

            if (-not $Negate -and -not $testMandatory) {
                $buts += "it wasn't mandatory"
            }
            elseif ($Negate -and $testMandatory) {
                $buts += "it was mandatory"
            }
        }

        if ($Type) {
            # This block is not using `Format-Nicely`, as in PSv2 the output differs. Eg:
            # PS2> [System.DateTime]
            # PS5> [datetime]
            [type]$actualType = $ActualValue.Parameters[$ParameterName].ParameterType
            $testType = ($Type -eq $actualType)
            $filters += "$(if ($Negate) { "not " })of type [$($Type.FullName)]"

            if (-not $Negate -and -not $testType) {
                $buts += "it was of type [$($actualType.FullName)]"
            }
            elseif ($Negate -and $testType) {
                $buts += "it was of type [$($Type.FullName)]"
            }
        }

        if ($PSBoundParameters.Keys -contains "DefaultValue") {
            $parameterMetadata = Get-ParameterInfo $ActualValue | & $SafeCommands['Where-Object'] { $_.Name -eq $ParameterName }
            $actualDefault = if ($parameterMetadata.DefaultValue) {
                $parameterMetadata.DefaultValue
            }
            else {
                ""
            }
            $testDefault = ($actualDefault -eq $DefaultValue)
            $filters += "the default value$(if ($Negate) {" not"}) to be $(Format-Nicely $DefaultValue)"

            if (-not $Negate -and -not $testDefault) {
                $buts += "the default value was $(Format-Nicely $actualDefault)"
            }
            elseif ($Negate -and $testDefault) {
                $buts += "the default value was $(Format-Nicely $DefaultValue)"
            }
        }

        if ($HasArgumentCompleter) {
            $testArgumentCompleter = $attributes | & $SafeCommands['Where-Object'] { $_ -is [ArgumentCompleter] }

            if (-not $testArgumentCompleter) {
                $testArgumentCompleter = Get-ArgumentCompleter -CommandName $ActualValue.Name -ParameterName $ParameterName
            }
            $filters += "has ArgumentCompletion"

            if (-not $Negate -and -not $testArgumentCompleter) {
                $buts += "has no ArgumentCompletion"
            }
            elseif ($Negate -and $testArgumentCompleter) {
                $buts += "has ArgumentCompletion"
            }
        }

        if ($Alias) {

            $filters += "with$(if ($Negate) {'out'}) alias$(if ($Alias.Count -ge 2) {'es'}) $(Join-And ($Alias -replace '^|$', "'"))"
            $faultyAliases = @()
            foreach ($AliasValue in $Alias) {
                $testPresenceOfAlias = $ActualValue.Parameters[$ParameterName].Aliases -contains $AliasValue
                if (-not $Negate -and -not $testPresenceOfAlias) {
                    $faultyAliases += $AliasValue
                }
                elseif ($Negate -and $testPresenceOfAlias) {
                    $faultyAliases += $AliasValue
                }
            }
            if ($faultyAliases.Count -ge 1) {
                $aliases = $(Join-And ($faultyAliases -replace '^|$', "'"))
                $singular = $faultyAliases.Count -eq 1
                if ($Negate) {
                    $buts += "it has $(if($singular) {"an alias"} else {"the aliases"} ) $aliases"
                }
                else {
                    $buts += "it didn't have $(if($singular) {"an alias"} else {"the aliases"} ) $aliases"
                }
            }
        }
    }

    if ($buts.Count -ne 0) {
        $filter = Add-SpaceToNonEmptyString ( Join-And $filters -Threshold 3 )
        $but = Join-And $buts
        $failureMessage = "Expected command $($ActualValue.Name)$filter,$(Format-Because $Because) but $but."

        return & $SafeCommands['New-Object'] PSObject -Property @{
            Succeeded      = $false
            FailureMessage = $failureMessage
        }
    }
    else {
        return & $SafeCommands['New-Object'] PSObject -Property @{ Succeeded = $true }
    }
}

& $script:SafeCommands['Add-ShouldOperator'] -Name         HaveParameter `
    -InternalName Should-HaveParameter `
    -Test         ${function:Should-HaveParameter}
