. $PSScriptRoot/Pester.Types.ps1
Get-Module Pester.Runtime | Remove-Module
. $PSScriptRoot/Pester.Utility.ps1
Import-Module $PSScriptRoot/Pester.Runtime.psm1 -DisableNameChecking


. $PSScriptRoot/Pester.RSpec.ps1
. $PSScriptRoot/functions/Pester.SafeCommands.ps1
### duplicate from pester.runtime
$flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
$script:SessionStateInternalProperty = [System.Management.Automation.SessionState].GetProperty('Internal', $flags)
$script:ScriptBlockSessionStateInternalProperty = [System.Management.Automation.ScriptBlock].GetProperty('SessionStateInternal', $flags)
$script:ScriptBlockSessionStateProperty = [System.Management.Automation.ScriptBlock].GetProperty("SessionState", $flags)
###

$script:AssertionOperators = & $SafeCommands['New-Object'] 'Collections.Generic.Dictionary[string,object]'([StringComparer]::InvariantCultureIgnoreCase)
$script:AssertionAliases = & $SafeCommands['New-Object'] 'Collections.Generic.Dictionary[string,object]'([StringComparer]::InvariantCultureIgnoreCase)
$script:AssertionDynamicParams = & $SafeCommands['New-Object'] System.Management.Automation.RuntimeDefinedParameterDictionary
$script:DisableScopeHints = $true

function Assert-ValidAssertionName {
    param([string]$Name)
    if ($Name -notmatch '^\S+$') {
        throw "Assertion name '$name' is invalid, assertion name must be a single word."
    }
}

function Assert-ValidAssertionAlias {
    param([string[]]$Alias)
    if ($Alias -notmatch '^\S+$') {
        throw "Assertion alias '$string' is invalid, assertion alias must be a single word."
    }
}

function Add-ShouldOperator {
    <#
.SYNOPSIS
    Register a Should Operator with Pester
.DESCRIPTION
    This function allows you to create custom Should assertions.
.EXAMPLE
    function BeAwesome($ActualValue, [switch] $Negate)
    {

        [bool] $succeeded = $ActualValue -eq 'Awesome'
        if ($Negate) { $succeeded = -not $succeeded }

        if (-not $succeeded)
        {
            if ($Negate)
            {
                $failureMessage = "{$ActualValue} is Awesome"
            }
            else
            {
                $failureMessage = "{$ActualValue} is not Awesome"
            }
        }

        return New-Object psobject -Property @{
            Succeeded      = $succeeded
            FailureMessage = $failureMessage
        }
    }

    Add-ShouldOperator -Name  BeAwesome `
                        -Test  $function:BeAwesome `
                        -Alias 'BA'

    PS C:\> "bad" | should -BeAwesome
    {bad} is not Awesome
.PARAMETER Name
    The name of the assertion. This will become a Named Parameter of Should.
.PARAMETER Test
    The test function. The function must return a PSObject with a [Bool]succeeded and a [string]failureMessage property.
.PARAMETER Alias
    A list of aliases for the Named Parameter.
.PARAMETER SupportsArrayInput
    Does the test function support the passing an array of values to test.
.PARAMETER InternalName
    If -Name is different from the actual function name, record the actual function name here.
    Used by Get-ShouldOperator to pull function help.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [scriptblock] $Test,

        [ValidateNotNullOrEmpty()]
        [AllowEmptyCollection()]
        [string[]] $Alias = @(),

        [Parameter()]
        [string] $InternalName,

        [switch] $SupportsArrayInput
    )

    $entry = New-Object psobject -Property @{
        Test               = $Test
        SupportsArrayInput = [bool]$SupportsArrayInput
        Name               = $Name
        Alias              = $Alias
        InternalName       = If ($InternalName) {
            $InternalName
        }
        Else {
            $Name
        }
    }
    if (Test-AssertionOperatorIsDuplicate -Operator $entry) {
        # This is an exact duplicate of an existing assertion operator.
        return
    }

    $namesToCheck = @(
        $Name
        $Alias
    )

    Assert-AssertionOperatorNameIsUnique -Name $namesToCheck

    $script:AssertionOperators[$Name] = $entry

    foreach ($string in $Alias | Where { -not ([string]::IsNullOrWhiteSpace($_))}) {
        Assert-ValidAssertionAlias -Alias $string
        $script:AssertionAliases[$string] = $Name
    }

    Add-AssertionDynamicParameterSet -AssertionEntry $entry
}

