

function Add-MockBehavior {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Behaviors,
        [Parameter(Mandatory)]
        $Behavior
    )

    if ($Behavior.IsDefault) {
        $Behaviors.Default.Add($Behavior)
    }
    else {
        $Behaviors.Parametrized.Add($Behavior)
    }
}

function New-MockBehavior {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $ContextInfo,
        [ScriptBlock] $MockWith = { },
        [Switch] $Verifiable,
        [ScriptBlock] $ParameterFilter,
        [Parameter(Mandatory)]
        $Hook,
        [string[]]$RemoveParameterType,
        [string[]]$RemoveParameterValidation
    )

    [PSCustomObject] @{
        CommandName = $ContextInfo.Command.Name
        ModuleName  = $ContextInfo.TargetModule
        Filter      = $ParameterFilter
        IsDefault   = $null -eq $ParameterFilter
        IsInModule  = -not [string]::IsNullOrEmpty($ContextInfo.TargetModule)
        Verifiable  = $Verifiable
        Executed    = $false
        ScriptBlock = $MockWith
        Hook        = $Hook
        PSTypeName  = 'MockBehavior'
    }
}

function EscapeSingleQuotedStringContent ($Content) {
    if ($global:PSVersionTable.PSVersion.Major -ge 5) {
        [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($Content)
    }
    else {
        $Content -replace "['‘’‚‛]", '$&$&'
    }
}

function Create-MockHook ($contextInfo, $InvokeMockCallback) {
    $commandName = $contextInfo.Command.Name
    $moduleName = $contextInfo.TargetModule
    $metadata = $contextInfo.CommandMetadata
    $cmdletBinding = ''
    $paramBlock = ''
    $dynamicParamBlock = ''
    $dynamicParamScriptBlock = $null

    if ($contextInfo.Command.psobject.Properties['ScriptBlock'] -or $contextInfo.Command.CommandType -eq 'Cmdlet') {
        $null = $metadata.Parameters.Remove('Verbose')
        $null = $metadata.Parameters.Remove('Debug')
        $null = $metadata.Parameters.Remove('ErrorAction')
        $null = $metadata.Parameters.Remove('WarningAction')
        $null = $metadata.Parameters.Remove('ErrorVariable')
        $null = $metadata.Parameters.Remove('WarningVariable')
        $null = $metadata.Parameters.Remove('OutVariable')
        $null = $metadata.Parameters.Remove('OutBuffer')

        # Some versions of PowerShell may include dynamic parameters here
        # We will filter them out and add them at the end to be
        # compatible with both earlier and later versions
        $dynamicParams = foreach ($m in $metadata.Parameters.Values) { if ($m.IsDynamic) { $m } }
        if ($null -ne $dynamicParams) {
            foreach ($p in $dynamicParams) {
                $null = $metadata.Parameters.Remove($d.name)
            }
        }
        $cmdletBinding = [Management.Automation.ProxyCommand]::GetCmdletBindingAttribute($metadata)
        if ($global:PSVersionTable.PSVersion.Major -ge 3 -and $contextInfo.Command.CommandType -eq 'Cmdlet') {
            if ($cmdletBinding -ne '[CmdletBinding()]') {
                $cmdletBinding = $cmdletBinding.Insert($cmdletBinding.Length - 2, ',')
            }
            $cmdletBinding = $cmdletBinding.Insert($cmdletBinding.Length - 2, 'PositionalBinding=$false')
        }

        $metadata = Repair-ConflictingParameters -Metadata $metadata -RemoveParameterType $RemoveParameterType -RemoveParameterValidation $RemoveParameterValidation
        $paramBlock = [Management.Automation.ProxyCommand]::GetParamBlock($metadata)
        $paramBlock = Repair-EnumParameters -ParamBlock $paramBlock -Metadata $metadata

        if ($contextInfo.Command.CommandType -eq 'Cmdlet') {
            $dynamicParamBlock = "dynamicparam { & `$MyInvocation.MyCommand.Mock.Get_MockDynamicParameter -CmdletName '$($contextInfo.Command.Name)' -Parameters `$PSBoundParameters }"
        }
        else {
            $dynamicParamStatements = Get-DynamicParamBlock -ScriptBlock $contextInfo.Command.ScriptBlock

            if ($dynamicParamStatements -match '\S') {
                $metadataSafeForDynamicParams = $contextInfo.CommandMetadata2
                foreach ($param in $metadataSafeForDynamicParams.Parameters.Values) {
                    $param.ParameterSets.Clear()
                }

                $paramBlockSafeForDynamicParams = [System.Management.Automation.ProxyCommand]::GetParamBlock($metadataSafeForDynamicParams)
                $comma = if ($metadataSafeForDynamicParams.Parameters.Count -gt 0) {
                    ','
                }
                else {
                    ''
                }
                $dynamicParamBlock = "dynamicparam { & `$MyInvocation.MyCommand.Mock.Get_MockDynamicParameter -ModuleName '$moduleName' -FunctionName '$commandName' -Parameters `$PSBoundParameters -Cmdlet `$PSCmdlet -DynamicParamScriptBlock `$MyInvocation.MyCommand.Mock.Hook.DynamicParamScriptBlock }"

                $code = @"
                    $cmdletBinding
                    param(
                        [object] `${P S Cmdlet}$comma
                        $paramBlockSafeForDynamicParams
                    )

                    `$PSCmdlet = `${P S Cmdlet}

                    $dynamicParamStatements
"@

                $dynamicParamScriptBlock = [scriptblock]::Create($code)

                $sessionStateInternal = $script:ScriptBlockSessionStateInternalProperty.GetValue($contextInfo.Command.ScriptBlock)

                if ($null -ne $sessionStateInternal) {
                    $script:ScriptBlockSessionStateInternalProperty.SetValue($dynamicParamScriptBlock, $sessionStateInternal)
                }
            }
        }
    }

    $mockPrototype = @"
    if (`$null -ne `$MyInvocation.MyCommand.Mock.Write_PesterDebugMessage) { & `$MyInvocation.MyCommand.Mock.Write_PesterDebugMessage -Message "Mock bootstrap function #FUNCTIONNAME# called from block #BLOCK#." }
    `$MyInvocation.MyCommand.Mock.Args = @()
    if (#CANCAPTUREARGS#) {
        if (`$null -ne `$MyInvocation.MyCommand.Mock.Write_PesterDebugMessage) { & `$MyInvocation.MyCommand.Mock.Write_PesterDebugMessage -Message "Capturing arguments of the mocked command." }
        `$MyInvocation.MyCommand.Mock.Args = `$MyInvocation.MyCommand.Mock.ExecutionContext.SessionState.PSVariable.GetValue('local:args')
    }
    `$MyInvocation.MyCommand.Mock.PSCmdlet = `$MyInvocation.MyCommand.Mock.ExecutionContext.SessionState.PSVariable.GetValue('local:PSCmdlet')


    `if (`$null -ne `$MyInvocation.MyCommand.Mock.PSCmdlet)
    {
        `$MyInvocation.MyCommand.Mock.SessionState = `$MyInvocation.MyCommand.Mock.PSCmdlet.SessionState
    }

    # MockCallState initialization is injected only into the begin block by the code that generates this prototype
    # also it is not a good idea to share it via the function local data because then it will get overwritten by nested
    # mock if there is any, instead it should be a variable that gets defined in begin and so it survives during the whole
    # pipeline, but does not overwrite other variables, because we are running in different scopes. Mindblowing.
    & `$MyInvocation.MyCommand.Mock.Invoke_Mock -CommandName '#FUNCTIONNAME#' -ModuleName '#MODULENAME#' ```
        -BoundParameters `$PSBoundParameters ```
        -ArgumentList `$MyInvocation.MyCommand.Mock.Args ```
        -CallerSessionState `$MyInvocation.MyCommand.Mock.SessionState ```
        -MockCallState `$_____MockCallState ```
        -FromBlock '#BLOCK#' ```
        -Hook `$MyInvocation.MyCommand.Mock.Hook #INPUT#
"@
    $newContent = $mockPrototype
    $newContent = $newContent -replace '#FUNCTIONNAME#', (EscapeSingleQuotedStringContent $CommandName)
    $newContent = $newContent -replace '#MODULENAME#', (EscapeSingleQuotedStringContent $ModuleName)

    $canCaptureArgs = '$true'
    if ($contextInfo.Command.CommandType -eq 'Cmdlet' -or
        ($contextInfo.Command.CommandType -eq 'Function' -and $contextInfo.Command.CmdletBinding)) {
        $canCaptureArgs = '$false'
    }
    $newContent = $newContent -replace '#CANCAPTUREARGS#', $canCaptureArgs

    $code = @"
    $cmdletBinding
    param ( $paramBlock )
    $dynamicParamBlock
    begin
    {
        # MockCallState is set only in begin block, to persist state between
        # begin, process, and end blocks
        `$_____MockCallState = @{}
        $($newContent -replace '#BLOCK#', 'Begin' -replace '#INPUT#')
    }

    process
    {
        $($newContent -replace '#BLOCK#', 'Process' -replace '#INPUT#', '-InputObject @($input)')
    }

    end
    {
        $($newContent -replace '#BLOCK#', 'End' -replace '#INPUT#')
    }
"@

    $mockScript = [scriptblock]::Create($code)

    $mockName = "PesterMock_$(if ([string]::IsNullOrEmpty($ModuleName)) { "script" } else { $ModuleName })_${CommandName}_$([Guid]::NewGuid().Guid)"

    $mock = @{
        OriginalCommand         = $contextInfo.Command
        OriginalMetadata        = $contextInfo.CommandMetadata
        OriginalMetadata2       = $contextInfo.CommandMetadata2
        CommandName             = $commandName
        SessionState            = $contextInfo.SessionState
        CallerSessionState      = $contextInfo.CallerSessionState
        Metadata                = $metadata
        DynamicParamScriptBlock = $dynamicParamScriptBlock
        Aliases                 = [Collections.Generic.List[object]]@($commandName)
        BootstrapFunctionName   = $mockName
    }

    if ($mock.OriginalCommand.ModuleName) {
        $mock.Aliases.Add("$($mock.OriginalCommand.ModuleName)\$($CommandName)")
    }

    if ('Application' -eq $Mock.OriginalCommand.CommandType) {
        $aliasWithoutExt = $CommandName -replace $Mock.OriginalCommand.Extension

        $mock.Aliases.Add($aliasWithoutExt)
    }

    $parameters = @{
        BootstrapFunctionName = $mock.BootstrapFunctionName
        Definition            = $mockScript
        Aliases               = $mock.Aliases

        Set_Alias             = $SafeCommands["Set-Alias"]
    }

    $defineFunctionAndAliases = {
        param($___Mock___parameters)
        # Make sure the you don't use _______parameters variable here, otherwise you overwrite
        # the variable that is defined in the same scope and the subsequent invocation of scripts will
        # be seriously broken (e.g. you will start resolving setups). But such is life of running in once scope.
        # from upper scope for no reason. But the reason is that you deleted ______param in this scope,
        # and so ______param from the parent scope was inherited

        ## THIS RUNS IN USER SCOPE, BE CAREFUL WHAT YOU PUBLISH AND CONSUME


        # it is possible to remove the script: (and -Scope Script) from here and from the alias, which makes the Mock scope just like a function.
        # but that breaks mocking inside of Pester itself, because the mock is defined in this function and dies with it
        # this is a cool concept to play with, but scoping mocks more granularly than per It is not something people asked for, and cleaning up
        # mocks is trivial now they are wrote in distinct tables based on where they are defined, so let's just do it as before, script scoped
        # function and alias, and cleaning it up in teardown

        # define the function and returns an array so we need to take the function out
        @($ExecutionContext.InvokeProvider.Item.Set("Function:\script:$($___Mock___parameters.BootstrapFunctionName)", $___Mock___parameters.Definition, $true, $true))[0]

        # define all aliases
        foreach ($______current in $___Mock___parameters.Aliases) {
            # this does not work because the syntax does not work, but would be faster
            # $ExecutionContext.InvokeProvider.Item.Set("Alias:script\:$______current", $___Mock___parameters.BootstrapFunctionName, $true, $true)
            & $___Mock___parameters.Set_Alias -Name $______current -Value $___Mock___parameters.BootstrapFunctionName -Scope Script
        }

        # clean up the variables because we are injecting them to the current scope
        $ExecutionContext.SessionState.PSVariable.Remove('______current')
        $ExecutionContext.SessionState.PSVariable.Remove('___Mock___parameters')
    }

    $definedFunction = Invoke-InMockScope -SessionState $mock.SessionState -ScriptBlock $defineFunctionAndAliases -Arguments @($parameters) -NoNewScope
    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Mock -Message "Defined new hook with bootstrap function $($parameters.BootstrapFunctionName)$(if ($parameters.Aliases.Count -gt 0) {" and aliases $($parameters.Aliases -join ", ")"})."
    }

    # attaching this object on the newly created function
    # so it has access to our internal and safe functions directly
    # and also to avoid any local variables, because everything is
    # accessed via $MyInvocation.MyCommand
    $functionLocalData = @{
        Args                     = $null
        SessionState             = $null

        Invoke_Mock              = $InvokeMockCallBack
        Get_MockDynamicParameter = $SafeCommands["Get-MockDynamicParameter"]
        # returning empty scriptblock when we should not write debug to avoid patching it in mock prototype
        Write_PesterDebugMessage = if ($PesterPreference.Debug.WriteDebugMessages.Value) { { param($Message) & $SafeCommands["Write-PesterDebugMessage"] -Scope MockCore -Message $Message } } else { $null }

        # used as temp variable
        PSCmdlet                 = $null

        # data from the time we captured and created this mock
        Hook                     = $mock

        ExecutionContext         = $ExecutionContext
    }

    $definedFunction.psobject.properties.Add([Pester.Factory]::CreateNoteProperty('Mock', $functionLocalData))

    $mock
}

