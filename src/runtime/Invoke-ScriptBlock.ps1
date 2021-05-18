function Invoke-ScriptBlock {
    param(
        [ScriptBlock] $ScriptBlock,
        [ScriptBlock[]] $OuterSetup,
        [ScriptBlock[]] $Setup,
        [ScriptBlock[]] $Teardown,
        [ScriptBlock[]] $OuterTeardown,
        $Context = @{ },
        # define data to be shared in only in the inner scope where e.g eachTestSetup + test run but not
        # in the scope where OneTimeTestSetup runs, on the other hand, plugins want context
        # in all scopes
        [Switch] $ReduceContextToInnerScope,
        # # setup, body and teardown will all run (be-dotsourced into)
        # # the same scope
        # [Switch] $SameScope,
        # will dot-source the wrapper scriptblock instead of invoking it
        # so in combination with the SameScope switch we are effectively
        # running the code in the current scope
        [Switch] $NoNewScope,
        [Switch] $MoveBetweenScopes,
        [ScriptBlock] $OnUserScopeTransition = $null,
        [ScriptBlock] $OnFrameworkScopeTransition = $null,
        $Configuration
    )

    # filter nulls, inlined to avoid overhead of combineNonNull and selectNonNull
    $OuterSetup = if ($null -ne $OuterSetup -and 0 -lt $OuterSetup.Count) {
        foreach ($i in $OuterSetup) {
            if ($null -ne $i) {
                $i
            }
        }
    }

    $Setup = if ($null -ne $Setup -and 0 -lt $Setup.Count) {
        foreach ($i in $Setup) {
            if ($null -ne $i) {
                $i
            }
        }
    }

    $Teardown = if ($null -ne $Teardown -and 0 -lt $Teardown.Count) {
        foreach ($i in $Teardown) {
            if ($null -ne $i) {
                $i
            }
        }
    }

    $OuterTeardown = if ($null -ne $OuterTeardown -and 0 -lt $OuterTeardown.Count) {
        foreach ($i in $OuterTeardown) {
            if ($null -ne $i) {
                $i
            }
        }
    }





    # this is what the code below does
    # . $OuterSetup
    # & {
    #     try {
    #       # import setup to scope
    #       . $Setup
    #       # executed the test code in the same scope
    #       . $ScriptBlock
    #     } finally {
    #       . $Teardown
    #     }
    # }
    # . $OuterTeardown


    $wrapperScriptBlock = {
        # THIS RUNS (MOST OF THE TIME) IN USER SCOPE, BE CAREFUL WHAT YOU PUBLISH AND CONSUME!
        param($______parameters)

        if (-not $______parameters.NoNewScope) {
            # a child runner that will not create a new scope will force itself into the current scope
            # and overwrite our params in the inner scope (denoted by & { below), keep a second reference to it
            # so we can use it for Teardowns and to forward errors that happened after test teardown
            $______parametersForward = $______parameters
        }



        try {
            if ($______parameters.ContextInOuterScope) {
                $______outerSplat = $______parameters.Context
                if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Setting context variables" }
                foreach ($______current in $______outerSplat.GetEnumerator()) {
                    if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Setting context variable '$($______current.Key)' with value '$($______current.Value)'" }
                    $ExecutionContext.SessionState.PSVariable.Set($______current.Key, $______current.Value)
                }

                if ($______outerSplat.ContainsKey("_")) {
                    $______outerSplat.Remove("_")
                }

                $______current = $null
            }
            else {
                $______outerSplat = @{ }
            }

            if ($null -ne $______parameters.OuterSetup -and $______parameters.OuterSetup.Length -gt 0) {
                if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Running outer setups" }
                foreach ($______current in $______parameters.OuterSetup) {
                    if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Running outer setup { $______current }" }
                    $______parameters.CurrentlyExecutingScriptBlock = $______current
                    . $______current @______outerSplat
                }
                $______current = $null
                $______parameters.OuterSetup = $null
                if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Done running outer setups" }
            }
            else {
                if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "There are no outer setups" }
            }

            & {
                try {

                    if (-not $______parameters.ContextInOuterScope) {
                        $______innerSplat = $______parameters.Context
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Setting context variables" }
                        foreach ($______current in $______innerSplat.GetEnumerator()) {
                            if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Setting context variable '$ ($______current.Key)' with value '$($______current.Value)'" }
                            $ExecutionContext.SessionState.PSVariable.Set($______current.Key, $______current.Value)
                        }

                        if ($______outerSplat.ContainsKey("_")) {
                            $______outerSplat.Remove("_")
                        }

                        $______current = $null
                    }
                    else {
                        $______innerSplat = $______outerSplat
                    }

                    if ($null -ne $______parameters.Setup -and $______parameters.Setup.Length -gt 0) {
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Running inner setups" }
                        foreach ($______current in $______parameters.Setup) {
                            if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Running inner setup { $______current }" }
                            $______parameters.CurrentlyExecutingScriptBlock = $______current
                            . $______current @______innerSplat
                        }
                        $______current = $null
                        $______parameters.Setup = $null
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Done running inner setups" }
                    }
                    else {
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "There are no inner setups" }
                    }

                    if ($null -ne $______parameters.ScriptBlock) {
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Running scriptblock { $($______parameters.ScriptBlock) }" }
                        $______parameters.CurrentlyExecutingScriptBlock = $______parameters.ScriptBlock
                        . $______parameters.ScriptBlock @______innerSplat

                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Done running scriptblock" }
                    }
                    else {
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "There is no scriptblock to run" }
                    }
                }
                catch {
                    $______parameters.ErrorRecord.Add($_)
                    if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Fail running setups or scriptblock" -ErrorRecord $_ }
                }
                finally {
                    if ($null -ne $______parameters.Teardown -and $______parameters.Teardown.Length -gt 0) {
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Running inner teardowns" }
                        foreach ($______current in $______parameters.Teardown) {
                            try {
                                if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Running inner teardown { $______current }" }
                                $______parameters.CurrentlyExecutingScriptBlock = $______current
                                . $______current @______innerSplat
                                if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Done running inner teardown" }
                            }
                            catch {
                                $______parameters.ErrorRecord.Add($_)
                                if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Fail running inner teardown" -ErrorRecord $_ }
                            }
                        }
                        $______current = $null

                        # nulling this variable is important when we run without new scope
                        # then $______parameters.Teardown remains set and EachBlockTeardown
                        # runs twice
                        $______parameters.Teardown = $null
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Done running inner teardowns" }
                    }
                    else {
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "There are no inner teardowns" }
                    }
                }
            }
        }
        finally {

            if ($null -ne $______parameters.OuterTeardown -and $______parameters.OuterTeardown.Length -gt 0) {
                if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Running outer teardowns" }
                foreach ($______current in $______parameters.OuterTeardown) {
                    try {
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Running outer teardown { $______current }" }
                        $______parameters.CurrentlyExecutingScriptBlock = $______current
                        . $______current @______outerSplat
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Done running outer teardown" }
                    }
                    catch {
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Fail running outer teardown" -ErrorRecord $_ }
                        $______parameters.ErrorRecord.Add($_)
                    }
                }
                $______parameters.OuterTeardown = $null
                $______current = $null
                if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Done running outer teardowns" }
            }
            else {
                if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "There are no outer teardowns" }
            }

            if ($______parameters.NoNewScope -and $ExecutionContext.SessionState.PSVariable.GetValue('______parametersForward')) {
                $______parameters = $______parametersForward
            }
        }
    }

    if ($MoveBetweenScopes -and $null -ne $ScriptBlock) {
        $SessionStateInternal = $script:ScriptBlockSessionStateInternalProperty.GetValue($ScriptBlock, $null)
        # attach the original session state to the wrapper scriptblock
        # making it invoke in the same scope as $ScriptBlock
        $script:ScriptBlockSessionStateInternalProperty.SetValue($wrapperScriptBlock, $SessionStateInternal, $null)
    }

    $writeDebug = if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        {
            param($Message, [Management.Automation.ErrorRecord] $ErrorRecord)
            Write-PesterDebugMessage -Scope "RuntimeCore" $Message -ErrorRecord $ErrorRecord
        }
    }

    #$break = $true
    $err = $null
    try {
        $parameters = @{
            ScriptBlock                   = $ScriptBlock
            OuterSetup                    = $OuterSetup
            Setup                         = $Setup
            Teardown                      = $Teardown
            OuterTeardown                 = $OuterTeardown
            CurrentlyExecutingScriptBlock = $null
            ErrorRecord                   = [Collections.Generic.List[Management.Automation.ErrorRecord]]@()
            Context                       = $Context
            ContextInOuterScope           = -not $ReduceContextToInnerScope
            EnableWriteDebug              = $PesterPreference.Debug.WriteDebugMessages.Value
            WriteDebug                    = $writeDebug
            Configuration                 = $Configuration
            NoNewScope                    = $NoNewScope
        }

        # here we are moving into the user scope if the provided
        # scriptblock was bound to user scope, so we want to take some actions
        # typically switching between user and framework timer. There are still tiny pieces of
        # framework code running in the scriptblock but we can safely ignore those becasue they are
        # just logging, so the time difference is miniscule.
        # The code might also run just in framework scope, in that case the callback can remain empty,
        # eg when we are invoking framework setup.
        if ($MoveBetweenScopes) {
            # switch-timer to user scope inlined
            $state.UserCodeStopWatch.Start()
            $state.FrameworkStopWatch.Stop()

            if ($null -ne $OnUserScopeTransition) {
                & $OnUserScopeTransition
            }
        }
        do {
            $standardOutput = if ($NoNewScope) {
                . $wrapperScriptBlock $parameters
            }
            else {
                & $wrapperScriptBlock $parameters
            }
            # if the code reaches here we did not break
            #$break = $false
        } while ($false)
    }
    catch {
        $err = $_
    }

    if ($MoveBetweenScopes) {
        # switch-timer to framework scope inlined
        $state.UserCodeStopWatch.Stop()
        $state.FrameworkStopWatch.Start()

        if ($null -ne $OnFrameworkScopeTransition) {
            & $OnFrameworkScopeTransition
        }
    }

    if ($err) {
        $parameters.ErrorRecord.Add($err)
    }

    $r = [Pester.InvocationResult]::Create((0 -eq $parameters.ErrorRecord.Count), $parameters. ErrorRecord, $standardOutput)

    return $r
}
