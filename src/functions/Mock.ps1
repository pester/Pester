

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
    [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($Content)
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
                $null = $metadata.Parameters.Remove($p.Name)
            }
        }
        $cmdletBinding = [Management.Automation.ProxyCommand]::GetCmdletBindingAttribute($metadata)
        if ($contextInfo.Command.CommandType -eq 'Cmdlet') {
            if ($cmdletBinding -ne '[CmdletBinding()]') {
                $cmdletBinding = $cmdletBinding.Insert($cmdletBinding.Length - 2, ',')
            }
            $cmdletBinding = $cmdletBinding.Insert($cmdletBinding.Length - 2, 'PositionalBinding=$false')
        }

        $metadata = Repair-ConflictingParameters -Metadata $metadata -RemoveParameterType $RemoveParameterType -RemoveParameterValidation $RemoveParameterValidation
        $paramBlock = [Management.Automation.ProxyCommand]::GetParamBlock($metadata)
        $paramBlock = Repair-EnumParameters -ParamBlock $paramBlock -Metadata $metadata

        # Repair-ConflictingParameters above strips validation from the static parameters, but it skips
        # dynamic parameters because they are not part of the static param block. To make
        # -RemoveParameterValidation reach a dynamic parameter (e.g. a dynamic -Name with a ValidateSet)
        # we forward the names to Get-MockDynamicParameter, which removes the validation attributes from
        # the dynamic parameters as they are produced for each call. (#1557)
        $removeValidationArg = ''
        if ($RemoveParameterValidation) {
            $escapedValidationNames = foreach ($n in $RemoveParameterValidation) { "'$(EscapeSingleQuotedStringContent $n)'" }
            $removeValidationArg = " -RemoveParameterValidation @($($escapedValidationNames -join ','))"
        }

        if ($contextInfo.Command.CommandType -eq 'Cmdlet') {
            $dynamicParamBlock = "dynamicparam { & `$MyInvocation.MyCommand.Mock.Get_MockDynamicParameter -CmdletName '$($contextInfo.Command.Name)' -Parameters `$PSBoundParameters$removeValidationArg }"
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
                $dynamicParamBlock = "dynamicparam { & `$MyInvocation.MyCommand.Mock.Get_MockDynamicParameter -ModuleName '$moduleName' -FunctionName '$commandName' -Parameters `$PSBoundParameters -Cmdlet `$PSCmdlet -DynamicParamScriptBlock `$MyInvocation.MyCommand.Mock.Hook.DynamicParamScriptBlock$removeValidationArg }"

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
        -MockPSCmdlet `$MyInvocation.MyCommand.Mock.PSCmdlet ```
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
        IsGlobal                = $false
        # The run that created this mock. A global mock installs a script-scope bootstrap alias in this
        # run; if that alias leaks into a nested Invoke-Pester run, the bootstrap compares this id to the
        # currently executing run and defers to the original command when they differ (see Invoke-Mock).
        OwnerRunId              = [Pester.GlobalMockHook]::CurrentRunId
        BootstrapFunctionInfo   = $null
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

    # keep a reference to the bootstrap function so a global mock can register it with the
    # engine-level command-lookup hook (see Register-GlobalMockHook). We store it on the hook
    # instead of registering here, so both freshly created and reused hooks go through the same path.
    $mock.BootstrapFunctionInfo = $definedFunction

    $mock
}

function Register-GlobalMockHook {
    # Makes a mock global by pointing the runspace-wide command-lookup hook at the mock's bootstrap
    # function. After this, a call to the mocked command from any module or script in the runspace is
    # redirected to the mock, not just calls from the session state where the mock was defined.
    param (
        [Parameter(Mandatory)]
        $Hook
    )

    $Hook.IsGlobal = $true

    foreach ($alias in $Hook.Aliases) {
        [Pester.GlobalMockHook]::Register($alias, $Hook.BootstrapFunctionInfo)
    }

    # Install our handler into the current runspace. This is idempotent: we remove any existing instance
    # of our handler first, so repeated runs in the same process don't stack duplicates, and so the
    # handler we later remove in teardown is the exact same delegate instance. Other consumers of
    # PreCommandLookupAction are preserved via Delegate.Combine.
    $invokeCommand = $ExecutionContext.SessionState.InvokeCommand
    $handler = [Pester.GlobalMockHook]::Handler
    $existing = $invokeCommand.PreCommandLookupAction
    if ($null -ne $existing) {
        $existing = [Delegate]::Remove($existing, $handler)
    }
    $invokeCommand.PreCommandLookupAction = [Delegate]::Combine($existing, $handler)

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Mock -Message "Registered global mock hook for aliases $($Hook.Aliases -join ', ')."
    }
}

