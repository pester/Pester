$global:mockTable = @{}
$global:mockCallHistory = @()

function Mock {

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

The SUT (code being tested) that calls the actual commands that you have 
mocked must not be executing from inside a module. Otherwise, the mocked 
commands will not be invoked and the real commands will run. The SUT must 
be in the same Script scope as the test. So it must be either dot sourced, 
in the same file, or in a script file.

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

.EXAMPLE
Mock Get-ChildItem {return @{FullName="A_File.TXT"}}

Using this Mock, all calls to Get-ChildItem will return an object with a 
FullName property returning "A_File.TXT"

.EXAMPLE
Mock Get-ChildItem {return @{FullName="A_File.TXT"}} -PrameterFilter {$Path.StartsWith($env:temp)}

This Mock will only be applied to Get-ChildItem calls within the user's temp directory.

.EXAMPLE
Mock Set-Content -Verifiable -ParameterFilter {$Path -eq "some_path" -and $Value -eq "Expected Value"}

When this mock is used, if the Mock is never invoked and Assert-VerifiableMocks is called, an exception will be thrown. The command behavior will do nothing since the ScriptBlock is empty.

.EXAMPLE
c:\PS>Mock Get-ChildItem {return @{FullName="A_File.TXT"}} -PrameterFilter {$Path.StartsWith($env:temp\1)}
c:\PS>Mock Get-ChildItem {return @{FullName="B_File.TXT"}} -PrameterFilter {$Path.StartsWith($env:temp\2)}
c:\PS>Mock Get-ChildItem {return @{FullName="C_File.TXT"}} -PrameterFilter {$Path.StartsWith($env:temp\3)}

Multiple mocks of the same command may be used. The parameter filter determines which is invoked. Here, if Get-ChildItem is called on the "2" directory of the temp folder, then B_File.txt will be returned.

.EXAMPLE
Mock Get-ChildItem {return @{FullName="B_File.TXT"}} -PrameterFilter {$Path -eq "$env:temp\me"}
Mock Get-ChildItem {return @{FullName="A_File.TXT"}} -PrameterFilter {$Path.StartsWith($env:temp)}

Get-ChildItem $env:temp\me

Here, both mocks could apply since both filters will pass. A_File.TXT will be returned because it was the last Mock created.

.EXAMPLE
Mock Get-ChildItem {return @{FullName="B_File.TXT"}} -PrameterFilter {$Path -eq "$env:temp\me"}
Mock Get-ChildItem {return @{FullName="A_File.TXT"}}

Get-ChildItem c:\windows

Here, A_File.TXT will be returned. Since no filterwas specified, it will apply to any call to Get-ChildItem that does not pass another filter.

.EXAMPLE
Mock Get-ChildItem {return @{FullName="B_File.TXT"}} -PrameterFilter {$Path -eq "$env:temp\me"}
Mock Get-ChildItem {return @{FullName="A_File.TXT"}}

Get-ChildItem $env:temp\me

Here, B_File.TXT will be returned. Even though the filterless mock was created last. This illustrates that filterless Mocks are always evaluated last regardlss of their creation order.

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
    Describe block. This allows all context blocks inside the describe to 
    use this Mock. If a context scoped mock, mocks Get-Version, that mock 
    will override the describe scoped mock within that contex tif both mocks 
    apply to the parameters passed to Get-Version.

.LINK
about_Mocking
#>

param(
    [string]$commandName, 
    [ScriptBlock]$mockWith={}, 
    [switch]$verifiable, 
    [ScriptBlock]$parameterFilter = {$True}    
)

    $origCommand = Validate-Command $commandName
    $filterTest=&($parameterFilter)
    if($filterTest -ne $True -and $filterTest -ne $False){ throw "The Parameter Filter must return a boolean"}
    $blocks = @{Mock=$mockWith; Filter=$parameterFilter; Verifiable=$verifiable; Scope=$pester.Scope}
    $mock = $mockTable.$commandName
    if(!$mock) {
        if($origCommand.CommandType -eq "Function") {
            Microsoft.PowerShell.Management\Rename-Item Function:\$commandName global:PesterIsMocking_$commandName
        }
        $metadata=Microsoft.PowerShell.Utility\New-Object System.Management.Automation.CommandMetaData $origCommand
        $metadata.Parameters.Remove("Verbose") | out-null
        $metadata.Parameters.Remove("Debug") | out-null
        $metadata.Parameters.Remove("ErrorAction") | out-null
        $metadata.Parameters.Remove("WarningAction") | out-null
        $metadata.Parameters.Remove("ErrorVariable") | out-null
        $metadata.Parameters.Remove("WarningVariable") | out-null
        $metadata.Parameters.Remove("OutVariable") | out-null
        $metadata.Parameters.Remove("OutBuffer") | out-null
        $cmdLetBinding = [Management.Automation.ProxyCommand]::GetCmdletBindingAttribute($metadata)
        $params = [Management.Automation.ProxyCommand]::GetParamBlock($metadata)
        $newContent=Microsoft.PowerShell.Management\Get-Content function:\MockPrototype
        Microsoft.PowerShell.Management\Set-Item Function:\script:$commandName -value "$cmdLetBinding `r`n param ( $params )Process{ `r`n$newContent}"
        $mock=@{OriginalCommand=$origCommand;blocks=@($blocks);CmdLet=$cmdLetBinding;Params=$params;CommandName=$CommandName}
    } 
    else {
        if($blocks.Filter.ToString() -eq "`$True") {
            if($mock.blocks[0].Filter.ToString() -eq "`$True") {
                $noParams=@()
                $noParams += $mock.blocks | ? { $_.Filter.ToString() -eq "`$True" }
                $noParams += $blocks
                if($mock.blocks.Length -gt 1){
                    $mock.blocks = $noParams + $mock.blocks[($noParams.Length-1)..($mock.blocks.Length-1)]
                }
                else {
                    $mock.blocks = $noParams
                }
            }
            else {
                $mock.blocks = ,$blocks + $mock.blocks
            }
        } 
        else { 
            $mock.blocks += $blocks 
        }
    }
    $mockTable.$commandName = $mock
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
            $message += "`r`n Expected $mock to be called with $($unVerified[$mock].Filter)"
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
This command checks the call history of the specified Command since 
the Mock was declared. If it had been called less than the number of 
times specified (1 is the default), then an exception is thrown. You 
may specify 0 times if you want to make sure that the mock has NOT 
been called. If you include the Exactly switch, the number of times 
that the command has been called must mach exactly with the number of 
times specified on this command.

.PARAMETER CommandName
The name of the command to check for mock calls.

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

.NOTES
While Mock will only mock commands if the Parameter Filter
matches the Parameters passed to the command, Assert-MockCalled 
will count calls to a command whether they are mocked or not. 
The Command must be declared as a mock but the parameter 
filter in its mock declaration do not need to include the 
parameter Filter specified by Assert-MockCalled.

#>

param(
    [string]$commandName,
    [switch]$Exactly,
    [int]$times=1,
    [ScriptBlock]$parameterFilter = {$True}    
)
    $mock = $global:mockTable.$commandName
    if(!$mock) { Throw "You did not declare a mock of the $commandName Command."}
    Microsoft.PowerShell.Management\Set-Item Function:\Pester_TempParamTest -value "$($mock.CmdLet) `r`n param ( $($mock.Params) ) `r`n$parameterFilter"
    $cmd=(Microsoft.PowerShell.Core\Get-Command Pester_TempParamTest)
    $qualifiedCalls = @()
    $global:mockCallHistory | ? {$_.CommandName -eq $commandName} | ? {$p=$_.BoundParams;$a=$_.Args;&($cmd) @a @p} | %{ $qualifiedCalls += $_}
    Microsoft.PowerShell.Management\Remove-Item Function:\Pester_TempParamTest
    if($qualifiedCalls.Length -ne $times -and ($Exactly -or ($times -eq 0))) {
        throw "Expected $commandName to be called $times times exactly but was called $($qualifiedCalls.Length.ToString()) times"
    } elseif($qualifiedCalls.Length -lt $times) {
        throw "Expected $commandName to be called at least $times times but was called $($qualifiedCalls.Length) times"
    }
}

