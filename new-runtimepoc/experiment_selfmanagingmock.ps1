# so this is a mock that self-manages
# based on the scopes, this allows us
# to let powershell manage the life-time of
# the bootstrap function and alias automatically
# so a Mock defined in It will die with the
# end of It (or more precisely the scope) it
# is defined in, just like functions do
# this prevents us from supporting the current
# behavior of leaking mocks outside of It,
# but that's a good thing and it lifts the burden
# of managing the scope correctly

# I also keep the aliases because they provide
# are resolved first and allow inter-file mocking

get-module m | remove-module
New-Module -name m -ScriptBlock {
    function m {
        [CmdletBinding()]
        param($name, $sb)

        $sb = [scriptblock]::Create("
            function mock_$name { $sb }
            Set-Alias -Name $name -Value mock_$name
        ")

        # $sb = {
        #     # $ExecutionContext.SessionState
        #     function mock_a { write-host 'this is mock' }
        #     Set-Alias -Name a -Value mock_a
        # }


        $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
        $SessionStateInternal = $pscmdlet.SessionState.GetType().GetProperty('Internal', $flags).GetValue($pscmdlet.SessionState, $null)

        # attach the original session state to the wrapper scriptblock
        # making it invoke in the caller session state
        $sb.GetType().GetProperty('SessionStateInternal', $flags).SetValue($sb, $SessionStateInternal, $null)

        # dot source the caller bound scriptblock which imports it into user scope
        . $sb
    }
} | Import-Module

get-date
& {
    function a {
        "real"
    }
    a
    & {
        m a { "mock" }
        write-host "calling a"
        a
    }

    a
}