function Unregister-GlobalMockHook {
    # Undoes Register-GlobalMockHook for a single hook. When the last global mock is removed we also
    # detach our handler from the runspace, so there is zero lookup overhead once no global mocks exist.
    param (
        [Parameter(Mandatory)]
        $Hook
    )

    foreach ($alias in $Hook.Aliases) {
        [Pester.GlobalMockHook]::Unregister($alias)
    }

    if (0 -eq [Pester.GlobalMockHook]::Count) {
        $invokeCommand = $ExecutionContext.SessionState.InvokeCommand
        $handler = [Pester.GlobalMockHook]::Handler
        $existing = $invokeCommand.PreCommandLookupAction
        if ($null -ne $existing) {
            $invokeCommand.PreCommandLookupAction = [Delegate]::Remove($existing, $handler)
        }

        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Mock -Message "Removed the global mock hook from the runspace, no global mocks remain."
        }
    }
}

function Reset-GlobalMockHook {
    # Detach our command-lookup handler and drop every global mock registration. The registry and the
    # handler are runspace-wide state that outlives a single test, so an interrupted run (for example a
    # Ctrl+C during a global mock) can leave them armed. Invoke-Pester calls this at the start of a
    # top-level run to clear anything a previous run left behind, and around a nested run to give it a
    # clean slate. Removes only our own handler instance, so other PreCommandLookupAction consumers are
    # preserved.
    $invokeCommand = $ExecutionContext.SessionState.InvokeCommand
    $handler = [Pester.GlobalMockHook]::Handler
    $existing = $invokeCommand.PreCommandLookupAction
    if ($null -ne $existing) {
        $invokeCommand.PreCommandLookupAction = [Delegate]::Remove($existing, $handler)
    }

    [Pester.GlobalMockHook]::Clear()
}

function Get-GlobalMockHookState {
    # Snapshot the current global mock registrations so a nested Pester run can clear the shared state for
    # itself and restore the outer run's global mocks afterwards (see Restore-GlobalMockHookState).
    [Pester.GlobalMockHook]::GetSnapshot()
}

