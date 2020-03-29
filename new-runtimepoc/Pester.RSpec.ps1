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

            if ((Test-Path $p)) {
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

    Filter-Excluded -Files $files -ExcludePath $ExcludePath | where { $_ }
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

    $result = if ($TestObject.Skipped) {
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

    $TestObject.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty("Result", $result))

    # TODO: rename this to Duration, and rename duration to UserCodeDuration or something like that
    $time = [timespan]::zero + $TestObject.Duration + $TestObject.FrameworkDuration
    $TestObject.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty("Time", $time))

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


function New-RSpecTestRunObject {
    param(
        [Parameter(Mandatory)]
        [DateTime] $ExecutedAt,
        [Parameter(Mandatory)]
        [Hashtable] $Parameters,
        [Hashtable] $BoundParameters,
        $Plugins,
        [Hashtable] $PluginConfiguration,
        [Hashtable] $PluginData,
        [PesterConfiguration] $Configuration,
        # [PSTypeName('ExecutedBlockContainer')]
        [object[]] $BlockContainer)

   [PSCustomObject]@{
        PSTypeName = 'PesterRSpecTestRun'
        ExecutedAt = $ExecutedAt
        Containers = [Collections.ArrayList]@($BlockContainer)
        PSBoundParameters = $BoundParameters
        Plugins = $Plugins
        PluginConfiguration = $PluginConfiguration
        PluginData = $PluginData
        Configuration = $Configuration

        Duration = [TimeSpan]::Zero
        FrameworkDuration = [TimeSpan]::Zero
        DiscoveryDuration = [TimeSpan]::Zero

        Passed = [Collections.ArrayList]@()
        PassedCount = 0
        Failed = [Collections.ArrayList]@()
        FailedCount = 0
        Skipped = [Collections.ArrayList]@()
        SkippedCount = 0
        NotRun = [Collections.ArrayList]@()
        NotRunCount = 0
        Tests = [Collections.ArrayList]@()
        TestsCount = 0

        FailedBlocks = [Collections.ArrayList]@()
        FailedBlocksCount = 0
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

        # here we add result
        $result = if ($b.Skip) {
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

        $b.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty("Result", $result))
        $b.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty("Type", $b.FrameworkData.CommandUsed))

        # add time that we will later rename to Duration in the output object filter
        $time = [timespan]::zero + $b.Duration + $b.FrameworkDuration
        $b.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty("Time", $time))

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
        $result = if ($b.Skipped) {
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

        $b.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty("Result", $result))

        # add time that we will later rename to Duration in the output object filter
        $time = [timespan]::zero + $b.Duration + $b.FrameworkDuration + $b.DiscoveryDuration
        $b.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty("Time", $time))


        foreach ($e in $b.ErrorRecord) {
            $r = ConvertTo-FailureLines $e
            $e.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty("DisplayErrorMessage", [string]($r.Message -join [Environment]::NewLine)))
            $e.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty("DisplayStackTrace", [string]($r.Trace -join [Environment]::NewLine)))
        }

        ## summarize
        $TestRun.Duration += $b.Duration
        $TestRun.FrameworkDuration += $b.FrameworkDuration
        $TestRun.DiscoveryDuration += $b.DiscoveryDuration
    }

    $TestRun.PassedCount = $TestRun.Passed.Count
    $TestRun.FailedCount = $TestRun.Failed.Count
    $TestRun.SkippedCount = $TestRun.Skipped.Count
    $TestRun.NotRunCount = $TestRun.NotRun.Count

    $TestRun.TestsCount = $TestRun.Tests.Count

    $TestRun.FailedBlocksCount = $TestRun.FailedBlocks.Count

    $result = if (0 -lt ($TestRun.FailedCount + $TestRun.FailedBlocksCount)) {
        "Failed"
    }
    else {
        "Passed"
    }

    $TestRun.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty("Result", $result))

    # add time that we will later rename to Duration in the output object filter
    $time = [timespan]::zero + $TestRun.Duration + $TestRun.FrameworkDuration +  $TestRun.DiscoveryDuration
    $TestRun.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty("Time", $time))
}

