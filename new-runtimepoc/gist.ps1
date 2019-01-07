
get-module a | remove-module
new-Module -name a -ScriptBlock {
  
    function Import-Dependency {
        [CmdletBinding()]
        param($Dependency)

        # caller state
        $SessionState = $PSCmdlet.SessionState
        if ($Dependency -is [ScriptBlock]) {
            . $Dependency
        }
        else {

            # when importing a file we need to 
            # dot source it into the user scope, the path has
            # no bound session state, so simply dot sourcing it would
            # import it into module scope
            # instead we wrap it into a scriptblock that we attach to user
            # scope, and dot source the file, that will import the functions into
            # that script block, and then we dot source it again to import it 
            # into the caller scope, effectively defining the functions there
            $sb = { 
                param ($p)
                . $($p; Remove-Variable -Scope Local -Name p)
            }

            $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
            $SessionStateInternal = $SessionState.GetType().GetProperty('Internal', $flags).GetValue($SessionState, $null)
        
            # attach the original session state to the wrapper scriptblock
            # making it invoke in the caller session state
            $sb.GetType().GetProperty('SessionStateInternal', $flags).SetValue($sb, $SessionStateInternal, $null)
            
            # dot source the caller bound scriptblock which imports it into user scope
            . $sb $Dependency
        }
    }
} | Import-Module


&{
   
    Import-Dependency { 
        $a = "from script block"
        function d { Write-Host "function d from scriptblock"}
    }

    Import-Dependency $PSScriptRoot\dependency.ps1
    $huh
    k
    d
    
    $b
    $a

    $p # <- make sure p does not leak from wrapper
}