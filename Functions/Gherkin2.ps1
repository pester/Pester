if (($PSVersionTable.ContainsKey('PSEdition')) -and ($PSVersionTable.PSEdition -eq 'Core')) {
    & $SafeCommands["Add-Type"] -Path "${Script:PesterRoot}/lib/Gherkin/core/Gherkin.dll"
} else {
    & $SafeCommands["Add-Type"] -Path "${Script:PesterRoot}/lib/Gherkin/legacy/Gherkin.dll"
}

$GherkinSteps = @{}
$GherkinHooks = @{
    AfterConfiguration = @() # Currently not supported
    BeforeFeature  = @()
    Arround = @() # Currently not supported
    BeforeScenario = @()
    BeforeStep = @() # Currently not supported
    AfterStep = @() # Currently not supported?
    AfterScenario  = @()
    AfterFeature   = @()
}

function New-GherkinState {
    param (
        [string[]]$TagFilter,
        [string[]]$ScenarioNameFilter,
        [System.Management.Automation.SessionState]$SessionState,
        [ValidateSet('None', 'Undefined', 'Pending', 'Any', 'Passing', 'Wip')]
        [string]$Strict,
        [Pester.OutputTypes]$Show = 'All',
        [PSTypeName('Pester.Option')]$PesterOption
    )

    if ($null -eq $SessionState) {
        $SessionState = Set-SessionStateHint -SessionState $ExecutionContext.SessionState -Hint 'Module - Pester (captured in New-GherkinState)' -PassThru
    }

    if ($null -eq $PesterOption) {
        $PesterOption = New-PesterOption
    } elseif ($PesterOption -is [Collections.IDictionary]) {
        try {
            $PesterOption = New-PesterOption @PesterOption
        } catch {
            throw
        }
    }

    & $SafeCommands['New-Module'] -Name PesterState -AsCustomObject -ArgumentList $TagFilter, $ScenarioNameFilter, $SessionState, $Strict, $Show, $PesterOption -ScriptBlock {
        param (
            [string[]]$_tagFilter,
            [string[]]$_scenarioNameFilter,
            [System.Management.Automation.SessionState]$_sessionState,
            [string]$Strict,
            [Pester.OutputTypes]$Show,
            [PStypeName('Pester.Option')]$PesterOption
        )

        $TagFilter = $_tagFilter
        $ScenarioNameFilter = $_scenarioNameFilter

        $Script:SessionState = $_sessionState
        $Script:Stopwatch = [Diagnostics.Stopwatch]::StartNew()
        $Script:MostRecentTimestamp = 0
        $Script:CommandCoverage = @()
        $Script:Strict = $Strict
        $Script:Show = $Show
        $Script:InTest = $False

        $Script:TestResult = @()

        $Script:TotalCount= 0
        $Script:Time = [TimeSpan]0
        $Script:UndefinedCount = 0
        $Script:PendingCount = 0
        $Script:SkippedCount = 0
        $Script:FailedCount = 0
        $Script:PassedCount = 0

        $Script:IncludeVSCodeMarker = $PesterOption.$Script:IncludeVSCodeMarker
        $Script:TestSuiteName = $PesterOption.$Script:TestSuiteName

        $Script:SafeCommands = @{}
        $Script:SafeCommands['New-Object']          = & (Pester\SafeGetCommand) -Name New-Object          -Module Microsoft.PowerShell.Utility -CommandType Cmdlet
        $Script:SafeCommands['Select-Object']       = & (Pester\SafeGetCommand) -Name Select-Object       -Module Microsoft.PowerShell.Utility -CommandType Cmdlet
        $Script:SafeCommands['Export-ModuleMember'] = & (Pester\SafeGetCommand) -Name Export-ModuleMember -Module Microsoft.PowerShell.Core    -CommandType Cmdlet
        $Script:SafeCommands['Add-Member']          = & (Pester\SafeGetCommand) -Name Add-Member          -Module Microsoft.PowerShell.Utility -CommandType Cmdlet

        function New-TestGroup {
            param(
                [string]$Name,
                [string]$Hint
            )

            # TODO: Don't really need this, as this is for step results??
            & $SafeCommands['New-Object'] PSCustomObject -Property @{
                PSTypeName     = 'Pester.TestGroup'
                Name           = $Name
                Type           = 'TestGroup'
                Hint           = $Hint
                Actions        = [Collections.ArrayList]@()
                BeforeFeature  = & $SafeCommands['New-Object'] System.Collections.Generic.List[ScriptBlock]
                AfterFeature   = & $SafeCommands['New-Object'] System.Collections.Generic.List[ScriptBlock]
                BeforeScenario = & $SafeCommands['New-Object'] System.Collections.Generic.List[ScriptBlock]
                AfterScenario  = & $SafeCommands['New-Object'] System.Collections.Generic.List[ScriptBlock]
                TotalCount     = 0
                Time           = [TimeSpan]0
                UndefinedCount = 0
                PendingCount   = 0
                SkippedCount   = 0
                FailedCount    = 0
                PassedCount    = 0
            }
        }

        $Script:TestActions = New-TestGroup -Name Pester -Hint
        $Script:TestGroupStack = & $SafeCommands['New-Object'] System.Collections.Stack
        $Script:TestGroupStack.Push($Script:TestActions)

        function EnterTestGroup {
            param (
                [string]$Name,
                [string]$Hint
            )

            $currentGroup = $Script:TestGroupStack.Pop()
            if ($currentGroup.Name -ne $Name -or $currentGroup.Hist -ne $Hint) {
                throw "TestGroups stack corrupted: Expected name/hint of ('$Name', '$Hint'). Found ('$($currentGroup.Name)', '$($currentGroup.Hint)')."
            }
        }

        function LeaveTestGroup {
            param (
                [string]$Name,
                [string]$Hint
            )

            $currentGroup = $Script:TestGroupStack.Pop()

            if ($currentGroup.Name -ne $Name -or $currentGroup.Hint -ne $Hint) {
                throw "TestGroups stack corrupted: Expected name/hint of ('$Name', '$Hint'). Found ('$($currentGroup.Name)', '$($currentGroup.Hint)')."
            }
        }

        function AddStepResult {
            [CmdletBinding()]
            param (
                [Gherkin.Ast.Step]$Step,
                [ValidateSet('Failed','Passed','Skipped','Pending','Undefined')]
                [string]$Result,
                [Nullable[TimeSpan]]$Time,
                [string]$FailureMessage,
                [string]$StackTrace,
                [string]$ParameterizedSuiteName,
                [Collections.IDictionary]$Parameters,
                [Management.Automation.ErrorRecord]$ErrorRecord
            )

            # Define this function here, otherwise, it is not available
            function New-ErrorRecord {
                [CmdletBinding()]
                param(
                    [string]$Message,
                    [string]$ErrorId,
                    [string]$File,
                    [string]$Line,
                    [string]$LineText
                )

                $exn = & $SafeCommands['New-Object'] Exception $Message
                $errorCategory = [Management.Automation.ErrorCategory]::InvalidResult
                # ErrorRecord.TargetObject is used to pass structured information about the error to a reporting system.
                $target = @{Message = $Message; File = $File; Line = $Line; LineText = $LineText}
                & $SafeCommands['New-Object'] Management.Automation.ErrorRecord $exn, $ErrorId, $errorCategory, $target
            }

            $previousTime = $Script:MostRecentTimestamp
            $Script:MostRecentTimestamp = $Script:Stopwatch.Elapsed

            if ($null -eq $Time) {
                $Time = $Script:MostRecentTimestamp - $previousTime
            }
        }
    }
}

