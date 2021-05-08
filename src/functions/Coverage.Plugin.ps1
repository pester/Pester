function Get-CoveragePlugin {
    New-PluginObject -Name "Coverage" -RunStart {
        param($Context)

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $logger = if ($Context.WriteDebugMessages) {
            # return partially apply callback to the logger when the logging is enabled
            # or implicit null
            {
                param ($Message)
                & $Context.Write_PesterDebugMessage -Scope CodeCoverage -Message $Message
            }
        }

        if ($null -ne $logger) {
            & $logger "Starting code coverage."
        }

        if ($PesterPreference.Output.Verbosity.Value -ne "None") {
            & $SafeCommands["Write-Host"] -ForegroundColor Magenta "Starting code coverage."
        }

        $config = $Context.Configuration['Coverage']

        if ($null -ne $logger) {
            & $logger "Config: $($config | & $script:SafeCommands['Out-String'])"
        }

        $breakpoints = Enter-CoverageAnalysis -CodeCoverage $config -Logger $logger -UseBreakpoints $config.UseBreakpoints -UseSingleHitBreakpoints $config.UseSingleHitBreakpoints



        if (-not $config.UseBreakpoints) {
            $points = [Collections.Generic.List[Profiler.CodeCoveragePoint]]@()
            foreach ($breakpoint in $breakpoints) {
                $location = $breakpoint.BreakpointLocation

                $hitColumn = $location.Column

                # breakpoints for some actions bind to different column than the hits, we need to adjust
                # when code contains assignment we need to translate it, because we are reporting the place where BP would bind as interesting
                # but we are getting the whole assignment from profiler, so we need to offset it
                $firstLine, $null = $breakpoint.Command -split "`n",2
                if ($firstLine -like "*=*") {
                    $ast = [System.Management.Automation.Language.Parser]::ParseInput($breakpoint.Command, [ref]$null, [ref]$null)

                    $assignment = $ast.Find( { param ($item) $item -is [System.Management.Automation.Language.AssignmentStatementAst] }, $false)
                    if ($assignment) {
                        if ($assignment.Right) {
                            $hitColumn = $location.Column - $assignment.Right.Extent.StartColumnNumber + 1
                            # Write-Host "Line $($i.Extent.StartLineNumber) is assignment $($i.Source), using $StartColumnNumber instead of $($i.Extent.StartColumnNumber)"
                        }
                    }
                }


                $points.Add([Profiler.CodeCoveragePoint]::new($location.Script, $location.Line, $hitColumn, $location.Column, $breakpoint.Command));
            }

            $tracer = [Profiler.CodeCoverageTracer]::new($points)
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            [Profiler.Tracer]::Patch($PSVersionTable.PSVersion.Major, $ExecutionContext, $host.UI, $tracer)
            Set-PSDebug -Trace 1
        }

        $Context.Data.Add('Coverage', @{
            CommandCoverage = $breakpoints
            Tracer = $tracer
            CoverageReport = $null
        })

        if ($PesterPreference.Output.Verbosity.Value -in "Detailed", "Diagnostic") {
            & $SafeCommands["Write-Host"] -ForegroundColor Magenta "Code Coverage preparation finished after $($sw.ElapsedMilliseconds) ms."
        }
    } -End {
        param($Context)

        Set-PSDebug -Trace 0
        [Profiler.Tracer]::Unpatch()
        if (-not $Context.TestRun.PluginData.ContainsKey("Coverage")) {
            return
        }

        $coverageData = $Context.TestRun.PluginData.Coverage
        #TODO: rather check the config to see which mode of coverage we used
        if ($null -eq $coverageData.Tracer) {
            # we used breakpoints to measure CC, clean them up
            Exit-CoverageAnalysis -CommandCoverage $coverageData.CommandCoverage
        }
    }
}
