$mockTable = @{}

function Mock ([string]$commandName, [ScriptBlock]$mockWith, [switch]$verifiable, [ScriptBlock]$parameterFilter = {$True})
{
    # If verifiable, add to a verifiable hashtable
    $origCommand = (Get-Command $commandName -ErrorAction SilentlyContinue)
    if(!$origCommand){ Throw "Could not find Command $commandName"}
    $blocks = @{Mock=$mockWith; Filter=$parameterFilter}
    $mock = $mockTable.$commandName
    if(!$mock) {
        if($origCommand.CommandType -eq "Function") {
            Rename-Item Function:\$commandName script:PesterIsMocking_$commandName
        }
        $metadata=New-Object System.Management.Automation.CommandMetaData $origCommand
        $cmdLetBinding = [Management.Automation.ProxyCommand]::GetCmdletBindingAttribute($metadata)
        $params = [Management.Automation.ProxyCommand]::GetParamBlock($metadata)
        $newContent=Get-Content function:\MockPrototype
        Set-Item Function:\script:$commandName -value "$cmdLetBinding `r`n param ( $params ) `r`n$newContent"
        $mock=@{OriginalCommand=$origCommand;blocks=@($blocks)}
    } else {$mock.blocks += $blocks}
    $mockTable.$commandName = $mock
    # param filters are met, mark in the verifiable table
}

function Assert-VerifiableMocks {
    # Check that the Verifiables have all been called
    # if not, throw
}

function Clear-Mocks {
    # Called at the end of Describe
    # Clears the Verifiable table
    $mockTable.Keys | % { Microsoft.PowerShell.Management\Remove-Item function:\$_ }
    $script:mockTable = @{}
    Microsoft.PowerShell.Management\Get-ChildItem Function: | ? { $_.Name.StartsWith("PesterIsMocking_") } | % {Microsoft.PowerShell.Management\Rename-Item Function:\$_ "script:$($_.Name.Replace('PesterIsMocking_', ''))"}
}

function MockPrototype {
    $functionName = $MyInvocation.MyCommand.Name
    $mock=$mockTable.$functionName
    $idx=$mock.blocks.Length
    while(--$idx -ge 0) {
        if(&($mock.blocks[$idx].Filter)) { 
            &($mockTable.$functionName.blocks.mock) @PSBoundParameters
            return
        }
    }
    &($mock.OriginalCommand) @PSBoundParameters
}