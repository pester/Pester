if (($PSVersionTable.ContainsKey('PSEdition')) -and ($PSVersionTable.PSEdition -eq 'Core')) {
    & $SafeCommands["Add-Type"] -Path "${Script:PesterRoot}/lib/Gherkin/core/Gherkin.dll"
} else {
    & $SafeCommands["Add-Type"] -Path "${Script:PesterRoot}/lib/Gherkin/legacy/Gherkin.dll"
}

function New-GherkinProject {
    @(
        @{ ItemType = 'Directory'; Path = "$PWD"; Name = 'features' },
        @{ ItemType = 'Directory'; Path = (Join-Path "$PWD" 'features'); Name = 'step_definitions' }
        @{ ItemType = 'Directory'; Path = (Join-Path "$PWD" 'features'); Name = 'support' }
        @{ ItemType = 'File'; Path = (Join-Path (Join-Path "$PWD" 'features') 'support'); Name = 'Environment.ps1' }
    ) | ForEach-Object {
        if (Test-Path (Join-Path $_.Path $_.Name)) {
            Write-Output "   exist   $((Join-Path $_.Path $_.Name) -replace [regex]::Escape("$PWD\"))"
        } else {
            $null = New-Item @_
            Write-Output "  create   $((Join-Path $_.Path $_.Name) -replace [regex]::Escape("$PWD\"))"
        }
    }
}

function Get-ScriptFile {
    [CmdletBinding()]
    [OutputType([IO.FileInfo[]])]
    param (
        [Parameter(Position = 0, Mandatory = $True)]
        [SupportsWildCards()]
        [string[]]$Require,

        [Parameter(Position = 1)]
        [regex[]]$Exclude = @()
    )

    begin {
        $ScriptFiles = [IO.FileInfo[]]@()
    }

    process {
        foreach ($Path in $Require) {
            $ScriptFiles += @(Get-ChildItem $Path -Filter '*.ps1' -File -Recurse |
                Where-Object {
                    $ScriptFile = $_
                    $Exclude | ForEach-Object -Begin { $Result = $True } -Process {
                        $Result = $Result -and ($ScriptFile.Fullname -notmatch $_)
                    } -End { $Result }
                } |
                ForEach-Object {
                    [PSCustomObject]@{ Length = $_.FullName.Length; File = $_ }
                } |
                Sort-Object -Property Length |
                Select-Object -ExpandProperty File
            )
        }
    }

    end {
        $ScriptFiles
    }
}

function Get-StepDefinition {
    [CmdletBinding()]
    [OutputType([IO.FileInfo[]])]
    param (
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True)]
        [AllowEmptyCollection()]
        [IO.FileInfo[]]$ScriptFile
    )

    foreach ($File in $ScriptFile) {
        if ($File.FullName -notmatch '(?i)[\\/]support[\\/]') {
            $File
        }
    }
}

function Get-SupportScript {
    [CmdletBinding()]
    [OutputType([IO.FileInfo[]])]
    param (
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True)]
        [AllowEmptyCollection()]
        [IO.FileInfo[]]$ScriptFile
    )

    $allSupportFiles = foreach ($File in $ScriptFile) {
        if ($File.FullName -match '(?i)[\\/]support[\\/]') {
            $File
        }
    }

    $EnvironmentFiles = $allSupportFiles | Where-Object {
        $_.FullName -match '(?i)[\\/]support[\\/]Environment.ps1'
    }

    $OtherFiles = $allSupportFiles | Where-Object {
        $_.FullName -notmatch '(?i)[\\/]support[\\/]Environment.ps1'
    }

    @($EnvironmentFiles) + @($OtherFiles)
}

# TODO: Need to add support for Rerun file...
function Get-FeatureFile {
    [CmdletBinding()]
    [OutputType([IO.FileInfo])]
    Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [SupportsWildcards()]
        [string[]]$Path,

        [SupportsWildcards()]
        [regex[]]$Exclude
    )

    Process {
        Get-ChildItem $Path -Filter '*.feature' -Recurse |
            Where-Object {
                if ($Exclude.Length) {
                    $FeatureFile = $_
                    $Exclude | ForEach-Object -Begin { $Result = $True } -Process {
                        $Result = $Result -and ($FeatureFile.FullName -notmatch $_)
                    } -End { $Result }
                } else {
                    $True
                }
            }
    }
}