function Restore-GlobalMockHookState {
    # Restore a snapshot taken by Get-GlobalMockHookState. Clears whatever the nested run left behind,
    # re-registers the saved entries, and installs or removes our command-lookup handler so its presence
    # matches whether any global mocks remain.
    param (
        $State
    )

    [Pester.GlobalMockHook]::Clear()

    if ($null -ne $State) {
        foreach ($name in $State.Keys) {
            [Pester.GlobalMockHook]::Register($name, $State[$name])
        }
    }

    $invokeCommand = $ExecutionContext.SessionState.InvokeCommand
    $handler = [Pester.GlobalMockHook]::Handler
    $existing = $invokeCommand.PreCommandLookupAction
    if ($null -ne $existing) {
        # remove any current instance of our handler first, so we never end up with a duplicate
        $existing = [Delegate]::Remove($existing, $handler)
    }

    if (0 -lt [Pester.GlobalMockHook]::Count) {
        $invokeCommand.PreCommandLookupAction = [Delegate]::Combine($existing, $handler)
    }
    else {
        $invokeCommand.PreCommandLookupAction = $existing
    }
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
        Succeeded = $true
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
            ScriptBlock         = $filter
            BoundParameters     = $historyEntry.BoundParams
            ArgumentList        = $historyEntry.Args
            Metadata            = $ContextInfo.Hook.Metadata
            # do not use the caller session state from the hook, the parameter filter
            # on Should -Invoke can come from a different session state if inModuleScope is used to
            # wrap it. Use the caller session state to which the scriptblock is bound
            SessionState        = $SessionState
            DynamicParamAliases = $historyEntry.DynamicParamAliases
        }

        # if ($null -ne $ContextInfo.Hook.Metadata -and $null -ne $params.ScriptBlock) {
        #     $params.ScriptBlock = New-BlockWithoutParameterAliases -Metadata $ContextInfo.Hook.Metadata -Block $params.ScriptBlock
        # }

        $filterResult = Test-ParameterFilter @params
        $passed = $filterResult[0]
        if ($passed) {
            $null = $matchingCalls.Add($historyEntry)
        }
        else {
            $null = $nonMatchingCalls.Add($historyEntry)
        }
    }

    if ($Negate) {
        # Negative checks
        if (-not $PSBoundParameters.ContainsKey('Times') -and -not $Exactly -and $matchingCalls.Count -ge 1) {
            # Plain 'Should -Not -Invoke' (no -Times/-Exactly) means the command should not have
            # been called at all. Word the failure that way instead of the confusing default
            # "not to be called exactly 1 times".
            $timeWord = if ($matchingCalls.Count -eq 1) { 'time' } else { 'times' }
            return [Pester.ShouldResult] @{
                Succeeded      = $false
                FailureMessage = "Expected ${commandName}${moduleMessage} not to be called,$(Format-Because $Because) but it was called $($matchingCalls.Count) $timeWord`n$(Format-MockCallHistoryMessage $callHistory $matchingCalls $nonMatchingCalls)"
                ExpectResult   = [Pester.ShouldExpectResult]@{
                    Expected = "${commandName}${moduleMessage} not to be called"
                    Actual   = "${commandName}${moduleMessage} was called $($matchingCalls.Count) $timeWord"
                    Because  = Format-Because $Because
                }
            }
        }
        elseif ($matchingCalls.Count -eq $Times -and ($Exactly -or !$PSBoundParameters.ContainsKey('Times'))) {
            return [Pester.ShouldResult] @{
                Succeeded      = $false
                FailureMessage = "Expected ${commandName}${moduleMessage} not to be called exactly $Times times,$(Format-Because $Because) but it was`n$(Format-MockCallHistoryMessage $callHistory $matchingCalls $nonMatchingCalls)"
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
                FailureMessage = "Expected ${commandName}${moduleMessage} to be called less than $Times times,$(Format-Because $Because) but was called $($matchingCalls.Count) times`n$(Format-MockCallHistoryMessage $callHistory $matchingCalls $nonMatchingCalls)"
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
                FailureMessage = "Expected ${commandName}${moduleMessage} to be called $Times times exactly,$(Format-Because $Because) but was called $($matchingCalls.Count) times`n$(Format-MockCallHistoryMessage $callHistory $matchingCalls $nonMatchingCalls)"
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
                FailureMessage = "Expected ${commandName}${moduleMessage} to be called at least $Times times,$(Format-Because $Because) but was called $($matchingCalls.Count) times`n$(Format-MockCallHistoryMessage $callHistory $matchingCalls $nonMatchingCalls)"
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
                FailureMessage = "Expected ${commandName}${moduleMessage} to only be called with with parameters matching the specified filter,$(Format-Because $Because) but $($nonMatchingCalls.Count) non-matching calls were made`n$(Format-MockCallHistoryMessage $callHistory $matchingCalls $nonMatchingCalls)"
                ExpectResult   = [Pester.ShouldExpectResult]@{
                    Expected = "${commandName}${moduleMessage} to only be called with with parameters matching the specified filter"
                    Actual   = "${commandName}${moduleMessage} was called $($nonMatchingCalls.Count) times with non-matching parameters"
                    Because  = Format-Because $Because
                }
            }
        }
    }

    return [Pester.ShouldResult] @{
        Succeeded = $true
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

        if ($h.IsGlobal) {
            Unregister-GlobalMockHook -Hook $h
        }

        $null = Invoke-InMockScope -SessionState $h.SessionState -ScriptBlock $removeMockStub -Arguments $h.BootstrapFunctionName, $h.Aliases, $Write_Debug_Enabled, $Write_Debug
    }
}

