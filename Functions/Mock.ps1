﻿

function Add-MockBehavior {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Behaviors,
        [Parameter(Mandatory)]
        $Behavior
    )

    if ($Behavior.IsDefault) {
        $Behaviors.Default += $Behavior
    }
    else {
        $Behaviors.Parametrized += $Behavior
    }
}

function New-MockBehavior {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $ContextInfo,
        [ScriptBlock] $MockWith = {},
        [Switch] $Verifiable,
        [ScriptBlock] $ParameterFilter,
        [Parameter(Mandatory)]
        $Hook,
        [string[]]$RemoveParameterType,
        [string[]]$RemoveParameterValidation
    )


    $scriptBlockIsClosure = Test-IsClosure -ScriptBlock $MockWith
    if ($scriptBlockIsClosure) {
        if ($PesterDebugPreference.WriteDebugMessages) {
            Write-PesterDebugMessage -Scope Mock -Message "The provided mock body is a closure, not touching it so the captured variables are preserved."
        }
        # If the user went out of their way to call GetNewClosure(), go ahead and leave the block bound to that
        # dynamic module's scope.
        $mockWithCopy = $MockWith
    }
    else {
        if ($PesterDebugPreference.WriteDebugMessages) {
            Write-PesterDebugMessage -Scope SessionState "Unbinding ScriptBlock from '$(Get-ScriptBlockHint $MockWith)'"
        }
        $mockWithCopy = [scriptblock]::Create($MockWith.ToString())
        Set-ScriptBlockHint -ScriptBlock $mockWithCopy -Hint "Unbound ScriptBlock from Mock"
        # bind the script block to the caller state which is most likely the test scope
        Set-ScriptBlockScope -ScriptBlock $mockWithCopy -SessionState $ContextInfo.CallerSessionState
    }

    if ($null -ne $ParameterFilter) {
        $ParameterFilter = New-BlockWithoutParameterAliases -Metadata $Hook.Metadata -Block $ParameterFilter
    }

    New_PSObject -Type 'MockBehavior' @{
        CommandName          = $ContextInfo.Command.Name
        ModuleName           = if ($ContextInfo.IsFromRequestedModule) { $ContextInfo.Module.Name } else { $null }
        Filter               = $ParameterFilter
        IsDefault            = $null -eq $ParameterFilter
        Verifiable           = $Verifiable
        ScriptBlock          = $mockWithCopy
        ScriptBlockIsClosure = $scriptBlockIsClosure
        Hook                 = $Hook
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
    $moduleName = if ($contextInfo.IsFromRequestedModule) { $contextInfo.Module.Name } else { '' }
    $metadata = $null
    $cmdletBinding = ''
    $paramBlock = ''
    $dynamicParamBlock = ''
    $dynamicParamScriptBlock = $null

    if ($contextInfo.Command.psobject.Properties['ScriptBlock'] -or $contextInfo.Command.CommandType -eq 'Cmdlet') {
        $metadata = [System.Management.Automation.CommandMetaData]$contextInfo.Command
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
        $dynamicParams = $metadata | & $SafeCommands['Select-Object'] -ExpandProperty Parameters | & $SafeCommands['Select-Object'] -ExpandProperty Values | & $SafeCommands['Where-Object'] {$_.IsDynamic}
        if ($null -ne $dynamicParams) {
            $dynamicparams | & $SafeCommands['ForEach-Object'] { $null = $metadata.Parameters.Remove($_.name) }
        }

        $cmdletBinding = [Management.Automation.ProxyCommand]::GetCmdletBindingAttribute($metadata)
        if ($global:PSVersionTable.PSVersion.Major -ge 3 -and $contextInfo.Command.CommandType -eq 'Cmdlet') {
            if ($cmdletBinding -ne '[CmdletBinding()]') {
                $cmdletBinding = $cmdletBinding.Insert($cmdletBinding.Length - 2, ',')
            }
            $cmdletBinding = $cmdletBinding.Insert($cmdletBinding.Length - 2, 'PositionalBinding=$false')
        }

            # Will modify $metadata object in-place
            $originalMetadata = $metadata
            $metadata = Repair-ConflictingParameters -Metadata $metadata -RemoveParameterType $RemoveParameterType -RemoveParameterValidation $RemoveParameterValidation
            $paramBlock = [Management.Automation.ProxyCommand]::GetParamBlock($metadata)

        if ($contextInfo.Command.CommandType -eq 'Cmdlet') {
            $dynamicParamBlock = "dynamicparam { & `$MyInvocation.MyCommand.Mock.Get_MockDynamicParameter -CmdletName '$($contextInfo.Command.Name)' -Parameters `$PSBoundParameters }"
        }
        else {
            $dynamicParamStatements = Get-DynamicParamBlock -ScriptBlock $contextInfo.Command.ScriptBlock

            if ($dynamicParamStatements -match '\S') {
                $metadataSafeForDynamicParams = [System.Management.Automation.CommandMetaData]$contextInfo.Command
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

                $sessionStateInternal = Get-ScriptBlockScope -ScriptBlock $contextInfo.Command.ScriptBlock

                if ($null -ne $sessionStateInternal) {
                    Set-ScriptBlockScope -ScriptBlock $dynamicParamScriptBlock -SessionStateInternal $sessionStateInternal
                }
            }
        }
    }

    $mockPrototype = @"
    & `$MyInvocation.MyCommand.Mock.Write_PesterDebugMessage -Message "Mock bootstrap function #FUNCTIONNAME# called from block #BLOCK#."
    `$MyInvocation.MyCommand.Mock.Args = `$null
    if (#CANCAPTUREARGS#) {
        & `$MyInvocation.MyCommand.Mock.Write_PesterDebugMessage -Message "Capturing arguments of the mocked command."
        `$MyInvocation.MyCommand.Mock.Args = & `$MyInvocation.MyCommand.Mock.Get_Variable ```
            -ErrorAction `$MyInvocation.MyCommand.Mock.ErrorAction ```
            -Name args -ValueOnly -Scope Local
    }

    `$MyInvocation.MyCommand.Mock.PSCmdlet = & `$MyInvocation.MyCommand.Mock.Get_Variable ```
        -ErrorAction `$MyInvocation.MyCommand.Mock.ErrorAction ```
        -Name PSCmdlet -ValueOnly -Scope Local

    `if (`$null -ne `$MyInvocation.MyCommand.Mock.PSCmdlet)
    {
        `$MyInvocation.MyCommand.Mock.SessionState = `$MyInvocation.MyCommand.Mock.PSCmdlet.SessionState
    }

    # MockCallState initialization is injected only into the begin block by the code that generates this prototype
    # also it is not a good idea to share it via the function local data because then it will get overwritten by nested
    # mock if there is any, instead it should be a varible that gets defined in describe and so it survives during the whole
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

    $mock = @{
        OriginalCommand         = $contextInfo.Command
        CommandName             = $commandName
        SessionState            = $contextInfo.SessionState
        CallerSessionState      = $contextInfo.CallerSessionState
        Metadata                = $metadata
        DynamicParamScriptBlock = $dynamicParamScriptBlock
        Aliases                 = @($commandName)
        BootstrapFunctionName   = 'PesterMock_' + [Guid]::NewGuid().Guid
    }

    if ($mock.OriginalCommand.ModuleName) {
        $mock.Aliases += "$($mock.OriginalCommand.ModuleName)\$($CommandName)"
    }

    if ('Application' -eq $Mock.OriginalCommand.CommandType) {
        $aliasWithoutExt = $CommandName -replace $Mock.OriginalCommand.Extension

        $Mock.Aliases += $aliasWithoutExt
    }

    $parameters = @{
        BootstrapFunctionName = $mock.BootstrapFunctionName
        Definition            = $mockScript
        Aliases               = $mock.Aliases

        Set_Alias             = $SafeCommands["Set-Alias"]
        Remove_Variable       = $SafeCommands["Remove-Variable"]
    }

    $defineFunctionAndAliases = {
        param($___Mock___parameters)
        # Make sure the you don't use _______parameters variable here, otherwise you overwrite
        # the variable that is defined in the same scope and the subsequent invocation of scrips will
        # be seriously broken (e.g. you will start resolving setups). But such is life of running in once scope.
        # from upper scope for no reason. But the reason is that you deleted ______param in this scope,
        # and so ______param from the parent scope was inherited

        ## THIS RUNS IN USER SCOPE, BE CAREFUL WHAT YOU PUBLISH AND COSUME


        # it is possible to remove the script: (and -Scope Script) from here and from the alias, which makes the Mock scope just like a function.
        # but that breaks mocking inside of Pester itself, because the mock is defined in this function and dies with it
        # this is a cool concept to play with, but scoping mocks more granularly than per It is not something people asked for, and cleaning up
        # mocks is trivial now they are wrote in distinct tables based on where they are defined, so let's just do it as before, script scoped
        # function and alias, and cleaning it up in teardown

        # define the function and returns an array so we need to take the function out
        @($ExecutionContext.InvokeProvider.Item.Set("Function:\script:$($___Mock___parameters.BootstrapFunctionName)", $___Mock___parameters.Definition, $true, $true))[0]

        # define all aliases
        foreach ($______current in $___Mock___parameters.Aliases) {
            & $___Mock___parameters.Set_Alias -Name $______current -Value $___Mock___parameters.BootstrapFunctionName -Scope Script
        }

        # clean up the variables because we are injecting them to the current scope
        & $___Mock___parameters.Remove_Variable -Name ______current
        & $___Mock___parameters.Remove_Variable -Name ___Mock___parameters
    }

    $definedFunction = Invoke-InMockScope -SessionState $mock.SessionState -ScriptBlock $defineFunctionAndAliases -Arguments @($parameters) -NoNewScope
    if ($PesterDebugPreference.WriteDebugMessages) {
        Write-PesterDebugMessage -Scope Mock -Message "Defined new hook with bootstrap function $($parameters.BootstrapFunctionName)$(if ($parameters.Aliases.Count -gt 0) {" and aliases $($parameters.Aliases -join ", ")"})."
    }

    # attaching this object on the newly created function
    # so it has access to our internal and safe functions directly
    # and also to avoid any local variables, because everything is
    # accessed via $MyInvocation.MyCommand
    $functionLocalData = @{
        Args                     = $null
        ErrorAction              = if ($PSVersionTable.PSVersion.Major -ge 3) { 'Ignore' } else { 'SilentlyContinue' }
        SessionState             = $null

        Get_Variable             = $SafeCommands["Get-Variable"]
        Invoke_Mock              = $InvokeMockCallBack
        Get_MockDynamicParameter = $SafeCommands["Get-MockDynamicParameter"]
        # returning empty scriptblock when we should not write debug to avoid patching it in mock prototype
        Write_PesterDebugMessage = if ($PesterDebugPreference.WriteDebugMessages) { { param($Message) & $SafeCommands["Write-PesterDebugMessage"] -Scope Mock -Message $Message } } else { {} }

        # used as temp variable
        PSCmdlet                 = $null

        # data from the time we captured and created this mock
        Hook                     = $mock
    }

    & $SafeCommands["Add-Member"] -InputObject $definedFunction -MemberType NoteProperty -Name Mock -Value $functionLocalData

    $mock
}

function Should-InvokeVerifiableInternal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Behaviors
    )

    $unverified = [System.Collections.Generic.List[Object]]@()
    foreach ($b in $Behaviors) {
        if ($b.Verifiable) {
            $unverified.Add($b)
        }
    }

    if ($unVerified.Count -gt 0) {
        foreach ($b in $unVerified) {
            $message = "$([System.Environment]::NewLine) Expected $($b.CommandName) "
            if ($b.ModuleName) {
                $message += "in module $($b.ModuleName) "
            }
            $message += "to be called with $($b.Filter)"
        }

        return [PSCustomObject] @{
            Succeeded      = $false
            FailureMessage = $message
        }
    }

    return [PSCustomObject] @{
        Succeeded      = $true
        FailureMessage = $null
    }
}

function Should-InvokeInternal {
    [CmdletBinding(DefaultParameterSetName = 'ParameterFilter')]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable] $ContextInfo,

        [int]$Times = 1,

        [Parameter(ParameterSetName = 'ParameterFilter')]
        [ScriptBlock]$ParameterFilter = {$True},

        [Parameter(ParameterSetName = 'ExclusiveFilter', Mandatory = $true)]
        [scriptblock] $ExclusiveFilter,

        [string] $ModuleName,

        [switch]$Exactly,

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

    $ModuleName = if ($ContextInfo.IsFromRequestedModule) { $ContextInfo.Module.Name } else { $null }
    $CommandName = $ContextInfo.Command.Name

    $callHistory = $MockTable["$ModuleName||$CommandName"]

    $moduleMessage = ''
    if ($ModuleName) {
        $moduleMessage = " in module $ModuleName"
    }

    # if (-not $callHistory) {
    #     throw "You did not declare a mock of the $commandName Command${moduleMessage}."
    # }

    $matchingCalls = [System.Collections.ArrayList]@()
    $nonMatchingCalls = [System.Collections.ArrayList]@()

    foreach ($historyEntry in $callHistory) {

        $params = @{
            ScriptBlock     = $filter
            BoundParameters = $historyEntry.BoundParams
            ArgumentList    = $historyEntry.Args
            Metadata        = $ContextInfo.Hook.Metadata
            SessionState    = $ContextInfo.Hook.CallerSessionState
        }

        if ($null -ne $ContextInfo.Hook.Metadata -and $null -ne $params.ScriptBlock) {
            $params.ScriptBlock = New-BlockWithoutParameterAliases -Metadata $ContextInfo.Hook.Metadata -Block $params.ScriptBlock
        }

        if (Test-ParameterFilter @params) {
            $null = $matchingCalls.Add($historyEntry)
        }
        else {
            $null = $nonMatchingCalls.Add($historyEntry)
        }
    }

    if ($matchingCalls.Count -ne $Times -and ($Exactly -or ($Times -eq 0))) {
        return [PSCustomObject] @{
            Succeeded      = $false
            FailureMessage = "Expected ${commandName}${moduleMessage} to be called $Times times exactly but was called $($matchingCalls.Count) times"
        }
    }
    elseif ($matchingCalls.Count -lt $Times) {
        return [PSCustomObject] @{
            Succeeded      = $false
            FailureMessage = "Expected ${commandName}${moduleMessage} to be called at least $Times times but was called $($matchingCalls.Count) times"
        }
    }
    elseif ($filterIsExclusive -and $nonMatchingCalls.Count -gt 0) {
        return [PSCustomObject] @{
            Succeeded      = $false
            FailureMessage = "Expected ${commandName}${moduleMessage} to only be called with with parameters matching the specified filter, but $($nonMatchingCalls.Count) non-matching calls were made"
        }
    }

    return [PSCustomObject] @{
        Succeeded      = $true
        FailureMessage = $null
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
            [string[]] $Aliases
        )

        if ($ExecutionContext.InvokeProvider.Item.Exists("Function:\$CommandName", $true, $true)) {
            $ExecutionContext.InvokeProvider.Item.Remove("Function:\$CommandName", $false, $true, $true)
        }

        foreach ($alias in $Aliases) {
            if ($ExecutionContext.InvokeProvider.Item.Exists("Alias:$alias", $true, $true)) {
                $ExecutionContext.InvokeProvider.Item.Remove("Alias:$alias", $false, $true, $true)
            }
        }
    }

    foreach ($h in $Hooks) {
        if ($PesterDebugPreference.WriteDebugMessages) {
            Write-PesterDebugMessage -Scope Mock -Message "Removing function $($h.BootstrapFunctionName)$(if($h.Aliases) { " and aliases $($h.Aliases -join ", ")" }) for$(if($h.ModuleName) { " $($h.ModuleName) -" }) $($h.CommmandName)."
        }

        $null = Invoke-InMockScope -SessionState $h.CallerSessionState -ScriptBlock $removeMockStub -Arguments $h.BootstrapFunctionName, $h.Aliases
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
    # in the caller scope, not the module scope so we need to hold ont the caller scope
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

        return $command
    }

    if ($PesterDebugPreference.WriteDebugMessages) {
        Write-PesterDebugMessage -Scope Mock "Resolving command $CommandName."
    }
    if ($ModuleName) {
        if ($PesterDebugPreference.WriteDebugMessages) {
            Write-PesterDebugMessage -Scope Mock "ModuleName was specified searching for the command in module $ModuleName."
        }
        $module = Get-ScriptModule -ModuleName $ModuleName -ErrorAction Stop
        if ($PesterDebugPreference.WriteDebugMessages) {
            Write-PesterDebugMessage -Scope Mock "Found module $($module.Name) version $($module.Version)."
        }
        $SessionState = Set-SessionStateHint -PassThru  -Hint "Module - $($module.Name)" -SessionState ( $module.SessionState )
        $command = & $module $findAndResolveCommand -Name $CommandName
        if ($command) {
            if ($command.Module -eq $module) {
                if ($PesterDebugPreference.WriteDebugMessages) {
                    Write-PesterDebugMessage -Scope Mock "Found the command $($CommandName) in module $($module.Name) version $($module.Version)$(if ($CommandName -ne $command.Name) {" and it resolved to $($command.Name)"})."
                }
            }
            else {
                if ($PesterDebugPreference.WriteDebugMessages) {
                    Write-PesterDebugMessage -Scope Mock "Found the command $($CommandName) in a different module$(if ($CommandName -ne $command.Name) {" and it resolved to $($command.Name)"})."
                }
            }
        }
        else {
            if ($PesterDebugPreference.WriteDebugMessages) {
                Write-PesterDebugMessage -Scope Mock "Did not find command $CommandName in module $($module.Name) version $($module.Version)."
            }
        }
    }

    if (-not $command) {


        # TODO: this resolves the command in the caller scope if the command was not found in the module scope, but that does not make sense does it? When the user specifies that he want's to use Module it should use just Module. Disabling the fall through makes tests fail.

        if ($PesterDebugPreference.WriteDebugMessages) {
            Write-PesterDebugMessage -Scope Mock "Searching for command $ComandName in the caller scope."
        }
        Set-ScriptBlockScope -ScriptBlock $findAndResolveCommand -SessionState $SessionState
        $command = & $findAndResolveCommand -Name $CommandName
        if ($command) {
            if ($PesterDebugPreference.WriteDebugMessages) {
                Write-PesterDebugMessage -Scope Mock "Found the command $CommandName in the caller scope$(if ($CommandName -ne $command.Name) {"and it resolved to $($command.Name)"})."
            }
        }
        else {
            if ($PesterDebugPreference.WriteDebugMessages) {
                Write-PesterDebugMessage -Scope Mock "Did not find command $CommandName in the caller scope."
            }
        }
    }

    if (-not $command) {
        throw ([System.Management.Automation.CommandNotFoundException] "Could not find Command $CommandName")
    }


    if ($command.Name -like 'PesterMock_*') {
        if ($PesterDebugPreference.WriteDebugMessages) {
            Write-PesterDebugMessage -Scope Mock "The resolved command is a mock bootstrap function, pointing the mock to the same command info an session state as the original mock."
        }
        $module = $command.Mock.OriginalSessionState.Module
        return @{
            Command                 = $command.Mock.Hook.OriginalCommand
            SessionState            = $command.Mock.Hook.SessionState
            CallerSessionState      = $command.Mock.Hook.CallerSessionState
            Module                  = $command.Module
            IsFromModule            = $null -ne $module
            IsFromRequestedModule   = $null -ne $module -and $module -eq $ModuleName
            IsMockBootstrapFunction = $true
            Hook                    = $command.Mock.Hook
        }
    }

    $module = $command.Module
    return @{
        Command                 = $command
        SessionState            = $SessionState
        CallerSessionState      = $callerSessionState
        Module                  = $module

        IsFromModule            = $null -ne $module
        IsFromRequestedModule   = $null -ne $module -and $module.Name -eq $ModuleName
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
            $MockCallState['InputObjects'] = [System.Collections.ArrayList]@()
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
                    $CallHistory.Add($key, @($call))
                }
                else {
                    $CallHistory[$key] += $call
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
                if ($PesterDebugPreference.WriteDebugMessages) {
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
                    if ($PesterDebugPreference.WriteDebugMessages) {
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
                if ($PesterDebugPreference.WriteDebugMessages) {
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
    if ($PesterDebugPreference.WriteDebugMessages) {
        Write-PesterDebugMessage -Scope Mock "Looking for mock $($ModuleName)||$CommandName."
    }
    $MockTable["$($ModuleName)||$CommandName"]

    if ($null -ne $mock) {
        if ($PesterDebugPreference.WriteDebugMessages) {
            Write-PesterDebugMessage -Scope Mock "Found mock $(if (-not [string]::IsNullOrEmpty($ModuleName)) {"with module name $($ModuleName)"})||$CommandName."
        }
        $result.MockFound = $true
    }
    else {
        if ($PesterDebugPreference.WriteDebugMessages) {
            Write-PesterDebugMessage -Scope Mock "No mock found, re-trying without module name ||$CommandName."
        }
        $mock = $MockTable["||$CommandName"]
        $result.ModuleName = $null
        if ($null -ne $mock) {
            if ($PesterDebugPreference.WriteDebugMessages) {
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
        [hashtable] $BoundParameters = @{},
        [object[]] $ArgumentList = @(),
        [Parameter(Mandatory)]
        [Management.Automation.SessionState] $SessionState,
        $Hook
    )

    if ($PesterDebugPreference.WriteDebugMessages) {
        Write-PesterDebugMessage -Scope Mock "Finding a mock behavior."
    }
    $count = $Behaviors.Count

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
                if ($PesterDebugPreference.WriteDebugMessages) {
                    Write-PesterDebugMessage -Scope Mock "{ $($b.ScriptBlock) } passed parameter filter and will be used for the mock call."
                }
                return $b
            }
        }
    }

    if ($foundDefaultBehavior) {
        if ($PesterDebugPreference.WriteDebugMessages) {
            Write-PesterDebugMessage -Scope Mock "{ $($defaultBehavior.ScriptBlock) } is a default behavior and will be used for the mock call."
        }
        return $defaultBehavior
    }

    if ($PesterDebugPreference.WriteDebugMessages) {
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
        [hashtable] $BoundParameters = @{},
        [object[]] $ArgumentList = @()
    )

    $ModuleName = $Behavior.ModuleName
    $CommandName = $Behavior.CommandName
    if ($PesterDebugPreference.WriteDebugMessages) {
        Write-PesterDebugMessage -Scope Mock "Executing mock behavior for mock $ModuleName - $CommandName."
    }

    $Behavior.Verifiable = $false

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
        & ${Script Block} @___BoundParameters___ @___ArgumentList___
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
            if ($PesterDebugPreference.WriteDebugMessages) {
                Write-ScriptBlockInvocationHint -Hint "Mock - of command $CommandName$(if ($ModuleName) { "from module $ModuleName"})" -ScriptBlock $ScriptBlock
            }
        }
        'Set Dynamic Parameter Variable' = $SafeCommands['Set-DynamicParameterVariable']
    }

    # the real scriptblock is passed to the other one, we are interested in the mock, not the wrapper, so I pass $block.ScriptBlock, and not $scriptBlock
    if ($PesterDebugPreference.WriteDebugMessages) {
        Write-ScriptBlockInvocationHint -Hint "Mock - of command $CommandName$(if ($ModuleName) { "from module $ModuleName"})" -ScriptBlock ($behavior.ScriptBlock)
    }
    & $scriptBlock @splat
    if ($PesterDebugPreference.WriteDebugMessages) {
        Write-PesterDebugMessage -Scope Mock "Behavior for $ModuleName - $CommandName was executed."
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
    if ($PesterDebugPreference.WriteDebugMessages) {
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

    $paramBlock = Get-ParamBlockFromBoundParameters -BoundParameters $BoundParameters -Metadata $Metadata

    $scriptBlockString = "
        $paramBlock

        Set-StrictMode -Off
        $ScriptBlock
    "
    if ($PesterDebugPreference.WriteDebugMessages) {
        Write-PesterDebugMessage -Scope Mock -Message "Running mock filter { $scriptBlockString }."
        Write-PesterDebugMessage -Scope SessionState "Unbinding ScriptBlock from '$(Get-ScriptBlockHint $ScriptBlock)'"
    }
    $cmd = [scriptblock]::Create($scriptBlockString)
    Set-ScriptBlockHint -ScriptBlock $cmd -Hint "Unbound ScriptBlock from Test-ParameterFilter"
    Set-ScriptBlockScope -ScriptBlock $cmd -SessionState $SessionState

    if ($PesterDebugPreference.WriteDebugMessages) {
        Write-ScriptBlockInvocationHint -Hint "Mock - Parameter filter" -ScriptBlock $cmd
    }
    $result = & $cmd @BoundParameters @arguments
    if ($result) {
        if ($PesterDebugPreference.WriteDebugMessages) {
            Write-PesterDebugMessage -Scope Mock -Message "Mock filter passed."
        }
    }
    else {
        if ($PesterDebugPreference.WriteDebugMessages) {
            Write-PesterDebugMessage -Scope Mock -Message "Mock filter did not pass."
        }
    }
    $result
}

function Get-ParamBlockFromBoundParameters {
    param (
        [System.Collections.IDictionary] $BoundParameters,
        [System.Management.Automation.CommandMetadata] $Metadata
    )

    $params = foreach ($paramName in $BoundParameters.get_Keys()) {
        if (IsCommonParameter -Name $paramName -Metadata $Metadata) {
            continue
        }

        "`${$paramName}"
    }

    $params = $params -join ','

    if ($null -ne $Metadata) {
        $cmdletBinding = [System.Management.Automation.ProxyCommand]::GetCmdletBindingAttribute($Metadata)
    }
    else {
        $cmdletBinding = ''
    }

    return "$cmdletBinding param ($params)"
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
        if ($PSVersionTable.PSVersion.Major -ge 3 -and $Metadata.SupportsPaging -and [System.Management.Automation.PagingParameters].GetProperty($Name)) {
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

    if ($PSVersionTable.PSVersion.Major -le 2) {
        $flags = [System.Reflection.BindingFlags]'Instance, NonPublic'
        $dynamicParams = [scriptblock].GetField('_dynamicParams', $flags).GetValue($ScriptBlock)

        if ($null -ne $dynamicParams) {
            return $dynamicParams.ToString()

        }
    }
    else {
        If ( $ScriptBlock.AST.psobject.Properties.Name -match "Body") {
            if ($null -ne $ScriptBlock.Ast.Body.DynamicParamBlock) {
                $statements = $ScriptBlock.Ast.Body.DynamicParamBlock.Statements |
                & $SafeCommands['Select-Object'] -ExpandProperty Extent |
                & $SafeCommands['Select-Object'] -ExpandProperty Text

                return $statements -join "$([System.Environment]::NewLine)"
            }
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

        $cmdlet = & $SafeCommands['New-Object'] $command.ImplementingType.FullName

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

    $sessionStateInternal = Get-ScriptBlockScope -ScriptBlock $ScriptBlock
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

function Remove-MockFunctionsAndAliases {
    # when a test is terminated (e.g. by stopping at a breakpoint and then stoping the execution of the script)
    # the aliases and bootstrap functions for the currently mocked functions will remain in place
    # Then on subsequent runs the bootstrap function will be picked up instead of the real command,
    # because there is still an alias associated with it, and the test will fail.
    # So before putting Pester state in place we should make sure that all Pester mocks are gone
    # by deleting every alias pointing to a function that starts with PesterMock_. Then we also delete the
    # bootstrap function.
    foreach ($alias in (& $script:SafeCommands['Get-Alias'] -Definition "PesterMock_*")) {
        & $script:SafeCommands['Remove-Item'] "alias:/$($alias.Name)"
    }

    foreach ($bootstrapFunction in (& $script:SafeCommands['Get-Command'] -Name "PesterMock_*")) {
        & $script:SafeCommands['Remove-Item'] "function:/$($bootstrapFunction.Name)"
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

    $repairedMetadata = New-Object System.Management.Automation.CommandMetadata -ArgumentList $Metadata
    $paramMetadatas = @()
    $paramMetadatas += $repairedMetadata.Parameters.Values

    $conflictingParams = Get-ConflictingParameterNames

    foreach ($paramMetadata in $paramMetadatas) {
        if ($paramMetadata.IsDynamic) {
            continue
        }

        if ($conflictingParams -contains $paramMetadata.Name) {
            $paramName = $paramMetadata.Name
            $newName = "_$paramName"
            $paramMetadata.Name = $newName
            $paramMetadata.Aliases.Add($paramName)

            $null = $repairedMetadata.Parameters.Remove($paramName)
            $repairedMetadata.Parameters.Add($newName, $paramMetadata)
        }

        $attrIndexesToRemove = New-Object System.Collections.ArrayList

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

function New-BlockWithoutParameterAliases {
    [CmdletBinding()]
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
