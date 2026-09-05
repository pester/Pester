function or_ {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        $DefaultValue,
        [Parameter(ValueFromPipeline = $true)]
        $InputObject
    )

    if ($InputObject) {
        $InputObject
    }
    else {
        $DefaultValue
    }
}

# looks for a property on object that might be null
function tryGetProperty_ {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        $InputObject,
        [Parameter(Mandatory = $true, Position = 1)]
        $PropertyName
    )
    if ($null -eq $InputObject) {
        return
    }

    $InputObject.$PropertyName

    # this would be useful if we looked for property that might not exist
    # but that is not the case so-far. Originally I implemented this incorrectly
    # so I will keep this here for reference in case I was wrong the second time as well
    # $property = $InputObject.PSObject.Properties.Item($PropertyName)
    # if ($null -ne $property) {
    #     $property.Value
    # }
}

# combines collections that are not null or empty, but does not remove null values
# from collections so e.g. combineNonNull @(@(1,$null), @(1,2,3), $null, $null, 10)
# returns 1, $null, 1, 2, 3, 10
function combineNonNull_ ($Array) {
    foreach ($i in $Array) {

        $arr = @($i)
        if ($null -ne $i -and $arr.Length -gt 0) {
            foreach ($a in $arr) {
                $a
            }
        }
    }
}

filter selectNonNull_ {
    param($Collection)
    @(foreach ($i in $Collection) {
            if ($i) { $i }
        })
}

