function New-PesterState {
    $o = [PSCustomObject] @{
        # indicate whether or not we are currently
        # running in discovery mode se we can change
        # behavior of the commands appropriately
        Discovery           = $false

        CurrentBlock        = $null
        CurrentTest         = $null

        Plugin              = $null
        PluginConfiguration = $null
        PluginData          = $null
        Configuration       = $null

        TotalStopWatch      = [Diagnostics.Stopwatch]::StartNew()
        UserCodeStopWatch   = [Diagnostics.Stopwatch]::StartNew()
        FrameworkStopWatch  = [Diagnostics.Stopwatch]::StartNew()

        Stack               = [Collections.Stack]@()
    }

    $o.TotalStopWatch.Restart()
    $o.FrameworkStopWatch.Restart()
    # user code stopwatch should not be running
    # because we are not in user code
    $o.UserCodeStopWatch.Reset()

    return $o
}