function Resolve-Command {
    param (
        [string] $CommandName,
        [string] $ModuleName,
        [Parameter(Mandatory)]
        [Management.Automation.SessionState] $SessionState,
        [switch] $Global
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

    if ($Global) {
        # Global mock: ModuleName is not the destination (the engine hook makes the mock effective
        # everywhere), it is only a hint to find the command. Resolve from the caller/script scope
        # first, which also finds the bootstrap of an existing global mock so re-mocking reuses its
        # hook. If the command is not visible there (a module-private command), fall back to the
        # module named by the hint to find and resolve it. Either way the mock is installed in the
        # caller scope and has no target module.
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Mock "Resolving command $CommandName for a global mock, searching the caller scope$(if ($ModuleName) { " and using module $ModuleName as a hint" })."
        }

        Set-ScriptBlockScope -ScriptBlock $findAndResolveCommand -SessionState $callerSessionState
        $command, $commandMetadata, $commandMetadata2 = & $findAndResolveCommand -Name $CommandName

        if ($null -eq $command -and $ModuleName) {
            $module = Get-CompatibleModule -ModuleName $ModuleName -ErrorAction SilentlyContinue
            if ($null -ne $module) {
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Mock "Command $CommandName not found in the caller scope, searching module $($module.Name) version $($module.Version)."
                }
                $command, $commandMetadata, $commandMetadata2 = & $module $findAndResolveCommand -Name $CommandName
            }
        }

        # the mock is installed in the caller (script) scope and has no target module
        $SessionState = $callerSessionState
        $ModuleName = ''
    }
    elseif ($ModuleName) {
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

            # Normalize $ModuleName to the plain module name in case slash notation ('Root/Nested')
            # was used. All downstream uses (TargetModule, mock-table keys, IsFromTargetModule) must
            # use the plain name, not the slash string.
            $ModuleName = $module.Name

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


    if ($Global -and $command.Name -like 'PesterMock_*' -and $command.Mock.Hook.OwnerRunId -ne [Pester.GlobalMockHook]::CurrentRunId) {
        # The resolved command is a mock bootstrap, but it belongs to a different (outer) Pester run whose
        # script-scope alias leaked into this run. Do not reuse it - unwrap to the original command so this
        # run creates and owns its own hook, and the outer run's mock stays intact.
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope MockCore "Resolved a global mock bootstrap owned by another run; unwrapping to the original command $($command.Mock.Hook.OriginalCommand.Name) so this run gets its own hook."
        }
        $commandMetadata = $command.Mock.Hook.OriginalMetadata
        $commandMetadata2 = $command.Mock.Hook.OriginalMetadata2
        $command = $command.Mock.Hook.OriginalCommand
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

        [object] $MockPSCmdlet,

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
            $MockCallState['MatchedNoBehavior'] = $false
            $MockCallState['BeginBoundParameters'] = $BoundParameters.Clone()
            # Capture the aliases of dynamic parameters now, while the mocked command's runtime
            # metadata is still reachable via its $PSCmdlet. Dynamic parameters are not part of the
            # static command metadata, so without this the parameter filter cannot match on their
            # aliases (#1275).
            $MockCallState['DynamicParamAliases'] = Get-DynamicParameterAlias -Cmdlet $MockPSCmdlet
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
            $behavior, $failedFilterInvocations = FindMatchingBehavior -Behaviors @($Behaviors) -BoundParameters $BoundParameters -ArgumentList @($ArgumentList) -SessionState $SessionState -Hook $Hook -DynamicParamAliases $MockCallState['DynamicParamAliases']

            if ($null -ne $behavior) {
                $call = @{
                    BoundParams         = $BoundParameters
                    Args                = $ArgumentList
                    Hook                = $Hook
                    Behavior            = $behavior
                    DynamicParamAliases = $MockCallState['DynamicParamAliases']
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
                $MockCallState['MatchedNoBehavior'] = $true
                $MockCallState['FailedFilterInvocations'] = $failedFilterInvocations
                if ($null -ne $InputObject) {
                    $null = $MockCallState['InputObjects'].AddRange(@($InputObject))
                }

                return
            }
        }

        End {
            if ($MockCallState['MatchedNoBehavior']) {
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Mock "The mock did not match any filtered behavior, and there was no default behavior. Failing."
                }

                $failedFilterInvocations = $MockCallState['FailedFilterInvocations']
                if ($null -eq $failedFilterInvocations -or $failedFilterInvocations.Count -eq 0) {
                    # No behaviors in this scope, but the bootstrap function is installed —
                    # an outer Mock leaked into a nested Invoke-Pester run.
                    throw "No mock for command '$($Hook.CommandName)' is defined in this scope, but the bootstrap is active (typically a Mock from an outer scope leaked into a nested Invoke-Pester run). Add a Mock for '$($Hook.CommandName)' in this scope, or restructure the test so the outer Mock does not leak."
                }

                $filterList = ($failedFilterInvocations | & $SafeCommands['ForEach-Object'] { "    $_" }) -join [System.Environment]::NewLine

                throw "No mock for command '$($Hook.CommandName)' matched the call: none of the parameter filters matched, and there is no default mock to fall back to. Add a default mock (e.g. ``Mock $($Hook.CommandName) { ... }``) or adjust an existing -ParameterFilter.$([System.Environment]::NewLine)$([System.Environment]::NewLine)The following parameter filters were evaluated and did not match:$([System.Environment]::NewLine)$filterList"
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
        $Hook,
        [hashtable] $DynamicParamAliases = @{ }
    )

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Mock "Finding behavior to use, one that passes filter or a default:"
    }

    $failedFilterInvocations = [System.Collections.Generic.List[String]]@()
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
                ScriptBlock         = $b.Filter
                BoundParameters     = $BoundParameters
                ArgumentList        = $ArgumentList
                Metadata            = $Hook.Metadata
                SessionState        = $Hook.CallerSessionState
                DynamicParamAliases = $DynamicParamAliases
            }

            $filterResult = Test-ParameterFilter @params
            $passed = $filterResult[0]
            $filterInvocations = $filterResult[1]
            if ($passed) {
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Mock "{ $($b.ScriptBlock) } passed parameter filter and will be used for the mock call."
                }
                return $b, $null
            }
            else {
                $failedFilterInvocations.AddRange($filterInvocations)
            }
        }
    }

    if ($foundDefaultBehavior) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Mock "{ $($defaultBehavior.ScriptBlock) } is a default behavior and will be used for the mock call."
        }
        return $defaultBehavior, $null
    }

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Mock "No parametrized or default behaviors were found."
    }
    return $null, $failedFilterInvocations
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
        $SessionState,

        [System.Collections.IDictionary]
        $DynamicParamAliases
    )

    if ($null -eq $BoundParameters) {
        $BoundParameters = @{ }
    }

    $arguments = $ArgumentList
    # $() gets rid of the @() defined for powershell 3
    if ($null -eq $($ArgumentList)) {
        $arguments = @()
    }

    $context = Get-ContextToDefine -BoundParameters $BoundParameters -Metadata $Metadata -DynamicParamAliases $DynamicParamAliases

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

    $parameterFilterInvocations = [Collections.Generic.List[string]]@()

    $previousIsInMockParameterFilter = & $SafeCommands['Get-Variable'] -Name '______isInMockParameterFilter' -Scope Script -ValueOnly -ErrorAction Ignore
    $script:______isInMockParameterFilter = $true
    try {
        $result = & $wrapper $parameters
    }
    finally {
        if ($null -eq $previousIsInMockParameterFilter) {
            & $SafeCommands['Remove-Variable'] -Name '______isInMockParameterFilter' -Scope Script -ErrorAction Ignore
        }
        else {
            $script:______isInMockParameterFilter = $previousIsInMockParameterFilter
        }
    }
    $passed = [bool]$result
    if ($passed) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Mock -Message "Mock filter returned value '$result', which is truthy. Filter passed."
        }
    }
    else {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Mock -Message "Mock filter returned value '$result', which is falsy. Filter did not pass."
        }

        # Filter did not pass, serialize the values and store them for future reference in case we don't find any behavior.
        $filterText = $scriptBlock.ToString().Trim()
        $hasContext = 0 -lt $Context.Count
        $contextText = if ($hasContext) {
            'bound parameters: ' + (($Context.GetEnumerator() | & $SafeCommands['ForEach-Object'] { "$($_.Key) = $($_.Value)" }) -join ', ')
        }
        else {
            'no bound parameters'
        }
        $filterCall = "{ $filterText }  $contextText"
        $parameterFilterInvocations.Add($filterCall)
    }
    # Return as a single 2-element array so multi-assignment works even when $result is empty/$null/array.
    , @($passed, $parameterFilterInvocations)
}