function Test-AssertionOperatorIsDuplicate {
    param (
        [psobject] $Operator
    )

    $existing = $script:AssertionOperators[$Operator.Name]
    if (-not $existing) {
        return $false
    }

    return $Operator.SupportsArrayInput -eq $existing.SupportsArrayInput -and
    $Operator.Test.ToString() -eq $existing.Test.ToString() -and
    -not (Compare-Object $Operator.Alias $existing.Alias)
}
function Assert-AssertionOperatorNameIsUnique {
    param (
        [string[]] $Name
    )

    foreach ($string in $name | Where { -not ([string]::IsNullOrWhiteSpace($_))}) {
        Assert-ValidAssertionName -Name $string

        if ($script:AssertionOperators.ContainsKey($string)) {
            throw "Assertion operator name '$string' has been added multiple times."
        }

        if ($script:AssertionAliases.ContainsKey($string)) {
            throw "Assertion operator name '$string' already exists as an alias for operator '$($script:AssertionAliases[$key])'"
        }
    }
}

function Add-AssertionDynamicParameterSet {
    param (
        [object] $AssertionEntry
    )

    ${function:__AssertionTest__} = $AssertionEntry.Test
    $commandInfo = Get-Command __AssertionTest__ -CommandType Function
    $metadata = [System.Management.Automation.CommandMetadata]$commandInfo

    $attribute = New-Object Management.Automation.ParameterAttribute
    $attribute.ParameterSetName = $AssertionEntry.Name
    $attribute.Mandatory = $true

    $attributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
    $null = $attributeCollection.Add($attribute)
    if (-not ([string]::IsNullOrWhiteSpace($AssertionEntry.Alias))) {
        Assert-ValidAssertionAlias -Alias $AssertionEntry.Alias
        $attribute = New-Object System.Management.Automation.AliasAttribute($AssertionEntry.Alias)
        $attributeCollection.Add($attribute)
    }

    $dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter($AssertionEntry.Name, [switch], $attributeCollection)
    $null = $script:AssertionDynamicParams.Add($AssertionEntry.Name, $dynamic)

    if ($script:AssertionDynamicParams.ContainsKey('Not')) {
        $dynamic = $script:AssertionDynamicParams['Not']
    }
    else {
        $dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter('Not', [switch], (New-Object System.Collections.ObjectModel.Collection[Attribute]))
        $null = $script:AssertionDynamicParams.Add('Not', $dynamic)
    }

    $attribute = New-Object System.Management.Automation.ParameterAttribute
    $attribute.ParameterSetName = $AssertionEntry.Name
    $attribute.Mandatory = $false
    $null = $dynamic.Attributes.Add($attribute)

    $i = 1
    foreach ($parameter in $metadata.Parameters.Values) {
        # common parameters that are already defined
        if ($parameter.Name -eq 'ActualValue' -or $parameter.Name -eq 'Not' -or $parameter.Name -eq 'Negate') {
            continue
        }


        if ($script:AssertionOperators.ContainsKey($parameter.Name) -or $script:AssertionAliases.ContainsKey($parameter.Name)) {
            throw "Test block for assertion operator $($AssertionEntry.Name) contains a parameter named $($parameter.Name), which conflicts with another assertion operator's name or alias."
        }

        foreach ($alias in $parameter.Aliases) {
            if ($script:AssertionOperators.ContainsKey($alias) -or $script:AssertionAliases.ContainsKey($alias)) {
                throw "Test block for assertion operator $($AssertionEntry.Name) contains a parameter named $($parameter.Name) with alias $alias, which conflicts with another assertion operator's name or alias."
            }
        }

        if ($script:AssertionDynamicParams.ContainsKey($parameter.Name)) {
            $dynamic = $script:AssertionDynamicParams[$parameter.Name]
        }
        else {
            # We deliberately use a type of [object] here to avoid conflicts between different assertion operators that may use the same parameter name.
            # We also don't bother to try to copy transformation / validation attributes here for the same reason.
            # Because we'll be passing these parameters on to the actual test function later, any errors will come out at that time.

            # few years later: using [object] causes problems with switch params (in my case -PassThru), because then we cannot use them without defining a value
            # so for switches we must prefer the conflicts over type
            if ([switch] -eq $parameter.ParameterType) {
                $type = [switch]
            }
            else {
                $type = [object]
            }

            $dynamic = New-Object System.Management.Automation.RuntimeDefinedParameter($parameter.Name, $type, (New-Object System.Collections.ObjectModel.Collection[Attribute]))
            $null = $script:AssertionDynamicParams.Add($parameter.Name, $dynamic)
        }

        $attribute = New-Object Management.Automation.ParameterAttribute
        $attribute.ParameterSetName = $AssertionEntry.Name
        $attribute.Mandatory = $false
        $attribute.Position = ($i++)

        $null = $dynamic.Attributes.Add($attribute)
    }
}