function Should-InvokeVerifiableInternal {
    [CmdletBinding()]
    [OutputType([Pester.ShouldResult])]
    param(
        [Parameter(Mandatory)]
        $Behaviors,
        [switch] $Negate,
        [string] $Because
    )

    $filteredBehaviors = [System.Collections.Generic.List[Object]]@()
    foreach ($b in $Behaviors) {
        if ($b.Executed -eq $Negate.IsPresent) {
            $filteredBehaviors.Add($b)
        }
    }

    if ($filteredBehaviors.Count -gt 0) {
        [string]$filteredBehaviorMessage = ''
        foreach ($b in $filteredBehaviors) {
            $filteredBehaviorMessage += "$([System.Environment]::NewLine) Command $($b.CommandName) "
            if ($b.ModuleName) {
                $filteredBehaviorMessage += "from inside module $($b.ModuleName) "
            }
            if ($null -ne $b.Filter) { $filteredBehaviorMessage += "with { $($b.Filter.ToString().Trim()) }" }
        }

        if ($Negate) {
            $message = "$([System.Environment]::NewLine)Expected no verifiable mocks to be called,$(Format-Because $Because) but these were:$filteredBehaviorMessage"
            $ExpectedValue = 'No verifiable mocks to be called'
            $ActualValue = "These mocks were called:$filteredBehaviorMessage"
        }
        else {
            $message = "$([System.Environment]::NewLine)Expected all verifiable mocks to be called,$(Format-Because $Because) but these were not:$filteredBehaviorMessage"
            $ExpectedValue = 'All verifiable mocks to be called'
            $ActualValue = "These mocks were not called:$filteredBehaviorMessage"
        }

        return [Pester.ShouldResult] @{
            Succeeded      = $false
            FailureMessage = $message
            ExpectResult   = @{
                Expected = $ExpectedValue
                Actual   = $ActualValue
                Because  = Format-Because $Because
            }
        }
    }

    return [Pester.ShouldResult] @{
        Succeeded      = $true
    }
}