function Get-DynamicParameterAlias {
    param (
        [object] $Cmdlet
    )

    # Build a map of dynamic-parameter name -> aliases from the mocked command's runtime metadata.
    # Only dynamic parameters are included; aliases of static parameters are already resolved from
    # the static command metadata in Get-ContextToDefine (#1275).
    $aliases = @{ }
    if ($null -eq $Cmdlet) {
        return $aliases
    }

    $parameters = $Cmdlet.MyInvocation.MyCommand.Parameters
    if ($null -eq $parameters) {
        return $aliases
    }

    foreach ($parameter in $parameters.GetEnumerator()) {
        $parameterMetadata = $parameter.Value
        if ($parameterMetadata.IsDynamic -and $null -ne $parameterMetadata.Aliases -and 0 -lt @($parameterMetadata.Aliases).Count) {
            $aliases[$parameter.Key] = @($parameterMetadata.Aliases)
        }
    }

    $aliases
}

function Get-ContextToDefine {
    param (
        [System.Collections.IDictionary] $BoundParameters,
        [System.Management.Automation.CommandMetadata] $Metadata,
        [System.Collections.IDictionary] $DynamicParamAliases
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
            # it is probably dynamic, try remove "_" since the conflicting names
            # are already handled to properly print the debug message

            if ($param.Key.StartsWith('_')) {
                $originalName = $param.Key.TrimStart('_')
                if ($originalName -in $script:ConflictingParameterNames) {
                    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                        Write-PesterDebugMessage -Scope Mock -Message "! Variable `$$($originalName) is a built-in variable, rewriting it to `$_$($originalName). Use the version with _ in your -ParameterFilter."
                    }
                }
            }

            if (-not $r.ContainsKey($param.Key)) {
                $r.Add($param.Key, $param.Value)
            }

            # dynamic parameters are not part of the static command metadata, so their aliases
            # were captured separately at call time. Define them as well, so the parameter filter
            # can match on a dynamic parameter's alias and not just its name (#1275).
            if ($null -ne $DynamicParamAliases -and $DynamicParamAliases.Contains($param.Key)) {
                foreach ($a in $DynamicParamAliases[$param.Key]) {
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
                        $r.Add($name, $param.Value)
                    }
                }
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
        $DynamicParamScriptBlock,

        [string[]] $RemoveParameterValidation
    )

    switch ($PSCmdlet.ParameterSetName) {
        'Cmdlet' {
            $dynamicParams = Get-DynamicParametersForCmdlet -CmdletName $CmdletName -Parameters $Parameters
        }

        'Function' {
            $dynamicParams = Get-DynamicParametersForMockedFunction -DynamicParamScriptBlock $DynamicParamScriptBlock -Parameters $Parameters -Cmdlet $Cmdlet
        }
    }

    if ($null -eq $dynamicParams) {
        return
    }

    if ($RemoveParameterValidation) {
        Remove-DynamicParameterValidation -DynamicParams $dynamicParams -ParameterName $RemoveParameterValidation
    }

    Repair-ConflictingDynamicParameters -DynamicParams $dynamicParams
}

