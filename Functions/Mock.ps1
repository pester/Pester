﻿function Mock {

<#
.SYNOPSIS
Mocks the behavior of an existing command with an alternate 
implementation.

.DESCRIPTION
This creates new behavior for any existing command within the scope of a 
Describe block. The function allows you to specify a ScriptBlock that will 
become the commands new behavior. 

Optionally you may create a Parameter Filter which will examine the 
parameters passed to the mocked command and will invoke the mocked 
behavior only if the values of the parameter values pass the filter. If 
they do not, the original commnd implementation will be invoked instead 
of the mock.

You may create multiple mocks for the same command, each using a different
ParameterFilter. ParameterFilters will be evaluated in reverse order of 
their creation. The last one created will be the first to be evaluated. 
The mock of the first filter to pass will be used. The exception to this 
rule are Mocks with no filters. They will always be evaluated last since 
they will act as a "catch all" mock.

Mocks can be marked Verifiable. If so, the Assert-VerifiableMocks can be 
used to check if all Verifiable mocks were actually called. If any 
verifiable mock is not called, Assert-VerifiableMocks will throw an 
exception and indicate all mocks not called.

You can mock commands on behalf of different calling scopes by using the
-ModuleName parameter.  If you do not specify a ModuleName, the command
is mocked in the scope of the test script.  If the mocked command needs
to be called from inside a module, Mock it with the -ModuleName parameter
instead.  You may mock the same command multiple times, in multiple scopes,
as necessary.

.PARAMETER CommandName
The name of the command to be mocked.

.PARAMETER MockWith
A ScriptBlock specifying the behvior that will be used to mock CommandName.
The default is an empty ScriptBlock.

.PARAMETER Verifiable
When this is set, the mock will be checked when using Assert-VerifiableMocks 
to ensure the mock was called.

.PARAMETER ParameterFilter
An optional filter to limit mocking behavior only to usages of 
CommandName where the values of the parameters passed to the command 
pass the filter.

This ScriptBlock must return a boolean value. See examples for usage.

.PARAMETER ModuleName
Optional string specifying the name of the module where this command
is to be mocked.  This should be a module that _calls_ the mocked
command; it doesn't necessarily have to be the same module which
originally implemented the command.

.EXAMPLE
Mock Get-ChildItem {return @{FullName="A_File.TXT"}}

Using this Mock, all calls to Get-ChildItem will return an object with a 
FullName property returning "A_File.TXT"

.EXAMPLE
Mock Get-ChildItem {return @{FullName="A_File.TXT"}} -ParameterFilter {$Path.StartsWith($env:temp)}

This Mock will only be applied to Get-ChildItem calls within the user's temp directory.

.EXAMPLE
Mock Set-Content -Verifiable -ParameterFilter {$Path -eq "some_path" -and $Value -eq "Expected Value"}

When this mock is used, if the Mock is never invoked and Assert-VerifiableMocks is called, an exception will be thrown. The command behavior will do nothing since the ScriptBlock is empty.

.EXAMPLE
c:\PS>Mock Get-ChildItem {return @{FullName="A_File.TXT"}} -ParameterFilter {$Path.StartsWith($env:temp\1)}
c:\PS>Mock Get-ChildItem {return @{FullName="B_File.TXT"}} -ParameterFilter {$Path.StartsWith($env:temp\2)}
c:\PS>Mock Get-ChildItem {return @{FullName="C_File.TXT"}} -ParameterFilter {$Path.StartsWith($env:temp\3)}

Multiple mocks of the same command may be used. The parameter filter determines which is invoked. Here, if Get-ChildItem is called on the "2" directory of the temp folder, then B_File.txt will be returned.

.EXAMPLE
Mock Get-ChildItem {return @{FullName="B_File.TXT"}} -ParameterFilter {$Path -eq "$env:temp\me"}
Mock Get-ChildItem {return @{FullName="A_File.TXT"}} -ParameterFilter {$Path.StartsWith($env:temp)}

Get-ChildItem $env:temp\me

Here, both mocks could apply since both filters will pass. A_File.TXT will be returned because it was the last Mock created.

.EXAMPLE
Mock Get-ChildItem {return @{FullName="B_File.TXT"}} -ParameterFilter {$Path -eq "$env:temp\me"}
Mock Get-ChildItem {return @{FullName="A_File.TXT"}}

Get-ChildItem c:\windows

Here, A_File.TXT will be returned. Since no filterwas specified, it will apply to any call to Get-ChildItem that does not pass another filter.

.EXAMPLE
Mock Get-ChildItem {return @{FullName="B_File.TXT"}} -ParameterFilter {$Path -eq "$env:temp\me"}
Mock Get-ChildItem {return @{FullName="A_File.TXT"}}

Get-ChildItem $env:temp\me

Here, B_File.TXT will be returned. Even though the filterless mock was created last. This illustrates that filterless Mocks are always evaluated last regardlss of their creation order.

.EXAMPLE
Mock -ModuleName MyTestModule Get-ChildItem {return @{FullName="A_File.TXT"}}

Using this Mock, all calls to Get-ChildItem from within the MyTestModule module
will return an object with a FullName property returning "A_File.TXT"

.EXAMPLE
    Describe "BuildIfChanged" {
        Mock Get-Version {return 1.1}
        Context "Wnen there are Changes" {
            Mock Get-NextVersion {return 1.2}
            Mock Build {} -Verifiable -ParameterFilter {$version -eq 1.2}

            $result = BuildIfChanged

            It "Builds the next version" {
                Assert-VerifiableMocks
            }
            It "returns the next version number" {
                $result.Should.Be(1.2)
            }
        }
        Context "Wnen there are no Changes" {
            Mock Get-NextVersion -MockWith {return 1.1}
            Mock Build -MockWith {}

            $result = BuildIfChanged

            It "Should not build the next version" {
                Assert-MockCalled Build -Times 0 -ParameterFilter{$version -eq 1.1}
            }
        }
    }

    Notice how 'Mock Get-Version {return 1.1}' is declared within the 
    Describe block. This allows all Context and It blocks inside the describe 
    to use this Mock. If a context scoped mock, mocks Get-Version, that mock 
    will override the describe scoped mock within that contex tif both mocks 
    apply to the parameters passed to Get-Version.

.EXAMPLE
Mock internal module function with Mock.

Get-Module -Name ModuleMockExample | Remove-Module 
New-Module -Name ModuleMockExample  -ScriptBlock {
	function Hidden {"Hidden"}
	function Exported { Hidden }
	
	Export-ModuleMember -Function Exported
} | Import-Module -Force

Describe "ModuleMockExample" {

	It "Hidden function is not directly accessible outside the module" {
		{ ModuleMockExample\Hidden } | Should Throw
	}
	
	It "Original Hidden function is called" {
		Exported | Should Be "Hidden"
	}
	
	It "Hidden is replaced with our implementation" {
		Mock Hidden { "mocked" } -ModuleName ModuleMockExample
		Exported | Should Be "mocked"
	}
}
	
.LINK
about_Mocking
#>

    param(
        [string]$CommandName, 
        [ScriptBlock]$MockWith={}, 
        [switch]$Verifiable, 
        [ScriptBlock]$ParameterFilter = {$True},
        [string]$ModuleName
    )
    
    $filterTest = Test-ParameterFilter -ScriptBlock $ParameterFilter

    if ($filterTest -isnot [bool]) { throw [System.Management.Automation.PSArgumentException] 'The Parameter Filter must return a boolean' }

    $contextInfo = Validate-Command $CommandName $ModuleName
    $CommandName = $contextInfo.Command.Name
    
    if ($contextInfo.Session.Module -and $contextInfo.Session.Module.Name)
    {
        $ModuleName = $contextInfo.Session.Module.Name
    }
    else
    {
        $ModuleName = ''
    }
    
    $mockWithCopy = [scriptblock]::Create($MockWith.ToString())
    Set-ScriptBlockScope -ScriptBlock $mockWithCopy -SessionState $contextInfo.Session

    $block = @{
        Mock       = $mockWithCopy
        Filter     = $ParameterFilter
        Verifiable = $Verifiable
        Scope      = $pester.Scope
    }

    $mock = $mockTable["$ModuleName||$CommandName"]

    if (-not $mock)
    {
        $cmdletBinding = ''
        $paramBlock    = ''

        if ($contextInfo.Command.psobject.Properties['ScriptBlock'] -or $contextInfo.Command.CommandType -eq 'Cmdlet')
        {
            $metadata = [System.Management.Automation.CommandMetaData]$contextInfo.Command
            $metadata.Parameters.Remove('Verbose')         > $null
            $metadata.Parameters.Remove('Debug')           > $null
            $metadata.Parameters.Remove('ErrorAction')     > $null
            $metadata.Parameters.Remove('WarningAction')   > $null
            $metadata.Parameters.Remove('ErrorVariable')   > $null
            $metadata.Parameters.Remove('WarningVariable') > $null
            $metadata.Parameters.Remove('OutVariable')     > $null
            $metadata.Parameters.Remove('OutBuffer')       > $null

            $cmdletBinding = [Management.Automation.ProxyCommand]::GetCmdletBindingAttribute($metadata)
            $paramBlock    = [Management.Automation.ProxyCommand]::GetParamBlock($metadata)
        }

        $newContent = Microsoft.PowerShell.Management\Get-Content function:\MockPrototype
        $mockScript = "$cmdletBinding`r`n    param( $paramBlock )`r`n`r`n    process{`r`n$newContent}"

        $mock = @{
            OriginalCommand = $contextInfo.Command
            Blocks          = @()
            Cmdlet          = $cmdletBinding
            Params          = $paramBlock
            CommandName     = $CommandName
            SessionState    = $contextInfo.Session
            Scope           = $pester.Scope
            CallHistory     = @()
        }

        $mockTable["$ModuleName||$CommandName"] = $mock

        if ($contextInfo.Command.CommandType -eq 'Function')
        {
            $scriptBlock =
            {
                if ($ExecutionContext.InvokeProvider.Item.Exists("Function:\$args"))
                {
                    $ExecutionContext.InvokeProvider.Item.Rename("Function:\$args", "script:PesterIsMocking_$args", $true)
                }
            }

            $null = Invoke-InMockScope -SessionState $mock.SessionState -ScriptBlock $scriptBlock -ArgumentList $CommandName
        }
        
        $scriptBlock = { $ExecutionContext.InvokeProvider.Item.Set("Function:\script:$($args[0])", $args[1], $true, $true) }
        $null = Invoke-InMockScope -SessionState $mock.SessionState -ScriptBlock $scriptBlock -ArgumentList $CommandName, $mockScript
    }

    $mock.Blocks = @(
        $mock.Blocks | Where-Object { $_.Filter.ToString() -eq '$True' }
        if ($block.Filter.ToString() -eq '$True') { $block }

        $mock.Blocks | Where-Object { $_.Filter.ToString() -ne '$True' }
        if ($block.Filter.ToString() -ne '$True') { $block }
    )
}