function any_ ($InputObject) {
    # inlining version
    $(<# any #> if (-not ($s = $InputObject)) { return $false } else { @($s).Length -gt 0 })
    # if (-not $InputObject) {
    #     return $false
    # }

    # @($InputObject).Length -gt 0
}

function none_ ($InputObject) {
    -not (any_ $InputObject)
}

function defined_ {
    param(
        [Parameter(Mandatory)]
        [String] $Name
    )
    # gets a variable via the provider and returns it's value, the name is slightly misleading
    # because it indicates that the variable is not defined when it is null, but that is fine
    # the call to the provider is slightly more expensive (at least it seems) so this should be
    # used only when we want a value that we will further inspect, and we don't want to add the overhead of
    # first checking that the variable exists and then getting it's value like here:
    # defined v & hasValue v & $v.Name -eq "abc"
    $ExecutionContext.SessionState.PSVariable.GetValue($Name)
}

function notDefined_ {
    param(
        [Parameter(Mandatory)]
        [String] $Name
    )
    # gets a variable via the provider and returns it's value, the name is slightly misleading
    # because it indicates that the variable is not defined when it is null, but that is fine
    # the call to the provider is slightly more expensive (at least it seems) so this should be
    # used only when we want a value that we will further inspect
    $null -eq ($ExecutionContext.SessionState.PSVariable.GetValue($Name))
}

function Get-CIDebugFlag {
    # Returns $true when a known CI system has its debug/verbose logging switch enabled.
    # Mirrors the CI detection used for Output.CIFormat so more CI systems can be added here later.
    # - Azure DevOps: enabling the 'System.Debug' pipeline variable sets $env:SYSTEM_DEBUG to the
    #   literal string 'true'.
    # - GitHub Actions: enabling step debug logging (secret/variable ACTIONS_STEP_DEBUG=true) sets
    #   $env:RUNNER_DEBUG to '1' inside a step. This is the same signal actions/toolkit core.isDebug() uses.
    # -eq is case-insensitive in PowerShell, so 'True'/'TRUE'/'true' all match.
    ('true' -eq $env:SYSTEM_DEBUG) -or ('1' -eq $env:RUNNER_DEBUG)
}

function Test-CIDebugOutputEnabled ([PesterConfiguration]$PesterPreference) {
    # CI debug-output surfacing is enabled when the user has not opted out (Output.CIDebugOutput is
    # not 'None') and a known CI system has its debug switch enabled. Lives here in Pester.Utility so it
    # is available both to Resolve-OutputConfiguration and to the runtime (Invoke-ContainerRun).
    ('None' -ne $PesterPreference.Output.CIDebugOutput.Value) -and (Get-CIDebugFlag)
}

function Add-DataToContext ($Destination, $Data) {
    # works as Merge-Hashtable, but additionally adds _
    # which will become $_, and checks if the Data is
    # expandable, otherwise it just defines $_

    if (-not $Destination.ContainsKey("_")) {
        $Destination.Add("_", $Data)
    }

    if ($Data -is [Collections.IDictionary]) {
        Merge-Hashtable -Destination $Destination -Source $Data
    }
}

function Merge-Hashtable ($Source, $Destination) {
    # only add non-existing keys so in case of conflict
    # the framework name wins, as if we had explicit parameters
    # on a scriptblock, then the parameter would also win
    foreach ($p in $Source.GetEnumerator()) {
        if (-not $Destination.ContainsKey($p.Key)) {
            $Destination.Add($p.Key, $p.Value)
        }
    }
}

function Merge-HashtableOrObject ($Source, $Destination) {
    if ($Source -isnot [Collections.IDictionary] -and $Source -isnot [PSObject]) {
        throw "Source must be a Hashtable, IDictionary or a PSObject."
    }

    if ($Destination -isnot [PSObject]) {
        throw "Destination must be a PSObject."
    }

    $sourceIsPSObject = $Source -is [PSObject]
    $sourceIsDictionary = $Source -is [Collections.IDictionary]
    $destinationIsPSObject = $Destination -is [PSObject]
    $destinationIsDictionary = $Destination -is [Collections.IDictionary]

    $items = if ($sourceIsDictionary) { $Source.GetEnumerator() } else { $Source.PSObject.Properties }
    foreach ($p in $items) {
        if ($null -eq $Destination.PSObject.Properties.Item($p.Key)) {
            $Destination.PSObject.Properties.Add([Pester.Factory]::CreateNoteProperty($p.Key, $p.Value))
        }
        else {
            if ($p.Value -is [hashtable] -or $p.Value -is [PSObject]) {
                Merge-HashtableOrObject -Source $p.Value -Destination $Destination.($p.Key)
            }
            else {
                $Destination.($p.Key) = $p.Value
            }

        }
    }
}

function Write-PesterDebugMessage {
    [CmdletBinding(DefaultParameterSetName = "Default")]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet("Filter", "Skip", "Runtime", "RuntimeCore", "Mock", "MockCore", "Discovery", "DiscoveryCore", "SessionState", "Timing", "TimingCore", "Plugin", "PluginCore", "CodeCoverage", "CodeCoverageCore")]
        [String[]] $Scope,
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = "Default")]
        [String] $Message,
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = "Lazy")]
        [ScriptBlock] $LazyMessage,
        [Parameter(Position = 2)]
        [Management.Automation.ErrorRecord] $ErrorRecord
    )

    if (-not $PesterPreference.Debug.WriteDebugMessages.Value) {
        throw "This should never happen. All calls to Write-PesterDebugMessage should be wrapped in `if` to avoid the performance hit of allocating the message and calling the function. Inspect the call stack to know where this call came from. This can also happen if `$PesterPreference is different from the `$PesterPreference that utilities see because of incorrect scoping."
    }

    $messagePreference = $PesterPreference.Debug.WriteDebugMessagesFrom.Value
    $any = $false
    foreach ($s in $Scope) {
        if ($any) {
            break
        }
        foreach ($p in $messagePreference) {
            if ($s -like $p) {
                $any = $true
                break
            }
        }
    }

    if (-not $any) {
        return
    }

    $color = if ($null -ne $ErrorRecord) {
        "Red"
    }
    else {
        switch ($Scope) {
            "Filter" { "Cyan" }
            "Skip" { "Cyan" }
            "Runtime" { "DarkGray" }
            "RuntimeCore" { "Cyan" }
            "Mock" { "DarkYellow" }
            "Discovery" { "DarkMagenta" }
            "DiscoveryCore" { "DarkMagenta" }
            "SessionState" { "Gray" }
            "Timing" { "Gray" }
            "TimingCore" { "Gray" }
            "PluginCore" { "Blue" }
            "Plugin" { "Blue" }
            "CodeCoverage" { "Yellow" }
            "CodeCoverageCore" { "Yellow" }
            default { "Cyan" }
        }
    }

    # this evaluates a message that is expensive to produce so we only evaluate it
    # when we know that we will write it. All messages could be provided as scriptblocks
    # but making a script block is slightly more expensive than making a string, so lazy approach
    # is used only when the message is obviously expensive, like folding the whole tree to get
    # count of found tests
    #TODO: remove this, it was clever but the best performance is achieved by putting an if around the whole call which is what I do in hopefully all places, that way the scriptblock nor the string are allocated
    if ($null -ne $LazyMessage) {
        $Message = (&$LazyMessage) -join "`n"
    }

    Write-PesterHostMessage -ForegroundColor Black -BackgroundColor $color  "${Scope}: $Message "
    if ($null -ne $ErrorRecord) {
        Write-PesterHostMessage -ForegroundColor Black -BackgroundColor $color "$ErrorRecord"
    }
}