function Remove-DynamicParameterValidation {
    [OutputType([void])]
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.RuntimeDefinedParameterDictionary]
        $DynamicParams,

        [Parameter(Mandatory = $true)]
        [string[]]
        $ParameterName
    )

    # Mirror the static-parameter handling in Repair-ConflictingParameters: a validation attribute is any
    # ValidateArgumentsAttribute (ValidateSet, ValidateRange, ValidatePattern, ValidateScript, ...), so
    # removing those from the dynamic parameter disables the validation while keeping the parameter itself.
    foreach ($name in $ParameterName) {
        if (-not $DynamicParams.ContainsKey($name)) {
            continue
        }

        $dynamicParam = $DynamicParams[$name]
        $attrIndexesToRemove = [System.Collections.Generic.List[int]]@()
        for ($i = 0; $i -lt $dynamicParam.Attributes.Count; $i++) {
            if ($dynamicParam.Attributes[$i] -is [System.Management.Automation.ValidateArgumentsAttribute]) {
                $null = $attrIndexesToRemove.Add($i)
            }
        }

        # remove attributes in reverse order to avoid index shifting
        $attrIndexesToRemove.Reverse()
        foreach ($index in $attrIndexesToRemove) {
            $null = $dynamicParam.Attributes.RemoveAt($index)
        }
    }
}