function Clear-Mocks {
    if($mockTable){
        $mocksToRemove=@()
        $mockTable.Keys | % { 
            $otherScopeBlocks = @()
            $mockTable[$_].blocks | ? {$_.Scope -ne $pester.Scope} | % { $otherScopeBlocks += $_ }
            $mockTable[$_].blocks = $otherScopeBlocks
        }
        $mockTable.values | ? { $_.blocks.Length -eq 0} | % { 
            $mocksToRemove += $_.CommandName
            Microsoft.PowerShell.Management\Remove-Item function:\$($_.CommandName)
            if(Test-Path Function:\PesterIsMocking_$($_.CommandName) ){
                Rename-Item Function:\PesterIsMocking_$($_.CommandName) "script:$($_.CommandName)"
            }
        }
        $mocksToRemove | % { $mockTable.Remove($_) }
        $global:mockCallHistory = @()
    }
}

function Validate-Command([string]$commandName) {
    $origCommand = (Microsoft.PowerShell.Core\Get-Command $commandName -ErrorAction SilentlyContinue)
    if(!$origCommand){ Throw "Could not find Command $commandName"}
    return $origCommand
}

function MockPrototype {
    $functionName = $MyInvocation.MyCommand.Name
    $global:mockCallHistory += @{CommandName=$functionName;BoundParams=$PSBoundParameters; Args=$args}
    $mock=$mockTable.$functionName
    $idx=$mock.blocks.Length
    while(--$idx -ge 0) {
        if(&($mock.blocks[$idx].Filter) @args @PSBoundParameters) { 
            $mock.blocks[$idx].Verifiable=$false
            &($mockTable.$functionName.blocks[$idx].mock) @args @PSBoundParameters
            return
        }
    }
    &($mock.OriginalCommand) @args @PSBoundParameters
}