function Get-FeatureFile {
    [CmdletBinding()]
    [OutputType([IO.FileInfo])]
    Param (
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [SupportsWildcards()]
        [string[]]$Path = "$PWD/features",

        [SupportsWildcards()]
        [string[]]$Exclude = [string[]]@()
    )

    Begin {
        $GetItem = $SafeCommands['Get-Item']
        $GetChildItem = $SafeCommands['Get-ChildItem']
        $ForEachObject = $SafeCommands['ForEach-Object']
        $Select = $SafeCommands['Select-Object']
    }

    Process {
        # This looks very convoluted, and it is. But Get-ChildItem's
        # -Exclude parameter doesn't work correctly, especially in
        # conjunction with -Filter.
        @(& $GetItem $Path | & $ForEachObject {
            # TODO: Write test to exclude Feature1.feature
            # Get all feature files directly under $_ except
            # files or folders matching any specified exclusions.
            @($_ | & $GetChildItem -Filter *.feature -File |
                & $Select -ExpandProperty FullName |
                & $GetItem -Exclude $Exclude
            )
            # If $_ is a directory, get all *.feature files under it
            # and its subfolders, except files or folders matching any
            # specified exclusions.
            if ($_.PSIsContainer) {
                @($_ | & $GetChildItem -Directory -Recurse |
                    & $Select -ExpandProperty FullName |
                    & $GetItem -Exclude @($Exclude) |
                    & $GetChildItem -Filter *.feature -File |
                    & $Select -ExpandProperty FullName |
                    & $GetItem -Exclude $Exclude
                )
            }
        })
    }
}

