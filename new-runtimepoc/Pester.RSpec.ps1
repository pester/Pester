function Find-RSpecTestFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String[]] $Path,
        [String[]] $ExcludePath
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
                    Get-ChildItem -Recurse -Path $p -Filter *.Tests.ps1 -File
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
            Get-ChildItem -Recurse -Path $p -Filter *.Tests.ps1 -File
        }

    Filter-Excluded -Files $files -ExludePath $ExcludePath
}

function Filter-Excluded ($Files, $ExludePath) {

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

    $result = if ($TestObject.Passed) {
        "Passed"
    }
    elseif ($TestObject.ShouldRun -and (-not $TestObject.Executed -or -not $TestObject.Passed)) {
        "Failed"
    }
    else {
        "Skipped"
    }

    $TestObject.PSObject.Properties.Add([MemberFactory]::CreateNoteProperty("Result", $result))

    # TODO: rename this to Duration, and rename duration to UserCodeDuration or something like that
    $time = [timespan]::zero + $TestObject.Duration + $TestObject.FrameworkDuration
    $TestObject.PSObject.Properties.Add([MemberFactory]::CreateNoteProperty("Time", $time))

    foreach ($e in $TestObject.ErrorRecord) {
        $r = ConvertTo-FailureLines $e
        $e.PSObject.Properties.Add([MemberFactory]::CreateNoteProperty("DisplayErrorMessage", [string]($r.Message -join [Environment]::NewLine)))
        $e.PSObject.Properties.Add([MemberFactory]::CreateNoteProperty("DisplayStackTrace", [string]($r.Trace -join [Environment]::NewLine)))
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

        Duration = [TimeSpan]::Zero
        FrameworkDuration = [TimeSpan]::Zero
        DiscoveryDuration = [TimeSpan]::Zero
        Passed = [Collections.ArrayList]@()
        PassedCount = 0
        Failed = [Collections.ArrayList]@()
        FailedCount = 0
        Skipped = [Collections.ArrayList]@()
        SkippedCount = 0
        Tests = [Collections.ArrayList]@()
        TestsCount = 0
    }
}

function PostProcess-RspecTestRun ($TestRun) {
    $tests = @(View-Flat -Block $TestRun.Containers)

    foreach ($t in $tests) {
        switch ($t.Result) {
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
    }

    foreach ($c in $TestRun.Containers) {
        $TestRun.Duration += $c.Duration
        $TestRun.FrameworkDuration += $c.FrameworkDuration
        $TestRun.DiscoveryDuration += $c.DiscoveryDuration
    }

    $TestRun.PassedCount = $TestRun.Passed.Count
    $TestRun.FailedCount = $TestRun.Failed.Count
    $TestRun.SkippedCount = $TestRun.Skipped.Count

    $TestRun.Tests = [Collections.ArrayList]@($tests)
    $TestRun.TestsCount = $tests.Count
}

function Get-RSpecObjectDecoratorPlugin () {
    Pester.Runtime\New-PluginObject -Name "RSpecObjectDecoratorPlugin" `
        -EachTestTeardownEnd {
        param ($Context)

        # TODO: consider moving this into the core if those results are just what we need, but look first at Gherkin and how many of those results are RSpec specific and how many are Gherkin specific
        #TODO: also this is a plugin because it needs to run before the error processing kicks in, this mixes concerns here imho, and needs to be revisited, because the error writing logic is now dependent on this plugin
        Add-RSpecTestObjectProperties $Context.Test
    }
}

function New-PesterConfiguration {
    [CmdletBinding()]
    param()

    New_PSObject -Type "PesterConfiguration" @{
        Should = New_PSObject -Type "PesterShouldConfiguration" @{
            ErrorAction = 'Continue'
        }
    }
}