function Should-InvokeInternal {
    [CmdletBinding(DefaultParameterSetName = 'ParameterFilter')]
    [OutputType([Pester.ShouldResult])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable] $ContextInfo,

        [int] $Times = 1,

        [Parameter(ParameterSetName = 'ParameterFilter')]
        [ScriptBlock] $ParameterFilter = { $True },

        [Parameter(ParameterSetName = 'ExclusiveFilter', Mandatory = $true)]
        [scriptblock] $ExclusiveFilter,

        [string] $ModuleName,

        [switch] $Exactly,
        [switch] $Negate,
        [string] $Because,

        [Parameter(Mandatory)]
        [Management.Automation.SessionState] $SessionState,

        [Parameter(Mandatory)]
        [HashTable] $MockTable
    )

    if ($PSCmdlet.ParameterSetName -eq 'ParameterFilter') {
        $filter = $ParameterFilter
        $filterIsExclusive = $false
    }
    else {
        $filter = $ExclusiveFilter
        $filterIsExclusive = $true
    }

    if (-not $PSBoundParameters.ContainsKey('ModuleName') -and $null -ne $SessionState.Module) {
        $ModuleName = $SessionState.Module.Name
    }

    $ModuleName = $ContextInfo.TargetModule
    $CommandName = $ContextInfo.Command.Name

    $callHistory = $MockTable["$ModuleName||$CommandName"]

    $moduleMessage = ''
    if ($ModuleName) {
        $moduleMessage = " in module $ModuleName"
    }

    # if (-not $callHistory) {
    #     throw "You did not declare a mock of the $commandName Command${moduleMessage}."
    # }

    $matchingCalls = [System.Collections.Generic.List[object]]@()
    $nonMatchingCalls = [System.Collections.Generic.List[object]]@()

    # Check for variables in ParameterFilter that already exists in session. Risk of conflict
    # Excluding native applications as they don't have parameters or metadata. Will always use $args
    if ($PesterPreference.Debug.WriteDebugMessages.Value -and
        $null -ne $ContextInfo.Hook.Metadata -and
        $ContextInfo.Hook.Metadata.Parameters.Count -gt 0) {
        $preExistingFilterVariables = @{}
        foreach ($v in $filter.Ast.FindAll( { $args[0] -is [System.Management.Automation.Language.VariableExpressionAst] }, $true)) {
            if (-not $preExistingFilterVariables.ContainsKey($v.VariablePath.UserPath)) {
                if ($existingVar = $SessionState.PSVariable.Get($v.VariablePath.UserPath)) {
                    $preExistingFilterVariables.Add($v.VariablePath.UserPath, $existingVar.Value)
                }
            }
        }

        # Check against parameters and aliases in mocked command as it may cause false positives
        if ($preExistingFilterVariables.Count -gt 0) {
            foreach ($p in $ContextInfo.Hook.Metadata.Parameters.GetEnumerator()) {
                if ($preExistingFilterVariables.ContainsKey($p.Key)) {
                    Write-PesterDebugMessage -Scope Mock -Message "! Variable `$$($p.Key) with value '$($preExistingFilterVariables[$p.Key])' exists in current scope and matches a parameter in $CommandName which may cause false matches in ParameterFilter. Consider renaming the existing variable or use `$PesterBoundParameters.$($p.Key) in ParameterFilter."
                }

                $aliases = $p.Value.Aliases
                if ($null -ne $aliases -and 0 -lt @($aliases).Count) {
                    foreach ($a in $aliases) {
                        if ($preExistingFilterVariables.ContainsKey($a)) {
                            Write-PesterDebugMessage -Scope Mock -Message "! Variable `$$($a) with value '$($preExistingFilterVariables[$a])' exists in current scope and matches a parameter in $CommandName which may cause false matches in ParameterFilter. Consider renaming the existing variable or use `$PesterBoundParameters.$($a) in ParameterFilter."
                        }
                    }
                }
            }
        }
    }

    foreach ($historyEntry in $callHistory) {

        $params = @{
            ScriptBlock     = $filter
            BoundParameters = $historyEntry.BoundParams
            ArgumentList    = $historyEntry.Args
            Metadata        = $ContextInfo.Hook.Metadata
            # do not use the callser session state from the hook, the parameter filter
            # on Should -Invoke can come from a different session state if inModuleScope is used to
            # wrap it. Use the caller session state to which the scriptblock is bound
            SessionState    = $SessionState
        }

        # if ($null -ne $ContextInfo.Hook.Metadata -and $null -ne $params.ScriptBlock) {
        #     $params.ScriptBlock = New-BlockWithoutParameterAliases -Metadata $ContextInfo.Hook.Metadata -Block $params.ScriptBlock
        # }

        if (Test-ParameterFilter @params) {
            $null = $matchingCalls.Add($historyEntry)
        }
        else {
            $null = $nonMatchingCalls.Add($historyEntry)
        }
    }

    if ($Negate) {
        # Negative checks
        if ($matchingCalls.Count -eq $Times -and ($Exactly -or !$PSBoundParameters.ContainsKey('Times'))) {
            return [Pester.ShouldResult] @{
                Succeeded      = $false
                FailureMessage = "Expected ${commandName}${moduleMessage} not to be called exactly $Times times,$(Format-Because $Because) but it was"
                ExpectResult   = [Pester.ShouldExpectResult]@{
                    Expected = "${commandName}${moduleMessage} not to be called exactly $Times times"
                    Actual   = "${commandName}${moduleMessage} was called $($matchingCalls.count) times"
                    Because  = Format-Because $Because
                }
            }
        }
        elseif ($matchingCalls.Count -ge $Times -and !$Exactly) {
            return [Pester.ShouldResult] @{
                Succeeded      = $false
                FailureMessage = "Expected ${commandName}${moduleMessage} to be called less than $Times times,$(Format-Because $Because) but was called $($matchingCalls.Count) times"
                ExpectResult   = [Pester.ShouldExpectResult]@{
                    Expected = "${commandName}${moduleMessage} to be called less than $Times times"
                    Actual   = "${commandName}${moduleMessage} was called $($matchingCalls.count) times"
                    Because  = Format-Because $Because
                }
            }
        }
    }
    else {
        if ($matchingCalls.Count -ne $Times -and ($Exactly -or ($Times -eq 0))) {
            return [Pester.ShouldResult] @{
                Succeeded      = $false
                FailureMessage = "Expected ${commandName}${moduleMessage} to be called $Times times exactly,$(Format-Because $Because) but was called $($matchingCalls.Count) times"
                ExpectResult   = [Pester.ShouldExpectResult]@{
                    Expected = "${commandName}${moduleMessage} to be called $Times times exactly"
                    Actual   = "${commandName}${moduleMessage} was called $($matchingCalls.count) times"
                    Because  = Format-Because $Because
                }
            }
        }
        elseif ($matchingCalls.Count -lt $Times) {
            return [Pester.ShouldResult] @{
                Succeeded      = $false
                FailureMessage = "Expected ${commandName}${moduleMessage} to be called at least $Times times,$(Format-Because $Because) but was called $($matchingCalls.Count) times"
                ExpectResult   = [Pester.ShouldExpectResult]@{
                    Expected = "${commandName}${moduleMessage} to be called at least $Times times"
                    Actual   = "${commandName}${moduleMessage} was called $($matchingCalls.count) times"
                    Because  = Format-Because $Because
                }
            }
        }
        elseif ($filterIsExclusive -and $nonMatchingCalls.Count -gt 0) {
            return [Pester.ShouldResult] @{
                Succeeded      = $false
                FailureMessage = "Expected ${commandName}${moduleMessage} to only be called with with parameters matching the specified filter,$(Format-Because $Because) but $($nonMatchingCalls.Count) non-matching calls were made"
                ExpectResult   = [Pester.ShouldExpectResult]@{
                    Expected = "${commandName}${moduleMessage} to only be called with with parameters matching the specified filter"
                    Actual   = "${commandName}${moduleMessage} was called $($nonMatchingCalls.Count) times with non-matching parameters"
                    Because  = Format-Because $Because
                }
            }
        }
    }

    return [Pester.ShouldResult] @{
        Succeeded      = $true
    }
}

function Remove-MockHook {
    param (
        [Parameter(Mandatory)]
        $Hooks
    )

    $removeMockStub = {
        param (
            [string] $CommandName,
            [string[]] $Aliases,
            [bool] $Write_Debug_Enabled,
            $Write_Debug
        )

        if ($ExecutionContext.InvokeProvider.Item.Exists("Function:\$CommandName", $true, $true)) {
            $ExecutionContext.InvokeProvider.Item.Remove("Function:\$CommandName", $false, $true, $true)
            if ($Write_Debug_Enabled) {
                & $Write_Debug -Scope Mock -Message "Removed function $($CommandName)$(if ($ExecutionContext.SessionState.Module) { " from module $($ExecutionContext.SessionState.Module) session state"} else { " from script session state"})."
            }
        }
        else {
            # # this runs from OnContainerRunEnd in the mock plugin, it might be running unnecessarily
            # if ($Write_Debug_Enabled) {
            #     & $Write_Debug -Scope Mock -Message "ERROR: Function $($CommandName) was not found$(if ($ExecutionContext.SessionState.Module) { " in module $($ExecutionContext.SessionState.Module) session state"} else { " in script session state"})."
            # }
        }

        foreach ($alias in $Aliases) {
            if ($ExecutionContext.InvokeProvider.Item.Exists("Alias:$alias", $true, $true)) {
                $ExecutionContext.InvokeProvider.Item.Remove("Alias:$alias", $false, $true, $true)
                if ($Write_Debug_Enabled) {
                    & $Write_Debug -Scope Mock -Message "Removed alias $($alias)$(if ($ExecutionContext.SessionState.Module) { " from module $($ExecutionContext.SessionState.Module) session state"} else { " from script session state"})."
                }
            }
            else {
                # # this runs from OnContainerRunEnd in the mock plugin, it might be running unnecessarily
                # if ($Write_Debug_Enabled) {
                #     & $Write_Debug -Scope Mock -Message "ERROR: Alias $($alias) was not found$(if ($ExecutionContext.SessionState.Module) { " in module $($ExecutionContext.SessionState.Module) session state"} else { " in script session state"})."
                # }
            }
        }
    }

    $Write_Debug_Enabled = $PesterPreference.Debug.WriteDebugMessages.Value
    $Write_Debug = $(if ($PesterPreference.Debug.WriteDebugMessages.Value) { $SafeCommands["Write-PesterDebugMessage"] } else { $null })

    foreach ($h in $Hooks) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Mock -Message "Removing function $($h.BootstrapFunctionName)$(if($h.Aliases) { " and aliases $($h.Aliases -join ", ")" }) for$(if($h.ModuleName) { " $($h.ModuleName) -" }) $($h.CommandName)."
        }

        $null = Invoke-InMockScope -SessionState $h.SessionState -ScriptBlock $removeMockStub -Arguments $h.BootstrapFunctionName, $h.Aliases, $Write_Debug_Enabled, $Write_Debug
    }
}