function Assert-VerifiableMocks {
<#
.SYNOPSIS
Checks if any Verifiable Mock has not been invoked. If so, this will throw an exception.

.DESCRIPTION
This can be used in tandem with the -Verifiable switch of the Mock 
function. Mock can be used to mock the behavior of an existing command 
and optionally take a -Verifiable switch. When Assert-VerifiableMocks 
is called, it checks to see if any Mock marked Verifiable has not been 
invoked. If any mocks have been found that specified -Verifiable and 
have not been invoked, an exception will be thrown.

.EXAMPLE
Mock Set-Content {} -Verifiable -ParameterFilter {$Path -eq "some_path" -and $Value -eq "Expected Value"}

{ ...some code that never calls Set-Content some_path -Value "Expected Value"... }

Assert-VerifiableMocks

This will throw an exception and cause the test to fail.

.EXAMPLE
Mock Set-Content {} -Verifiable -ParameterFilter {$Path -eq "some_path" -and $Value -eq "Expected Value"}

Set-Content some_path -Value "Expected Value"

Assert-VerifiableMocks

This will not throw an exception because the mock was invoked.

#>
    $unVerified=@{}
    $mockTable.Keys | % { 
        $m=$_; $mockTable[$m].blocks | ? { $_.Verifiable } | % { $unVerified[$m]=$_ }
    }
    if($unVerified.Count -gt 0) {
        foreach($mock in $unVerified.Keys){
            $array = $mock -split '\|\|'
            $function = $array[1]
            $module = $array[0]

            $message = "`r`n Expected $function "
            if ($module) { $message += "in module $module " }
            $message += "to be called with $($unVerified[$mock].Filter)"
        }
        throw $message
    }
}