filter Import-Script {
    [CmdletBinding()]
    [OutputType([IO.FileInfo])]
    Param (
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [IO.FileInfo]$Path,

        # TODO: Need to determine how scoping will work
        [Parameter(Mandatory = $True)]
        [PSTypeName('Pester.GherkinState')]
        [PSCustomObject]$GherkinState
    )

    process {
        $Path | ForEach-Object {
            $invokeScript = {
                [CmdletBinding()]
                Param(
                    [Parameter(Position = 0)]
                    [string]$Path
                )

                & $Path
            }

            Set-ScriptBlockScope -ScriptBlock $invokeScript -SessionState $GherkinState.SessionState

            & $invokeScript $_.FullName

            $_
        }
    }
}

function Find-EnvironmentScript {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $True)]
        [PSTypeName('Pester.GherkinState')]
        [PSCustomObject]$GherkinState
    )

    if (Test-Path "$PWD/features/support/env.ps1") {
        $GherkinState.EnvironmentScript = & $SafeCommands['Get-ChildItem'] -File "$PWD/features/support/env.ps1"
        Write-Debug "Found environment script '$($GherkinState.EnvironmentScript.FullName)'."
    } else {
        Write-Debug "Environment script '$PWD/features/support/env.ps1' not found."
    }
}

function Find-SupportScript {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $True)]
        [string]$Path,

        [Parameter(Position = 1, Mandatory = $True)]
        [PSTypeName('Pester.GherkinState')]
        [PSCustomObject]$GherkinState
    )

    $GetItem = $SafeCommands['Get-Item']
    $GetChildItem = $SafeCommands['Get-ChildItem']
    $ForEachObject = $SafeCommands['ForEach-Object']
    $Select = $SafeCommands['Select-Object']

    $SupportFiles += @(& $GetChildItem (Join-Path $Path 'support') -Exclude $Exclude, $GherkinState.EnvironmentScript.FullName)
}

function Get-Environment {
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
        [Parameter(Position = 0, Mandatory = $True)]
        [PSTypeName('Pester.GherkinState')]
        [PSCustomObject]$GherkinState
    )

    # TODO: The point of this function is that it imports any
    # TODO: ./support/env.ps1 file such that anything defined in it
    # TODO: is available to any step definition, hook, or other
    # TODO: support function loaded after it.
    # TODO:
    # TODO: However, this doesn't seem to be working and it's because
    # TODO: of my favorite topic: PowerShell scopes and sessions!
    # TODO:
    # TODO: The real question is, how to setup the session state.
    # TODO: It sems to me, every feature should have a scope
    # TODO: associated with it. Each Scenario would have a
    # TODO: scope whose parent is the feature (think, BeforeEach
    # TODO: hook), and each Step Definition would have it's own
    # TODO: local scope whose parent is the current scenario.

    # NOTE: According to _The Cucumber Book_, the environment script
    # NOTE: is loaded prior to _ANY_ feature executing. It's global,
    # NOTE: and if anything mutates it during the test run, all other
    # NOTE: features which run after could be impacted. It seems to me,
    # NOTE: though, that this is intentional. Your tests should not be
    # NOTE: making use of global shared/static state anyway. No, the
    # NOTE: "world"--as it's called in cucumber--is meant to store
    # NOTE: utility functions, test-doubles, mocks, etc.
    # NOTE:
    # NOTE: Also, this promotes good, isolated test design.

    $WriteVerbose = $SafeCommands['Write-Verbose']

    # In cucumber, when specifying --dry-run, equivalent to -WhatIf in PowerShell,
    # the './features/support/env.rb' script is not executed. Similarly then,
    # './features/support/env.ps1' should not be imported/loaded either.
    $EnvScript = & $SafeCommands['Get-ChildItem'] "$PWD/features/support/env.ps1" -File
    if ($PSCmdlet.ShouldProcess($EnvScript.FullName, "Loading test run environment script")) {
        if ($EnvScript) {
            $GherkinState.EnvironmentScript = $EnvScript
            #Import-Script $EnvScript -PesterState $PesterState
            & $WriteVerbose "Loaded environment file '$($EnvScript.FullName)'."
        } else {
            & $WriteVerbose "The environment file '$PWD/features/support/env.ps1' was not loaded. The file was not found."
        }
    }
}

