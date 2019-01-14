
function New-Mock {
    [CmdletBinding()]
    param(
        [string]$CommandName,
        [ScriptBlock]$MockWith = {},
        [switch]$Verifiable,
        [ScriptBlock]$ParameterFilter = {$True},
        [string]$ModuleName,
        [Parameter(Mandatory)]
        [Management.Automation.SessionState] $SessionState,
        $MockTable = @{},
        # current test group should probably be removed/renames, mock should not care
        # about the current place where it is running, it should simple add the mock to the
        # provided mock table (or return it??), the scoping concern should be maintained
        # externally be giving Assert-MockCalled the appropriate mock table (or aggregation of them)
        $CurrentTestGroup,

        # this is a bit complicated, the mock that is generated needs to call a function that provides
        # our Invoke-MockInternal with the correct mock table, but that is coming from the upper layer
        # not this layer, we then need to pass the reference to this script block to the bootstrapper
        # function and this function then hopefully calls our internal Invoke-MockInternalFunction
        # TODO: will this be able to see the correct state? it needs to be defined (or executed) in the same module as
        # Invoke-MockInternal
        [Parameter(Mandatory)]
        $InvokeMockCallback
    )

    $contextInfo = Resolve-Command $CommandName $ModuleName -SessionState $SessionState -MockTable $MockTable

    if (Test-IsClosure -ScriptBlock $MockWith) {
        # If the user went out of their way to call GetNewClosure(), go ahead and leave the block bound to that
        # dynamic module's scope.
        $mockWithCopy = $MockWith
    }
    else {
        Write-Hint "Unbinding ScriptBlock from '$(Get-ScriptBlockHint $MockWith)'"
        $mockWithCopy = [scriptblock]::Create($MockWith.ToString())
        Set-ScriptBlockHint -ScriptBlock $mockWithCopy -Hint "Unbound ScriptBlock from Mock"
        Set-ScriptBlockScope -ScriptBlock $mockWithCopy -SessionState $contextInfo.SessionState
    }

    $block = @{
        Mock       = $mockWithCopy
        Filter     = $ParameterFilter
        Verifiable = $Verifiable
        Scope      = $CurrentTestGroup
    }

    $moduleName = if ($null -ne $contextInfo.Module) { $contextInfo.Module.Name }
    $mock = $MockTable["$moduleName||$($contextInfo.Command.Name)"]

    if (-not $mock) {
        $mock = Create-Mock -ContextInfo $contextInfo -InvokeMockCallback ($InvokeMockCallback)
    }

    $mock.Blocks = @(
        $mock.Blocks | & $SafeCommands['Where-Object'] { $_.Filter.ToString() -eq '$True' }
        if ($block.Filter.ToString() -eq '$True') {
            $block
        }

        $mock.Blocks | & $SafeCommands['Where-Object'] { $_.Filter.ToString() -ne '$True' }
        if ($block.Filter.ToString() -ne '$True') {
            $block
        }
    )
}

