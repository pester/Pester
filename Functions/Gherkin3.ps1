if (($PSVersionTable.ContainsKey('PSEdition')) -and ($PSVersionTable.PSEdition -eq 'Core')) {
    & $SafeCommands["Add-Type"] -Path "${Script:PesterRoot}/lib/Gherkin/core/Gherkin.dll"
} else {
    & $SafeCommands["Add-Type"] -Path "${Script:PesterRoot}/lib/Gherkin/legacy/Gherkin.dll"
}

function Get-FeatureFile {
    [CmdletBinding()]
    [OutputType([IO.FileInfo])]
    Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [SupportsWildcards()]
        [string[]]$Path,

        [SupportsWildcards()]
        [string[]]$Exclude = [string[]]@()
    )

    Process {
        # This looks very convoluted, and it is. But Get-ChildItem's
        # -Exclude parameter doesn't work correctly, especially in
        # conjunction with -Filter.
        @(Get-Item $Path | ForEach-Object {
            # Get all feature files directly under $_ except
            # files or folders matching any specified exclusions.
            @($_ | Get-ChildItem -Filter *.feature -File |
                Select-Object -ExpandProperty FullName |
                Get-Item -Exclude $Exclude
            )
            # If $_ is a directory, get all *.feature files under it
            # and its subfolders, except files or folders matching any
            # specified exclusions.
            if ($_.PSIsContainer) {
                @($_ | Get-ChildItem -Directory -Recurse |
                    Select-Object -ExpandProperty FullName |
                    Get-Item -Exclude @($Exclude) |
                    Get-ChildItem -Filter *.feature -File |
                    Select-Object -ExpandProperty FullName |
                    Get-Item -Exclude $Exclude
                )
            }
        })
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
        [Parameter(Position = 0, ParameterSetName = 'Initialize')]
        [switch]$Init,

        [Parameter(Position = 0, ParameterSetName = 'Standard')]
        [SupportsWildCards()]
        [string[]]$Path = $PWD,

        [Parameter(ParameterSetName = 'Standard')]
        [SupportsWildCards()]
        [string[]]$Exclude,

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

        $SupportScripts = [IO.FileInfo[]]@()
        $FeatureFiles = [IO.FileInfo[]]@()

        $Results = [PSCustomObject]@{
            PSTypeName = 'Pester.GherkinResults'
            TotalScenarios = 0
            TotalSteps = 0
            TestRunDuration = [TimeSpan]::Zero
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Initialize') {
            Write-Output '  create   features'
            New-Item -ItemType Directory -Path $PWD -Name 'features' > $null
            Write-Output '  create   features/step_definitions'
            New-Item -ItemType Directory -Path "$PWD/features" -Name 'step_definitions' > $null
            Write-Output '  create   features/support'
            New-ITem -ItemType Directory -Path "$PWD/features" -Name 'support' > $null
            Write-Output '  create   features/support/env.ps1'
            New-Item -ItemType File -Path "$PWD/features/support" -Name 'env.ps1' > $null

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

        $EnvironmentScript = if ((& $SafeCommands['Test-Path'] "$Path/features/support/env.ps1")) {
            & $SafeCommands['Get-ChildItem'] "$Path/featuers/support/env.ps1"
        } else {
            [IO.FileInfo]$null
        }

        $FeatureFiles = Get-FeatureFile -Path "$Path/features" -Exclude $Exclude

        Write-GherkinResults $Results

        if ($PassThru) {
            $Results
        }

        # TODO: Make sure to exit with the correct exit code
        if ($EnableExit) {
            exit
        }
    }
}