function Fold-Block {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $Block,
        $OnBlock = {},
        $OnTest = {},
        $Accumulator
    )
    process {
        foreach ($b in $Block) {
            $Accumulator = & $OnBlock $Block $Accumulator
            foreach ($test in $Block.Tests) {
                $Accumulator = & $OnTest $test $Accumulator
            }

            foreach ($b in $Block.Blocks) {
                Fold-Block -Block $b -OnTest $OnTest -OnBlock $OnBlock -Accumulator $Accumulator
            }
        }
    }
}

function Fold-Container {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Container,
        $OnContainer = {},
        $OnBlock = {},
        $OnTest = {},
        $Accumulator
    )

    process {
        foreach ($c in $Container) {
            $Accumulator = & $OnContainer $c $Accumulator
            foreach ($block in $c.Blocks) {
                Fold-Block -Block $block -OnBlock $OnBlock -OnTest $OnTest -Accumulator $Accumulator
            }
        }
    }
}

function Fold-Run {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Run,
        $OnRun = {},
        $OnContainer = {},
        $OnBlock = {},
        $OnTest = {},
        $Accumulator
    )

    process {
        foreach ($r in $Run) {
            $Accumulator = & $OnRun $r $Accumulator
            foreach ($container in $r.Containers) {
                Fold-Container -Container $container -OnContainer $OnContainer -OnBlock $OnBlock -OnTest $OnTest -Accumulator $Accumulator
            }
        }
    }
}

function Get-StringOptionErrorMessage {
    param (
        [Parameter(Mandatory)]
        [string] $OptionPath,
        [string[]] $SupportedValues = @(),
        [string] $Value
    )
    $supportedValuesString = Join-Or ($SupportedValues -replace '^|$', "'")
    return "$OptionPath must be $supportedValuesString, but it was '$Value'. Please review your configuration."
}

function Get-DictionaryValueFromFirstKeyFound {
    param ([System.Collections.IDictionary] $Dictionary, [object[]] $Key)

    foreach ($keyToTry in $Key) {
        if ($Dictionary.Contains($keyToTry)) {
            return $Dictionary[$keyToTry]
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

function View-Flat {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Block
    )

    begin {
        $tests = [System.Collections.Generic.List[Object]]@()
    }
    process {
        # TODO: normally I would output to pipeline but in fold there is accumulator and so it does not output
        foreach ($b in $Block) {
            Fold-Container $b -OnTest { param($t) $tests.Add($t) }
        }
    }

    end {
        $tests
    }
}