function Get-AssertionOperatorEntry([string] $Name) {
    return $script:AssertionOperators[$Name]
}

function Get-AssertionDynamicParams {
    return $script:AssertionDynamicParams
}

$Script:PesterRoot = & $SafeCommands['Split-Path'] -Path $MyInvocation.MyCommand.Path
& $script:SafeCommands['Get-ChildItem'] $PesterRoot -Recurse -Filter *.ps1 |
& $script:SafeCommands['Where-Object'] { -not ($_.ProviderPath.ToLower().Contains(".tests.")) } |
& $script:SafeCommands['ForEach-Object'] { . $_.ProviderPath }


# sub-modules
& $script:SafeCommands['Get-ChildItem'] "$PesterRoot/*.psm1" -Exclude "*Pester.psm1" |
    & $script:SafeCommands['ForEach-Object'] { & $script:SafeCommands['Import-Module'] $_.FullName -DisableNameChecking }


Add-Type -TypeDefinition @"
using System;

namespace Pester
{
    [Flags]
    public enum OutputTypes
    {
        None = 0,
        Default = 1,
        Passed = 2,
        Failed = 4,
        Pending = 8,
        Skipped = 16,
        Inconclusive = 32,
        Describe = 64,
        Context = 128,
        Summary = 256,
        Header = 512,
        All = Default | Passed | Failed | Pending | Skipped | Inconclusive | Describe | Context | Summary | Header,
        Fails = Default | Failed | Pending | Skipped | Inconclusive | Describe | Context | Summary | Header
    }
}
"@

function Has-Flag {
    param
    (
        [Parameter(Mandatory = $true)]
        [Pester.OutputTypes]
        $Setting,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Pester.OutputTypes]
        $Value
    )

    0 -ne ($Setting -band $Value)
}