function Repair-ConflictingDynamicParameters {
    [OutputType([System.Management.Automation.RuntimeDefinedParameterDictionary])]
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.RuntimeDefinedParameterDictionary]
        $DynamicParams
    )

    $repairedDynamicParams = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
    $conflictingParams = Get-ConflictingParameterNames

    foreach ($paramName in $DynamicParams.Keys) {
        $dynamicParam = $DynamicParams[$paramName]

        if ($conflictingParams -contains $paramName) {
            $newName = "_$paramName"
            $dynamicParam.Name = $newName

            $aliasAttribute = [System.Management.Automation.AliasAttribute]::new($paramName)
            $dynamicParam.Attributes.Add($aliasAttribute)

            $repairedDynamicParams[$newName] = $dynamicParam
        }
        else {
            $repairedDynamicParams[$paramName] = $dynamicParam
        }
    }

    return $repairedDynamicParams
}

function Get-DynamicParametersForCmdlet {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $CmdletName,

        [ValidateScript( {
                if ($null -ne $_ -and
                    $_.GetType().FullName -ne 'System.Management.Automation.PSBoundParametersDictionary') {
                    throw 'The -Parameters argument must be a PSBoundParametersDictionary object ($PSBoundParameters).'
                }

                return $true
            })]
        [System.Collections.IDictionary] $Parameters
    )

    # When a global mock is active, its bootstrap function shadows $CmdletName in every scope via the
    # engine command-lookup hook. Resolving the *original* cmdlet here (by name) to discover its
    # dynamic parameters would be redirected back to the mock and the real dynamic parameters (e.g.
    # Get-ChildItem -Hidden) would be lost. Suppress the redirect for this name while we resolve it.
    [Pester.GlobalMockHook]::BeginSuppress($CmdletName)
    try {
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

        if ($null -eq $Parameters) {
            $paramsArg = @()
        }
        else {
            $paramsArg = @($Parameters)
        }

        try {
            $command = $ExecutionContext.InvokeCommand.GetCommand($CmdletName, [System.Management.Automation.CommandTypes]::Cmdlet, $paramsArg)
        }
        catch {
            # Resolving a cmdlet's dynamic parameters can fail when they are built from external state that isn't
            # available while the command is mocked - e.g. Set-PSRepository's -Location comes from the package
            # provider and validates while resolving. Fall back to no dynamic parameters instead of failing. (#619)
            return
        }
    }
    finally {
        [Pester.GlobalMockHook]::EndSuppress()
    }
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
        try {
            return & $DynamicParamScriptBlock @Parameters @splat
        }
        catch {
            # The mocked command's own dynamicparam block failed to produce its dynamic parameters - e.g. it
            # validates against state that isn't available while it is being mocked. We only need the metadata
            # to forward the call, so fall back to no dynamic parameters instead of failing the whole mock. (#619)
            return
        }
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

function Format-MockCallHistoryMessage ($callHistory, $matchingCalls, $nonMatchingCalls) {
    if ($null -eq $callHistory -or $callHistory.Count -eq 0) {
        return "Performed invocations:`n  <none>"
    }

    $result = "Performed invocations:"
    foreach ($historyEntry in $callHistory) {
        $params = $historyEntry.BoundParams
        if ($null -ne $params -and $params.Count -gt 0) {
            $parts = foreach ($p in $params.GetEnumerator()) { "-$($p.Key) $(Format-Nicely2 $p.Value)" }
            $paramText = $parts -join " "
        }
        else {
            $paramText = ""
        }

        $marker = if ($historyEntry -in $matchingCalls) { "[*]" } else { "[ ]" }
        $cmd = $historyEntry.Behavior.CommandName

        $location = ""
        $sb = $historyEntry.Behavior.ScriptBlock
        if ($null -ne $sb -and $sb.File) {
            $file = $sb.File
            $line = $sb.StartPosition.StartLine
            $location = " from ${file}:${line}"
        }

        if ($paramText) {
            $result += "`n  $marker $cmd $paramText$location"
        }
        else {
            $result += "`n  $marker $cmd$location"
        }
    }

    $result
}