function Resolve-Command {
    param (
        [string] $CommandName,
        [string] $ModuleName,
        [Parameter(Mandatory)]
        [Management.Automation.SessionState] $SessionState
    )

    # saving the caller session state here, below the command is looked up and
    # the $SessionState is overwritten with the session state in which the command
    # was found (if -ModuleName was specified), but we will be running the mock body
    # in the caller scope (in the test scope), to be able to use the variables defined in the test inside of the mock
    # so we need to hold onto the caller scope
    $callerSessionState = $SessionState

    $command = $null
    $module = $null

    $findAndResolveCommand = {
        param ($Name)

        # this scriptblock gets bound to multiple session states so we can find
        # commands in module or in caller scope
        $command = $ExecutionContext.InvokeCommand.GetCommand($Name, 'All')
        # resolve command from alias recursively
        while ($null -ne $command -and $command.CommandType -eq [System.Management.Automation.CommandTypes]::Alias) {
            $resolved = $command.ResolvedCommand
            if ($null -eq $resolved) {
                throw "Alias $($command.Name) points to a command $($command.Definition) that but the actual commands no longer exists!"
            }
            $command = $resolved
        }

        if ($command) {
            $command

            # trying to resolve metadate for non scriptblock / cmdlet results in this beautiful error:
            # PSInvalidCastException: Cannot convert value "notepad.exe" to type "System.Management.Automation.CommandMetadata".
            # Error: "Cannot perform operation because operation "NewNotSupportedException at offset 34 in file:line:column <filename unknown>:0:0
            if ($command.PSObject.Properties['ScriptBlock'] -or $command.CommandType -eq 'Cmdlet') {
                # Resolve command metadata in the same scope where we resolved the command to have
                # all custom attributes available https://github.com/pester/Pester/issues/1772
                [System.Management.Automation.CommandMetaData] $command
                # resolve it one more time because we need two instances sometimes for dynamic
                # parameters resolve
                [System.Management.Automation.CommandMetaData] $command
            }
        }
    }

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Mock "Resolving command $CommandName."
    }

    if ($ModuleName) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Mock "ModuleName was specified searching for the command in module $ModuleName."
        }

        if ($null -ne $callerSessionState.Module -and $callerSessionState.Module.Name -eq $ModuleName) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Mock "We are already running in $ModuleName. Using that."
            }

            $module = $callerSessionState.Module
            $SessionState = $callerSessionState
        }
        else {
            $module = Get-CompatibleModule -ModuleName $ModuleName -ErrorAction Stop
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Mock "Found module $($module.Name) version $($module.Version)."
            }

            # this is the target session state in which we will insert the mock
            $SessionState = $module.SessionState
        }

        $command, $commandMetadata, $commandMetadata2 = & $module $findAndResolveCommand -Name $CommandName
        if ($command) {
            if ($command.Module -eq $module) {
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Mock "Found the command $($CommandName) in module $($module.Name) version $($module.Version)$(if ($CommandName -ne $command.Name) {" and it resolved to $($command.Name)"})."
                }
            }
            else {
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Mock "Found the command $($CommandName) in a different module$(if ($CommandName -ne $command.Name) {" and it resolved to $($command.Name)"})."
                }
            }
        }
        else {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Mock "Did not find command $CommandName in module $($module.Name) version $($module.Version)."
            }
        }
    }
    else {
        # we used to fallback to the script scope when command was not found in the module, we no longer do that
        # now we just search the script scope when module name is not specified. This was probably needed because of
        # some inconsistencies of resolving the mocks. But it never made sense to me.

        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Mock "Searching for command $CommandName in the script scope."
        }
        Set-ScriptBlockScope -ScriptBlock $findAndResolveCommand -SessionState $SessionState
        $command, $commandMetadata, $commandMetadata2 = & $findAndResolveCommand -Name $CommandName
        if ($command) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Mock "Found the command $CommandName in the script scope$(if ($CommandName -ne $command.Name) {" and it resolved to $($command.Name)"})."
            }
        }
        else {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Mock "Did not find command $CommandName in the script scope."
            }
        }
    }

    if (-not $command) {
        throw ([System.Management.Automation.CommandNotFoundException] "Could not find Command $CommandName")
    }


    if ($command.Name -like 'PesterMock_*') {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope MockCore "The resolved command is a mock bootstrap function, pointing the mock to the same command info and session state as the original mock."
        }
        # the target module into which we inserted the mock
        $module = $command.Mock.Hook.SessionState.Module
        return @{
            Command                 = $command.Mock.Hook.OriginalCommand
            CommandMetadata         = $command.Mock.Hook.OriginalMetadata
            CommandMetadata2        = $command.Mock.Hook.OriginalMetadata2
            # the session state of the target module
            SessionState            = $command.Mock.Hook.SessionState
            # the session state in which we invoke the mock body (where the test runs)
            CallerSessionState      = $command.Mock.Hook.CallerSessionState
            # the module that defines the command
            Module                  = $command.Mock.Hook.OriginalCommand.Module
            # true if we inserted the mock into a module
            IsFromModule            = $null -ne $module
            TargetModule            = $ModuleName
            # true if the command comes from the target module
            IsFromTargetModule      = $null -ne $module -and $ModuleName -eq $command.Mock.Hook.OriginalCommand.Module.Name
            IsMockBootstrapFunction = $true
            Hook                    = $command.Mock.Hook
        }
    }

    $module = $command.Module
    return @{
        Command                 = $command
        CommandMetadata         = $commandMetadata
        CommandMetadata2        = $commandMetadata2
        SessionState            = $SessionState
        CallerSessionState      = $callerSessionState
        Module                  = $module

        IsFromModule            = $null -ne $module
        # The target module in which we are inserting the mock, this may not be the same as the module in which the
        # function is defined. For example when module m exports function f, and we mock it in script scope or in module o.
        # They would be the same if we mock an internal function in module m by specifying -ModuleName m, to be able to test it.
        TargetModule            = $ModuleName
        IsFromTargetModule      = $null -ne $module -and $module.Name -eq $ModuleName
        IsMockBootstrapFunction = $false
        Hook                    = $null
    }
}