function Invoke-Pester {
    [CmdletBinding(DefaultParameterSetName = 'Simple')]
    param(
        [Parameter(Position = 0, Mandatory = 0,  ParameterSetName = "Simple")]
        [String[]] $Path = '.',
        [Parameter(ParameterSetName = "Simple")]
        [String[]] $ExcludePath = @(),

        [Parameter(ParameterSetName = "Simple")]
        [string[]] $TagFilter,
        [Parameter(ParameterSetName = "Simple")]
        [string[]] $ExcludeTagFilter,

        [Parameter(ParameterSetName = "Simple")]
        [string[]] $FullNameFilter,

        [Parameter(ParameterSetName = "Simple")]
        [Switch] $CI,

        [Parameter(ParameterSetName = "Simple")]
        [ValidateSet("Normal", "Minimal", "None")]
        [String] $Output,

        [Parameter(ParameterSetName = "Simple")]
        [Switch] $PassThru,

        [Parameter(ParameterSetName = "Advanced")]
        [PesterConfiguration] $Configuration
    )
    begin {
        $start = [DateTime]::Now
        # this will inherit to child scopes and allow Describe / Context to run directly from a file or command line
        $invokedViaInvokePester = $true

        # TODO: Remove all references to mock table, there should not be many.
        $script:mockTable = @{}
        # todo: move mock cleanup to BeforeAllBlockContainer when there is any
        Remove-MockFunctionsAndAliases

        # maybe -IgnorePesterPreference to avoid using $PesterPreference from the context

        $callerPreference = [PesterConfiguration] $PSCmdlet.SessionState.PSVariable.GetValue("PesterPreference")
        $hasCallerPreference = $null -ne $callerPreference
        $hasConfiguration = $null -ne $Configuration

        # preference is inherited in all subsequent calls in this session state
        # but we still pass it explicitly where practical
        if ($hasCallerPreference -and -not $hasConfiguration) {
            [PesterConfiguration] $PesterPreference = $callerPreference
        }
        elseif (-not $hasCallerPreference -and $hasConfiguration) {
            [PesterConfiguration] $PesterPreference = $Configuration
        }
        elseif ($hasCallerPreference -and $hasConfiguration) {
            [PesterConfiguration] $PesterPreference = [PesterConfiguration]::Merge($callerPreference, $Configuration)
        }
        else {
            [PesterConfiguration] $PesterPreference = [PesterConfiguration]::Default
        }

        Get-Variable 'Configuration' -Scope Local | Remove-Variable
    }

    end {
        try {
            if ('Simple' -eq $PSCmdlet.ParameterSetName) {
                # populate preference from parameters and remove them so we
                # don't inherit them to child functions by accident

                if ($Path) {
                    if ($null -ne $Path) {
                        $PesterPreference.Run.Path = $Path
                    }
                    Get-Variable 'Path' -Scope Local | Remove-Variable
                }

                if ($ExcludePath) {
                    if ($null -ne $ExcludePath) {
                        $PesterPreference.Run.ExcludePath = $ExcludePath
                    }
                    Get-Variable 'ExcludePath' -Scope Local | Remove-Variable
                }

                if (any $TagFilter) {
                    if ($null -ne $TagFilter) {
                        $PesterPreference.Filter.Tag = $TagFilter
                    }
                    Get-Variable 'TagFilter' -Scope Local | Remove-Variable
                }

                if (any $ExcludeTagFilter) {
                    if ($null -ne $ExcludeTagFilter) {
                        $PesterPreference.Filter.ExcludeTag = $ExcludeTagFilter
                    }
                    Get-Variable 'ExcludeTagFilter' -Scope Local | Remove-Variable
                }

                if (any $FullNameFilter) {
                    if ($null -ne $FullNameFilter) {
                        $PesterPreference.Filter.FullName = $FullNameFilter
                    }
                    Get-Variable 'FullNameFilter' -Scope Local | Remove-Variable
                }

                if ($CI) {
                    $PesterPreference.Run.Exit = $true
                    $PesterPreference.CodeCoverage.Enabled = $true
                    $PesterPreference.TestResult.Enabled = $true
                    Get-Variable 'CI' -Scope Local | Remove-Variable
                }

                if ($Output) {
                    if ($null -ne $Output) {
                        $PesterPreference.Output.Verbosity = $Output
                    }

                    Get-Variable 'Output' -Scope Local | Remove-Variable
                }

                if ($PassThru) {
                    if ($null -ne $PassThru) {
                        $PesterPreference.Run.PassThru = [bool] $PassThru
                    }

                    Get-Variable 'PassThru' -Scope Local | Remove-Variable
                }
            }

            # $sessionState = Set-SessionStateHint -PassThru  -Hint "Caller - Captured in Invoke-Pester" -SessionState $PSCmdlet.SessionState
            $sessionState = $PSCmdlet.SessionState

            $pluginConfiguration = @{}
            $plugins = @()
            if ('None' -ne $PesterPreference.Output.Verbosity.Value) {
                $plugins += Get-WriteScreenPlugin
            }

            $plugins +=
            @(
                # decorator plugin needs to be added after output
                # because on teardown they will run in opposite order
                # and that way output can consume the fixed object that decorator
                # decorated, not nice but works
                Get-RSpecObjectDecoratorPlugin
                Get-TestDrivePlugin
                Get-MockPlugin
            )

            if ($PesterPreference.CodeCoverage.Enabled.Value) {
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
                            $i = Get-Item $p
                            if ($i.PSIsContainer) {
                                Join-Path $i.FullName "*"
                            }
                            else {
                                Join-Path $i.Directory.FullName "*"
                            }
                        })
                    })

                $outputPath = if ([IO.Path]::IsPathRooted($PesterPreference.CodeCoverage.OutputPath.Value)) {
                        $PesterPreference.CodeCoverage.OutputPath.Value
                    }
                    else {
                        Join-Path $pwd.Path $PesterPreference.CodeCoverage.OutputPath.Value
                    }

                $CodeCoverage = @{
                    Enabled = $PesterPreference.CodeCoverage.Enabled.Value
                    OutputFormat = $PesterPreference.CodeCoverage.OutputFormat.Value
                    OutputPath = $outputPath
                    OutputEncoding = $PesterPreference.CodeCoverage.OutputEncoding.Value
                    ExcludeTests = $PesterPreference.CodeCoverage.ExcludeTests.Value
                    Path = @($paths)
                    TestExtension = $PesterPreference.Run.TestExtension.Value
                }

                $plugins += (Get-CoveragePlugin)
                $pluginConfiguration["Coverage"] = $CodeCoverage
            }

            $filter = New-FilterObject `
                -Tag $PesterPreference.Filter.Tag.Value `
                -ExcludeTag $PesterPreference.Filter.ExcludeTag.Value `
                -Line $PesterPreference.Filter.Line.Value `
                -FullName $PesterPreference.Filter.FullName.Value

            $containers = @()
            if (any $PesterPreference.Run.ScriptBlock.Value) {
                $containers += @( $PesterPreference.Run.ScriptBlock.Value | foreach { Pester.Runtime\New-BlockContainerObject -ScriptBlock $_ })
            }

            if ((any $PesterPreference.Run.Path.Value)) {
                if ((none $PesterPreference.Run.ScriptBlock.Value) -or ((any $PesterPreference.Run.ScriptBlock.Value) -and '.' -ne $PesterPreference.Run.Path.Value[0])) {
                    #TODO: Skipping the invocation when scriptblock is provided and the default path, later keep path in the default parameter set and remove scriptblock from it, so get-help still shows . as the default value and we can still provide script blocks via an advanced settings parameter
                    # TODO: pass the startup options as context to Start instead of just paths

                    $containers += @(Find-File -Path $PesterPreference.Run.Path.Value -ExcludePath $PesterPreference.Run.ExcludePath.Value -Extension $PesterPreference.Run.TestExtension.Value | foreach { Pester.Runtime\New-BlockContainerObject -File $_ })
                }
            }

            # monkey patching that we need global data for code coverage, this is problematic because code coverage should be setup once for the whole run, but because at the start everything was separated on container level the discovery is not done at this point, and we don't have any info about the containers apart from the path, or scriptblock content
            $pluginData = @{}
            Invoke-PluginStep -Plugins $Plugins -Step Start -Context @{
                Containers = $containers
                Configuration = $pluginConfiguration
                GlobalPluginData = $pluginData
            } -ThrowOnFailure

            if ((none $containers)) {
                throw "No test files were found and no scriptblocks were provided."
                return
            }

            $r = Invoke-Test -BlockContainer $containers -Plugin $plugins -PluginConfiguration $pluginConfiguration -SessionState $sessionState -Filter $filter -Configuration $PesterPreference

            foreach ($c in $r) {
                Fold-Container -Container $c  -OnTest { param($t) Add-RSpecTestObjectProperties $t }
            }

            $parameters = @{
                PSBoundParameters = $PSBoundParameters
            }

            $run = New-RSpecTestRunObject -ExecutedAt $start -Parameters $parameters -BoundParameters $PSBoundParameters -BlockContainer @($r) -PluginConfiguration $pluginConfiguration -Plugins $Plugins -PluginData $pluginData -Configuration $PesterPreference

            PostProcess-RSpecTestRun -TestRun $run

            Invoke-PluginStep -Plugins $Plugins -Step End -Context @{
                TestRun = $run
                Configuration = $pluginConfiguration
            } -ThrowOnFailure

            if ($PesterPreference.TestResult.Enabled.Value) {
                Export-NunitReport $run $PesterPreference.TestResult.OutputPath.Value
            }

            if ($PesterPreference.CodeCoverage.Enabled.Value) {
                $breakpoints = @($run.PluginData.Coverage.CommandCoverage)
                $coverageReport = Get-CoverageReport -CommandCoverage $breakpoints
                $totalMilliseconds = ($run.Duration + $run.DiscoveryDuration + $run.FrameworkDuration).TotalMilliseconds
                $jaCoCoReport = Get-JaCoCoReportXml -CommandCoverage $breakpoints -TotalMilliseconds $totalMilliseconds -CoverageReport $coverageReport
                $jaCoCoReport | & $SafeCommands['Out-File'] $PesterPreference.CodeCoverage.OutputPath.Value -Encoding $PesterPreference.CodeCoverage.OutputEncoding.Value
            }

            if (-not $PesterPreference.Debug.ReturnRawResultObject.Value) {
                Remove-RSPecNonPublicProperties $run
            }

            if ($PesterPreference.Run.PassThru.Value) {
                $run
            }

            if ($PesterPreference.Run.Exit.Value -and "failed" -eq $run.Result) {
                exit ($run.FailedCount + $run.FailedBlocksCount)
            }
        }
        catch {
            Write-ErrorToScreen $_
            if ($PesterPreference.Run.Exit.Value) {
                exit -1
            }
        }
    }
}

