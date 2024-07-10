function Should-HaveParameterAssertion (
    $ActualValue,
    [String] $ParameterName,
    $Type,
    [String] $DefaultValue,
    [Switch] $Mandatory,
    [String] $InParameterSet,
    [Switch] $HasArgumentCompleter,
    [String[]] $Alias,
    [Switch] $Negate,
    [String] $Because ) {
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
        throw [ArgumentException]"Input value must be non-null CommandInfo object. You can get one by calling Get-Command."
    }

    if ($ActualValue -is [Management.Automation.ApplicationInfo]) {
        throw [ArgumentException]"Input value can not be an ApplicationInfo object."
    }

    if ($null -eq $ParameterName) {
        throw [ArgumentException]"The ParameterName can't be empty"
    }

    #region HelperFunctions
    function Get-ParameterInfo {
        param (
            [Parameter(Mandatory = $true)]
            [Management.Automation.CommandInfo]$Command,
            [Parameter(Mandatory = $true)]
            [string] $Name
        )

        # Resolve alias to the actual command so we can access scriptblock
        if ($Command -is [System.Management.Automation.AliasInfo] -and $Command.ResolvedCommand) {
            $Command = $Command.ResolvedCommand
        }

        $ast = $Command.ScriptBlock.Ast

        if ($null -eq $ast) {
            # Ast is unavailable, ex. for a binary cmdlet
            throw [ArgumentException]'Using -DefaultValue is only supported for functions and scripts.'
        }

        if ($null -ne $ast.Parameters) {
            # Functions without paramblock
            $parameters = $ast.Parameters
        }
        elseif ($null -ne $ast.Body.ParamBlock) {
            # Functions with paramblock
            $parameters = $ast.Body.ParamBlock.Parameters
        }
        elseif ($null -ne $ast.ParamBlock) {
            # Script paramblock
            $parameters = $ast.ParamBlock.Parameters
        }
        else {
            return
        }

        foreach ($parameter in $parameters) {
            if ($Name -ne $parameter.Name.VariablePath.UserPath) {
                continue
            }

            $paramInfo = [PSCustomObject] @{
                Name             = $parameter.Name.VariablePath.UserPath
                Type             = "[$($parameter.StaticType.Name.ToLower())]"
                HasDefaultValue  = $false
                DefaultValue     = $null
                DefaultValueType = $parameter.StaticType.Name
            }

            # Default value here contains a descriptor object of the default value,
            # so this is null only when default value is not present at all, if default value
            # is actually $null, this will have an object describing the type and the $null value.
            if ($null -ne $parameter.DefaultValue) {
                # The actual value of the default value can be falsy (e.g. $null, $false or 0)
                # use this flag to communicate if default value was found in the AST or not,
                # no matter if the actual default value is falsy.
                # That is: param($param1 = $false) will set this to true for $param1
                # but param($param1) will have this set to false, because there was no default value.
                $paramInfo.HasDefaultValue = $true
                # When the value has a known fully realized value (indicated by .Value being on the DefaultValue object)
                # we take that and use it, otherwise we take the extent (how it was written in code). This will make
                # 1, 2, or "abc", appear as 1, 2, abc to the assertion, but (Get-Date) will be (Get-Date).
                $paramInfo.DefaultValue = Get-DefaultValue $parameter.DefaultValue
            }

            $paramInfo
            break
        }
    }

    function Get-DefaultValue {
        param($DefaultValue)

        # This is a value like 1, or 0, return it direcly.
        if ($DefaultValue.PSObject.Properties["Value"]) {
            return $DefaultValue.Value
        }

        # This is for backwards compatibility with Pester v5.4.0.
        # Existing assertions check for -DefaultValue "false", while the definition
        # of the function says $MyParam = $false.
        if ('$true' -eq $DefaultValue.Extent.Text -or '$false' -eq $DefaultValue.Extent.Text) {
            # returns "true", or "false" without $ prefix
            return $DefaultValue.VariablePath
        }

        # This is for backwards compatibility with Pester v5.4.0.
        # Existing assertions check for -DefaultValue "", while the definition
        # of the function says $MyParam = $null or $MyParam without any default value.
        if ('$null' -eq $DefaultValue.Extent.Text) {
            return ""
        }

        $DefaultValue.Extent.Text
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
    #endregion HelperFunctions

    if ($Type -is [string]) {
        # parses type that is provided as a string in brackets (such as [int])
        $trimmedType = $Type -replace '^\[(.*)\]$', '$1'
        $parsedType = $trimmedType -as [Type]
        if ($null -eq $parsedType) {
            throw [ArgumentException]"Could not find type [$trimmedType]. Make sure that the assembly that contains that type is loaded."
        }

        $Type = $parsedType
    }

    $buts = @()
    $filters = @()

    $null = $ActualValue.Parameters # necessary for PSv2. Keeping just in case
    if ($null -eq $ActualValue.Parameters -and $ActualValue -is [System.Management.Automation.AliasInfo]) {
        # PowerShell doesn't resolve alias parameters properly in Get-Command when function is defined in a local scope in a different session state.
        # https://github.com/pester/Pester/issues/1431 and https://github.com/PowerShell/PowerShell/issues/17629
        if ($ActualValue.Definition -match '^PesterMock_') {
            $type = 'mock'
            $suggestion = "'Get-Command $($ActualValue.Name) | Where-Object Parameters | Should -HaveParameter ...'"
        }
        else {
            $type = 'alias'
            $suggestion = "using the actual command name. For example: 'Get-Command $($ActualValue.Definition) | Should -HaveParameter ...'"
        }

        throw "Could not retrieve parameters for $type $($ActualValue.Name). This is a known issue with Get-Command in PowerShell. Try $suggestion"
    }

    $hasKey = $ActualValue.Parameters.PSBase.ContainsKey($ParameterName)
    $filters += "to$(if ($Negate) {' not'}) have a parameter $ParameterName$(if ($InParameterSet) { " in parameter set $InParameterSet" })"

    if (-not $Negate -and -not $hasKey) {
        $buts += "the parameter is missing"
    }
    elseif ($Negate -and -not $hasKey) {
        return [Pester.ShouldResult] @{ Succeeded = $true }
    }
    elseif ($Negate -and $hasKey -and -not ($InParameterSet -or $Mandatory -or $Type -or $DefaultValue -or $HasArgumentCompleter)) {
        $buts += 'the parameter exists'
    }
    else {
        $attributes = $ActualValue.Parameters[$ParameterName].Attributes
        $parameterAttributes = $attributes | & $SafeCommands['Where-Object'] { $_ -is [System.Management.Automation.ParameterAttribute] }

        if ($InParameterSet) {
            $parameterAttributes = $parameterAttributes | & $SafeCommands['Where-Object'] { $_.ParameterSetName -eq $InParameterSet }

            if (-not $Negate -and -not $parameterAttributes) {
                $buts += 'the parameter is missing'
            }
            elseif ($Negate -and $parameterAttributes) {
                $buts += 'the parameter exists'
            }
        }
    }

    if ($buts.Count -eq 0) {
        # Parameter exists (in set if specified), assert remaining requirements

        if ($Mandatory) {
            $testMandatory = $parameterAttributes | & $SafeCommands['Where-Object'] { $_.Mandatory }
            $filters += "which is$(if ($Negate) {' not'}) mandatory"

            if (-not $Negate -and -not $testMandatory) {
                $buts += "it wasn't mandatory"
            }
            elseif ($Negate -and $testMandatory) {
                $buts += 'it was mandatory'
            }
        }

        if ($Type) {
            # This block is not using `Format-Nicely`, as in PSv2 the output differs. Eg:
            # PS2> [System.DateTime]
            # PS5> [datetime]
            [type]$actualType = $ActualValue.Parameters[$ParameterName].ParameterType
            $testType = ($Type -eq $actualType)
            $filters += "$(if ($Negate) { 'not ' })of type [$($Type.FullName)]"

            if (-not $Negate -and -not $testType) {
                $buts += "it was of type [$($actualType.FullName)]"
            }
            elseif ($Negate -and $testType) {
                $buts += "it was of type [$($Type.FullName)]"
            }
        }

        if ($PSBoundParameters.Keys -contains "DefaultValue") {
            $parameterMetadata = Get-ParameterInfo -Name $ParameterName -Command $ActualValue
            if ($null -eq $parameterMetadata) {
                # For safety, but this probably won't happen because if the parameter is not on the command we will fail much sooner.
                throw "Metadata for parameter '$ParameterName' were not found."
            }

            $filters += "the default value$(if ($Negate) {" not"}) to be $(Format-Nicely $DefaultValue)"

            # We could determine if the value is present and what is it's exact value, and also always use the
            # code literal that was used in the definition of the function (e.g. $true instead of "True"),
            # but that would be a breaking change for Pester 5, and in case of strings it would be a little
            # inconvenient for the users, because they would always have to provide doubled quotes, like '"aaa"'.
            # So instead we force the values to be strings, and when the value is not there we define it as $null
            # which prevents us from full checking if there was or was not an actual $null definition, but that is
            # okay because you would rarely need to do that.
            $defaultIsUnspecified = -not $parameterMetadata.HasDefaultValue
            [string] $actualDefault = if ($defaultIsUnspecified) { $null } else { $parameterMetadata.DefaultValue }
            $testDefault = ($actualDefault -eq $DefaultValue)

            if (-not $Negate -and -not $testDefault) {
                $buts += "the default value was $(Format-Nicely $actualDefault)"
            }
            elseif ($Negate -and $testDefault) {
                $buts += "the default value was $(Format-Nicely $actualDefault)"
            }
        }

        if ($HasArgumentCompleter) {
            $testArgumentCompleter = $attributes | & $SafeCommands['Where-Object'] { $_ -is [ArgumentCompleter] }

            if (-not $testArgumentCompleter) {
                $testArgumentCompleter = Get-ArgumentCompleter -CommandName $ActualValue.Name -ParameterName $ParameterName
            }
            $filters += 'has ArgumentCompletion'

            if (-not $Negate -and -not $testArgumentCompleter) {
                $buts += 'has no ArgumentCompletion'
            }
            elseif ($Negate -and $testArgumentCompleter) {
                $buts += 'has ArgumentCompletion'
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
                    $buts += "it has $(if($singular) {'an alias'} else {'the aliases'} ) $aliases"
                }
                else {
                    $buts += "it didn't have $(if($singular) {'an alias'} else {'the aliases'} ) $aliases"
                }
            }
        }
    }

    if ($buts.Count -ne 0) {
        $filter = Add-SpaceToNonEmptyString ( Join-And $filters -Threshold 3 )
        $but = Join-And $buts
        $failureMessage = "Expected command $($ActualValue.Name)$filter,$(Format-Because $Because) but $but."

        $ExpectedValue = "Parameter $($ActualValue.Name)$filter"

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
    else {
        return [Pester.ShouldResult] @{ Succeeded = $true }
    }
}

& $script:SafeCommands['Add-ShouldOperator'] -Name HaveParameter `
    -InternalName Should-HaveParameterAssertion `
    -Test         ${function:Should-HaveParameterAssertion}

Set-ShouldOperatorHelpMessage -OperatorName HaveParameter `
    -HelpMessage 'Asserts that a command has the expected parameter.'