function Invoke-MockInternal {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $CommandName,

        [Parameter(Mandatory = $true)]
        [hashtable] $MockCallState,

        [string]
        $ModuleName,

        [hashtable]
        $BoundParameters = @{ },

        [object[]]
        $ArgumentList = @(),

        [object] $CallerSessionState,

        [ValidateSet('Begin', 'Process', 'End')]
        [string] $FromBlock,

        [object] $InputObject,

        [Parameter(Mandatory)]
        $Behaviors,

        [Parameter(Mandatory)]
        [HashTable]
        $CallHistory,

        [Parameter(Mandatory)]
        $Hook
    )

    switch ($FromBlock) {
        Begin {
            $MockCallState['InputObjects'] = [System.Collections.Generic.List[object]]@()
            $MockCallState['ShouldExecuteOriginalCommand'] = $false
            $MockCallState['BeginBoundParameters'] = $BoundParameters.Clone()
            # argument list must not be null, if the bootstrap functions has no parameters
            # we get null and need to replace it with empty array to make the splatting work
            # later on.
            $MockCallState['BeginArgumentList'] = $ArgumentList

            return
        }

        Process {
            # the incoming caller session state is the place from where
            # the mock hook is invoked, this does not have to be the same as
            # the test "caller scope" that we saved earlier, we won't use the
            # test caller scope here, but the scope from which the mock was called
            $SessionState = if ($CallerSessionState) { $CallerSessionState } else { $Hook.SessionState }

            # the @() are needed for powerShell3 otherwise it throws CheckAutomationNullInCommandArgumentArray (unless there is any breakpoint defined anywhere, then it works just fine :DDD)
            $behavior = FindMatchingBehavior -Behaviors @($Behaviors) -BoundParameters $BoundParameters -ArgumentList @($ArgumentList) -SessionState $SessionState -Hook $Hook

            if ($null -ne $behavior) {
                $call = @{
                    BoundParams = $BoundParameters
                    Args        = $ArgumentList
                    Hook        = $Hook
                    Behavior    = $behavior
                }
                $key = "$($behavior.ModuleName)||$($behavior.CommandName)"
                if (-not $CallHistory.ContainsKey($key)) {
                    $CallHistory.Add($key, [Collections.Generic.List[object]]@($call))
                }
                else {
                    $CallHistory[$key].Add($call)
                }

                ExecuteBehavior -Behavior $behavior `
                    -Hook $Hook `
                    -BoundParameters $BoundParameters `
                    -ArgumentList @($ArgumentList)

                return
            }
            else {
                $MockCallState['ShouldExecuteOriginalCommand'] = $true
                if ($null -ne $InputObject) {
                    $null = $MockCallState['InputObjects'].AddRange(@($InputObject))
                }

                return
            }
        }

        End {
            if ($MockCallState['ShouldExecuteOriginalCommand']) {
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Mock "Invoking the original command."
                }

                $MockCallState['BeginBoundParameters'] = Reset-ConflictingParameters -BoundParameters $MockCallState['BeginBoundParameters']

                if ($MockCallState['InputObjects'].Count -gt 0) {
                    $scriptBlock = {
                        param ($Command, $ArgumentList, $BoundParameters, $InputObjects)
                        $InputObjects | & $Command @ArgumentList @BoundParameters
                    }
                }
                else {
                    $scriptBlock = {
                        param ($Command, $ArgumentList, $BoundParameters, $InputObjects)
                        & $Command @ArgumentList @BoundParameters
                    }
                }

                $SessionState = if ($CallerSessionState) {
                    $CallerSessionState
                }
                else {
                    $Hook.SessionState
                }

                Set-ScriptBlockScope -ScriptBlock $scriptBlock -SessionState $SessionState

                # In order to mock Set-Variable correctly we need to write the variable
                # two scopes above
                if ("Set-Variable" -eq $Hook.OriginalCommand.Name) {
                    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                        Write-PesterDebugMessage -Scope Mock "Original command is Set-Variable, patching the call."
                    }
                    if ($MockCallState['BeginBoundParameters'].Keys -notcontains "Scope") {
                        $MockCallState['BeginBoundParameters'].Add( "Scope", 2)
                    }
                    # local is the same as scope 0, in that case we also write to scope 2
                    elseif ("Local", "0" -contains $MockCallState['BeginBoundParameters'].Scope) {
                        $MockCallState['BeginBoundParameters'].Scope = 2
                    }
                    elseif ($MockCallState['BeginBoundParameters'].Scope -match "\d+") {
                        $MockCallState['BeginBoundParameters'].Scope = 2 + $matches[0]
                    }
                    else {
                        # not sure what the user did, but we won't change it
                    }
                }

                if ($null -eq ($MockCallState['BeginArgumentList'])) {
                    $arguments = @()
                }
                else {
                    $arguments = $MockCallState['BeginArgumentList']
                }
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-ScriptBlockInvocationHint -Hint "Mock - Original Command" -ScriptBlock $scriptBlock
                }
                & $scriptBlock -Command $Hook.OriginalCommand `
                    -ArgumentList $arguments `
                    -BoundParameters $MockCallState['BeginBoundParameters'] `
                    -InputObjects $MockCallState['InputObjects']
            }
        }
    }
}

function FindMock {
    param (
        [Parameter(Mandatory)]
        [String] $CommandName,
        $ModuleName,
        [Parameter(Mandatory)]
        [HashTable] $MockTable
    )

    $result = @{
        Mock        = $null
        MockFound   = $false
        CommandName = $CommandName
        ModuleName  = $ModuleName
    }
    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Mock "Looking for mock $($ModuleName)||$CommandName."
    }
    $MockTable["$($ModuleName)||$CommandName"]

    if ($null -ne $mock) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Mock "Found mock $(if (-not [string]::IsNullOrEmpty($ModuleName)) {"with module name $($ModuleName)"})||$CommandName."
        }
        $result.MockFound = $true
    }
    else {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Mock "No mock found, re-trying without module name ||$CommandName."
        }
        $mock = $MockTable["||$CommandName"]
        $result.ModuleName = $null
        if ($null -ne $mock) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Mock "Found mock without module name, setting the target module to empty."
            }
            $result.MockFound = $true
        }
        else {
            $result.MockFound = $false
        }
    }

    return $result
}

function FindMatchingBehavior {
    param (
        [Parameter(Mandatory)]
        $Behaviors,
        [hashtable] $BoundParameters = @{ },
        [object[]] $ArgumentList = @(),
        [Parameter(Mandatory)]
        [Management.Automation.SessionState] $SessionState,
        $Hook
    )

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Mock "Finding behavior to use, one that passes filter or a default:"
    }

    $foundDefaultBehavior = $false
    $defaultBehavior = $null
    foreach ($b in $Behaviors) {

        if ($b.IsDefault -and -not $foundDefaultBehavior) {
            # store the most recently defined default behavior we find
            $defaultBehavior = $b
            $foundDefaultBehavior = $true
        }

        if (-not $b.IsDefault) {
            $params = @{
                ScriptBlock     = $b.Filter
                BoundParameters = $BoundParameters
                ArgumentList    = $ArgumentList
                Metadata        = $Hook.Metadata
                SessionState    = $Hook.CallerSessionState
            }

            if (Test-ParameterFilter @params) {
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Mock "{ $($b.ScriptBlock) } passed parameter filter and will be used for the mock call."
                }
                return $b
            }
        }
    }

    if ($foundDefaultBehavior) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Mock "{ $($defaultBehavior.ScriptBlock) } is a default behavior and will be used for the mock call."
        }
        return $defaultBehavior
    }

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Mock "No parametrized or default behaviors were found filter."
    }
    return $null
}

function LastThat {
    param (
        $Collection,
        $Predicate
    )

    $count = $Collection.Count
    for ($i = $count; $i -gt 0; $i--) {
        $item = $Collection[$i]
        if (&$Predicate $Item) {
            return $Item
        }
    }
}


function ExecuteBehavior {
    param (
        $Behavior,
        $Hook,
        [hashtable] $BoundParameters = @{ },
        [object[]] $ArgumentList = @()
    )

    $ModuleName = $Behavior.ModuleName
    $CommandName = $Behavior.CommandName
    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Mock "Executing mock behavior for mock$(if ($ModuleName) {" $ModuleName -" }) $CommandName."
    }

    $Behavior.Executed = $true

    $scriptBlock = {
        param (
            [Parameter(Mandatory = $true)]
            [scriptblock]
            ${Script Block},

            [hashtable]
            $___BoundParameters___ = @{ },

            [object[]]
            $___ArgumentList___ = @(),

            [System.Management.Automation.CommandMetadata]
            ${Meta data},

            [System.Management.Automation.SessionState]
            ${Session State},

            ${R e p o r t S c o p e},

            ${M o d u l e N a m e},

            ${Set Dynamic Parameter Variable}
        )

        # This script block exists to hold variables without polluting the test script's current scope.
        # Dynamic parameters in functions, for some reason, only exist in $PSBoundParameters instead
        # of being assigned a local variable the way static parameters do.  By calling Set-DynamicParameterVariable,
        # we create these variables for the caller's use in a Parameter Filter or within the mock itself, and
        # by doing it inside this temporary script block, those variables don't stick around longer than they
        # should.

        & ${Set Dynamic Parameter Variable} -SessionState ${Session State} -Parameters $___BoundParameters___ -Metadata ${Meta data}
        # Name property is not present on Application Command metadata in PowerShell 2
        & ${R e p o r t S c o p e} -ModuleName ${M o d u l e N a m e} -CommandName $(try {
                ${Meta data}.Name
            }
            catch {
            }) -ScriptBlock ${Script Block}
        # define this in the current scope to be used instead of $PSBoundParameter if needed
        $PesterBoundParameters = if ($null -ne $___BoundParameters___) { $___BoundParameters___ } else { @{} }
        & ${Script Block} @___BoundParameters___ @___ArgumentList___
    }

    if ($null -eq $Hook) {
        throw "Hook should not be null."
    }

    if ($null -eq $Hook.SessionState) {
        throw "Hook.SessionState should not be null."
    }

    Set-ScriptBlockScope -ScriptBlock $scriptBlock -SessionState $Hook.CallerSessionState
    $splat = @{
        'Script Block'                   = $Behavior.ScriptBlock
        '___ArgumentList___'             = $ArgumentList
        '___BoundParameters___'          = $BoundParameters
        'Meta data'                      = $Hook.Metadata
        'Session State'                  = $Hook.CallerSessionState
        'R e p o r t S c o p e'          = {
            param ($CommandName, $ModuleName, $ScriptBlock)
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-ScriptBlockInvocationHint -Hint "Mock - of command $CommandName$(if ($ModuleName) { "from module $ModuleName"})" -ScriptBlock $ScriptBlock
            }
        }
        'Set Dynamic Parameter Variable' = $SafeCommands['Set-DynamicParameterVariable']
    }

    # the real scriptblock is passed to the other one, we are interested in the mock, not the wrapper, so I pass $block.ScriptBlock, and not $scriptBlock
    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-ScriptBlockInvocationHint -Hint "Mock - of command $CommandName$(if ($ModuleName) { "from module $ModuleName"})" -ScriptBlock ($behavior.ScriptBlock)
    }
    & $scriptBlock @splat
    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Mock "Behavior for$(if ($ModuleName) { " $ModuleName -"}) $CommandName was executed."
    }
}