function New-PesterOption {
    #TODO: move those options, right now I am just not exposing this function and added the testSuiteName
    <#
    .SYNOPSIS
    Creates an object that contains advanced options for Invoke-Pester
    .DESCRIPTION
    By using New-PesterOption you can set options what allow easier integration with external applications or
    modifies output generated by Invoke-Pester.
    The result of New-PesterOption need to be assigned to the parameter 'PesterOption' of the Invoke-Pester function.
    .PARAMETER IncludeVSCodeMarker
    When this switch is set, an extra line of output will be written to the console for test failures, making it easier
    for VSCode's parser to provide highlighting / tooltips on the line where the error occurred.
    .PARAMETER TestSuiteName
    When generating NUnit XML output, this controls the name assigned to the root "test-suite" element.  Defaults to "Pester".
    .PARAMETER ScriptBlockFilter
    Filters scriptblock based on the path and line number. This is intended for integration with external tools so we don't rely on names (strings) that can have expandable variables in them.
    .PARAMETER Experimental
    Enables experimental features of Pester to be enabled.
    .PARAMETER ShowScopeHints
    EXPERIMENTAL: Enables debugging output for debugging tranisition among scopes. (Experimental flag needs to be used to enable this.)

    .INPUTS
    None
    You cannot pipe input to this command.
    .OUTPUTS
    System.Management.Automation.PSObject
    .EXAMPLE
        PS > $Options = New-PesterOption -TestSuiteName "Tests - Set A"

        PS > Invoke-Pester -PesterOption $Options -Outputfile ".\Results-Set-A.xml" -OutputFormat NUnitXML

        The result of commands will be execution of tests and saving results of them in a NUnitMXL file where the root "test-suite"
        will be named "Tests - Set A".
    .LINK
    https://github.com/pester/Pester/wiki/New-PesterOption

    .LINK
    Invoke-Pester
    #>

    [CmdletBinding()]
    param (
        [switch] $IncludeVSCodeMarker,

        [ValidateNotNullOrEmpty()]
        [string] $TestSuiteName = 'Pester',

        [switch] $Experimental,

        [switch] $ShowScopeHints,

        [hashtable[]] $ScriptBlockFilter
    )

    # in PowerShell 2 Add-Member can attach properties only to
    # PSObjects, I could work around this by capturing all instances
    # in checking them during runtime, but that would bring a lot of
    # object management problems - so let's just not allow this in PowerShell 2
    if ($Experimental -and $ShowScopeHints) {
        if ($PSVersionTable.PSVersion.Major -lt 3) {
            throw "Scope hints cannot be used on PowerShell 2 due to limitations of Add-Member."
        }

        $script:DisableScopeHints = $false
    }
    else {
        $script:DisableScopeHints = $true
    }

    return & $script:SafeCommands['New-Object'] psobject -Property @{
        IncludeVSCodeMarker = [bool] $IncludeVSCodeMarker
        TestSuiteName       = $TestSuiteName
        ShowScopeHints      = $ShowScopeHints
        Experimental        = $Experimental
        ScriptBlockFilter   = $ScriptBlockFilter
    }
}