function Import-SupportScripts {
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [SupportsWildCards()]
        [string]$Path,

        [SupportsWildCards()]
        [string[]]$Require,

        [SupportsWildCards()]
        [string[]]$Exclude,

        # TODO: Need to determine how scoping will work
        [Parameter(Mandatory = $True)]
        [PSCustomObject]$PesterState
    )

    $GetItem = $SafeCommands['Get-Item']
    $GetChildItem = $SafeCommands['Get-ChildItem']
    $ForEachObject = $SafeCommands['ForEach-Object']
    $Select = $SafeCommands['Select-Object']

    # [DONE] a. Attempt to load $Path/support/env[ironment].ps1
    # b. Load $Path/support/*.ps1 -Exclude env[ironment].ps1
    # c. Get all directories named support under $Path, recursively, and load any scripts found: "$Path" -Directory -Exclude "$Path/support" -Recurse | Where { $_ has any path segment matching ^support$ } | gci -Directory -Exculed $Exclude | gci -File -Recurse -Filter *.ps1

    # In cucumber, when specifying --dry-run, equivalent to -WhatIf in PowerShell,
    # the './features/support/env.rb' script is not executed. Similarly then,
    # './features/support/env.ps1' should not be imported/loaded either.
    Import-Environment $PesterState -WhatIf:$WhatIf

    # TODO: See below --v
    # Now find and import all files under '$Path/support/*.ps1', but don't re-import
    # '$Path/support/env.ps1'. These files are imported, even when -WhatIf is specified
    # because they may be required by step definitions, which are loaded later.






    # Even if -WhatIf is specified, all other support files should be loaded.
    # These files can include things like transforms, hooks, etc. and may have
    # an effect on the output of the dry run in terms of reporting to the user
    # any Scenarios which have undefined steps through the usage formatter.
    $SupportFiles += @(Get-ChildItem (Join-Path $Path 'support') -Exclude $Exclude, $EnvScript.FullName)





    # Get all powershell files at or below the feature file(s), or, if $Required
    # is specified, at or below $Required. Files under directories named "support"
    # are always loaded.
    # TODO: Need to handle -ExcludePath parameter...
    if ($PSBoundParameters.ContainsKey('Require')) {
        #$StepDefinitionFiles = @(& $SafeCommands['Get-ChildItem'] $Require -Filter '*.ps1' -File -Recurse) +
        @(& $SafeCommands['Get-ChildItem'] $Require -Filter '*.ps1' -File -Recurse) +
            @(& $SafeCommands['Get-ChildItem'] './' -Filter 'support' -Directory -Recurse |
                & $SafeCommands['Get-ChildItem'] -Filter '*.ps1' -File) |
                Import-StepDefinition -PesterState $PesterState
    } else {
        # Find all *.ps1 files at or below the feature file(s)
        #$StepDefinitionFiles = @($FeatureFile | ForEach-Object {
        @($FeatureFile | ForEach-Object {
            if ((Get-Item $_) -is [IO.DirectoryInfo]) {
                & $SafeCommands['Get-ChildItem'] $_ -Filter '*.ps1' -Recurse -File | Import-StepDefinition
            } else {
                & $SafeCommands['Split-Path'] $_ -Parent |
                & $SafeCommands['Get-ChildItem'] -Filter '*.ps1' -Recurse -File |
                Import-StepDefinition -PesterState $PesterState
            }
        })
    }
}

function Get-StepDefinition {

}

function Import-Feature {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [IO.FileInfo[]]$Feature
    )

    Begin {
        $Parser = & $SafeCommands['New-Object'] Gherkin.Parser
    }

    Process {
        foreach ($f in $Feature) {
            $importedFeature = $Parser.Parse($f.FullName).Feature
            & $SafeCommands['Write-Verbose'] "Imported feature '$($importedFeature.Name)' from '$($f.FullName)'."
            $importedFeature
        }
    }
}