function Invoke-InMockScope {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.SessionState]
        $SessionState,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true)]
        $Arguments,

        [Switch]
        $NoNewScope
    )

    Set-ScriptBlockScope -ScriptBlock $ScriptBlock -SessionState $SessionState
    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-ScriptBlockInvocationHint -Hint "Mock - InMockScope" -ScriptBlock $ScriptBlock
    }
    if ($NoNewScope) {
        . $ScriptBlock @Arguments
    }
    else {
        & $ScriptBlock @Arguments
    }
}

function Test-ParameterFilter {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [System.Collections.IDictionary]
        $BoundParameters,

        [object[]]
        $ArgumentList,

        [System.Management.Automation.CommandMetadata]
        $Metadata,

        [Parameter(Mandatory)]
        [Management.Automation.SessionState]
        $SessionState
    )

    if ($null -eq $BoundParameters) {
        $BoundParameters = @{ }
    }

    $arguments = $ArgumentList
    # $() gets rid of the @() defined for powershell 3
    if ($null -eq $($ArgumentList)) {
        $arguments = @()
    }

    $context = Get-ContextToDefine -BoundParameters $BoundParameters -Metadata $Metadata

    $wrapper = {
        param ($private:______mock_parameters)
        & $private:______mock_parameters.Set_StrictMode -Off

        foreach ($private:______current in $private:______mock_parameters.Context.GetEnumerator()) {
            $private:______mock_parameters.SessionState.PSVariable.Set($private:______current.Key, $private:______current.Value)
        }

        # define this in the current scope to be used instead of $PSBoundParameter if needed
        $PesterBoundParameters = if ($null -ne $private:______mock_parameters.Context) { $private:______mock_parameters.Context } else { @{} }

        #TODO: a hacky solution to make Should throw on failure in Mock ParameterFilter, to make it good enough for the first release $______isInMockParameterFilter
        # this should not be private, it should leak into Should command when used in ParameterFilter
        $______isInMockParameterFilter = $true
        # $private:BoundParameters = $private:______mock_parameters.BoundParameters
        $private:______arguments = $private:______mock_parameters.Arguments
        # TODO: not binding the bound parameters here because it would make the parameters unbound when the user does
        # not provide a param block, which they would never provide, so that is okay, but if there is a workaround this then
        # it would be nice to have. maybe changing the order in which I bind?
        & $private:______mock_parameters.ScriptBlock @______arguments
    }

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        $hasContext = 0 -lt $Context.Count
        $c = $(if ($hasContext) { foreach ($p in $Context.GetEnumerator()) { "$($p.Key) = $($p.Value)" } }) -join ", "
        Write-PesterDebugMessage -Scope Mock -Message "Running mock filter { $scriptBlock } $(if ($hasContext) { "with context: $c" } else { "without any context"})."
    }

    Set-ScriptBlockScope -ScriptBlock $wrapper -SessionState $SessionState

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-ScriptBlockInvocationHint -Hint "Mock - Parameter filter" -ScriptBlock $wrapper
    }
    $parameters = @{
        ScriptBlock        = $ScriptBlock
        BoundParameters    = $BoundParameters
        Arguments          = $Arguments
        SessionState       = $SessionState
        Context            = $context
        Set_StrictMode     = $SafeCommands['Set-StrictMode']
        WriteDebugMessages = $PesterPreference.Debug.WriteDebugMessages.Value
        Write_DebugMessage = if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            { param ($Message) & $SafeCommands["Write-PesterDebugMessage"] -Scope Mock -Message $Message }
        }
        else { $null }
    }

    $result = & $wrapper $parameters
    if ($result) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Mock -Message "Mock filter returned value '$result', which is truthy. Filter passed."
        }
    }
    else {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Mock -Message "Mock filter returned value '$result', which is falsy. Filter did not pass."
        }
    }
    $result
}

function Get-ContextToDefine {
    param (
        [System.Collections.IDictionary] $BoundParameters,
        [System.Management.Automation.CommandMetadata] $Metadata
    )

    $conflictingParameterNames = Get-ConflictingParameterNames
    $r = @{ }
    # key the parameters by aliases so we can resolve to
    # the param itself and define it and all of it's aliases
    $h = @{ }
    if ($null -eq $Metadata) {
        # there is no metadata so there will be no aliases
        # return the parameters that we got, just fix the conflicting
        # names
        foreach ($p in $BoundParameters.GetEnumerator()) {
            $name = if ($p.Key -in $conflictingParameterNames) {
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Mock -Message "! Variable `$$($p.Key) is a built-in variable, rewriting it to `$_$($p.Key). Use the version with _ in your -ParameterFilter."
                }
                "_$($p.Key)"
            }
            else {
                $p.Key
            }

            $r.Add($name, $p.Value)
        }

        return $r
    }

    foreach ($p in $Metadata.Parameters.GetEnumerator()) {
        $aliases = $p.Value.Aliases
        if ($null -ne $aliases -and 0 -lt @($aliases).Count) {
            foreach ($a in $aliases) { $h.Add($a, $p) }
        }
    }

    foreach ($param in $BoundParameters.GetEnumerator()) {
        $parameterInfo = if ($h.ContainsKey($param.Key)) {
            $h.($param.Key)
        }
        elseif ($Metadata.Parameters.ContainsKey($param.Key)) {
            $Metadata.Parameters.($param.Key)
        }

        $value = $param.Value

        if ($parameterInfo) {
            foreach ($p in $parameterInfo) {
                $name = if ($p.Name -in $conflictingParameterNames) {
                    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                        Write-PesterDebugMessage -Scope Mock -Message "! Variable `$$($p.Name) is a built-in variable, rewriting it to `$_$($p.Name). Use the version with _ in your -ParameterFilter."
                    }
                    "_$($p.Name)"
                }
                else {
                    $p.Name
                }

                if (-not $r.ContainsKey($name)) {
                    $r.Add($name, $value)
                }

                foreach ($a in $p.Aliases) {
                    $name = if ($a -in $conflictingParameterNames) {
                        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                            Write-PesterDebugMessage -Scope Mock -Message "! Variable `$$($a) is a built-in variable, rewriting it to `$_$($a). Use the version with _ in your -ParameterFilter."
                        }
                        "_$($a)"
                    }
                    else {
                        $a
                    }

                    if (-not $r.ContainsKey($name)) {
                        $r.Add($name, $value)
                    }
                }
            }
        }
        else {
            # the parameter is not defined in the parameter set,
            # it is probably dynamic, let's see if I can get away with just adding
            # it to the list of stuff to define

            $name = if ($param.Key -in $script:ConflictingParameterNames) {
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Mock -Message "! Variable `$$($param.Key) is a built-in variable, rewriting it to `$_$($param.Key). Use the version with _ in your -ParameterFilter."
                }
                "_$($param.Key)"
            }
            else {
                $param.Key
            }

            if (-not $r.ContainsKey($name)) {
                $r.Add($name, $param.Value)
            }
        }
    }

    $r
}

function IsCommonParameter {
    param (
        [string] $Name,
        [System.Management.Automation.CommandMetadata] $Metadata
    )

    if ($null -ne $Metadata) {
        if ([System.Management.Automation.Internal.CommonParameters].GetProperty($Name)) {
            return $true
        }
        if ($Metadata.SupportsShouldProcess -and [System.Management.Automation.Internal.ShouldProcessParameters].GetProperty($Name)) {
            return $true
        }
        if ($Metadata.SupportsPaging -and [System.Management.Automation.PagingParameters].GetProperty($Name)) {
            return $true
        }
        if ($Metadata.SupportsTransactions -and [System.Management.Automation.Internal.TransactionParameters].GetProperty($Name)) {
            return $true
        }
    }

    return $false
}