function ResolveTestScripts {
    param ([object[]] $Path)

    $resolvedScriptInfo = @(
        foreach ($object in $Path) {
            if ($object -is [System.Collections.IDictionary]) {
                $unresolvedPath = Get-DictionaryValueFromFirstKeyFound -Dictionary $object -Key 'Path', 'p'
                $script = Get-DictionaryValueFromFirstKeyFound -Dictionary $object -Key 'Script'
                $arguments = @(Get-DictionaryValueFromFirstKeyFound -Dictionary $object -Key 'Arguments', 'args', 'a')
                $parameters = Get-DictionaryValueFromFirstKeyFound -Dictionary $object -Key 'Parameters', 'params'

                if ($null -eq $Parameters) {
                    $Parameters = @{}
                }

                if ($unresolvedPath -isnot [string] -or $unresolvedPath -notmatch '\S' -and ($script -isnot [string] -or $script -notmatch '\S')) {
                    throw 'When passing hashtables to the -Path parameter, the Path key is mandatory, and must contain a single string.'
                }

                if ($null -ne $parameters -and $parameters -isnot [System.Collections.IDictionary]) {
                    throw 'When passing hashtables to the -Path parameter, the Parameters key (if present) must be assigned an IDictionary object.'
                }
            }
            else {
                $unresolvedPath = [string] $object
                $script = [string] $object
                $arguments = @()
                $parameters = @{}
            }

            if (-not [string]::IsNullOrEmpty($unresolvedPath)) {
                if ($unresolvedPath -notmatch '[\*\?\[\]]' -and
                    (& $script:SafeCommands['Test-Path'] -LiteralPath $unresolvedPath -PathType Leaf) -and
                    (& $script:SafeCommands['Get-Item'] -LiteralPath $unresolvedPath) -is [System.IO.FileInfo]) {
                    $extension = [System.IO.Path]::GetExtension($unresolvedPath)
                    if ($extension -ne '.ps1') {
                        & $script:SafeCommands['Write-Error'] "Script path '$unresolvedPath' is not a ps1 file."
                    }
                    else {
                        & $script:SafeCommands['New-Object'] psobject -Property @{
                            Path       = $unresolvedPath
                            Script     = $null
                            Arguments  = $arguments
                            Parameters = $parameters
                        }
                    }
                }
                else {
                    # World's longest pipeline?

                    & $script:SafeCommands['Resolve-Path'] -Path $unresolvedPath |
                        & $script:SafeCommands['Where-Object'] { $_.Provider.Name -eq 'FileSystem' } |
                        & $script:SafeCommands['Select-Object'] -ExpandProperty ProviderPath |
                        & $script:SafeCommands['Get-ChildItem'] -Include *.Tests.ps1 -Recurse |
                        & $script:SafeCommands['Where-Object'] { -not $_.PSIsContainer } |
                        & $script:SafeCommands['Select-Object'] -ExpandProperty FullName -Unique |
                        & $script:SafeCommands['ForEach-Object'] {
                        & $script:SafeCommands['New-Object'] psobject -Property @{
                            Path       = $_
                            Script     = $null
                            Arguments  = $arguments
                            Parameters = $parameters
                        }
                    }
                }
            }
            elseif (-not [string]::IsNullOrEmpty($script)) {
                & $script:SafeCommands['New-Object'] psobject -Property @{
                    Path       = $null
                    Script     = $script
                    Arguments  = $arguments
                    Parameters = $parameters
                }
            }
        }
    )

    # Here, we have the option of trying to weed out duplicate file paths that also contain identical
    # Parameters / Arguments.  However, we already make sure that each object in $Path didn't produce
    # any duplicate file paths, and if the caller happens to pass in a set of parameters that produce
    # dupes, maybe that's not our problem.  For now, just return what we found.

    $resolvedScriptInfo
}

