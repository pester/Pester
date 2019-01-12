function Import-Sb {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $sb,
        # [Parameter(Mandatory=$true)]
        [Management.Automation.SessionState] $SessionState
    )

    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
    $SessionStateInternal = $SessionState.GetType().GetProperty('Internal', $flags).GetValue($SessionState, $null)

    # attach the original session state to the wrapper scriptblock
    # making it invoke in the caller session state
    $sb.GetType().GetProperty('SessionStateInternal', $flags).SetValue($sb, $SessionStateInternal, $null)

    # dot source the caller bound scriptblock which imports it into user scope
    . $sb
}


get-module m | remove-module
New-Module -name m -ScriptBlock {
    function m {
        [CmdletBinding()]
        param($name, $sb)

        $mockBody = [scriptblock]::Create("
        function Mock_$name { Write-Host 'this is mock' }
        Set-Alias -Name $name -Value Mock_$Name
        ")


        Import-Sb -SessionState $PSCmdlet.SessionState -sb $mockBody
    }
} | Import-Module

& {
    function a {
        "real"
    }
    a
    & {
        m a { "mock" }
        a
    }
    a
}