function Write-GherkinResults {
    param (
        [Parameter(Position = 0, Mandatory = $True)]
        [PSTypeName('Pester.GherkinResults')]
        [PSCustomObject]$Results
    )

    # NOTE: This is just to "fake it 'till you make it."
    if ($Results.TotalScenarios -eq 1) {
        $ScenarioResultsFormatString = '1 scenario'
    } else {
        $ScenarioResultsFormatString = '{0} scenarios'
    }

    if ($Results.TotalSteps -eq 1) {
        $StepsResultsFormatString = '1 step'
    } else {
        $StepsResultsFormatString = '{0} steps'
    }

    $DurationFormatString = "{0:m\ms\.fff\s}"
    Write-Host ($ScenarioResultsFormatString -f $Results.TotalScenarios)
    Write-Host ($StepsResultsFormatString -f $Results.TotalSteps)
    Write-Host ($DurationFormatString -f $Results.TestRunDuration)
}

function Invoke-Gherkin3 {
    [CmdletBinding(DefaultParameterSetName = 'Standard')]
    [OutputType('Initialize', [int])]
    [OutputType('Standard', 'Pester.GherkinResults')]
    param(
        [Parameter(Mandatory = $True, ParameterSetName = 'Initialize')]
        [switch]$Init,

        [Parameter(ParameterSetName = 'Standard')]
        [regex[]]$Exclude,

        [Parameter(ParameterSetName = 'Standard')]
        [SupportsWildCards()]
        [ValidateNotNullOrEmpty()]
        [string[]]$Require = 'features',

        [switch]$EnableExit,

        [Parameter(ParameterSetName = 'Standard')]
        [switch]$PassThru
    )

    begin {
        # # TODO: Parameterize this to accept a parameter passed in to specify different localization
        # & $SafeCommands['Import-LocalizedData'] -BindingVariable GherkinReportdata -BaseDirectory $PesterRoot -Filename Gherkin.psd1 -ErrorAction SilentlyContinue

        # $Script:ReportStrings = $GherkinReportData.ReportStrings
        # $Script:ReportTheme = $GherkinReportData.$Script:ReportTheme

        # # Fallback to en-US culture strings
        # if (!$ReportStrings) {
        #     & $SafeCommands['Import-LocalizedData'] -BaseDirectory $PesterRoot -BindingVariable Script:ReportStrings -UICulture 'en-US' -Filename Gherkin.psd1 -ErrorAction Stop
        # }

        # Make sure we can return to the current directory in the event of broken tests...
        $CWD = [Environment]::CurrentDirectory
        $Location = Get-Location
        [Environment]::CurrentDirectory = Get-Location -PSProvider FileSystem

        $Results = [PSCustomObject]@{
            PSTypeName = 'Pester.GherkinResults'
            TotalScenarios = 0
            TotalSteps = 0
            TestRunDuration = [TimeSpan]::Zero
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Initialize') {
            New-GherkinProject

            if ($EnableExit) {
                exit
            } else {
                return
            }
        }

        if (!(Test-Path "$Path/features")) {
            Write-Output "No such file or directory - features. You can use ``Invoke-Gherkin -Init`` to get started."

            if ($EnableExit) {
                exit 2
            } else {
                return
            }
        }

        # NOTE: From this point on -- fake it 'till you make it...

        # If -Require is specified, don't perform automatic loading of any support
        # scripts. According to Issue #567 on Cucumber's GH repo, when -Require
        # is used, all loading of support and environment scripts becomes explicit:
        # whatever is specified by -Require.
        $AllScripts = [IO.FileInfo[]]@(Get-ScriptFile $Require $Exclude)
        $SupportScripts = Get-SupportScript $AllScripts
        $StepDefintions = Get-StepDefinition $AllScripts

        $FeatureFiles = if ($PSBoundParameters.ContainsKey('Path')) {
            Get-FeatureFile -Path $Path -Exclude $Exclude
        } else {
            Get-FeatureFile -Path "$Path/features" -Exclude $Exclude
        }

        #Write-GherkinResults $Results

        if ($PassThru) {
            $Results
        }

        # TODO: Make sure to exit with the correct exit code
        if ($EnableExit) {
            exit
        }
    }
}
