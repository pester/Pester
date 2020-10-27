function Find-File {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String[]] $Path,
        [String[]] $ExcludePath,
        [Parameter(Mandatory=$true)]
        [string] $Extension
    )


    $files =
        foreach ($p in $Path) {
            if ([String]::IsNullOrWhiteSpace($p))
            {
                continue
            }

            if ((& $script:SafeCommands['Test-Path'] $p)) {
                $item = Get-Item $p

                if ($item.PSIsContainer) {
                    # this is an existing directory search it for tests file
                    Get-ChildItem -Recurse -Path $p -Filter "*$Extension" -File
                    continue
                }

                if ("FileSystem" -ne $item.PSProvider.Name) {
                    # item is not a directory and exists but is not a file so we are not interested
                    continue
                }

                if (".ps1" -ne $item.Extension) {
                    Write-Error "Script path '$p' is not a ps1 file." -ErrorAction Stop
                }

                # this is some file, we don't care if it is just a .ps1 file or .Tests.ps1 file
                Add-Member -Name UnresolvedPath -Type NoteProperty -Value $p -InputObject $item
                $item
                continue
            }

            # this is a path that does not exist so let's hope it is
            # a wildcarded path that will resolve to some files
            Get-ChildItem -Recurse -Path $p -Filter "*$Extension" -File
        }

    Filter-Excluded -Files $files -ExcludePath $ExcludePath | & $script:SafeCommands['Where-Object'] { $_ }
}

function Filter-Excluded ($Files, $ExcludePath) {

    if ($null -eq $ExcludePath -or @($ExcludePath).Length -eq 0) {
        return @($Files)
    }

    foreach ($file in @($Files)) {
        # normalize backslashes for cross-platform ease of use
        $p = $file.FullName -replace "/","\"
        $excluded = $false

        foreach ($exclusion in (@($ExcludePath) -replace "/","\")) {
            if ($excluded) {
                continue
            }

            if ($p -like $exclusion) {
                $excluded = $true
            }
        }

        if (-not $excluded) {
            $file
        }
    }
}

function Add-RSpecTestObjectProperties {
    param ($TestObject)

    # adds properties that are specific to RSpec to the result object
    # this includes figuring out the result
    # formatting the failure message and stacktrace

    $TestObject.Result = if ($TestObject.Skipped) {
        "Skipped"
    }
    elseif ($TestObject.Passed) {
        "Passed"
    }
    elseif ($TestObject.ShouldRun -and (-not $TestObject.Executed -or -not $TestObject.Passed)) {
        "Failed"
    }
    else {
        "NotRun"
    }

    foreach ($e in $TestObject.ErrorRecord) {
        $r = ConvertTo-FailureLines $e
        $e.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty("DisplayErrorMessage", [string]($r.Message -join [Environment]::NewLine)))
        $e.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty("DisplayStackTrace", [string]($r.Trace -join [Environment]::NewLine)))
    }
}

function Add-RSpecBlockObjectProperties ($BlockObject) {
    foreach ($e in $BlockObject.ErrorRecord) {
        $r = ConvertTo-FailureLines $e
        $e.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty("DisplayErrorMessage", [string]($r.Message -join [Environment]::NewLine)))
        $e.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty("DisplayStackTrace", [string]($r.Trace -join [Environment]::NewLine)))
    }
}

function PostProcess-RspecTestRun ($TestRun) {

    Fold-Run $Run -OnTest {
        param($t)

        ## decorate
        # we already added the RSpec properties as part of the plugin

        ### summarize
        $TestRun.Tests.Add($t)

        switch ($t.Result) {
            "NotRun" {
                $null = $TestRun.NotRun.Add($t)
            }
            "Passed" {
                $null = $TestRun.Passed.Add($t)
            }
            "Failed" {
                $null = $TestRun.Failed.Add($t)
            }
            "Skipped" {
                $null = $TestRun.Skipped.Add($t)
            }
            default { throw "Result $($t.Result) is not supported."}
        }

    } -OnBlock {
        param ($b)

        ## decorate

        # we already processed errors in the plugin step to make the available for reporting

        $b.Result = if ($b.Skip) {
            "Skipped"
        }
        elseif ($b.Passed) {
            "Passed"
        }
        elseif ($b.ShouldRun -and (-not $b.Executed -or -not $b.Passed)) {
            "Failed"
        }
        else {
            "NotRun"
        }

        ## sumamrize

        # a block that has errors would write into failed blocks so we can report them
        # later we can filter this to only report errors from AfterAll
        if (0 -lt $b.ErrorRecord.Count) {
            $TestRun.FailedBlocks.Add($b)
        }

    } -OnContainer {
        param ($b)

        ## decorate

        # here we add result
        $b.result = if ($b.Skipped) {
            "Skipped"
        }
        elseif ($b.Passed) {
            "Passed"
        }
        elseif ($b.ShouldRun -and (-not $b.Executed -or -not $b.Passed)) {
            "Failed"
        }
        else {
            "NotRun"
        }

        foreach ($e in $b.ErrorRecord) {
            $r = ConvertTo-FailureLines $e
            $e.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty("DisplayErrorMessage", [string]($r.Message -join [Environment]::NewLine)))
            $e.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty("DisplayStackTrace", [string]($r.Trace -join [Environment]::NewLine)))
        }

        ## summarize
        if (0 -lt $b.ErrorRecord.Count) {
            $TestRun.FailedContainers.Add($b)
        }

        $TestRun.Duration += $b.Duration
        $TestRun.UserDuration += $b.UserDuration
        $TestRun.FrameworkDuration += $b.FrameworkDuration
        $TestRun.DiscoveryDuration += $b.DiscoveryDuration
    }

    $TestRun.PassedCount = $TestRun.Passed.Count
    $TestRun.FailedCount = $TestRun.Failed.Count
    $TestRun.SkippedCount = $TestRun.Skipped.Count
    $TestRun.NotRunCount = $TestRun.NotRun.Count

    $TestRun.TotalCount = $TestRun.Tests.Count

    $TestRun.FailedBlocksCount = $TestRun.FailedBlocks.Count
    $TestRun.FailedContainersCount = $TestRun.FailedContainers.Count

    $TestRun.Result = if (0 -lt ($TestRun.FailedCount + $TestRun.FailedBlocksCount + $TestRun.FailedContainersCount)) {
        "Failed"
    }
    else {
        "Passed"
    }
}

