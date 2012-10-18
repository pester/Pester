$script:mockTable = @{}

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

.PARAMETER CommandName
The name of the command to be mocked.

.PARAMETER MockWith
A ScriptBlock specifying the behvior that will be used to mock CommandName.

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
Mock Set-Content {} -Verifiable -ParameterFilter {$Path -eq "some_path" -and $Value -eq "Expected Value"}

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

#>

param(
    [string]$commandName, 
    [ScriptBlock]$mockWith, 
    [switch]$verifiable, 
    [ScriptBlock]$parameterFilter = {$True}    
)

    $origCommand = (Microsoft.PowerShell.Core\Get-Command $commandName -ErrorAction SilentlyContinue)
    if(!$origCommand){ Throw "Could not find Command $commandName"}
    $filterTest=&($parameterFilter)
    if($filterTest -ne $True -and $filterTest -ne $False){ throw "The Parameter Filter must return a boolean"}
    $blocks = @{Mock=$mockWith; Filter=$parameterFilter; Verifiable=$verifiable}
    $mock = $mockTable.$commandName
    if(!$mock) {
        if($origCommand.CommandType -eq "Function") {
            Microsoft.PowerShell.Management\Rename-Item Function:\$commandName script:PesterIsMocking_$commandName
        }
        $metadata=Microsoft.PowerShell.Utility\New-Object System.Management.Automation.CommandMetaData $origCommand
        $cmdLetBinding = [Management.Automation.ProxyCommand]::GetCmdletBindingAttribute($metadata)
        $params = [Management.Automation.ProxyCommand]::GetParamBlock($metadata)
        $newContent=Microsoft.PowerShell.Management\Get-Content function:\MockPrototype
        Microsoft.PowerShell.Management\Set-Item Function:\script:$commandName -value "$cmdLetBinding `r`n param ( $params ) `r`n$newContent"
        $mock=@{OriginalCommand=$origCommand;blocks=@($blocks)}
    } else {
        if($blocks.Filter.ToString() -eq "`$True") {$mock.blocks = ,$blocks + $mock.blocks} else { $mock.blocks += $blocks }
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

function Clear-Mocks {
    $mockTable.Keys | % { Microsoft.PowerShell.Management\Remove-Item function:\$_ }
    $mockTable.Clear()
    Get-ChildItem Function: | ? { $_.Name.StartsWith("PesterIsMocking_") } | % {Rename-Item Function:\$_ "script:$($_.Name.Replace('PesterIsMocking_', ''))"}
}

function MockPrototype {
    $functionName = $MyInvocation.MyCommand.Name
    $mock=$mockTable.$functionName
    $idx=$mock.blocks.Length
    while(--$idx -ge 0) {
        if(&($mock.blocks[$idx].Filter)) { 
            $mock.blocks[$idx].Verifiable=$false
            &($mockTable.$functionName.blocks[$idx].mock) @PSBoundParameters
            return
        }
    }
    &($mock.OriginalCommand) @PSBoundParameters
}