function Import-StepDefinition {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [IO.FileInfo[]]$StepDefinitionFiles,

        # TODO: Need to determine how scoping will work
        [PSTypeName('Pester.GherkinState')]
        [PSCustomObject]$GherkinState
    )

    begin {
        $NumProcessedFiles = 0
        $TotalImportedStepDefinitions = 0
    }

    process {
        $StepDefinitionFiles | ForEach-Object {
            $invokeStepDefinitionsScript = {
                [CmdletBinding()]
                Param(
                    [Parameter(Position = 0)]
                    [string]$Path
                )

                & $Path
            }

            Set-ScriptBlockScope -ScriptBlock $invokeStepDefinitionsScript -SessionState $GherkinState.SessionState

            & $invokeStepDefinitionsScript $_.FullName

            $ImportedStepDefinitionCount = $Script:GherkinSteps.Count - $TotalImportedStepDefinitions
            & $SafeCommands['Write-Verbose'] "Imported $ImportedStepDefinitionCount step definition(s) from '$($_.FullName).'"

            $TotalImportedStepDefinitions = $Script:GherkinSteps.Count
            $NumProcessedFiles++
        }
    }

    end {
        & $SafeCommands['Write-Verbose'] "Loaded $TotalImportedStepDefinitions step definitions from $NumProcessedFiles file(s)."
    }
}