function Get-DictionaryValueFromFirstKeyFound {
    param ([System.Collections.IDictionary] $Dictionary, [object[]] $Key)

    foreach ($keyToTry in $Key) {
        if ($Dictionary.Contains($keyToTry)) {
            return $Dictionary[$keyToTry]
        }
    }
}

function Set-PesterStatistics($Node) {
    if ($null -eq $Node) {
        $Node = $pester.TestActions
    }

    foreach ($action in $Node.Actions) {
        if ($action.Type -eq 'TestGroup') {
            Set-PesterStatistics -Node $action

            $Node.TotalCount += $action.TotalCount
            $Node.PassedCount += $action.PassedCount
            $Node.FailedCount += $action.FailedCount
            $Node.SkippedCount += $action.SkippedCount
            $Node.PendingCount += $action.PendingCount
            $Node.InconclusiveCount += $action.InconclusiveCount
        }
        elseif ($action.Type -eq 'TestCase') {
            $node.TotalCount++

            switch ($action.Result) {
                Passed {
                    $Node.PassedCount++; break;
                }
                Failed {
                    $Node.FailedCount++; break;
                }
                Skipped {
                    $Node.SkippedCount++; break;
                }
                Pending {
                    $Node.PendingCount++; break;
                }
                Inconclusive {
                    $Node.InconclusiveCount++; break;
                }
            }
        }
    }
}

function Contain-AnyStringLike ($Filter, $Collection) {
    foreach ($item in $Collection) {
        foreach ($value in $Filter) {
            if ($item -like $value) {
                return $true
            }
        }
    }
    return $false
}

