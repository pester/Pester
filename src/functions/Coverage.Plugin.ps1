function Get-CoveragePlugin {
    # Validate configuration
    Resolve-CodeCoverageConfiguration

    $p = @{
        Name = 'Coverage'
    }

    $p.Start = {
        param($Context)

        $paths = @(if (0 -lt $PesterPreference.CodeCoverage.Path.Value.Count) {
                $PesterPreference.CodeCoverage.Path.Value
            }
            else {
                # no paths specific to CodeCoverage were provided, resolve them from
                # tests by using the whole directory in which the test or the
                # provided directory. We might need another option to disable this convention.
                @(foreach ($p in $PesterPreference.Run.Path.Value) {
                        # this is a bit ugly, but the logic here is
                        # that we check if the path exists,
                        # and if it does and is a file then we return the
                        # parent directory, otherwise we got a directory
                        # and return just it
                        $i = & $SafeCommands['Get-Item'] $p
                        if ($i.PSIsContainer) {
                            & $SafeCommands['Join-Path'] $i.FullName "*"
                        }
                        else {
                            & $SafeCommands['Join-Path'] $i.Directory.FullName "*"
                        }
                    })
            })

        $outputPath = if ([IO.Path]::IsPathRooted($PesterPreference.CodeCoverage.OutputPath.Value)) {
            $PesterPreference.CodeCoverage.OutputPath.Value
        }
        else {
            & $SafeCommands['Join-Path'] $pwd.Path $PesterPreference.CodeCoverage.OutputPath.Value
        }

        $CodeCoverage = @{
            Enabled                 = $PesterPreference.CodeCoverage.Enabled.Value
            OutputFormat            = $PesterPreference.CodeCoverage.OutputFormat.Value
            OutputPath              = $outputPath
            OutputEncoding          = $PesterPreference.CodeCoverage.OutputEncoding.Value
            ExcludeTests            = $PesterPreference.CodeCoverage.ExcludeTests.Value
            Path                    = @($paths)
            RecursePaths            = $PesterPreference.CodeCoverage.RecursePaths.Value
            TestExtension           = $PesterPreference.Run.TestExtension.Value
            UseSingleHitBreakpoints = $PesterPreference.CodeCoverage.SingleHitBreakpoints.Value
            UseBreakpoints          = $PesterPreference.CodeCoverage.UseBreakpoints.Value
        }

        # Save PluginConfiguration for Coverage
        $Context.Configuration['Coverage'] = $CodeCoverage
    }

    $p.RunStart = {
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
            Write-PesterHostMessage -ForegroundColor Magenta "Starting code coverage."
        }

        $config = $Context.Configuration['Coverage']

        if ($null -ne $logger) {
            & $logger "Config: $($config | & $script:SafeCommands['Out-String'])"
        }

        $breakpoints = Enter-CoverageAnalysis -CodeCoverage $config -Logger $logger -UseBreakpoints $config.UseBreakpoints -UseSingleHitBreakpoints $config.UseSingleHitBreakpoints

        $patched = $false
        if (-not $config.UseBreakpoints) {
            $patched, $tracer = Start-TraceScript $breakpoints
        }

        $Context.Data.Add('Coverage', @{
                CommandCoverage = $breakpoints
                # the tracer that was used for profiler based CC
                Tracer          = $tracer
                # if the tracer was patching the session, or if we just plugged in to an existing
                # profiler session, in case Profiler is profiling a Pester run that has Profiler based
                # CodeCoverage enabled
                Patched         = $patched
                CoverageReport  = $null
            })

        if ($PesterPreference.Output.Verbosity.Value -in "Detailed", "Diagnostic") {
            Write-PesterHostMessage -ForegroundColor Magenta "Code Coverage preparation finished after $($sw.ElapsedMilliseconds) ms."
        }
    }

    $p.RunEnd = {
        param($Context)

        $config = $Context.Configuration['Coverage']

        if (-not $Context.Data.ContainsKey("Coverage")) {
            return
        }

        $coverageData = $Context.Data.Coverage

        if (-not $config.UseBreakpoints) {
            Stop-TraceScript -Patched $coverageData.Patched
        }

        #TODO: rather check the config to see which mode of coverage we used
        if ($null -eq $coverageData.Tracer) {
            # we used breakpoints to measure CC, clean them up
            Exit-CoverageAnalysis -CommandCoverage $coverageData.CommandCoverage
        }
    }

    $p.End = {
        param($Context)

        $run = $Context.TestRun

        if ($PesterPreference.Output.Verbosity.Value -ne "None") {
            $sw = [Diagnostics.Stopwatch]::StartNew()
            Write-PesterHostMessage -ForegroundColor Magenta "Processing code coverage result."
        }

        $breakpoints = @($run.PluginData.Coverage.CommandCoverage)
        $measure = if (-not $PesterPreference.CodeCoverage.UseBreakpoints.Value) { @($run.PluginData.Coverage.Tracer.Hits) }
        $coverageReport = Get-CoverageReport -CommandCoverage $breakpoints -Measure $measure
        $totalMilliseconds = $run.Duration.TotalMilliseconds

        $configuration = $run.PluginConfiguration.Coverage

        $coverageXmlReport = switch ($configuration.OutputFormat) {
            'JaCoCo' { [xml](Get-JaCoCoReportXml -CommandCoverage $breakpoints -TotalMilliseconds $totalMilliseconds -CoverageReport $coverageReport -Format 'JaCoCo') }
            'CoverageGutters' { [xml](Get-JaCoCoReportXml -CommandCoverage $breakpoints -TotalMilliseconds $totalMilliseconds -CoverageReport $coverageReport -Format 'CoverageGutters') }
            'Cobertura' { [xml](Get-CoberturaReportXml -CoverageReport $coverageReport  -TotalMilliseconds $totalMilliseconds) }
            default { throw "CodeCoverage.CoverageFormat '$($configuration.OutputFormat)' is not valid, please review your configuration." }
        }

        $settings = [Xml.XmlWriterSettings] @{
            Indent              = $true
            NewLineOnAttributes = $false
        }

        $stringWriter = $null
        $xmlWriter = $null
        try {
            $stringWriter = [Pester.Factory]::CreateStringWriter()
            $xmlWriter = [Xml.XmlWriter]::Create($stringWriter, $settings)

            $coverageXmlReport.WriteContentTo($xmlWriter)

            $xmlWriter.Flush()
            $stringWriter.Flush()
        }
        finally {
            if ($null -ne $xmlWriter) {
                try {
                    $xmlWriter.Close()
                }
                catch {
                }
            }
            if ($null -ne $stringWriter) {
                try {
                    $stringWriter.Close()
                }
                catch {
                }
            }
        }

        $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($PesterPreference.CodeCoverage.OutputPath.Value)
        if (-not (& $SafeCommands['Test-Path'] $resolvedPath)) {
            $dir = & $SafeCommands['Split-Path'] $resolvedPath
            $null = & $SafeCommands['New-Item'] $dir -Force -ItemType Container
        }

        $stringWriter.ToString() | & $SafeCommands['Out-File'] $resolvedPath -Encoding $PesterPreference.CodeCoverage.OutputEncoding.Value -Force
        if ($PesterPreference.Output.Verbosity.Value -in 'Detailed', 'Diagnostic') {
            Write-PesterHostMessage -ForegroundColor Magenta "Code Coverage result processed in $($sw.ElapsedMilliseconds) ms."
        }
        $reportText = Write-CoverageReport $coverageReport

        $coverage = [Pester.CodeCoverage]::Create()
        $coverage.CoverageReport = $reportText
        $coverage.CoveragePercent = $coverageReport.CoveragePercent
        $coverage.CommandsAnalyzedCount = $coverageReport.NumberOfCommandsAnalyzed
        $coverage.CommandsExecutedCount = $coverageReport.NumberOfCommandsExecuted
        $coverage.CommandsMissedCount = $coverageReport.NumberOfCommandsMissed
        $coverage.FilesAnalyzedCount = $coverageReport.NumberOfFilesAnalyzed
        $coverage.CommandsMissed = $coverageReport.MissedCommands
        $coverage.CommandsExecuted = $coverageReport.HitCommands
        $coverage.FilesAnalyzed = $coverageReport.AnalyzedFiles
        $coverage.CoveragePercentTarget = $PesterPreference.CodeCoverage.CoveragePercentTarget.Value

        $run.CodeCoverage = $coverage
    }

    New-PluginObject @p
}

function Resolve-CodeCoverageConfiguration {
    $supportedFormats = 'JaCoCo', 'CoverageGutters', 'Cobertura'
    if ($PesterPreference.CodeCoverage.OutputFormat.Value -notin $supportedFormats) {
        throw (Get-StringOptionErrorMessage -OptionPath 'CodeCoverage.OutputFormat' -SupportedValues $supportedFormats -Value $PesterPreference.CodeCoverage.OutputFormat.Value)
    }
}