function Get-RSpecObjectDecoratorPlugin () {
    New-PluginObject -Name "RSpecObjectDecoratorPlugin" `
        -EachTestTeardownEnd {
        param ($Context)

        # TODO: consider moving this into the core if those results are just what we need, but look first at Gherkin and how many of those results are RSpec specific and how many are Gherkin specific
        #TODO: also this is a plugin because it needs to run before the error processing kicks in, this mixes concerns here imho, and needs to be revisited, because the error writing logic is now dependent on this plugin
        Add-RSpecTestObjectProperties $Context.Test
    } -EachBlockTeardownEnd {
        param($Context)
        #TODO: also this is a plugin because it needs to run before the error processing kicks in (to be able to report correctly formatted errors on scrren in case teardown failure), this mixes concerns here imho, and needs to be revisited, because the error writing logic is now dependent on this plugin
        Add-RSpecBlockObjectProperties $Context.Block
    }
}

function New-PesterConfiguration {
    [CmdletBinding()]
    param()

    [PesterConfiguration]@{}
}

function Remove-RSpecNonPublicProperties ($run){
    # $runProperties = @(
    #     'Configuration'
    #     'Containers'
    #     'ExecutedAt'
    #     'FailedBlocksCount'
    #     'FailedCount'
    #     'NotRunCount'
    #     'PassedCount'
    #     'PSBoundParameters'
    #     'Result'
    #     'SkippedCount'
    #     'TotalCount'
    #     'Duration'
    # )

    # $containerProperties = @(
    #     'Blocks'
    #     'Content'
    #     'ErrorRecord'
    #     'Executed'
    #     'ExecutedAt'
    #     'FailedCount'
    #     'NotRunCount'
    #     'PassedCount'
    #     'Result'
    #     'ShouldRun'
    #     'Skip'
    #     'SkippedCount'
    #     'Duration'
    #     'Type' # needed because of nunit export path expansion
    #     'TotalCount'
    # )

    # $blockProperties = @(
    #     'Blocks'
    #     'ErrorRecord'
    #     'Executed'
    #     'ExecutedAt'
    #     'FailedCount'
    #     'Name'
    #     'NotRunCount'
    #     'PassedCount'
    #     'Path'
    #     'Result'
    #     'ScriptBlock'
    #     'ShouldRun'
    #     'Skip'
    #     'SkippedCount'
    #     'StandardOutput'
    #     'Tag'
    #     'Tests'
    #     'Duration'
    #     'TotalCount'
    # )

    # $testProperties = @(
    #     'Data'
    #     'ErrorRecord'
    #     'Executed'
    #     'ExecutedAt'
    #     'ExpandedName'
    #     'Id' # needed because of grouping of data driven tests in nunit export
    #     'Name'
    #     'Path'
    #     'Result'
    #     'ScriptBlock'
    #     'ShouldRun'
    #     'Skip'
    #     'Skipped'
    #     'StandardOutput'
    #     'Tag'
    #     'Duration'
    # )

    Fold-Run $run -OnRun {
        param($i)
        # $ps = $i.PsObject.Properties.Name
        # foreach ($p in $ps) {
        #     if ($p -like 'Plugin*') {
        #         $i.PsObject.Properties.Remove($p)
        #     }
        # }

        $i.PluginConfiguration = $null
        $i.PluginData = $null
        $i.Plugins = $null

    } -OnContainer {
        param($i)
        # $ps = $i.PsObject.Properties.Name
        # foreach ($p in $ps) {
        #     if ($p -like 'Own*') {
        #         $i.PsObject.Properties.Remove($p)
        #     }
        # }

        # $i.FrameworkData = $null
        # $i.PluginConfiguration = $null
        # $i.PluginData = $null
        # $i.Plugins = $null

    } -OnBlock {
        param($i)
        # $ps = $i.PsObject.Properties.Name
        # foreach ($p in $ps) {
        #     if ($p -eq 'FrameworkData' -or $p -like 'Own*' -or $p -like 'Plugin*') {
        #         $i.PsObject.Properties.Remove($p)
        #     }
        # }

        $i.FrameworkData = $null
        $i.PluginData = $null

    } -OnTest {
        param($i)
        # $ps = $i.PsObject.Properties.Name
        # foreach ($p in $ps) {
        #     if ($p -eq 'FrameworkData' -or $p -like 'Plugin*') {
        #         $i.PsObject.Properties.Remove($p)
        #     }
        # }

        $i.FrameworkData = $null
        $i.PluginData = $null
    }
}


function New-TestContainer {
    [CmdletBinding(DefaultParameterSetName="Path")]
    param(
        [Parameter(Mandatory, ParameterSetName = "Path")]
        [String] $Path,

        [Parameter(Mandatory, ParameterSetName = "ScriptBlock")]
        [ScriptBlock] $ScriptBlock,

        [Collections.IDictionary[]] $Data
    )

    switch ($PSCmdlet.ParameterSetName) {
        "ScriptBlock" { [Pester.TestScriptBlock]::Create($ScriptBlock, $Data) }
        Default { [Pester.TestPath]::Create($Path, $Data) }
    }
}
