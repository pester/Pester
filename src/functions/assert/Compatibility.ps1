function New-PSObject ([hashtable]$Property) {
    New-Object -Type PSObject -Property $Property
}

function Invoke-WithContext {
    param(
        [Parameter(Mandatory = $true )]
        [ScriptBlock] $ScriptBlock,
        [Parameter(Mandatory = $true)]
        [hashtable] $Variables)

    # this functions is a psv2 compatible version of
    # ScriptBlock InvokeWithContext that is not available
    # in that version of PowerShell

    # this is what the code below does
    # which in effect sets the context without detaching the
    # scriptblock from the original scope
    # & {
    #     # context
    #     $a = 10
    #     $b = 20
    #     # invoking our original scriptblock
    #     & $sb
    # }

    # a similar solution was $SessionState.PSVariable.Set('a', 10)
    # but that sets the variable for all "scopes" in the current
    # scope so the value persist after the original has run which
    # is not correct,

    $scriptBlockWithContext = {
        param($context)

        foreach ($pair in $context.Variables.GetEnumerator()) {
            New-Variable -Name $pair.Key -Value $pair.Value
        }

        # this cleans up the variable from the session
        # the subexpression outputs the value of the variable
        # and then deletes the variable, so the value is still passed
        # but the variable no longer exists when the scriptblock executes
        & $($context.ScriptBlock; Remove-Variable -Name 'context' -Scope Local)
    }

    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
    $SessionState = $ScriptBlock.GetType().GetProperty("SessionState", $flags).GetValue($ScriptBlock, $null)
    $SessionStateInternal = $SessionState.GetType().GetProperty('Internal', $flags).GetValue($SessionState, $null)

    # attach the original session state to the wrapper scriptblock
    # making it invoke in the same scope as $ScriptBlock
    $scriptBlockWithContext.GetType().GetProperty('SessionStateInternal', $flags).SetValue($scriptBlockWithContext, $SessionStateInternal, $null)

    & $scriptBlockWithContext @{ ScriptBlock = $ScriptBlock; Variables = $Variables  }
}

function Test-NullOrWhiteSpace ($Value) {
    # psv2 compatibility, on newer .net we would simply use
    # [string]::isnullorwhitespace
    $null -eq $Value -or $Value -match "^\s*$"
}

function Get-Type ($InputObject) {
    try {
        $ErrorActionPreference = 'Stop'
        # normally this would not ever throw
        # but in psv2 when datatable is deserialized then
        # [Deserialized.System.Data.DataTable] does not contain
        # .GetType()
        $InputObject.GetType()
    }
    catch [Exception] {
        return [Object]
    }

}