function EscapeSingleQuotedStringContent ($Content) {
    if ($global:PSVersionTable.PSVersion.Major -ge 5) {
        [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($Content)
    }
    else {
        $Content -replace "['‘’‚‛]", '$&$&'
    }
}

function Create-Mock ($contextInfo, $InvokeMockCallback) {
    $commandName = $contextInfo.Command.Name
    $moduleName = if ($null -ne $contextInfo.Module) { $contextInfo.Module.Name } else { '' }
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

        $paramBlock = [Management.Automation.ProxyCommand]::GetParamBlock($metadata)

        if ($contextInfo.Command.CommandType -eq 'Cmdlet') {
            $dynamicParamBlock = "dynamicparam { Get-MockDynamicParameter -CmdletName '$($contextInfo.Command.Name)' -Parameters `$PSBoundParameters }"
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
                $dynamicParamBlock = "dynamicparam { `$MyInvocation.MyCommand.Mock.Get_MockDynamicParameter -ModuleName '$moduleName' -FunctionName '$commandName' -Parameters `$PSBoundParameters -Cmdlet `$PSCmdlet }"

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
    `$MyInvocation.MyCommand.Mock.Args = `$null
    if (#CANCAPTUREARGS#) {
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
    & `$MyInvocation.MyCommand.Mock.Invoke_Mock -CommandName '#FUNCTIONNAME#' -ModuleName '#MODULENAME#' ```
        -BoundParameters `$PSBoundParameters ```
        -ArgumentList `$MyInvocation.MyCommand.Mock.Args ```
        -CallerSessionState `$MyInvocation.MyCommand.Mock.SessionState ```
        -MockCallState `$MyInvocation.MyCommand.Mock.MockCallState ```
        -FromBlock '#BLOCK#' #INPUT#
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
        `$MyInvocation.MyCommand.Mock.MockCallState = @{}
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
        Blocks                  = @()
        CommandName             = $commandName
        SessionState            = $contextInfo.SessionState
        Scope                   = $CurrentTestGroup
        # TODO: get rid of this binding to state
        PesterState             = $null #$pester
        Metadata                = $metadata
        CallHistory             = @()
        DynamicParamScriptBlock = $dynamicParamScriptBlock
        Aliases                 = @()
        BootstrapFunctionName   = 'PesterMock_' + [Guid]::NewGuid().Guid
    }

    $mockTable["$ModuleName||$CommandName"] = $mock

    $defineFunctionAndAliases = {
        param($___Mock___parameters)
        # Make sure the you don't use _______parameters variable here, otherwise you overwrite
        # the variable that is defined in the same scope and the subsequent invocation of scrips will
        # be seriously broken (e.g. you will start resolving setups). But such is life of running in once scope.
        # from upper scope for no reason. But the reason is that you deleted ______param in this scope,
        # and so ______param from the parent scope was inherited

        ## THIS RUNS IN USER SCOPE, BE CAREFUL WHAT YOU PUBLISH AND COSUME

        # define the function and returns an array so we need to take the function out
        @($ExecutionContext.InvokeProvider.Item.Set("Function:\$($___Mock___parameters.BootstrapFunctionName)", $___Mock___parameters.Definition, $true, $true))[0]

        # define all aliases
        foreach ($______current in $___Mock___parameters.Aliases) {
            & $___Mock___parameters.Set_Alias -Name $______current -Value $___Mock___parameters.BootstrapFunctionName
        }

        # clean up the variable
        & $___Mock___parameters.Remove_Variable -Name ______current
        & $___Mock___parameters.Remove_Variable -Name ___Mock___parameters
    }


    $parameters = @{
        BootstrapFunctionName = $mock.BootstrapFunctionName
        Definition            = $mockScript
        Aliases               = @($CommandName)

        Set_Alias             = $SafeCommands["Set-Alias"]
        Remove_Variable       = $SafeCommands["Remove-Variable"]
        #Add_Member            = $SafeCommands["Add-Member"]

        # used as a temp variable
        Function              = $null
        #FunctionLocalData     = $functionLocalData
    }

    if ($mock.OriginalCommand.ModuleName) {
        $parameters.Aliases += "$($mock.OriginalCommand.ModuleName)\$($CommandName)"
    }

    $definedFunction = Invoke-InMockScope -SessionState $mock.SessionState -ScriptBlock $defineFunctionAndAliases -Arguments @($parameters) -NoNewScope

    # attaching this object on the newly created function
    # so it has access to our internal and safe functions directly
    # and also to avoid any local variables, because everything is
    # accessed via $MyInvocation.MyCommand
    $functionLocalData = @{
        Args          = $null
        ErrorAction   = if ($PSVersionTable.PSVersion.Major -ge 3) { 'Ignore' } else { 'SilentlyContinue' }
        SessionState  = $null
        MockCallState = $null

        Get_Variable  = $SafeCommands["Get-Variable"]
        Invoke_Mock   = $InvokeMockCallBack

        # used as temp variable
        PSCmdlet      = $null
    }

    & $SafeCommands["Add-Member"] -InputObject $definedFunction -MemberType NoteProperty -Name Mock -Value $functionLocalData

    $mock
}

function Assert-VerifiableMockIntenal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [HashTable] $MockTable
    )

    $unVerified = @{}
    $mockTable.Keys | & $SafeCommands['ForEach-Object'] {
        $m = $_;

        $mockTable[$m].blocks |
            & $SafeCommands['Where-Object'] { $_.Verifiable } |
            & $SafeCommands['ForEach-Object'] { $unVerified[$m] = $_ }
    }
    if ($unVerified.Count -gt 0) {
        foreach ($mock in $unVerified.Keys) {
            $array = $mock -split '\|\|'
            $function = $array[1]
            $module = $array[0]

            $message = "$([System.Environment]::NewLine) Expected $function "
            if ($module) {
                $message += "in module $module "
            }
            $message += "to be called with $($unVerified[$mock].Filter)"
        }
        throw $message
    }
}

function Assert-MockCalledInternal {
    [CmdletBinding(DefaultParameterSetName = 'ParameterFilter')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$CommandName,

        [Parameter(Position = 1)]
        [int]$Times = 1,

        [Parameter(ParameterSetName = 'ParameterFilter', Position = 2)]
        [ScriptBlock]$ParameterFilter = {$True},

        [Parameter(ParameterSetName = 'ExclusiveFilter', Mandatory = $true)]
        [scriptblock] $ExclusiveFilter,

        [Parameter(Position = 3)]
        [string] $ModuleName,

        [Parameter(Position = 4)]
        [ValidateScript( {
                if ([uint32]::TryParse($_, [ref] $null) -or
                    $_ -eq 'Describe' -or
                    $_ -eq 'Context' -or
                    $_ -eq 'It' -or
                    $_ -eq 'Feature' -or
                    $_ -eq 'Scenario') {
                    return $true
                }

                throw "Scope argument must either be an unsigned integer, or one of the words 'Describe', 'Context', 'It', 'Feature', or 'Scenario'."
            })]
        [string] $Scope,
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

    $contextInfo = Resolve-Command $CommandName $ModuleName -SessionState $SessionState -MockTable $MockTable
    $CommandName = $contextInfo.Command.Name

    $mock = $MockTable["$ModuleName||$CommandName"]

    $moduleMessage = ''
    if ($ModuleName) {
        $moduleMessage = " in module $ModuleName"
    }

    if (-not $mock) {
        throw "You did not declare a mock of the $commandName Command${moduleMessage}."
    }

    if (-not $PSBoundParameters.ContainsKey('Scope')) {
        $scope = 1
    }

    $matchingCalls = & $SafeCommands['New-Object'] System.Collections.ArrayList
    $nonMatchingCalls = & $SafeCommands['New-Object'] System.Collections.ArrayList

    foreach ($historyEntry in $mock.CallHistory) {
        if (-not (Test-MockCallScope -CallScope $historyEntry.Scope -DesiredScope $Scope)) {
            continue
        }

        $params = @{
            ScriptBlock     = $filter
            BoundParameters = $historyEntry.BoundParams
            ArgumentList    = $historyEntry.Args
            Metadata        = $mock.Metadata
            SessionState    = $SessionState
        }


        if (Test-ParameterFilter @params) {
            $null = $matchingCalls.Add($historyEntry)
        }
        else {
            $null = $nonMatchingCalls.Add($historyEntry)
        }
    }


    $lineText = $MyInvocation.Line.TrimEnd("$([System.Environment]::NewLine)")
    $line = $MyInvocation.ScriptLineNumber

    # todo: return this as an object and throw externally? so Mock is sepearate from Should
    if ($matchingCalls.Count -ne $times -and ($Exactly -or ($times -eq 0))) {
        $failureMessage = "Expected ${commandName}${moduleMessage} to be called $times times exactly but was called $($matchingCalls.Count) times"
        throw ( New-ShouldErrorRecord -Message $failureMessage -Line $line -LineText $lineText)
    }
    elseif ($matchingCalls.Count -lt $times) {
        $failureMessage = "Expected ${commandName}${moduleMessage} to be called at least $times times but was called $($matchingCalls.Count) times"
        throw ( New-ShouldErrorRecord -Message $failureMessage -Line $line -LineText $lineText)
    }
    elseif ($filterIsExclusive -and $nonMatchingCalls.Count -gt 0) {
        $failureMessage = "Expected ${commandName}${moduleMessage} to only be called with with parameters matching the specified filter, but $($nonMatchingCalls.Count) non-matching calls were made"
        throw ( New-ShouldErrorRecord -Message $failureMessage -Line $line -LineText $lineText)
    }
}

function Test-MockCallScope {
    [CmdletBinding()]
    param (
        [object] $CallScope,
        [string] $DesiredScope
    )

    if ($null -eq $CallScope) {
        # This indicates a call from the current test case ("It" block), which always passes Test-MockCallScope
        return $true
    }

    $testGroups = $pester.TestGroups
    [Array]::Reverse($testGroups)

    $target = 0
    $isNumberedScope = [int]::TryParse($DesiredScope, [ref] $target)

    # The Describe / Context stuff here is for backward compatibility.  May be deprecated / removed in the future.
    $actualScopeNumber = -1
    $describe = -1
    $context = -1

    for ($i = 0; $i -lt $testGroups.Count; $i++) {
        if ($CallScope -eq $testGroups[$i]) {
            $actualScopeNumber = $i
            if ($isNumberedScope) {
                break
            }
        }

        if ($describe -lt 0 -and 'Describe', 'Feature' -contains $testGroups[$i].Hint) {
            $describe = $i
        }
        if ($context -lt 0 -and 'Context', 'Scenario' -contains $testGroups[$i].Hint) {
            $context = $i
        }
    }

    if ($actualScopeNumber -lt 0) {
        # this should never happen; if we get here, it's a Pester bug.

        throw "Pester error: Corrupted mock call history table."
    }

    if ($isNumberedScope) {
        # For this, we consider scope 0 to be the current test case / It block, scope 1 to be the first Test Group up the stack, etc.
        # $actualScopeNumber currently off by one from that scale (zero-indexed for test groups only; we already checked for the 0 case
        # farther up, which only applies if $CallScope is $null).
        return $target -gt $actualScopeNumber
    }
    else {
        if ('Describe', 'Feature' -contains $DesiredScope) {
            return $describe -ge $actualScopeNumber
        }
        if ('Context', 'Scenario' -contains $DesiredScope) {
            return $context -ge $actualScopeNumber
        }
    }

    return $false
}

function Exit-MockScope {
    param (
        [switch] $ExitTestCaseOnly
    )

    if ($null -eq $mockTable) {
        return
    }

    $removeMockStub =
    {
        param (
            [string] $CommandName,
            [string[]] $Aliases
        )

        $ExecutionContext.InvokeProvider.Item.Remove("Function:\$CommandName", $false, $true, $true)

        foreach ($alias in $Aliases) {
            if ($ExecutionContext.InvokeProvider.Item.Exists("Alias:$alias", $true, $true)) {
                $ExecutionContext.InvokeProvider.Item.Remove("Alias:$alias", $false, $true, $true)
            }
        }
    }

    $mockKeys = [string[]]$mockTable.Keys

    foreach ($mockKey in $mockKeys) {
        $mock = $mockTable[$mockKey]

        $shouldRemoveMock = (-not $ExitTestCaseOnly) -and (ShouldRemoveMock -Mock $mock -ActivePesterState $pester)
        if ($shouldRemoveMock) {
            $null = Invoke-InMockScope -SessionState $mock.SessionState -ScriptBlock $removeMockStub -ArgumentList $mock.BootstrapFunctionName, $mock.Aliases
            $mockTable.Remove($mockKey)
        }
        elseif ($mock.PesterState -eq $pester) {
            if (-not $ExitTestCaseOnly) {
                $mock.Blocks = @($mock.Blocks | & $SafeCommands['Where-Object'] { $_.Scope -ne $pester.CurrentTestGroup })
            }

            $testGroups = @($pester.TestGroups)

            $parentTestGroup = $null

            if ($testGroups.Count -gt 1) {
                $parentTestGroup = $testGroups[-2]
            }

            foreach ($historyEntry in $mock.CallHistory) {
                if ($ExitTestCaseOnly) {
                    if ($null -eq $historyEntry.Scope) {
                        $historyEntry.Scope = $pester.CurrentTestGroup
                    }
                }
                elseif ($parentTestGroup) {
                    if ($historyEntry.Scope -eq $pester.CurrentTestGroup) {
                        $historyEntry.Scope = $parentTestGroup
                    }
                }
            }
        }
    }
}

function ShouldRemoveMock($Mock, $ActivePesterState) {
    # I guess this is because we want to be able to run
    # Pester in Pester? this is reference comparison so not
    # and I don't see why there should be two pester states
    # at the same time otherwise
    if ($ActivePesterState -ne $mock.PesterState) {
        return $false
    }
    if ($mock.Scope -eq $ActivePesterState.CurrentTestGroup) {
        return $true
    }

    # These two should conditions should _probably_ never happen, because the above condition should
    # catch it, but just in case:
    if ($ActivePesterState.TestGroups.Count -eq 1) {
        return $true
    }
    if ($ActivePesterState.TestGroups[-2].Hint -eq 'Root') {
        return $true
    }

    return $false
}

function Resolve-Command {
    param (
        [string] $CommandName,
        [string] $ModuleName,
        [Parameter(Mandatory)]
        [Management.Automation.SessionState] $SessionState,
        [Parameter(Mandatory)]
        [HashTable] $MockTable
    )

    $command = $null
    $module = $null

    $findAndResolveCommand = {
        param ($Name)

        # this scriptblock gets bound to multiple session states so we can find
        # commands in module or in caller scope

        $command = $ExecutionContext.InvokeCommand.GetCommand($Name, 'All')
        # resolve command from alias recursively
        while ($null -ne $command -and $command.CommandType -eq [System.Management.Automation.CommandTypes]::Alias) {
            $command = $command.ResolvedCommand
        }

        return $command
    }

    if ($ModuleName) {
        $module = Get-ScriptModule -ModuleName $ModuleName -ErrorAction Stop
        $SessionState = Set-SessionStateHint -PassThru  -Hint "Module - $($module.Name)" -SessionState ( $module.SessionState )
        $command = & $module $findAndResolveCommand -Name $CommandName
    }
    else {
        # TODO: breaking change here, this used to resolve the command in the caller scope if the command was not found in the module scope, but that does not make sense does it? When the user specifies that he want's to use Module it should use just Module.

        Set-ScriptBlockScope -ScriptBlock $findAndResolveCommand -SessionState $SessionState
        $command = & $findAndResolveCommand -Name $CommandName
    }

    if (-not $command) {
        throw ([System.Management.Automation.CommandNotFoundException] "Could not find Command $CommandName")
    }

    if ($command.CommandType -eq 'Function') {
        # TODO: finds command in mock table, so does that mean that mocking a
        # bootstrap function will bind to the same scope as the original mock?
        # Why do we want that?
        foreach ($mock in $MockTable.Values) {
            if ($command.Name -eq $mock.BootstrapFunctionName) {
                $module = $mock.SessionState.Module
                return @{
                    Command                 = $mock.OriginalCommand
                    SessionState            = $mock.SessionState
                    Module                  = $module
                    IsFromModule = $null -ne $module
                    IsFromRequestedModule   = $null -ne $module -and $module -eq $ModuleName
                    IsMockBootstrapFunction = $true
                }
            }
        }
    }

    return @{
        Command                 = $command
        SessionState            = $SessionState
        Module                  = $module

        IsFromModule            = $null -ne $module
        IsFromRequestedModule   = $null -ne $module -and $module.Name -eq $ModuleName
        IsMockBootstrapFunction = $false
    }
}
function Invoke-MockInternal {
    <#
        .SYNOPSIS
        This command is used by Pester's Mocking framework.  You do not need to call it directly.
    #>

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
        $BoundParameters = @{},

        [object[]]
        $ArgumentList = @(),

        [object] $CallerSessionState,

        [ValidateSet('Begin', 'Process', 'End')]
        [string] $FromBlock,

        [object] $InputObject,

        [Parameter(Mandatory)]
        [HashTable]
        $MockTable,

        [Parameter(Mandatory)]
        [Management.Automation.SessionState]
        $SessionState
    )

    $detectedModule = $ModuleName
    $mock = FindMock -CommandName $CommandName -ModuleName ([ref]$detectedModule) -MockTable $MockTable

    if ($null -eq $mock) {
        # If this ever happens, it's a bug in Pester.  The scriptBlock that calls Invoke-Mock should be removed at the same time as the entry in the mock table.
        throw "Internal error detected:  Mock for '$CommandName' in module '$ModuleName' was called, but does not exist in the mock table."
    }

    switch ($FromBlock) {
        Begin {
            $MockCallState['InputObjects'] = & $SafeCommands['New-Object'] System.Collections.ArrayList
            $MockCallState['ShouldExecuteOriginalCommand'] = $false
            $MockCallState['BeginBoundParameters'] = $BoundParameters.Clone()
            $MockCallState['BeginArgumentList'] = $ArgumentList

            return
        }

        Process {
            $block = $null
            if ($detectedModule -eq $ModuleName) {
                $block = FindMatchingBlock -Mock $mock -BoundParameters $BoundParameters -ArgumentList $ArgumentList -SessionState $SessionState
            }

            if ($null -ne $block) {
                ExecuteBlock -Block $block `
                    -CommandName $CommandName `
                    -ModuleName $ModuleName `
                    -BoundParameters $BoundParameters `
                    -ArgumentList $ArgumentList `
                    -Mock $mock

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

                $state = if ($CallerSessionState) {
                    $CallerSessionState
                }
                else {
                    $mock.SessionState
                }

                Set-ScriptBlockScope -ScriptBlock $scriptBlock -SessionState $state

                # In order to mock Set-Variable correctly we need to write the variable
                # two scopes above
                if ( $mock.OriginalCommand -like "Set-Variable" ) {
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

                Write-ScriptBlockInvocationHint -Hint "Mock - Original Command" -ScriptBlock $scriptBlock
                & $scriptBlock -Command $mock.OriginalCommand `
                    -ArgumentList $MockCallState['BeginArgumentList'] `
                    -BoundParameters $MockCallState['BeginBoundParameters'] `
                    -InputObjects $MockCallState['InputObjects']
            }
        }
    }
}

function FindMock {
    param (
        [string] $CommandName,
        [ref] $ModuleName,
        [Parameter(Mandatory)]
        [HashTable] $MockTable
    )

    $mock = $MockTable["$($ModuleName.Value)||$CommandName"]

    if ($null -eq $mock) {
        $mock = $MockTable["||$CommandName"]
        if ($null -ne $mock) {
            $ModuleName.Value = ''
        }
    }

    return $mock
}

function FindMatchingBlock {
    param (
        [object] $Mock,
        [hashtable] $BoundParameters = @{},
        [object[]] $ArgumentList = @(),
        [Parameter(Mandatory)]
        [Management.Automation.SessionState] $SessionState
    )

    for ($idx = $mock.Blocks.Length; $idx -gt 0; $idx--) {
        $block = $mock.Blocks[$idx - 1]

        $params = @{
            ScriptBlock     = $block.Filter
            BoundParameters = $BoundParameters
            ArgumentList    = $ArgumentList
            Metadata        = $mock.Metadata
            SessionState    = $SessionState
        }

        if (Test-ParameterFilter @params) {
            return $block
        }
    }

    return $null
}

function ExecuteBlock {
    param (
        [object] $Block,
        [object] $Mock,
        [string] $CommandName,
        [string] $ModuleName,
        [hashtable] $BoundParameters = @{},
        [object[]] $ArgumentList = @()
    )

    $Block.Verifiable = $false

    $scope = if ($pester.InTest) {
        $null
    }
    else {
        $pester.CurrentTestGroup
    }
    $Mock.CallHistory += @{CommandName = "$ModuleName||$CommandName"; BoundParams = $BoundParameters; Args = $ArgumentList; Scope = $scope }

    $scriptBlock = {
        param (
            [Parameter(Mandatory = $true)]
            [scriptblock]
            ${Script Block},

            [hashtable]
            $___BoundParameters___ = @{},

            [object[]]
            $___ArgumentList___ = @(),

            [System.Management.Automation.CommandMetadata]
            ${Meta data},

            [System.Management.Automation.SessionState]
            ${Session State},

            ${R e p o r t S c o p e},

            ${M o d u l e N a m e}
        )

        # This script block exists to hold variables without polluting the test script's current scope.
        # Dynamic parameters in functions, for some reason, only exist in $PSBoundParameters instead
        # of being assigned a local variable the way static parameters do.  By calling Set-DynamicParameterVariable,
        # we create these variables for the caller's use in a Parameter Filter or within the mock itself, and
        # by doing it inside this temporary script block, those variables don't stick around longer than they
        # should.

        Set-DynamicParameterVariable -SessionState ${Session State} -Parameters $___BoundParameters___ -Metadata ${Meta data}
        # Name property is not present on Application Command metadata in PowerShell 2
        & ${R e p o r t S c o p e} -ModuleName ${M o d u l e N a m e} -CommandName $(try {
                ${Meta data}.Name
            }
            catch {
            }) -ScriptBlock ${Script Block}
        & ${Script Block} @___BoundParameters___ @___ArgumentList___
    }

    Set-ScriptBlockScope -ScriptBlock $scriptBlock -SessionState $mock.SessionState
    $splat = @{
        'Script Block'          = $block.Mock
        '___ArgumentList___'    = $ArgumentList
        '___BoundParameters___' = $BoundParameters
        'Meta data'             = $mock.Metadata
        'Session State'         = $mock.SessionState
        'R e p o r t S c o p e' = { param ($CommandName, $ModuleName, $ScriptBlock)
            Write-ScriptBlockInvocationHint -Hint "Mock - of command $CommandName$(if ($ModuleName) { "from module $ModuleName"})" -ScriptBlock $ScriptBlock }
    }

    # the real scriptblock is passed to the other one, we are interested in the mock, not the wrapper, so I pass $block.Mock, and not $scriptBlock

    Write-ScriptBlockInvocationHint -Hint "Mock - of command $CommandName$(if ($ModuleName) { "from module $ModuleName"})" -ScriptBlock ($block.Mock)
    & $scriptBlock @splat
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
    Write-ScriptBlockInvocationHint -Hint "Mock - InMockScope" -ScriptBlock $ScriptBlock
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
        $BoundParameters = @{}
    }
    if ($null -eq $ArgumentList) {
        $ArgumentList = @()
    }

    $paramBlock = Get-ParamBlockFromBoundParameters -BoundParameters $BoundParameters -Metadata $Metadata

    $scriptBlockString = "
        $paramBlock

        Set-StrictMode -Off
        $ScriptBlock
    "
    Write-Hint "Unbinding ScriptBlock from '$(Get-ScriptBlockHint $ScriptBlock)'"
    $cmd = [scriptblock]::Create($scriptBlockString)
    Set-ScriptBlockHint -ScriptBlock $cmd -Hint "Unbound ScriptBlock from Test-ParameterFilter"
    Set-ScriptBlockScope -ScriptBlock $cmd -SessionState $SessionState

    Write-ScriptBlockInvocationHint -Hint "Mock - Parameter filter" -ScriptBlock $cmd
    & $cmd @BoundParameters @ArgumentList
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
        $Parameters = @{}
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
    <#
        .SYNOPSIS
        This command is used by Pester's Mocking framework.  You do not need to call it directly.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Cmdlet')]
        [string] $CmdletName,

        [Parameter(Mandatory = $true, ParameterSetName = 'Function')]
        [string] $FunctionName,

        [Parameter(ParameterSetName = 'Function')]
        [string] $ModuleName,

        [System.Collections.IDictionary] $Parameters,

        [object] $Cmdlet
    )

    switch ($PSCmdlet.ParameterSetName) {
        'Cmdlet' {
            Get-DynamicParametersForCmdlet -CmdletName $CmdletName -Parameters $Parameters
        }

        'Function' {
            Get-DynamicParametersForMockedFunction -FunctionName $FunctionName -ModuleName $ModuleName -Parameters $Parameters -Cmdlet $Cmdlet
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
            $Parameters = @{}
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
        [Parameter(Mandatory = $true)]
        [string]
        $FunctionName,

        [string]
        $ModuleName,

        [System.Collections.IDictionary]
        $Parameters,

        [object]
        $Cmdlet
    )

    $mock = $mockTable["$ModuleName||$FunctionName"]

    if (-not $mock) {
        throw "Internal error detected:  Mock for '$FunctionName' in module '$ModuleName' was called, but does not exist in the mock table."
    }

    if ($mock.DynamicParamScriptBlock) {
        $splat = @{ 'P S Cmdlet' = $Cmdlet }
        return & $mock.DynamicParamScriptBlock @Parameters @splat
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