function Invoke-Gherkin2 {
    <#
        .SYNOPSIS
            Invokes Pester to run all tests defined in .feature files
            TODO: Write a better synopsis

        .DESCRIPTION
            TODO: Write a better description

        .PARAMETER FeatureFile
            The path(s) to the feature files to be loaded, parsed, and executed. If
            given a path, find all *.feature files at and below the specified path.

        .Parameter Require
            Require files before executing the features. If this option is not specified,
            then all *.ps1 files that are siblings or below the features will be loaded
            automatically. Automatic loading is disabled when this option is specified,
            and all loading becomes explicit. Files under directories named "support"
            are always loaded first.
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param (
        [Parameter(Position = 0, Mandatory = $False)]
        [Alias('Script', 'Path', 'relative_path')]
        [SupportsWildcards()]
        # TODO: Consider supporting [[DIR | FILE | URL][:LINE[:LINE]*]]+
        [string[]]$FeatureFile = "$PWD/features",

        [Parameter(Mandatory = $False)]
        [Alias('r', '-require')]
        [SupportsWildcards()]
        [string[]]$Require,

        [Parameter(Mandatory = $False)]
        [int]$Retry = 0,

        # TODO: Add support for --i18n-* options...

        [Parameter(Mandatory = $False)]
        [Alias('-fail-fast')]
        [switch]$FailFast,

        [Parameter(Mandatory = $False)]
        # TODO: Add support for other formats, like cucumber
        [ValidateSet('NUnitXml')]
        [Alias('f', 'format', '-format')]
        [string]$OutputFormat = 'NUnitXml',

        # TODO: Add support for --init??

        [Parameter(Mandatory = $False)]
        [Alias('out', 'o', '-out')]
        [string]$OutputFile,

        [Parameter(Mandatory = $False, ParameterSetName = "RerunFailedTests")]
        [Alias('FailedLast')]
        [switch]$Rerun,

        # TODO: Consider how to handle a list of tags in addition to "tag expressions"
        [Parameter(Mandatory = $False)]
        [Alias('t', 'tags', '-tags')]
        [string[]]$Tag,

        # TODO: Kept only for backward compatability
        [Parameter(Mandatory = $False)]
        [string[]]$ExcludeTag,

        [Parameter(Position = 1, Mandatory = $False)]
        [Alias('Name', 'n', '-name')]
        [string[]]$ScenarioName,

        [Parameter(Mandatory = $False)]
        [SupportsWildcards()]
        [Alias('e', '-exclude')]
        [string[]]$Exclude,

        # TODO: Add support for -p, --profile

        [Parameter(Mandatory = $False)]
        [Alias('-no-color')]
        [switch]$NoColor,

        # TODO: Delete this parameter--PowerShell has a -WhatIf common parameter for this purpose
        [Parameter(Mandatory = $False)]
        [Alias('-dry-run', 'd')]
        [switch]$DryRun,

        [Parameter(Mandatory = $False)]
        [Alias('-no-multiline', 'm')]
        [switch]$NoMultiline,

        [Parameter(Mandatory = $False)]
        [Alias('-no-source', 's')]
        [switch]$NoSource,

        # TODO: Support --no-snippets -- Currently, Pester Gherkin does not support outputting snippets for missing step definitions, yet.

        # TODO: Add support for cucumber expressions.
        #[Parameter(Mandatory = $False)]
        #[Alias('-snippet-type')]
        #[ValidateSet('cucumber_expression', 'regexp')]
        #[string]$SnippetType = 'RegExp',

        [Parameter(Mandatory = $False)]
        [Pester.OutputTypes]$Show = 'All',

        [Parameter(Mandatory = $False)]
        [Alias('-no-duration')]
        [switch]$NoDuration,

        [Parameter(Mandatory = $False)]
        [Alias('b', 'backtrace', '-backtrace')]
        [switch]$ShowFullStackTrace,

        [Parameter(Mandatory = $False)]
        [Alias('-strict')]
        [ValidateSet('None', 'Undefined', 'Pending', 'Any', 'Passing', 'Wip')]
        [string]$Strict = 'None',

        # TODO: Support attempting to guess ambiguous step definitions
        #[Parameter(Mandatory = $False)]
        #[Alias('g', '-guess')]
        #[switch]$Guess,

        # TODO: Support lines parameter
        # [Parameter(Mandatory = $False)]
        # [Alias('l', '-lines')]
        # [int[]]$Lines,

        [Parameter(Mandatory = $False)]
        [Alias('-expand', 'x')]
        [switch]$Expand,

        # TODO: Support --order, which allows you to randomize the order in which scenarios are executed
        # [Parameter(Mandatory = $False)]
        # [Alias('-order')]
        # [ValidateRegex('(?i:defined|random(:\d+)?)')]
        # [string]$Order = 'Defined',

        [Parameter(Mandatory = $False)]
        [switch]$EnableExit,

        [Parameter(Mandatory = $False)]
        [switch]$PassThru,

        [Parameter(Mandatory = $False)]
        [Alias('v', '-version')]
        [switch]$Version
    )

    begin {
        # TODO: Parameterize this to accept a parameter passed in to specify different localization
        & $SafeCommands['Import-LocalizedData'] -BindingVariable GherkinReportdata -BaseDirectory $PesterRoot -Filename Gherkin.psd1 -ErrorAction SilentlyContinue

        $Script:ReportStrings = $GherkinReportData.ReportStrings
        $Script:ReportTheme = $GherkinReportData.$Script:ReportTheme

        # Fallback to en-US culture strings
        if (!$ReportStrings) {
            & $SafeCommands['Import-LocalizedData'] -BaseDirectory $PesterRoot -BindingVariable Script:ReportStrings -UICulture 'en-US' -Filename Gherkin.psd1 -ErrorAction Stop
        }

        # Make sure we can return to the current directory in the event of broken tests...
        $CWD = [Environment]::CurrentDirectory
        $Location = & $SafeCommands['Get-Location']
        [Environment]::CurrentDirectory = & $SafeCommands['Get-Location'] -PSProvider FileSystem
    }

    process {
        # TODO: Each path _MUST_ be processed in this process block
        # TODO: This is because support files must be loaded for _EACH_ path
        # TODO: If you do not process paths this way, you run the risk of
        # TODO: corrupting the "environment" in which the scenarios run
        # TODO: depending on the location of feature files and their support
        # TODO: and step definitions.

        # TODO: Remove this line
        $DebugPreference = 'Continue'

        #$plugins = @((Get-TestDrivePlugin))

        foreach ($path in $FeatureFile) {
            # TODO: Need to add support for -Rerun

            #$sessionState = Set-SessionStateHint -PassThru  -Hint "Caller - Captured in Invoke-Gherkin" -SessionState $PSCmdlet.SessionState
            #$PesterState = New-PesterState -SessionState $sessionState -Show $Show -PesterOption $PesterOption
            #$PesterState = @{ SessionState = $PSCmdlet.SessionState }

            # TODO: This is very preliminary. It'll probably be replaced by whatever state management will be used by Pester v5.
            $GherkinState = [PSCustomObject]@{
                PSTypeName = 'Pester.GherkinState'
                Features = [PSTypeName('Pester.GherkinFeature')][PSCustomObject[]]$null
                World = $PSCmdlet.SessionState
                EnvironmentScript = [IO.FileInfo]$null
                SupportScripts = [IO.FileInfo[]]@()
                StepDefinitions = [IO.FileInfo[]]@()
            }

            # Load support files
            # TODO: Need some sort of "state" object that
            # TODO: 1. Holds the parsed feature file
            # TODO: 2. Holds the path to ./support/env.ps1 file
            # TODO: 3. Holds a path[] to ./support/*.ps1 and ./**/support/*.ps1 files
            # TODO: 4. Holdas a path[] to ./step_defintions/*.ps1 and ./**/step_definitions/*.ps1 files
            # TODO: This would be analogous to Pester v5's new "test discovery" phase.

            # In cucumber, when specifying --dry-run, equivalent to -WhatIf in PowerShell,
            # the './features/support/env.rb' script is not executed. Similarly then,
            # './features/support/env.ps1' should not be imported/loaded either.
            Find-EnvironmentScript $GherkinState

            #Import-SupportScripts $Path -Exclude $Exclude -Require $Require -PesterState $PesterState -WhatIf:$WhatIf

            # Load Step Definitions

            # Get feature files and import them

            # Filter features to be executed according to feature tags, and
            # filter scenarios according to -Tag and -Line and -Name

            # Execute each feature if -WhatIf is not speified

            # After each feature has executed, print the results to the console
            # based on the -Formatter, -Multiline, -NoSource, -NoSnippets,
            # -Backtrace, -NoDuration, -Strict and -Expand

            # Save results of feature execution so that they can be
            # reported in the 'end { }' block.
        }
    }

    end {
        # TODO: Need to add support for -Rerun

        # TODO: Remove this line...
        $DebugPreference = 'Continue'

        # $sessionState = Set-SessionStateHint -PassThru  -Hint "Caller - Captured in Invoke-Gherkin" -SessionState $PSCmdlet.SessionState
        # $PesterState = New-PesterState -SessionState $sessionState -Show $Show -PesterOption $PesterOption

        # Get all powershell files at or below the feature file(s), or, if $Required
        # is specified, at or below $Required. Files under directories named "support"
        # are always loaded.
        # TODO: Need to handle -ExcludePath parameter...
        if ($PSBoundParameters.ContainsKey('Require')) {
            #$StepDefinitionFiles = @(& $SafeCommands['Get-ChildItem'] $Require -Filter '*.ps1' -File -Recurse) +
            @(& $SafeCommands['Get-ChildItem'] $Require -Filter '*.ps1' -File -Recurse) +
                @(& $SafeCommands['Get-ChildItem'] './' -Filter 'support' -Directory -Recurse |
                    & $SafeCommands['Get-ChildItem'] -Filter '*.ps1' -File) |
                    Import-StepDefinition -PesterState $PesterState
        } else {
            # Find all *.ps1 files at or below the feature file(s)
            #$StepDefinitionFiles = @($FeatureFile | ForEach-Object {
            @($FeatureFile | ForEach-Object {
                if ((Get-Item $_) -is [IO.DirectoryInfo]) {
                    & $SafeCommands['Get-ChildItem'] $_ -Filter '*.ps1' -Recurse -File | Import-StepDefinition
                } else {
                    & $SafeCommands['Split-Path'] $_ -Parent |
                    & $SafeCommands['Get-ChildItem'] -Filter '*.ps1' -Recurse -File |
                    Import-StepDefinition -PesterState $PesterState
                }
            })
        }

        # Parse all feature files specified by $FeatureFile...
        $Features = Get-FeatureFile $FeatureFile -Exclude $Exclude |
            Import-Feature |
            Select-Object -ExpandProperty Children |
            ForEach-Object {
                $StepDefinitions = $_.Steps | ForEach-Object {
                    $StepText = $_.Text
                    $MatchingStepDefinitions = @($Script:GherkinSteps.Keys |
                        Where-Object { $StepText -match $_ })

                    if ($MatchingStepDefinitions.Length -gt 1) {
                        # TODO: Implement proper error handling here.
                        throw "Ambiguous Step Definition!"
                    }

                    $Script:GherkinSteps[$MatchingStepDefinitions]
                }

                [PSCustomObject]@{
                    PSTypeName = 'Pester.GherkinFeature'
                    Feature = $_
                    StepDefinitions = $StepDefinitions
                }
            }

        # Now that we have parsed all the features and paired them with
        # all available imported step definitions, we can begin to
        # execute the scenarios.
        foreach ($feature in $Features) {
            # TODO: Need to handle before feature hooks
            $backgroundSteps = $feature.Children | Where-Object {
                Test-Keyword $_.Keyword 'background' $Feature.Language
            }

            # TODO: Run BeforeFeature hooks here...
        }

    }

}