function Assert-MockCalled {
<#
.SYNOPSIS
Checks if a Mocked command has been called a certain number of times 
and throws an exception if it has not.

.DESCRIPTION
This command checks the call history of the specified Command, in the
specified Pester scope (or any child scopes). If it had been called less
than the number of  times specified (1 is the default), then an exception
is thrown. You  may specify 0 times if you want to make sure that the mock
has NOT  been called. If you include the Exactly switch, the number of times 
that the command has been called must mach exactly with the number of 
times specified on this command.

.PARAMETER CommandName
The name of the command to check for mock calls.

.PARAMETER ModuleName
The module where the mock being checked was injected.  This is optional,
and must match the ModuleName that was used when setting up the Mock.

.PARAMETER Times
The number of times that the mock must be called to avoid an exception 
from throwing.

.PARAMETER Exactly
If this switch is present, the number specifid in Times must match 
exactly the number of times the mock has been called. Otherwise it 
must match "at least" the number of times specified.

.PARAMETER ParameterFilter
An optional filter to qualify wich calls should be counted. Only those 
calls to the mock whose parameters cause this filter to return true 
will be counted.


.PARAMETER Scope
An optional parameter specifying the Pester scope in which to check for
calls to the mocked command.  By default, Assert-MockCalled will find
all calls to the mocked command, regardless of scope. Valid values are
Describe (the default), Context and It. If you use a scope of Describe
or Context, the command will identify all calls to the mocked command
in the current Describe / Context block, as well as all child scopes of
that block.

.EXAMPLE
C:\PS>Mock Set-Content {}

{... Some Code ...}

C:\PS>Assert-MockCalled Set-Content

This will throw an exception and cause the test to fail if Set-Content is not called in Some Code.

.EXAMPLE
C:\PS>Mock Set-Content -parameterFilter {$path.StartsWith("$env:temp\")}

{... Some Code ...}

C:\PS>Assert-MockCalled Set-Content 2 {$path=$env:temp\test.txt}

This will throw an exception if some code calls Set-Content on $path=$env:temp\test.txt less than 2 times 

.EXAMPLE
C:\PS>Mock Set-Content {}

{... Some Code ...}

C:\PS>Assert-MockCalled Set-Content 0

This will throw an exception if some code calls Set-Content at all

.EXAMPLE
C:\PS>Mock Set-Content {}

{... Some Code ...}

C:\PS>Assert-MockCalled Set-Content -Exactly 2

This will throw an exception if some code does not call Set-Content Exactly two times.

.EXAMPLE
Describe 'Describe' {
    Mock Set-Content { }

    {... Some Code ...}

    It 'Calls Set-Content at least once in the Describe block' {
        Assert-MockCalled Set-Content -Exactly 0 -Scope It
    }
}

Checks for calls only within the current It block

.EXAMPLE
Describe 'Describe' {
    Mock -ModuleName SomeModule Set-Content { }
    
    {... Some Code ...}

    It 'Calls Set-Content at least once in the Describe block' {
        Assert-MockCalled -ModuleName SomeModule Set-Content
    }
}

Checks for calls to the mock within the SomeModule module.  Note that both the Mock
and Assert-MockCalled commands use the same module name.

.NOTES
The parameter filter passed to Assert-MockCalled does not necessarily have to match the parameter filter
(if any) which was used to create the Mock.  Assert-MockCalled will find any entry in the command history
which matches its parameter filter, regardless of how the Mock was created.

#>

[CmdletBinding()]
param(
    [string]$CommandName,
    [switch]$Exactly,
    [int]$Times=1,
    [ScriptBlock]$ParameterFilter = {$True},
    [string] $ModuleName,

    [ValidateSet('Describe','Context','It')]
    [string] $Scope = 'Describe'
)
    $mock = $script:mockTable["$ModuleName||$commandName"]

    $moduleMessage = ''
    if ($ModuleName)
    {
        $moduleMessage = " in module $ModuleName"
    }

    if (-not $mock)
    {
        throw "You did not declare a mock of the $commandName Command${moduleMessage}."
    }

    if (-not $Scope)
    {
        $Scope = $pester.Scope
    }

    $cmd = [scriptblock]::Create("$($mock.CmdLet) `r`n param ( $($mock.Params) ) `r`n$parameterFilter")

    $qualifiedCalls = @(
        $mock.CallHistory |
        Where-Object {
            (Test-MockCallScope -CallScope $_.Scope -DesiredScope $Scope) -and
            (Test-ParameterFilter -ScriptBlock $ParameterFilter -BoundParameters $_.BoundParams -ArgumentList $_.Args -CmdletBinding $mock.Cmdlet -ParamBlock $mock.Params)
        }
    )

    if($qualifiedCalls.Length -ne $times -and ($Exactly -or ($times -eq 0))) {
        throw "Expected ${commandName}${$moduleMessage} to be called $times times exactly but was called $($qualifiedCalls.Length.ToString()) times"
    } elseif($qualifiedCalls.Length -lt $times) {
        throw "Expected ${commandName}${moduleMessage} to be called at least $times times but was called $($qualifiedCalls.Length) times"
    }
}

function Test-MockCallScope
{
    [CmdletBinding()]
    param (
        [string] $CallScope,
        [string] $DesiredScope
    )

    # It would probably be cleaner to replace all of these scope strings with an enumerated type at some point.
    $scopes = 'Describe', 'Context', 'It'

    return ([array]::IndexOf($scopes, $CallScope) -ge [array]::IndexOf($scopes, $DesiredScope))
}

function Clear-Mocks {
    if($mockTable){
        $currentScope = $pester.Scope
        $parentScope = $pester.ParentScope

        $scriptBlock =
        {
            param ([string] $CommandName)

            $ExecutionContext.InvokeProvider.Item.Remove("Function:\$CommandName", $false, $true, $true)
            if ($ExecutionContext.InvokeProvider.Item.Exists("Function:\PesterIsMocking_$CommandName", $true, $true))
            {
                $ExecutionContext.InvokeProvider.Item.Rename("Function:\PesterIsMocking_$CommandName", "script:$CommandName", $true)
            }
        }

        $mockKeys = [string[]]$mockTable.Keys

        foreach ($mockKey in $mockKeys)
        {
            $mock = $mockTable[$mockKey]
            $mock.Blocks = @($mock.Blocks | Where {$_.Scope -ne $pester.Scope})

            if ($null -eq $parentScope)
            {
                $null = Invoke-InMockScope -SessionState $mock.SessionState -ScriptBlock $scriptBlock -ArgumentList $mock.CommandName
                $mockTable.Remove($mockKey)
            }
            else
            {
                foreach ($historyEntry in $mock.CallHistory)
                {
                    if ($historyEntry.Scope -eq $currentScope) { $historyEntry.Scope = $parentScope }
                }
            }
        }
    }
}

function Validate-Command([string]$CommandName, [string]$ModuleName) {
    $module = $null
    $origCommand = $null
    
    $scriptBlock = { $ExecutionContext.InvokeCommand.GetCommand($args[0], 'All') }

    if ($ModuleName) {
        $module = Microsoft.PowerShell.Core\Get-Module $ModuleName -All |
                  Sort ModuleType |
                  Where { ($origCommand = & $_ $scriptBlock $commandName) } |
                  Select -First 1
    }
    
    $session = $pester.SessionState

    if (-not $origCommand) {
        Set-ScriptBlockScope -ScriptBlock $scriptBlock -SessionState $session
        $origCommand = & $scriptBlock $commandName
    }

    if ($origCommand -and $origCommand.CommandType -eq [System.Management.Automation.CommandTypes]::Alias) {
        $origCommand = $origCommand.ResolvedCommand
    }

    if (-not $origCommand) {
        throw ([System.Management.Automation.CommandNotFoundException] "Could not find Command $commandName")
    }
    
    if ($module) {
        $session = & @($module)[0] { $ExecutionContext.SessionState }
    }

    @{Command = $origCommand; Session = $session}
}

function MockPrototype {
    $functionName = $MyInvocation.MyCommand.Name
    
    $moduleName = ''
    if ($ExecutionContext.SessionState.Module)
    {
        $moduleName = $ExecutionContext.SessionState.Module.Name
    }

    Invoke-Mock -CommandName $functionName -ModuleName $moduleName -BoundParameters $PSBoundParameters -ArgumentList $args
}

function Invoke-Mock {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $CommandName,

        [string]
        $ModuleName,

        [hashtable]
        $BoundParameters = @{},

        [object[]]
        $ArgumentList = @()
    )

    $mock = $mockTable["$ModuleName||$CommandName"]

    if ($null -ne $mock)
    {
        for ($idx = $mock.Blocks.Length; $idx -gt 0; $idx--)
        {
            $block = $mock.Blocks[$idx - 1]

            if (Test-ParameterFilter -ScriptBlock $block.Filter -BoundParameters $BoundParameters -ArgumentList $ArgumentList -CmdletBinding $mock.Cmdlet -ParamBlock $mock.Params)
            {
                $block.Verifiable = $false
                $mock.CallHistory += @{CommandName = "$ModuleName||$CommandName"; BoundParams = $BoundParameters; Args = $ArgumentList; Scope = $pester.Scope }

                & $block.Mock @ArgumentList @BoundParameters

                return
            }
        }

        & $mock.OriginalCommand @ArgumentList @BoundParameters
    }
    else
    {
        # If this ever happens, it's a bug in Pester.  The scriptBlock that calls Invoke-Mock should be removed at the same time as the entry in the mock table.
        throw "Internal error detected:  Mock for '$CommandName' in module '$ModuleName' was called, but does not exist in the mock table."
    }
}

function Invoke-InMockScope
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.SessionState]
        $SessionState,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]]
        $ArgumentList = @()
    )

    if ($SessionState.Module)
    {
        $SessionState.Module.Invoke($ScriptBlock, $ArgumentList)
    }
    else
    {
        Set-ScriptBlockScope -ScriptBlock $ScriptBlock -SessionState $SessionState
        & $ScriptBlock @ArgumentList
    }
}

function Test-ParameterFilter
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [System.Collections.IDictionary]
        $BoundParameters,

        [object[]]
        $ArgumentList,

        [string]
        $CmdletBinding,

        [string]
        $ParamBlock
    )

    if ($null -eq $BoundParameters) { $BoundParameters = @{} }
    if ($null -eq $ArgumentList)    { $ArgumentList = @() }
    if ($null -eq $CmdletBinding)   { $CmdletBinding = '' }
    if ($null -eq $ParamBlock)      { $ParamBlock = '' }

    $cmd = [scriptblock]::Create("$CmdletBinding `r`n param ( $ParamBlock ) `r`n$ScriptBlock")

    & $cmd @BoundParameters @ArgumentList
}