function Get-RSpecObjectDecoratorPlugin () {
    Pester.Runtime\New-PluginObject -Name "RSpecObjectDecoratorPlugin" `
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
    $runProperties = @(
        'Configuration'
        'Containers'
        'ExecutedAt'
        'FailedBlocksCount'
        'FailedCount'
        'NotRunCount'
        'PassedCount'
        'PSBoundParameters'
        'Result'
        'SkippedCount'
        'TestsCount'
        'Time' # renamed to Duration in next step
    )

    $containerProperties = @(
        'Blocks'
        'Content'
        'ErrorRecord'
        'Executed'
        'ExecutedAt'
        'FailedCount'
        'NotRunCount'
        'PassedCount'
        'Result'
        'ScriptBlock'
        'ShouldRun'
        'Skip'
        'SkippedCount'
        'Tests'
        'Time' # renamed to Duration in next step
        'Type' # needed because of nunit export path expansion
        'TotalCount'
    )

    $blockProperties = @(
        'Blocks'
        'ErrorRecord'
        'Executed'
        'ExecutedAt'
        'FailedCount'
        'Name'
        'NotRunCount'
        'PassedCount'
        'Path'
        'Result'
        'ScriptBlock'
        'ShouldRun'
        'Skip'
        'SkippedCount'
        'StandardOutput'
        'Tag'
        'Tests'
        'Time' # renamed to Duration in next step
        'Type' # useful for processing of blocks
        'TotalCount'
    )

    $testProperties = @(
        'Data'
        'ErrorRecord'
        'Executed'
        'ExecutedAt'
        'ExpandedName'
        'Id' # needed because of grouping of data driven tests in nunit export
        'Name'
        'Path'
        'Result'
        'ScriptBlock'
        'ShouldRun'
        'Skip'
        'Skipped'
        'StandardOutput'
        'Tag'
        'Time' # renamed to Duration in next step
    )

    Fold-Run $run -OnRun {
        param($i)
        $ps = $i.PsObject.Properties.Name
        foreach ($p in $ps) {
            if ($p -notin $runProperties) {
                $i.PsObject.Properties.Remove($p)
            }
        }

        $i.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty("Duration", $i.PsObject.Properties.Item("Time").Value))
        $i.PsObject.Properties.Remove("Time")
    } -OnContainer {
        param($i)
        $ps = $i.PsObject.Properties.Name
        foreach ($p in $ps) {
            if ($p -notin $containerProperties) {
                $i.PsObject.Properties.Remove($p)
            }
        }

        $i.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty("Duration", $i.PsObject.Properties.Item("Time").Value))
        $i.PsObject.Properties.Remove("Time")
    } -OnBlock {
        param($i)
        $ps = $i.PsObject.Properties.Name
        foreach ($p in $ps) {
            if ($p -notin $blockProperties) {
                $i.PsObject.Properties.Remove($p)
            }
        }

        $i.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty("Duration", $i.PsObject.Properties.Item("Time").Value))
        $i.PsObject.Properties.Remove("Time")
    } -OnTest {
        param($i)
        $ps = $i.PsObject.Properties.Name
        foreach ($p in $ps) {
            if ($p -notin $testProperties) {
                $i.PsObject.Properties.Remove($p)
            }
        }

        $i.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty("Duration", $i.PsObject.Properties.Item("Time").Value))
        $i.PsObject.Properties.Remove("Time")
    }
}

function Expand-PesterObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $PesterResult,
        [ScriptBlock] $OnIt = {},
        [ScriptBlock] $OnDescribe = {},
        [ScriptBlock] $OnContext = {},
        [ScriptBlock] $OnDescribeAndContext = {},
        [ScriptBlock] $OnContainer = {},
        [ScriptBlock] $OnPesterResult = {},
        $Accumulator
    )

    process {
        foreach ($r in @($PesterResult)) {
            if ($null -ne $OnPesterResult) {
                & $OnPesterResult $r $Accumulator
            }
            foreach ($c in $r.Containers) {
                if ($null -ne $OnContainer) {
                    & $OnContainer $c $Accumulator
                }
                foreach ($b in $c.Blocks) {
                    Expand-DescribeAndContext -Block $b -OnDescribeAndContext $OnDescribeAndContext -OnDescribe $OnDescribe -OnContext $OnContext -OnIt $OnIt -Accumulator $Accumulator
                }
            }
        }
    }
}

function Expand-DescribeAndContext {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $Block,
        $OnDescribe,
        $OnContext,
        [Alias("OnBlock")]
        $OnDescribeAndContext,
        $OnIt,
        $Accumulator
    )

    if ($null -ne $OnDescribeAndContext)
    {
        & $OnDescribeAndContext $Block $Accumulator
    }

    if ($null -ne $OnDescribe -and "Describe" -eq $Block.Type) {
        & $OnDescribe $Block $Accumulator
    }

    if ($null -ne $OnContext -and "Context" -eq $Block.Type) {
        & $OnContext $Block $Accumulator
    }

    foreach ($b in $Block.Blocks) {
        Expand-DescribeAndContext -Block $b -OnDescribeAndContext $OnDescribeAndContext -OnDescribe $OnDescribe -OnContext $OnContext -OnIt $OnIt -Accumulator $Accumulator
    }

    if ($null -ne $OnIt) {
        foreach ($i in $Block.Tests) {
            & $OnIt $i $Accumulator
        }
    }
}