function Set-DynamicParameterVariable {
    <#
        .SYNOPSIS
        This command is used by Pester's Mocking framework.  You do not need to call it directly.
    #>

    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.SessionState]
        $SessionState,

        [hashtable]
        $Parameters,

        [System.Management.Automation.CommandMetadata]
        $Metadata
    )

    if ($null -eq $Parameters) {
        $Parameters = @{ }
    }

    foreach ($keyValuePair in $Parameters.GetEnumerator()) {
        $variableName = $keyValuePair.Key

        if (-not (IsCommonParameter -Name $variableName -Metadata $Metadata)) {
            if ($ExecutionContext.SessionState -eq $SessionState) {
                & $SafeCommands['Set-Variable'] -Scope 1 -Name $variableName -Value $keyValuePair.Value -Force -Confirm:$false -WhatIf:$false
            }
            else {
                $SessionState.PSVariable.Set($variableName, $keyValuePair.Value)
            }
        }
    }
}

function Get-DynamicParamBlock {
    param (
        [scriptblock] $ScriptBlock
    )

    if ($ScriptBlock.AST.psobject.Properties.Name -match "Body") {
        if ($null -ne $ScriptBlock.Ast.Body.DynamicParamBlock) {
            $statements = $ScriptBlock.Ast.Body.DynamicParamBlock.Statements.Extent.Text

            return $statements -join [System.Environment]::NewLine
        }
    }
}

function Get-MockDynamicParameter {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Cmdlet')]
        [string] $CmdletName,

        [Parameter(Mandatory = $true, ParameterSetName = 'Function')]
        [string] $FunctionName,

        [Parameter(ParameterSetName = 'Function')]
        [string] $ModuleName,

        [System.Collections.IDictionary] $Parameters,

        [object] $Cmdlet,

        [Parameter(ParameterSetName = "Function")]
        $DynamicParamScriptBlock
    )

    switch ($PSCmdlet.ParameterSetName) {
        'Cmdlet' {
            Get-DynamicParametersForCmdlet -CmdletName $CmdletName -Parameters $Parameters
        }

        'Function' {
            Get-DynamicParametersForMockedFunction -DynamicParamScriptBlock $DynamicParamScriptBlock -Parameters $Parameters -Cmdlet $Cmdlet
        }
    }
}

function Get-DynamicParametersForCmdlet {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $CmdletName,

        [ValidateScript( {
                if ($PSVersionTable.PSVersion.Major -ge 3 -and
                    $null -ne $_ -and
                    $_.GetType().FullName -ne 'System.Management.Automation.PSBoundParametersDictionary') {
                    throw 'The -Parameters argument must be a PSBoundParametersDictionary object ($PSBoundParameters).'
                }

                return $true
            })]
        [System.Collections.IDictionary] $Parameters
    )

    try {
        $command = & $SafeCommands['Get-Command'] -Name $CmdletName -CommandType Cmdlet -ErrorAction Stop

        if (@($command).Count -gt 1) {
            throw "Name '$CmdletName' resolved to multiple Cmdlets"
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }

    if ($null -eq $command.ImplementingType.GetInterface('IDynamicParameters', $true)) {
        return
    }

    if ('5.0.10586.122' -lt $PSVersionTable.PSVersion) {
        # Older version of PS required Reflection to do this.  It has run into problems on occasion with certain cmdlets,
        # such as ActiveDirectory and AzureRM, so we'll take advantage of the newer PSv5 engine features if at all possible.

        if ($null -eq $Parameters) {
            $paramsArg = @()
        }
        else {
            $paramsArg = @($Parameters)
        }

        $command = $ExecutionContext.InvokeCommand.GetCommand($CmdletName, [System.Management.Automation.CommandTypes]::Cmdlet, $paramsArg)
        $paramDictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()

        foreach ($param in $command.Parameters.Values) {
            if (-not $param.IsDynamic) {
                continue
            }
            if ($Parameters.ContainsKey($param.Name)) {
                continue
            }

            $dynParam = [System.Management.Automation.RuntimeDefinedParameter]::new($param.Name, $param.ParameterType, $param.Attributes)
            $paramDictionary.Add($param.Name, $dynParam)
        }

        return $paramDictionary
    }
    else {
        if ($null -eq $Parameters) {
            $Parameters = @{ }
        }

        $cmdlet = ($command.ImplementingType)::new()

        $flags = [System.Reflection.BindingFlags]'Instance, Nonpublic'
        $context = $ExecutionContext.GetType().GetField('_context', $flags).GetValue($ExecutionContext)
        [System.Management.Automation.Cmdlet].GetProperty('Context', $flags).SetValue($cmdlet, $context, $null)

        foreach ($keyValuePair in $Parameters.GetEnumerator()) {
            $property = $cmdlet.GetType().GetProperty($keyValuePair.Key)
            if ($null -eq $property -or -not $property.CanWrite) {
                continue
            }

            $isParameter = [bool]($property.GetCustomAttributes([System.Management.Automation.ParameterAttribute], $true))
            if (-not $isParameter) {
                continue
            }

            $property.SetValue($cmdlet, $keyValuePair.Value, $null)
        }

        try {
            # This unary comma is important in some cases.  On Windows 7 systems, the ActiveDirectory module cmdlets
            # return objects from this method which implement IEnumerable for some reason, and even cause PowerShell
            # to throw an exception when it tries to cast the object to that interface.

            # We avoid that problem by wrapping the result of GetDynamicParameters() in a one-element array with the
            # unary comma.  PowerShell enumerates that array instead of trying to enumerate the goofy object, and
            # everyone's happy.

            # Love the comma.  Don't delete it.  We don't have a test for this yet, unless we can get the AD module
            # on a Server 2008 R2 build server, or until we write some C# code to reproduce its goofy behavior.

            , $cmdlet.GetDynamicParameters()
        }
        catch [System.NotImplementedException] {
            # Some cmdlets implement IDynamicParameters but then throw a NotImplementedException.  I have no idea why.  Ignore them.
        }
    }
}

function Get-DynamicParametersForMockedFunction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $DynamicParamScriptBlock,

        [System.Collections.IDictionary]
        $Parameters,

        [object]
        $Cmdlet
    )

    if ($DynamicParamScriptBlock) {
        $splat = @{ 'P S Cmdlet' = $Cmdlet }
        return & $DynamicParamScriptBlock @Parameters @splat
    }
}

function Test-IsClosure {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    $sessionStateInternal = $script:ScriptBlockSessionStateInternalProperty.GetValue($ScriptBlock)
    if ($null -eq $sessionStateInternal) {
        return $false
    }

    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
    $module = $sessionStateInternal.GetType().GetProperty('Module', $flags).GetValue($sessionStateInternal, $null)

    return (
        $null -ne $module -and
        $module.Name -match '^__DynamicModule_([a-f\d-]+)$' -and
        $null -ne ($matches[1] -as [guid])
    )
}

function Remove-MockFunctionsAndAliases ($SessionState) {
    # when a test is terminated (e.g. by stopping at a breakpoint and then stopping the execution of the script)
    # the aliases and bootstrap functions for the currently mocked functions will remain in place
    # Then on subsequent runs the bootstrap function will be picked up instead of the real command,
    # because there is still an alias associated with it, and the test will fail.
    # So before putting Pester state in place we should make sure that all Pester mocks are gone
    # by deleting every alias pointing to a function that starts with PesterMock_. Then we also delete the
    # bootstrap function.
    #
    # Avoid using Get-Command to find mock functions, it is slow. https://github.com/pester/Pester/discussions/2331
    $Get_Alias = $script:SafeCommands['Get-Alias']
    $Get_ChildItem = $script:SafeCommands['Get-ChildItem']
    $Remove_Item = $script:SafeCommands['Remove-Item']
    foreach ($alias in (& $Get_Alias -Definition "PesterMock_*")) {
        & $Remove_Item "alias:/$($alias.Name)"
    }

    foreach ($bootstrapFunction in (& $Get_ChildItem -Name "function:/PesterMock_*")) {
        & $Remove_Item "function:/$($bootstrapFunction)" -Recurse -Force -Confirm:$false
    }

    $ScriptBlock = {
        param ($Get_Alias, $Get_ChildItem, $Remove_Item)
        foreach ($alias in (& $Get_Alias -Definition "PesterMock_*")) {
            & $Remove_Item "alias:/$($alias.Name)"
        }

        foreach ($bootstrapFunction in (& $Get_ChildItem -Name "function:/PesterMock_*")) {
            & $Remove_Item "function:/$($bootstrapFunction)" -Recurse -Force -Confirm:$false
        }
    }

    # clean up in caller session state
    Set-ScriptBlockScope -SessionState $SessionState -ScriptBlock $ScriptBlock
    & $ScriptBlock $Get_Alias $Get_ChildItem $Remove_Item

    # clean up also in all loaded script and manifest modules
    $modules = & $script:SafeCommands['Get-Module']
    foreach ($module in $modules) {
        # we cleaned up in module on the start of this method without overhead of moving to module scope
        if ('pester' -eq $module.Name) {
            continue
        }

        # some script modules apparently can have no session state
        # https://github.com/PowerShell/PowerShell/blob/658837323599ab1c7a81fe66fcd43f7420e4402b/src/System.Management.Automation/engine/runtime/Operations/MiscOps.cs#L51-L55
        # https://github.com/pester/Pester/issues/1921
        if ('Script', 'Manifest' -contains $module.ModuleType -and $null -ne $module.SessionState) {
            & ($module) $ScriptBlock $Get_Alias $Get_ChildItem $Remove_Item
        }
    }
}

