$mockTable = @{}

function Mock ([string]$commandName, [ScriptBlock]$mockWith, [switch]$verifiable, [ScriptBlock]$parameterFilter = {$True})
{
    $origCommand = (Get-Command $commandName -ErrorAction SilentlyContinue)
    if(!$origCommand){ Throw "Could not find Command $commandName"}
    $blocks = @{Mock=$mockWith; Filter=$parameterFilter; Verifiable=$verifiable}
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
    } else {
        if($blocks.Filter.ToString() -eq "`$True") {$mock.blocks = ,$blocks + $mock.blocks} else { $mock.blocks += $blocks }
    }
    $mockTable.$commandName = $mock
}

function Assert-VerifiableMocks {
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
    $script:mockTable = @{}
    Microsoft.PowerShell.Management\Get-ChildItem Function: | ? { $_.Name.StartsWith("PesterIsMocking_") } | % {Microsoft.PowerShell.Management\Rename-Item Function:\$_ "script:$($_.Name.Replace('PesterIsMocking_', ''))"}
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