function ConvertTo-Pester4Result {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $PesterResult
    )
    process {
        $legacyResult = [PSCustomObject] @{
            TagFilter = $null
            ExcludeTagFilter = $null
            TestNameFilter = $null
            ScriptBlockFilter = $null
            TotalCount = 0
            PassedCount = 0
            FailedCount = 0
            SkippedCount = 0
            PendingCount = 0
            InconclusiveCount = 0
            Time = [TimeSpan]::Zero
            TestResult = [System.Collections.ArrayList]@()
        }
        $filter = $PesterResult.Configuration.Filter
        $legacyResult.TagFilter = if (0 -ne $filter.Tag.Value.Count) { $filter.Tag.Value }
        $legacyResult.ExcludeTagFilter = if (0 -ne $filter.ExcludeTag.Value.Count) { $filter.ExcludeTag.Value }
        $legacyResult.TestNameFilter = if (0 -ne $filter.TestNameFilter.Value.Count) { $filter.TestNameFilter.Value }
        $legacyResult.ScriptBlockFilter = if (0 -ne $filter.ScriptBlockFilter.Value.Count) { $filter.ScriptBlockFilter.Value }

        $sb = {
            param($test)

            if ("NotRun" -eq $test.Result) {
                return
            }

            $result = [PSCustomObject] @{
                Passed = "Passed" -eq $test.Result
                Result = $test.Result
                Time = $test.Duration
                Name = $test.Name

                # in the legacy result the top block is considered to be a Describe and any blocks inside of it are
                # considered to be Context and joined by '\'
                Describe = $test.Path[0]
                Context = $(if ($test.Path.Count -gt 2) { $test.Path[1..($test.Path.Count-2)] -join '\'})

                Show = $PesterResult.Configuration.Output.Verbosity.Value
                Parameters = $test.Data
                ParameterizedSuiteName = $test.DisplayName

                FailureMessage = $(if (any $test.ErrorRecord -and $null -ne $test.ErrorRecord[-1].Exception) { $test.ErrorRecord[-1].DisplayErrorMessage })
                ErrorRecord = $(if (any $test.ErrorRecord) { $test.ErrorRecord[-1] })
                StackTrace = $(if (any $test.ErrorRecord) { $test.ErrorRecord[1].DisplayStackTrace })
            }

            $null = $legacyResult.TestResult.Add($result)
        }


        Fold-Run $PesterResult -OnTest $sb -OnBlock {
            param($b)

            if (0 -ne $b.ErrorRecord.Count) {
                & $sb $b
            }
        }

        # the counts here include failed blocks as tests, that's we don't use
        # the normal properties on the reslt to count

        foreach ($r in $legacyResult.TestResult) {
            switch ($r.Result) {
                "Passed" {
                    $legacyResult.PassedCount++
                }
                "Failed" {
                    $legacyResult.FailedCount++
                }
                "Skipped" {
                    $legacyResult.SkippedCount++
                }
            }
        }
        $legacyResult.TotalCount = $legacyResult.TestResult.Count
        $legacyResult.PendingCount = 0
        $legacyResult.InconclusiveCount = 0
        $legacyResult.Time = $PesterResult.Duration

        $legacyResult
    }
}

Set-SessionStateHint -Hint Pester -SessionState $ExecutionContext.SessionState
# these functions will be shared with the mock bootstrap function, or used in mocked calls so let's capture them just once instead of everytime we use a mock
$script:SafeCommands['ExecutionContext'] = $ExecutionContext
$script:SafeCommands['Get-MockDynamicParameter'] = $ExecutionContext.SessionState.InvokeCommand.GetCommand('Get-MockDynamicParameter', 'function')
$script:SafeCommands['Write-PesterDebugMessage'] = $ExecutionContext.SessionState.InvokeCommand.GetCommand('Write-PesterDebugMessage', 'function')
$script:SafeCommands['Set-DynamicParameterVariable'] = $ExecutionContext.SessionState.InvokeCommand.GetCommand('Set-DynamicParameterVariable', 'function')


Set-Alias 'Add-AssertionOperator' 'Add-ShouldOperator'
Set-Alias 'Get-AssertionOperator' 'Get-ShouldOperator'


& $script:SafeCommands['Export-ModuleMember'] @(
    'Invoke-Pester'

    # blocks
    'Describe'
    'Context'
    'It'

    # mocking
    'Mock'
    'InModuleScope'

    # setups
    'BeforeAll'
    'BeforeEach'
    'AfterEach'
    'AfterAll'

    # should
    'Should'
    'Add-ShouldOperator'
    'Get-ShouldOperator'

    # export
    'Export-NunitReport'
    'ConvertTo-NUnitReport'
    'ConvertTo-Pester4Result'

    # legacy
    'Assert-VerifiableMock'
    'Assert-MockCalled'
    'Set-ItResult'
    'New-MockObject'

) -Alias @(
    'Add-AssertionOperator'
    'Get-AssertionOperator'
)