function Repair-ConflictingParameters {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.CommandMetadata])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.CommandMetadata]
        $Metadata,
        [Parameter()]
        [string[]]
        $RemoveParameterType,
        [Parameter()]
        [string[]]
        $RemoveParameterValidation
    )

    $repairedMetadata = [System.Management.Automation.CommandMetadata]$Metadata
    $paramMetadatas = [Collections.Generic.List[object]]@($repairedMetadata.Parameters.Values)

    # unnecessary function call that could be replaced by variable access, but is needed for tests
    $conflictingParams = Get-ConflictingParameterNames

    foreach ($paramMetadata in $paramMetadatas) {
        if ($paramMetadata.IsDynamic) {
            continue
        }

        # rewrite the metadata to avoid defining conflicting parameters
        # in the function such as $PSEdition
        if ($conflictingParams -contains $paramMetadata.Name) {
            $paramName = $paramMetadata.Name
            $newName = "_$paramName"
            $paramMetadata.Name = $newName
            $paramMetadata.Aliases.Add($paramName)

            $null = $repairedMetadata.Parameters.Remove($paramName)
            $repairedMetadata.Parameters.Add($newName, $paramMetadata)
        }

        $attrIndexesToRemove = [System.Collections.Generic.List[int]]@()

        if ($RemoveParameterType -contains $paramMetadata.Name) {
            $paramMetadata.ParameterType = [object]

            for ($i = 0; $i -lt $paramMetadata.Attributes.Count; $i++) {
                $attr = $paramMetadata.Attributes[$i]
                if ($attr -is [PSTypeNameAttribute]) {
                    $null = $attrIndexesToRemove.Add($i)
                    break
                }
            }
        }

        if ($RemoveParameterValidation -contains $paramMetadata.Name) {
            for ($i = 0; $i -lt $paramMetadata.Attributes.Count; $i++) {
                $attr = $paramMetadata.Attributes[$i]
                if ($attr -is [System.Management.Automation.ValidateArgumentsAttribute]) {
                    $null = $attrIndexesToRemove.Add($i)
                }
            }
        }

        # remove attributes in reverse order to avoid index shifting
        $attrIndexesToRemove.Sort()
        $attrIndexesToRemove.Reverse()
        foreach ($index in $attrIndexesToRemove) {
            $null = $paramMetadata.Attributes.RemoveAt($index)
        }
    }

    $repairedMetadata
}

function Reset-ConflictingParameters {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]
        $BoundParameters
    )

    $parameters = $BoundParameters.Clone()
    # unnecessary function call that could be replaced by variable access, but is needed for tests
    $names = Get-ConflictingParameterNames

    foreach ($param in $names) {
        $fixedName = "_$param"

        if (-not $parameters.ContainsKey($fixedName)) {
            continue
        }

        $parameters[$param] = $parameters[$fixedName]
        $null = $parameters.Remove($fixedName)
    }

    $parameters
}

$script:ConflictingParameterNames = @(
    '?'
    'ConsoleFileName'
    'EnabledExperimentalFeatures'
    'Error'
    'ExecutionContext'
    'false'
    'HOME'
    'Host'
    'IsCoreCLR'
    'IsMacOS'
    'IsWindows'
    'PID'
    'PSCulture'
    'PSEdition'
    'PSHOME'
    'PSUICulture'
    'PSVersionTable'
    'ShellId'
    'true'
)

function Get-ConflictingParameterNames {
    $script:ConflictingParameterNames
}

# TODO: Remove?
function Get-ScriptBlockAST {
    param (
        [scriptblock]
        $ScriptBlock
    )

    if ($ScriptBlock.Ast -is [System.Management.Automation.Language.ScriptBlockAst]) {
        $ast = $Block.Ast.EndBlock
    }
    elseif ($ScriptBlock.Ast -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
        $ast = $Block.Ast.Body.EndBlock
    }
    else {
        throw "Pester failed to parse ParameterFilter, scriptblock is invalid type. Please reformat your ParameterFilter."
    }

    return $ast
}

# TODO: Remove?
function New-BlockWithoutParameterAliases {
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Management.Automation.CommandMetadata]
        $Metadata,
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [scriptblock]
        $Block
    )
    try {
        if ($PSVersionTable.PSVersion.Major -ge 3) {
            $params = $Metadata.Parameters.Values
            $ast = Get-ScriptBlockAST $Block
            $blockText = $ast.Extent.Text
            $variables = [array]($Ast.FindAll( { param($ast) $ast -is [System.Management.Automation.Language.VariableExpressionAst] }, $true))
            [array]::Reverse($variables)

            foreach ($var in $variables) {
                $varName = $var.VariablePath.UserPath
                $length = $varName.Length

                foreach ($param in $params) {
                    if ($param.Aliases -contains $varName) {
                        $startIndex = $var.Extent.StartOffset - $ast.Extent.StartOffset + 1 # move one position after the dollar sign

                        $blockText = $blockText.Remove($startIndex, $length).Insert($startIndex, $param.Name)

                        break # It is safe to stop checking for further params here, since aliases cannot be shared by parameters
                    }
                }
            }

            $Block = [scriptblock]::Create($blockText)
        }

        $Block
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Repair-EnumParameters {
    param (
        [string]
        $ParamBlock,
        [System.Management.Automation.CommandMetadata]
        $Metadata
    )

    # proxycommand breaks ValidateRange for enum-parameters
    # broken arguments (unquoted strings) will show as NamedArguments in ast, while valid arguments are PositionalArguments.
    # https://github.com/pester/Pester/issues/1496
    # https://github.com/PowerShell/PowerShell/issues/17546
    $ast = [System.Management.Automation.Language.Parser]::ParseInput("param($ParamBlock)", [ref]$null, [ref]$null)
    $brokenValidateRange = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.AttributeAst] -and
            $node.TypeName.Name -match '(?:ValidateRange|System\.Management\.Automation\.ValidateRangeAttribute)$' -and
            $node.NamedArguments.Count -gt 0 -and
            # triple checking for broken argument - it won't have a value/expression
            $node.NamedArguments.ExpressionOmitted -notcontains $false
        }, $false)

    if ($brokenValidateRange.Count -eq 0) {
        # No errors found. Return original string
        return $ParamBlock
    }

    $sb = [System.Text.StringBuilder]::new($ParamBlock)

    foreach ($attr in $brokenValidateRange) {
        $paramName = $attr.Parent.Name.VariablePath.UserPath
        $originalAttribute = $Metadata.Parameters[$paramName].Attributes | & $SafeCommands['Where-Object'] { $_ -is [ValidateRange] }
        $enumType = @($originalAttribute)[0].MinRange.GetType()
        if (-not $enumType.IsEnum) { continue }

        # prefix arguments with [My.Enum.Type]::
        $enumPrefix = "[$($enumType.FullName)]::"
        $fixedValidation = $attr.Extent.Text -replace '(\w+)(?=,\s|\)\])', "$enumPrefix`$1"

        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Mock -Message "Fixed ValidateRange-attribute parameter '$paramName' from '$($attr.Extent.Text)' to '$fixedValidation'"
        }

        # make sure we modify the correct parameter by modifying the whole thing
        $orgParameter = $attr.Parent.Extent.Text
        $fixedParameter = $orgParameter.Replace($attr.Extent.Text, $fixedValidation)
        $null = $sb.Replace($orgParameter, $fixedParameter)
    }

    $sb.ToString()
}
