function Enter-CoverageAnalysis {
    [CmdletBinding()]
    param (
        [object[]] $CodeCoverage,
        [ScriptBlock] $Logger,
        [bool] $UseSingleHitBreakpoints = $true,
        [bool] $UseBreakpoints = $false
    )

    if ($null -ne $logger) {
        & $logger "Figuring out breakpoint positions."
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $coverageInfo = foreach ($object in $CodeCoverage) {
        Get-CoverageInfoFromUserInput -InputObject $object -Logger $Logger
    }

    if ($null -eq $coverageInfo) {
        if ($null -ne $logger) {
            & $logger "No no files were found for coverage."
        }

        return @()
    }

    # breakpoints collection actually contains locations in script that are interesting,
    # not actual breakpoints
    $breakpoints = @(Get-CoverageBreakpoints -CoverageInfo $coverageInfo -Logger $Logger)
    if ($null -ne $logger) {
        & $logger "Figuring out $($breakpoints.Count) measurable code locations took $($sw.ElapsedMilliseconds) ms."
    }

    if ($UseBreakpoints) {
        if ($null -ne $logger) {
            & $logger "Using breakpoints for code coverage. Setting $($breakpoints.Count) breakpoints."
        }

        $action = if ($UseSingleHitBreakpoints) {
            # remove itself on hit scriptblock
            {

                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    $bp = Get-PSBreakpoint -Id $_.Id
                    & $SafeCommands["Write-PesterDebugMessage"] -Scope CodeCoverageCore -Message "Hit breakpoint $($bp.Id) on $($bp.Line):$($bp.Column) in $($bp.Script)."
                }

                & $SafeCommands['Remove-PSBreakpoint'] -Id $_.Id
            }
        }
        else {
            if ($null -ne $logger) {
                & $logger "Using normal breakpoints."
            }

            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                # scriptblock with logging
                {
                    $bp = Get-PSBreakpoint -Id $_.Id
                    & $SafeCommands["Write-PesterDebugMessage"] -Scope CodeCoverageCore -Message "Hit breakpoint $($bp.Id) on $($bp.Line):$($bp.Column) in $($bp.Script)."
                }
            }
            else {
                # empty ScriptBlock
                {}
            }
        }

        foreach ($breakpoint in $breakpoints) {
            $params = $breakpoint.Breakpointlocation
            $params.Action = $action

            $breakpoint.Breakpoint = & $SafeCommands['Set-PSBreakpoint'] @params
        }

        $sw.Stop()

        if ($null -ne $logger) {
            & $logger "Setting $($breakpoints.Count) breakpoints took $($sw.ElapsedMilliseconds) ms."
        }
    }
    else {
        if ($null -ne $logger) {
            & $logger "Using Profiler based tracer for code coverage, not setting any breakpoints."
        }
    }

    return $breakpoints
}

function Exit-CoverageAnalysis {
    param ([object] $CommandCoverage)

    & $SafeCommands['Set-StrictMode'] -Off

    if ($null -ne $logger) {
        & $logger "Removing breakpoints."
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    # PSScriptAnalyzer it will flag this line because $null is on the LHS of -ne.
    # BUT that is correct in this case. We are filtering the list of breakpoints
    # to only get those that are not $null
    # (like if we did $breakpoints | where {$_ -ne $null})
    # so DON'T change this.
    $breakpoints = @($CommandCoverage.Breakpoint) -ne $null
    if ($breakpoints.Count -gt 0) {
        & $SafeCommands['Remove-PSBreakpoint'] -Breakpoint $breakpoints
    }

    if ($null -ne $logger) {
        & $logger "Removing $($breakpoints.Count) breakpoints took $($sw.ElapsedMilliseconds) ms."
    }
}

function Get-CoverageInfoFromUserInput {
    param (
        [Parameter(Mandatory = $true)]
        [object]
        $InputObject,
        $Logger
    )

    if ($InputObject -is [System.Collections.IDictionary]) {
        $unresolvedCoverageInfo = Get-CoverageInfoFromDictionary -Dictionary $InputObject
    }
    else {
        $Path = $InputObject -as [string]

        # Auto-detect IncludeTests-value from path-input if user provides path that is a test
        $IncludeTests = $Path -like "*$($PesterPreference.Run.TestExtension.Value)"

        $unresolvedCoverageInfo = New-CoverageInfo -Path $Path -IncludeTests $IncludeTests -RecursePaths $PesterPreference.CodeCoverage.RecursePaths.Value
    }

    Resolve-CoverageInfo -UnresolvedCoverageInfo $unresolvedCoverageInfo
}

function New-CoverageInfo {
    param ($Path, [string] $Class = $null, [string] $Function = $null, [int] $StartLine = 0, [int] $EndLine = 0, [bool] $IncludeTests = $false, $RecursePaths = $true)

    return [pscustomobject]@{
        Path         = $Path
        Class        = $Class
        Function     = $Function
        StartLine    = $StartLine
        EndLine      = $EndLine
        IncludeTests = $IncludeTests
        RecursePaths = $RecursePaths
    }
}

# TODO: Remove this and other code related to hashtable syntax?
function Get-CoverageInfoFromDictionary {
    param ([System.Collections.IDictionary] $Dictionary)

    $path = Get-DictionaryValueFromFirstKeyFound -Dictionary $Dictionary -Key 'Path', 'p'
    if ($null -eq $path -or 0 -ge @($path).Count) {
        throw "Coverage value '$($Dictionary | & $script:SafeCommands['Out-String'])' is missing required Path key."
    }

    $startLine = Get-DictionaryValueFromFirstKeyFound -Dictionary $Dictionary -Key 'StartLine', 'Start', 's'
    $endLine = Get-DictionaryValueFromFirstKeyFound -Dictionary $Dictionary -Key 'EndLine', 'End', 'e'
    [string] $class = Get-DictionaryValueFromFirstKeyFound -Dictionary $Dictionary -Key 'Class', 'c'
    [string] $function = Get-DictionaryValueFromFirstKeyFound -Dictionary $Dictionary -Key 'Function', 'f'
    $includeTests = Get-DictionaryValueFromFirstKeyFound -Dictionary $Dictionary -Key 'IncludeTests'
    $recursePaths = Get-DictionaryValueFromFirstKeyFound -Dictionary $Dictionary -Key 'RecursePaths'

    # TODO: Implement or remove the IDictionary config logic from CodeCoverage
    # Quick fix for https://github.com/pester/Pester/issues/2514 until CodeCoverage config logic is updated
    if ($null -eq $includeTests) { $includeTests = $PesterPreference.CodeCoverage.ExcludeTests.Value -ne $true }

    $startLine = Convert-UnknownValueToInt -Value $startLine -DefaultValue 0
    $endLine = Convert-UnknownValueToInt -Value $endLine -DefaultValue 0
    [bool] $includeTests = Convert-UnknownValueToInt -Value $includeTests -DefaultValue 0
    [bool] $recursePaths = Convert-UnknownValueToInt -Value $recursePaths -DefaultValue 1

    return New-CoverageInfo -Path $path -StartLine $startLine -EndLine $endLine -Class $class -Function $function -IncludeTests $includeTests -RecursePaths $recursePaths
}

# TODO: Remove or move til Utility?
function Convert-UnknownValueToInt {
    param ([object] $Value, [int] $DefaultValue = 0)

    try {
        return [int] $Value
    }
    catch {
        return $DefaultValue
    }
}

function Resolve-CoverageInfo {
    param ([psobject] $UnresolvedCoverageInfo)

    $paths = $UnresolvedCoverageInfo.Path
    $includeTests = $UnresolvedCoverageInfo.IncludeTests
    $recursePaths = $UnresolvedCoverageInfo.RecursePaths
    $resolvedPaths = @()

    try {
        $resolvedPaths = foreach ($path in $paths) {
            & $SafeCommands['Resolve-Path'] -Path $path -ErrorAction Stop
        }
    }
    catch {
        & $SafeCommands['Write-Error'] "Could not resolve coverage path '$path': $($_.Exception.Message)"
        return
    }

    $filePaths = Get-CodeCoverageFilePaths -Paths $resolvedPaths -IncludeTests $includeTests -RecursePaths $recursePaths

    $commonParams = @{
        StartLine = $UnresolvedCoverageInfo.StartLine
        EndLine   = $UnresolvedCoverageInfo.EndLine
        Class     = $UnresolvedCoverageInfo.Class
        Function  = $UnresolvedCoverageInfo.Function
    }

    foreach ($filePath in $filePaths) {
        New-CoverageInfo @commonParams -Path $filePath
    }
}

function Get-CodeCoverageFilePaths {
    param (
        [string[]]$Paths,
        [bool]$IncludeTests,
        [bool]$RecursePaths
    )

    $testsPattern = "*$($PesterPreference.Run.TestExtension.Value)"

    [string[]] $filteredFiles = @(foreach ($file in (& $SafeCommands['Get-ChildItem'] -LiteralPath $Paths -File -Recurse:$RecursePaths)) {
        if (('.ps1', '.psm1') -contains $file.Extension -and ($IncludeTests -or $file.Name -notlike $testsPattern)) {
            $file.FullName
        }
    })

    $uniqueFiles = [System.Collections.Generic.HashSet[string]]::new($filteredFiles)
    return $uniqueFiles
}

function Get-CoverageBreakpoints {
    [CmdletBinding()]
    param (
        [object[]] $CoverageInfo,
        [ScriptBlock]$Logger
    )

    $fileGroups = @($CoverageInfo | & $SafeCommands['Group-Object'] -Property Path)
    foreach ($fileGroup in $fileGroups) {
        if ($null -ne $Logger) {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            & $Logger "Initializing code coverage analysis for file '$($fileGroup.Name)'"
        }
        $totalCommands = 0
        $analyzedCommands = 0

        :commandLoop
        foreach ($command in Get-CommandsInFile -Path $fileGroup.Name) {
            $totalCommands++

            foreach ($coverageInfoObject in $fileGroup.Group) {
                if (Test-CoverageOverlapsCommand -CoverageInfo $coverageInfoObject -Command $command) {
                    $analyzedCommands++
                    New-CoverageBreakpoint -Command $command
                    continue commandLoop
                }
            }
        }
        if ($null -ne $Logger) {
            & $Logger  "Analyzing $analyzedCommands of $totalCommands commands in file '$($fileGroup.Name)' for code coverage, in $($sw.ElapsedMilliseconds) ms"
        }
    }
}

function Get-CommandsInFile {
    param ([string] $Path)

    $errors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref] $tokens, [ref] $errors)

    if ($PSVersionTable.PSVersion.Major -ge 5) {
        # In PowerShell 5.0, dynamic keywords for DSC configurations are represented by the DynamicKeywordStatementAst
        # class.  They still trigger breakpoints, but are not a child class of CommandBaseAst anymore.

        $predicate = {
            $args[0] -is [System.Management.Automation.Language.DynamicKeywordStatementAst] -or
            $args[0] -is [System.Management.Automation.Language.CommandBaseAst]
        }
    }
    else {
        $predicate = { $args[0] -is [System.Management.Automation.Language.CommandBaseAst] }
    }

    $searchNestedScriptBlocks = $true
    $ast.FindAll($predicate, $searchNestedScriptBlocks)
}

function Test-CoverageOverlapsCommand {
    param ([object] $CoverageInfo, [System.Management.Automation.Language.Ast] $Command)

    if ($CoverageInfo.Class -or $CoverageInfo.Function) {
        Test-CommandInScope -Command $Command -Class $CoverageInfo.Class -Function $CoverageInfo.Function
    }
    else {
        Test-CoverageOverlapsCommandByLineNumber @PSBoundParameters
    }

}

function Test-CommandInScope {
    param ([System.Management.Automation.Language.Ast] $Command, [string] $Class, [string] $Function)

    $classResult = !$Class
    $functionResult = !$Function
    for ($ast = $Command; $null -ne $ast; $ast = $ast.Parent) {
        if (!$classResult -and $PSVersionTable.PSVersion.Major -ge 5) {
            # Classes have been introduced in PowerShell 5.0
            $classAst = $ast -as [System.Management.Automation.Language.TypeDefinitionAst]
            if ($null -ne $classAst -and $classAst.Name -like $Class) {
                $classResult = $true
            }
        }
        if (!$functionResult) {
            $functionAst = $ast -as [System.Management.Automation.Language.FunctionDefinitionAst]
            if ($null -ne $functionAst -and $functionAst.Name -like $Function) {
                $functionResult = $true
            }
        }
        if ($classResult -and $functionResult) {
            return $true
        }
    }

    return $false
}

function Test-CoverageOverlapsCommandByLineNumber {
    param ([object] $CoverageInfo, [System.Management.Automation.Language.Ast] $Command)

    $commandStart = $Command.Extent.StartLineNumber
    $commandEnd = $Command.Extent.EndLineNumber
    $coverStart = $CoverageInfo.StartLine
    $coverEnd = $CoverageInfo.EndLine

    # An EndLine value of 0 means to cover the entire rest of the file from StartLine
    # (which may also be 0)
    if ($coverEnd -le 0) {
        $coverEnd = [int]::MaxValue
    }

    return (Test-RangeContainsValue -Value $commandStart -Min $coverStart -Max $coverEnd) -or
    (Test-RangeContainsValue -Value $commandEnd -Min $coverStart -Max $coverEnd)
}

function Test-RangeContainsValue {
    param ([int] $Value, [int] $Min, [int] $Max)
    return $Value -ge $Min -and $Value -le $Max
}

function New-CoverageBreakpoint {
    param ([System.Management.Automation.Language.Ast] $Command)

    if (IsIgnoredCommand -Command $Command) {
        return
    }

    $params = @{
        Script = $Command.Extent.File
        Line   = $Command.Extent.StartLineNumber
        Column = $Command.Extent.StartColumnNumber
        # we write the breakpoint later, the action will become empty scriptblock
        # or scriptblock that removes the breakpoint on hit depending on configuration
        Action = $null
    }

    [pscustomobject] @{
        File               = $Command.Extent.File
        Class              = Get-ParentClassName -Ast $Command
        Function           = Get-ParentFunctionName -Ast $Command
        StartLine          = $Command.Extent.StartLineNumber
        EndLine            = $Command.Extent.EndLineNumber
        StartColumn        = $Command.Extent.StartColumnNumber
        EndColumn          = $Command.Extent.EndColumnNumber
        Command            = Get-CoverageCommandText -Ast $Command
        Ast                = $Command
        # keep property for breakpoint but we will set it later
        Breakpoint         = $null
        BreakpointLocation = $params
    }
}

Function Get-AstTopParent {
    param(
        [System.Management.Automation.Language.Ast] $Ast,
        [int] $MaxDepth = 30
    )

    if ([string]::IsNullOrEmpty($Ast.Parent)) {
        return $Ast
    }
    elseif ($MaxDepth -le 0) {
        & $SafeCommands['Write-Verbose'] "Max depth reached, moving on"
        return $null
    }
    else {
        $MaxDepth--
        Get-AstTopParent -Ast $Ast.Parent -MaxDepth $MaxDepth
    }
}

function IsIgnoredCommand {
    param ([System.Management.Automation.Language.Ast] $Command)

    if (-not $Command.Extent.File) {
        # This can happen if the script contains "configuration" or any similarly implemented
        # dynamic keyword.  PowerShell modifies the script code and reparses it in memory, leading
        # to AST elements with no File in their Extent.
        return $true
    }

    if ($PSVersionTable.PSVersion.Major -ge 4) {
        if ($Command.Extent.Text -eq 'Configuration') {
            # More DSC voodoo.  Calls to "configuration" generate breakpoints, but their HitCount
            # stays zero (even though they are executed.)  For now, ignore them, unless we can come
            # up with a better solution.
            return $true
        }

        if (IsChildOfHashtableDynamicKeyword -Command $Command) {
            # The lines inside DSC resource declarations don't trigger their breakpoints when executed,
            # just like the "configuration" keyword itself.  I don't know why, at this point, but just like
            # configuration, we'll ignore it so it doesn't clutter up the coverage analysis with useless junk.
            return $true
        }
    }

    if ($Command.Extent.Text -match '^{?& \$wrappedCmd @PSBoundParameters ?}?$' -and
        (Get-AstTopParent -Ast $Command) -like '*$steppablePipeline.Begin($PSCmdlet)*$steppablePipeline.Process($_)*$steppablePipeline.End()*' ) {
        # Fix for proxy function wrapped pipeline command. PowerShell does not increment the hit count when
        # these functions are executed using the steppable pipeline; further, these checks are redundant, as
        # all steppable pipeline constituents already get breakpoints set. This checks to ensure the top parent
        # node of the command contains all three constituents of the steppable pipeline before ignoring it.
        return $true
    }

    if (IsClosingLoopCondition -Command $Command) {
        # For some reason, the closing expressions of do/while and do/until loops don't trigger their breakpoints.
        # To avoid useless clutter, we'll ignore those lines as well.
        return $true
    }

    if ($PSVersionTable.PSVersion.Major -ge 5) {
        if ($Command -is [System.Management.Automation.Language.CommandExpressionAst] -and
            $Command.Expression[0] -is [System.Management.Automation.Language.BaseCtorInvokeMemberExpressionAst]) {
            # Calls to inherited "base(...)" constructor does not trigger breakpoint or tracer hit, ignore.
            return $true
        }
    }

    return $false
}

function IsChildOfHashtableDynamicKeyword {
    param ([System.Management.Automation.Language.Ast] $Command)

    for ($ast = $Command.Parent; $null -ne $ast; $ast = $ast.Parent) {
        if ($PSVersionTable.PSVersion.Major -ge 5) {
            # The ast behaves differently for DSC resources with version 5+.  There's a new DynamicKeywordStatementAst class,
            # and they no longer are represented by CommandAst objects.

            if ($ast -is [System.Management.Automation.Language.DynamicKeywordStatementAst] -and
                $ast.CommandElements[-1] -is [System.Management.Automation.Language.HashtableAst]) {
                return $true
            }
        }
        else {
            if ($ast -is [System.Management.Automation.Language.CommandAst] -and
                $null -ne $ast.DefiningKeyword -and
                $ast.DefiningKeyword.BodyMode -eq [System.Management.Automation.Language.DynamicKeywordBodyMode]::Hashtable) {
                return $true
            }
        }
    }

    return $false
}

function IsClosingLoopCondition {
    param ([System.Management.Automation.Language.Ast] $Command)

    $ast = $Command

    while ($null -ne $ast.Parent) {
        if (($ast.Parent -is [System.Management.Automation.Language.DoWhileStatementAst] -or
                $ast.Parent -is [System.Management.Automation.Language.DoUntilStatementAst]) -and
            $ast.Parent.Condition -eq $ast) {
            return $true
        }

        $ast = $ast.Parent
    }

    return $false
}

function Get-ParentClassName {
    param ([System.Management.Automation.Language.Ast] $Ast)

    if ($PSVersionTable.PSVersion.Major -ge 5) {
        # Classes have been introduced in PowerShell 5.0

        $parent = $Ast.Parent

        while ($null -ne $parent -and $parent -isnot [System.Management.Automation.Language.TypeDefinitionAst]) {
            $parent = $parent.Parent
        }
    }

    if ($null -eq $parent) {
        return ''
    }
    else {
        return $parent.Name
    }
}

function Get-ParentFunctionName {
    param ([System.Management.Automation.Language.Ast] $Ast)

    $parent = $Ast.Parent

    while ($null -ne $parent -and $parent -isnot [System.Management.Automation.Language.FunctionDefinitionAst]) {
        $parent = $parent.Parent
    }

    if ($null -eq $parent) {
        return ''
    }
    else {
        return $parent.Name
    }
}

function Get-CoverageCommandText {
    param ([System.Management.Automation.Language.Ast] $Ast)

    $reportParentExtentTypes = @(
        [System.Management.Automation.Language.ReturnStatementAst]
        [System.Management.Automation.Language.ThrowStatementAst]
        [System.Management.Automation.Language.AssignmentStatementAst]
        [System.Management.Automation.Language.IfStatementAst]
    )

    $parent = Get-ParentNonPipelineAst -Ast $Ast

    if ($null -ne $parent) {
        if ($parent -is [System.Management.Automation.Language.HashtableAst]) {
            return Get-KeyValuePairText -HashtableAst $parent -ChildAst $Ast
        }
        elseif ($reportParentExtentTypes -contains $parent.GetType()) {
            return $parent.Extent.Text
        }
    }

    return $Ast.Extent.Text
}

function Get-ParentNonPipelineAst {
    param ([System.Management.Automation.Language.Ast] $Ast)

    $parent = $null
    if ($null -ne $Ast) {
        $parent = $Ast.Parent
    }

    while ($parent -is [System.Management.Automation.Language.PipelineAst]) {
        $parent = $parent.Parent
    }

    return $parent
}

function Get-KeyValuePairText {
    param (
        [System.Management.Automation.Language.HashtableAst] $HashtableAst,
        [System.Management.Automation.Language.Ast] $ChildAst
    )

    & $SafeCommands['Set-StrictMode'] -Off

    foreach ($keyValuePair in $HashtableAst.KeyValuePairs) {
        if ($keyValuePair.Item2.PipelineElements -contains $ChildAst) {
            return '{0} = {1}' -f $keyValuePair.Item1.Extent.Text, $keyValuePair.Item2.Extent.Text
        }
    }

    # This shouldn't happen, but just in case, default to the old output of just the expression.
    return $ChildAst.Extent.Text
}

function Get-CoverageMissedCommands {
    param ([object[]] $CommandCoverage)
    $CommandCoverage | & $SafeCommands['Where-Object'] { $_.Breakpoint.HitCount -eq 0 }
}

function Get-CoverageHitCommands {
    param ([object[]] $CommandCoverage)
    $CommandCoverage | & $SafeCommands['Where-Object'] { $_.Breakpoint.HitCount -gt 0 }
}

function Merge-CommandCoverage {
    param ([object[]] $CommandCoverage)

    # todo: this is a quick implementation of merging lists of breakpoints together, this is needed
    # because the code coverage is stored per container and so in the end a lot of commands are missed
    # in the container while they are hit in other, what we want is to know how many of the commands were
    # hit in at least one file. This simple implementation does not add together the number of hits on each breakpoint
    # so the HitCommands is not accurate, it only keeps the first breakpoint that points to that command and it's hit count
    # this should be improved in the future.

    # todo: move this implementation to the calling function so we don't need to split and merge the collection twice and we
    # can also accumulate the hit count across the different breakpoints

    $hitBps = @{}
    $hits = [System.Collections.Generic.List[object]]@()
    foreach ($bp in $CommandCoverage) {
        if (0 -lt $bp.Breakpoint.HitCount) {
            $key = "$($bp.File):$($bp.StartLine):$($bp.StartColumn)"
            if (-not $hitBps.ContainsKey($key)) {
                # adding to a hashtable to make sure we can look up the keys quickly
                # and also to an array list to make sure we can later dump them in the correct order
                $hitBps.Add($key, $bp)
                $null = $hits.Add($bp)
            }
        }
    }

    $missedBps = @{}
    $misses = [System.Collections.Generic.List[object]]@()
    foreach ($bp in $CommandCoverage) {
        if (0 -eq $bp.Breakpoint.HitCount) {
            $key = "$($bp.File):$($bp.StartLine):$($bp.StartColumn)"
            if (-not $hitBps.ContainsKey($key)) {
                if (-not $missedBps.ContainsKey($key)) {
                    $missedBps.Add($key, $bp)
                    $null = $misses.Add($bp)
                }
            }
        }
    }

    # this is also not very efficient because in the next step we are splitting this collection again
    # into hit and missed breakpoints
    $c = $hits.GetEnumerator() + $misses.GetEnumerator()
    $c
}

function Get-CoverageReport {
    # make sure this is an array, otherwise the counts start failing
    # on powershell 3
    param ([object[]] $CommandCoverage, $Measure)

    # Measure is null when we used Breakpoints to do code coverage, otherwise it is populated with the measure
    if ($null -ne $Measure) {

        # re-key the measures to use columns that are corrected for BP placement
        # also 1 column in tracer can map to multiple columns for BP, when there are assignments, so expand them
        $bpm = @{}
        foreach ($path in $Measure.Keys) {
            $lines = @{}

            foreach ($line in $Measure[$path].Values) {
                foreach ($point in $line) {
                    $lines.Add("$($point.BpLine):$($point.BpColumn)", $point)
                }
            }

            $bpm.Add($path, $lines)
        }

        # adapting the data to the breakpoint like api we use for breakpoint based CC
        # so the rest of our code just works
        foreach ($i in $CommandCoverage) {
            # Write-Host "CC: $($i.File), $($i.StartLine), $($i.StartColumn)"
            $bp = @{ HitCount = 0 }
            if ($bpm.ContainsKey($i.File)) {
                $f = $bpm[$i.File]
                $key = "$($i.StartLine):$($i.StartColumn)"
                if ($f.ContainsKey($key)) {
                    $h = $f[$key]
                    $bp.HitCount = [int] $h.Hit
                }
            }

            $i.Breakpoint = $bp
        }
    }

    $properties = @(
        'File'
        @{ Name = 'Line'; Expression = { $_.StartLine } }
        'StartLine'
        'EndLine'
        'StartColumn'
        'EndColumn'
        'Class'
        'Function'
        'Command'
        @{ Name = 'HitCount'; Expression = { $_.Breakpoint.HitCount } }
    )

    $missedCommands = @(Get-CoverageMissedCommands -CommandCoverage @($CommandCoverage) | & $SafeCommands['Select-Object'] $properties)
    $hitCommands = @(Get-CoverageHitCommands -CommandCoverage @($CommandCoverage) | & $SafeCommands['Select-Object'] $properties)
    $analyzedFiles = @(@($CommandCoverage) | & $SafeCommands['Select-Object'] -ExpandProperty File -Unique)


    [pscustomobject] @{
        NumberOfCommandsAnalyzed = $CommandCoverage.Count
        NumberOfFilesAnalyzed    = $analyzedFiles.Count
        NumberOfCommandsExecuted = $hitCommands.Count
        NumberOfCommandsMissed   = $missedCommands.Count
        MissedCommands           = $missedCommands
        HitCommands              = $hitCommands
        AnalyzedFiles            = $analyzedFiles
        CoveragePercent          = if ($null -eq $CommandCoverage -or $CommandCoverage.Count -eq 0) { 0 } else { ($hitCommands.Count / $CommandCoverage.Count) * 100 }
    }
}

function Get-CommonParentPath {
    param ([string[]] $Path)

    if ("CoverageGutters" -eq $PesterPreference.CodeCoverage.OutputFormat.Value) {
        # for coverage gutters the root path is relative to the coverage.xml
        $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($PesterPreference.CodeCoverage.OutputPath.Value)
        return (& $SafeCommands['Split-Path'] -Path $fullPath | Normalize-Path )
    }

    $pathsToTest = @(
        $Path |
            Normalize-Path |
            & $SafeCommands['Select-Object'] -Unique
    )

    if ($pathsToTest.Count -gt 0) {
        $parentPath = & $SafeCommands['Split-Path'] -Path $pathsToTest[0] -Parent

        while ($parentPath.Length -gt 0) {
            $nonMatches = $pathsToTest -notmatch "^$([regex]::Escape($parentPath))"

            if ($nonMatches.Count -eq 0) {
                return $parentPath
            }
            else {
                $parentPath = & $SafeCommands['Split-Path'] -Path $parentPath -Parent
            }
        }
    }

    return [string]::Empty
}

function Get-RelativePath {
    param ( [string] $Path, [string] $RelativeTo )
    return $Path -replace "^$([regex]::Escape("$RelativeTo$([System.IO.Path]::DirectorySeparatorChar)"))?"
}

function Normalize-Path {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('PSPath', 'FullName')]
        [string[]] $Path
    )

    # Split-Path and Join-Path will replace any AltDirectorySeparatorChar instances with the DirectorySeparatorChar
    # (Even if it's not the one that the split / join happens on.)  So splitting / rejoining a path will give us
    # consistent separators for later string comparison.

    process {
        if ($null -ne $Path) {
            foreach ($p in $Path) {
                $normalizedPath = & $SafeCommands['Split-Path'] $p -Leaf

                if ($normalizedPath -ne $p) {
                    $parent = & $SafeCommands['Split-Path'] $p -Parent
                    $normalizedPath = & $SafeCommands['Join-Path'] $parent $normalizedPath
                }

                $normalizedPath
            }
        }
    }
}

function Get-JaCoCoReportXml {
    param (
        [parameter(Mandatory = $true)]
        $CommandCoverage,
        [parameter(Mandatory = $true)]
        [object] $CoverageReport,
        [parameter(Mandatory = $true)]
        [long] $TotalMilliseconds,
        [string] $Format
    )

    $isGutters = "CoverageGutters" -eq $Format

    if ($null -eq $CoverageReport -or $CoverageReport.NumberOfCommandsAnalyzed -eq 0) {
        return [string]::Empty
    }

    # Report uses unix epoch time format (milliseconds since midnight 1/1/1970 UTC)
    [long] $endTime = [System.DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    [long] $startTime = [math]::Floor($endTime - $TotalMilliseconds)

    $folderGroups = $CommandCoverage | & $SafeCommands["Group-Object"] -Property {
        & $SafeCommands["Split-Path"] $_.File -Parent
    }

    $packageList = [System.Collections.Generic.List[psobject]]@()

    $report = @{
        Instruction = @{ Missed = 0; Covered = 0 }
        Line        = @{ Missed = 0; Covered = 0 }
        Method      = @{ Missed = 0; Covered = 0 }
        Class       = @{ Missed = 0; Covered = 0 }
    }

    foreach ($folderGroup in $folderGroups) {

        $package = @{
            Name        = $folderGroup.Name
            Classes     = [ordered] @{ }
            Instruction = @{ Missed = 0; Covered = 0 }
            Line        = @{ Missed = 0; Covered = 0 }
            Method      = @{ Missed = 0; Covered = 0 }
            Class       = @{ Missed = 0; Covered = 0 }
        }

        foreach ($command in $folderGroup.Group) {
            $file = $command.File
            $function = $command.Function
            if (!$function) { $function = '<script>' }
            $line = $command.StartLine.ToString()

            $missed = if ($command.Breakpoint.HitCount) { 0 } else { 1 }
            $covered = if ($command.Breakpoint.HitCount) { 1 } else { 0 }

            if (!$package.Classes.Contains($file)) {
                $package.Class.Missed += $missed
                $package.Class.Covered += $covered
                $package.Classes.$file = @{
                    Methods     = [ordered] @{ }
                    Lines       = [ordered] @{ }
                    Instruction = @{ Missed = 0; Covered = 0 }
                    Line        = @{ Missed = 0; Covered = 0 }
                    Method      = @{ Missed = 0; Covered = 0 }
                    Class       = @{ Missed = $missed; Covered = $covered }
                }
            }

            if (!$package.Classes.$file.Methods.Contains($function)) {
                $package.Method.Missed += $missed
                $package.Method.Covered += $covered
                $package.Classes.$file.Method.Missed += $missed
                $package.Classes.$file.Method.Covered += $covered
                $package.Classes.$file.Methods.$function = @{
                    FirstLine   = $line
                    Instruction = @{ Missed = 0; Covered = 0 }
                    Line        = @{ Missed = 0; Covered = 0 }
                    Method      = @{ Missed = $missed; Covered = $covered }
                }
            }

            if (!$package.Classes.$file.Lines.Contains($line)) {
                $package.Line.Missed += $missed
                $package.Line.Covered += $covered
                $package.Classes.$file.Line.Missed += $missed
                $package.Classes.$file.Line.Covered += $covered
                $package.Classes.$file.Methods.$function.Line.Missed += $missed
                $package.Classes.$file.Methods.$function.Line.Covered += $covered
                $package.Classes.$file.Lines.$line = @{
                    Instruction = @{ Missed = 0; Covered = 0 }
                }
            }

            $package.Instruction.Missed += $missed
            $package.Instruction.Covered += $covered
            $package.Classes.$file.Instruction.Missed += $missed
            $package.Classes.$file.Instruction.Covered += $covered
            $package.Classes.$file.Methods.$function.Instruction.Missed += $missed
            $package.Classes.$file.Methods.$function.Instruction.Covered += $covered
            $package.Classes.$file.Lines.$line.Instruction.Missed += $missed
            $package.Classes.$file.Lines.$line.Instruction.Covered += $covered
        }

        $report.Class.Missed += $package.Class.Missed
        $report.Class.Covered += $package.Class.Covered
        $report.Method.Missed += $package.Method.Missed
        $report.Method.Covered += $package.Method.Covered
        $report.Line.Missed += $package.Line.Missed
        $report.Line.Covered += $package.Line.Covered
        $report.Instruction.Missed += $package.Instruction.Missed
        $report.Instruction.Covered += $package.Instruction.Covered

        $packageList.Add($package)
    }

    $commonParent = Get-CommonParentPath -Path $CoverageReport.AnalyzedFiles
    $commonParentLeaf = & $SafeCommands["Split-Path"] $commonParent -Leaf

    # the JaCoCo xml format without the doctype, as the XML stuff does not like DTD's.
    $jaCoCoReport = '<?xml version="1.0" encoding="UTF-8" standalone="no"?>'
    $jaCoCoReport += '<report name="">'
    $jaCoCoReport += '<sessioninfo id="this" start="" dump="" />'
    $jaCoCoReport += '</report>'

    [xml] $jaCoCoReportXml = $jaCoCoReport
    $reportElement = $jaCoCoReportXml.report
    $reportElement.name = "Pester ($now)"
    $reportElement.sessioninfo.start = $startTime.ToString()
    $reportElement.sessioninfo.dump = $endTime.ToString()

    foreach ($package in $packageList) {
        $packageRelativePath = Get-RelativePath -Path $package.Name -RelativeTo $commonParent

        # e.g. "." for gutters, and "package" for non gutters in root
        # and "sub-dir" for gutters, and "package/sub-dir" for non-gutters
        $packageName = if ($null -eq $packageRelativePath -or "" -eq $packageRelativePath) {
            if ($isGutters) {
                "."
            }
            else {
                $commonParentLeaf
            }
        }
        else {
            $packageRelativePathFormatted = $packageRelativePath.Replace("\", "/")
            if ($isGutters) {
                $packageRelativePathFormatted
            }
            else {
                "$commonParentLeaf/$packageRelativePathFormatted"
            }
        }

        $packageElement = Add-XmlElement -Parent $reportElement -Name 'package' -Attributes @{
            name = ($packageName -replace "/$", "")
        }

        foreach ($file in $package.Classes.Keys) {
            $class = $package.Classes.$file
            $classElementRelativePath = (Get-RelativePath -Path $file -RelativeTo $commonParent).Replace("\", "/")
            $classElementName = if ($isGutters) {
                $classElementRelativePath
            }
            else {
                "$commonParentLeaf/$classElementRelativePath"
            }
            $classElementName = $classElementName.Substring(0, $($classElementName.LastIndexOf(".")))
            $classElement = Add-XmlElement -Parent $packageElement -Name 'class' -Attributes ([ordered] @{
                    name           = $classElementName
                    sourcefilename = if ($isGutters) {
                        & $SafeCommands["Split-Path"] $classElementRelativePath -Leaf
                    }
                    else {
                        $classElementRelativePath
                    }
                })

            foreach ($function in $class.Methods.Keys) {
                $method = $class.Methods.$function
                $methodElement = Add-XmlElement -Parent $classElement -Name 'method' -Attributes ([ordered] @{
                        name = $function
                        desc = '()'
                        line = $method.FirstLine
                    })
                Add-JaCoCoCounter -Type 'Instruction' -Data $method -Parent $methodElement
                Add-JaCoCoCounter -Type 'Line' -Data $method -Parent $methodElement
                Add-JaCoCoCounter -Type 'Method' -Data $method -Parent $methodElement
            }

            Add-JaCoCoCounter -Type 'Instruction' -Data $class -Parent $classElement
            Add-JaCoCoCounter -Type 'Line' -Data $class -Parent $classElement
            Add-JaCoCoCounter -Type 'Method' -Data $class -Parent $classElement
            Add-JaCoCoCounter -Type 'Class' -Data $class -Parent $classElement
        }

        foreach ($file in $package.Classes.Keys) {
            $class = $package.Classes.$file
            $classElementRelativePath = (Get-RelativePath -Path $file -RelativeTo $commonParent).Replace("\", "/")
            $sourceFileElement = Add-XmlElement -Parent $packageElement -Name 'sourcefile' -Attributes ([ordered] @{
                    name = if ($isGutters) {
                        & $SafeCommands["Split-Path"] $classElementRelativePath -Leaf
                    }
                    else {
                        $classElementRelativePath
                    }
                })

            foreach ($line in $class.Lines.Keys) {
                $null = Add-XmlElement -Parent $sourceFileElement -Name 'line' -Attributes ([ordered] @{
                        nr = $line
                        mi = $class.Lines.$line.Instruction.Missed
                        ci = $class.Lines.$line.Instruction.Covered
                        mb = 0
                        cb = 0
                    })
            }

            Add-JaCoCoCounter -Type 'Instruction' -Data $class -Parent $sourceFileElement
            Add-JaCoCoCounter -Type 'Line' -Data $class -Parent $sourceFileElement
            Add-JaCoCoCounter -Type 'Method' -Data $class -Parent $sourceFileElement
            Add-JaCoCoCounter -Type 'Class' -Data $class -Parent $sourceFileElement
        }

        Add-JaCoCoCounter -Type 'Instruction' -Data $package -Parent $packageElement
        Add-JaCoCoCounter -Type 'Line' -Data $package -Parent $packageElement
        Add-JaCoCoCounter -Type 'Method' -Data $package -Parent $packageElement
        Add-JaCoCoCounter -Type 'Class' -Data $package -Parent $packageElement
    }

    Add-JaCoCoCounter -Type 'Instruction' -Data $report -Parent $reportElement
    Add-JaCoCoCounter -Type 'Line' -Data $report -Parent $reportElement
    Add-JaCoCoCounter -Type 'Method' -Data $report -Parent $reportElement
    Add-JaCoCoCounter -Type 'Class' -Data $report -Parent $reportElement

    # There is no pretty way to insert the Doctype, as microsoft has deprecated the DTD stuff.
    $jaCoCoReportDocType = '<!DOCTYPE report PUBLIC "-//JACOCO//DTD Report 1.1//EN" "report.dtd">'
    $xml = $jaCocoReportXml.OuterXml.Insert(54, $jaCoCoReportDocType)

    return $xml
}

function Get-CoberturaReportXml {
    param (
        [parameter(Mandatory = $true)]
        [object] $CoverageReport,
        [parameter(Mandatory = $true)]
        [long] $TotalMilliseconds
    )

    if ($null -eq $CoverageReport -or $CoverageReport.NumberOfCommandsAnalyzed -eq 0) {
        return [string]::Empty
    }

    # Report uses unix epoch time format (milliseconds since midnight 1/1/1970 UTC)
    [long] $endTime = [System.DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    [long] $startTime = [math]::Floor($endTime - $TotalMilliseconds)

    $commonRoot = Get-CommonParentPath -Path $CoverageReport.AnalyzedFiles

    $allLines = [System.Collections.Generic.List[object]]@()
    $allLines.AddRange($CoverageReport.MissedCommands)
    $allLines.AddRange($CoverageReport.HitCommands)
    $packages = @{}
    foreach ($command in $allLines) {
        $package = & $SafeCommands["Split-Path"] $command.File -Parent
        if (!$packages[$package]) {
            $packages[$package] = @{
                Classes = @{}
            }
        }

        $class = $command.File
        if (!$packages[$package].Classes[$class]) {
            $packages[$package].Classes[$class] = @{
                Methods = @{}
                Lines   = @{}
            }
        }

        if (!$packages[$package].Classes[$class].Lines[$command.Line]) {
            $packages[$package].Classes[$class].Lines[$command.Line] = [ordered]@{ number = $command.Line ; hits = 0 }
        }
        $packages[$package].Classes[$class].Lines[$command.Line].hits += $command.HitCount

        $method = $command.Function
        if (!$method) {
            continue
        }

        if (!$packages[$package].Classes[$class].Methods[$method]) {
            $packages[$package].Classes[$class].Methods[$method] = @{}
        }

        if (!$packages[$package].Classes[$class].Methods[$method][$command.Line]) {
            $packages[$package].Classes[$class].Methods[$method][$command.Line] = [ordered]@{ number = $command.Line ; hits = 0 }
        }
        $packages[$package].Classes[$class].Methods[$method][$command.Line].hits += $command.HitCount
    }

    $packages = foreach ($packageGroup in $packages.GetEnumerator()) {
        $classGroups = $packageGroup.Value.Classes
        $classes = foreach ($classGroup in $classGroups.GetEnumerator()) {
            $methodGroups = $classGroup.Value.Methods
            $methods = foreach ($methodGroup in $methodGroups.GetEnumerator()) {
                $lines = ([object[]]$methodGroup.Value.Values) | New-LineNode
                $coveredLines = foreach ($line in $lines) { if (0 -lt $line.attributes.hits) { $line } }

                $method = [ordered]@{
                    name         = 'method'
                    attributes   = [ordered]@{
                        name      = $methodGroup.Name
                        signature = '()'
                    }
                    children     = [ordered]@{
                        lines = $lines | & $SafeCommands["Sort-Object"] { [int]$_.attributes.number }
                    }
                    totalLines   = $lines.Length
                    coveredLines = $coveredLines.Length
                }

                $method
            }

            $lines = ([object[]]$classGroup.Value.Lines.Values) | New-LineNode
            $coveredLines = foreach ($line in $lines) { if (0 -lt $line.attributes.hits) { $line } }

            $lineRate = Get-LineRate -CoveredLines $coveredLines.Length -TotalLines $lines.Length
            $filename = $classGroup.Name.Substring($commonRoot.Length).Replace('\', '/').TrimStart('/')

            $class = [ordered]@{
                name         = 'class'
                attributes   = [ordered]@{
                    name          = (& $SafeCommands["Split-Path"] $classGroup.Name -Leaf)
                    filename      = $filename
                    'line-rate'   = $lineRate
                    'branch-rate' = 1
                }
                children     = [ordered]@{
                    methods = $methods | & $SafeCommands["Sort-Object"] { $_.attributes.name }
                    lines   = $lines | & $SafeCommands["Sort-Object"] { [int]$_.attributes.number }
                }
                totalLines   = $lines.Length
                coveredLines = $coveredLines.Length
            }

            $class
        }

        $totalLines = ($classes.totalLines | & $SafeCommands["Measure-Object"] -Sum).Sum
        $coveredLines = ($classes.coveredLines | & $SafeCommands["Measure-Object"] -Sum).Sum
        $lineRate = Get-LineRate -CoveredLines $coveredLines -TotalLines $totalLines
        $packageName = $packageGroup.Name.Substring($commonRoot.Length).Replace('\', '/').TrimStart('/')

        $package = [ordered]@{
            name         = 'package'
            attributes   = [ordered]@{
                name          = $packageName
                'line-rate'   = $lineRate
                'branch-rate' = 0
            }
            children     = [ordered]@{
                classes = $classes | & $SafeCommands["Sort-Object"] { $_.attributes.name }
            }
            totalLines   = $totalLines
            coveredLines = $coveredLines
        }

        $package
    }

    $totalLines = ($packages.totalLines | & $SafeCommands["Measure-Object"] -Sum).Sum
    $coveredLines = ($packages.coveredLines | & $SafeCommands["Measure-Object"] -Sum).Sum
    $lineRate = Get-LineRate -CoveredLines $coveredLines -TotalLines $totalLines

    $coverage = [ordered]@{
        name       = 'coverage'
        attributes = [ordered]@{
            'lines-valid'      = $totalLines
            'lines-covered'    = $coveredLines
            'line-rate'        = $lineRate
            'branches-valid'   = 0
            'branches-covered' = 0
            'branch-rate'      = 1
            timestamp          = $startTime
            version            = 0.1
        }
        children   = [ordered]@{
            sources  = [ordered]@{
                name  = 'source'
                value = $commonRoot.Replace('\', '/')
            }
            packages = $packages | & $SafeCommands["Sort-Object"] { $_.attributes.name }
        }
    }

    $xmlDeclaration = '<?xml version="1.0" ?>'
    $docType = '<!DOCTYPE coverage SYSTEM "coverage-loose.dtd">'
    $coverageXml = ConvertTo-XmlElement -Node $coverage
    $document = "$xmlDeclaration`n$docType`n$($coverageXml.OuterXml)"

    $document
}

function New-LineNode {
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)] [object] $LineObject
    )

    process {
        [ordered]@{
            name       = 'line'
            attributes = $LineObject
        }
    }
}

function Get-LineRate {
    param(
        [parameter(Mandatory = $true)] [int] $CoveredLines,
        [parameter(Mandatory = $true)] [int] $TotalLines
    )

    [double]$denominator = if ($TotalLines) { $TotalLines } else { 1 }

    $CoveredLines / $denominator
}

function ConvertTo-XmlElement {
    param(
        [parameter(Mandatory = $true)] [object] $Node
    )

    $element = ([xml]"<$($Node.name)/>").DocumentElement
    if ($node.attributes) {
        $attributes = $node.attributes
        foreach ($attr in $attributes.GetEnumerator()) {
            $element.SetAttribute($attr.Name, $attr.Value)
        }
    }
    if ($node.children) {
        $children = $node.children
        foreach ($child in $children.GetEnumerator()) {
            $childElement = ([xml]"<$($child.Name)/>").DocumentElement
            foreach ($value in $child.Value) {
                $childXml = ConvertTo-XmlElement $value
                $importedChildXml = $childElement.OwnerDocument.ImportNode($childXml, $true)
                $null = $childElement.AppendChild($importedChildXml)
            }
            $importedChild = $element.OwnerDocument.ImportNode($childElement, $true)
            $null = $element.AppendChild($importedChild)
        }
    }
    if ($node.value) {
        $element.InnerText = $node.value
    }

    $element
}

function Add-XmlElement {
    param (
        [parameter(Mandatory = $true)] [System.Xml.XmlNode] $Parent,
        [parameter(Mandatory = $true)] [string] $Name,
        [System.Collections.IDictionary] $Attributes
    )
    $element = $Parent.AppendChild($Parent.OwnerDocument.CreateElement($Name))
    if ($Attributes) {
        Add-XmlAttribute -Element $element -Attributes $Attributes
    }
    return $element
}

function Add-XmlAttribute {
    param(
        [parameter(Mandatory = $true)] [System.Xml.XmlNode] $Element,
        [parameter(Mandatory = $true)] [System.Collections.IDictionary] $Attributes
    )

    foreach ($key in $Attributes.Keys) {
        $attribute = $Element.Attributes.Append($Element.OwnerDocument.CreateAttribute($key))
        $attribute.Value = $Attributes.$key
    }
}

function Add-JaCoCoCounter {
    param (
        [parameter(Mandatory = $true)] [ValidateSet('Instruction', 'Line', 'Method', 'Class')] [string] $Type,
        [parameter(Mandatory = $true)] [System.Collections.IDictionary] $Data,
        [parameter(Mandatory = $true)] [System.Xml.XmlNode] $Parent
    )
    if ($Data.$Type.Missed -isnot [int] -or $Data.$Type.Covered -isnot [int]) {
        throw 'Counter data expected'
    }
    $null = Add-XmlElement -Parent $Parent -Name 'counter' -Attributes ([ordered] @{
            type    = $Type.ToUpperInvariant()
            missed  = $Data.$Type.Missed
            covered = $Data.$Type.Covered
        })
}

function Start-TraceScript ($Breakpoints) {

    $points = [Collections.Generic.List[Pester.Tracing.CodeCoveragePoint]]@()
    foreach ($breakpoint in $breakpoints) {
        $location = $breakpoint.BreakpointLocation

        $hitColumn = $location.Column
        $hitLine = $location.Line

        # breakpoints for some actions bind to different column than the hits, we need to adjust them
        # for example when code contains hashtable we need to translate it,
        # because we are reporting the place where BP would bind, but from the tracer we are getting the whole hashtable
        # this often changes not only the column but also the line where we record the hit, so there can be many
        # points pointed at the same location
        $parent = Get-TracerHitLocation $breakpoint.Ast

        if ($parent -is [System.Management.Automation.Language.ReturnStatementAst]) {
            $hitLine = $parent.Extent.StartLineNumber
            $hitColumn = $parent.Extent.StartColumnNumber + 7 # offset by the length of 'return '
        }
        else {
            $hitLine = $parent.Extent.StartLineNumber
            $hitColumn = $parent.Extent.StartColumnNumber
        }

        $points.Add([Pester.Tracing.CodeCoveragePoint]::Create($location.Script, $hitLine, $hitColumn, $location.Line, $location.Column, $breakpoint.Command))
    }

    $tracer = [Pester.Tracing.CodeCoverageTracer]::Create($points)

    # detect if profiler is imported and running and in that case just add us as a second tracer
    # to not disturb the profiling session
    $profilerType = "Profiler.Tracer" -as [Type]
    $registered = $false
    $patched = $false

    if ($null -ne $profilerType) {
        # api changed in 4.0.0
        $version = [Version] (& $SafeCommands['Get-Item'] $profilerType.Assembly.Location).VersionInfo.FileVersion
        if (($version -lt "4.0.0" -and $profilerType::IsEnabled) -or ($version -ge "4.0.0" -and $profilerType::ShouldRegisterTracer($tracer, $true))) {
            $patched = $false
            $registered = $true
            $profilerType::Register($tracer)
        }
    }

    if (-not $registered) {

        # detect if code coverage is enabled throuh Pester tracer, and in that case just add us as a second tracer
        if (1 -eq $env:PESTER_CC_IN_CC -and [Pester.Tracing.Tracer]::ShouldRegisterTracer($tracer, <# overwrite: #> $false)) {
            $patched = $false
            $registered = $true
            [Pester.Tracing.Tracer]::Register($tracer)
        }
        else {
            $patched = $true
            [Pester.Tracing.Tracer]::Patch($PSVersionTable.PSVersion.Major, $ExecutionContext, $host.UI, $tracer)
            Set-PSDebug -Trace 1
        }
    }

    # true if we patched powershell and have to unpatch it later,
    # false if we just registered to already running profiling session and just need to unregister ourselves
    $patched, $tracer
}

function Stop-TraceScript {
    param ([bool] $Patched)

    # if we patched powershell we need to unpatch it, if we did not patch it, then we need to unregister ourselves because we are the second tracer.
    if ($Patched) {
        $corruptionAutodetectionVariable = Set-PSDebug -Trace 0
        [Pester.Tracing.Tracer]::Unpatch()
    }
    else {
        # Stop tracing so we don't record Unregister
        $corruptionAutodetectionVariable = Set-PSDebug -Trace 0
        # This variable name is used to detect if the tracer was broken, we cannot use comments because they are not part of the ast Extent.Text
        # Assigning it here to null, because otherwise it gives warning about not being used.
        $null = $corruptionAutodetectionVariable
        # detect if profiler is imported, if yes, unregister us from Profiler (because we are profiling Pester)
        $profilerType = "Profiler.Tracer" -as [Type]
        if ($null -ne $profilerType) {
            $profilerType::Unregister()
        }
        elseif (1 -eq $env:PESTER_CC_IN_CC) {
            # we are not profiling we are running code coverage in code coverage
            [Pester.Tracing.Tracer]::Unregister()
        }
        # start tracing again so the other tracer can continue
        Set-PSDebug -Trace 1
    }
}

function Get-TracerHitLocation ($command) {

    if (-not $env:PESTER_CC_DEBUG) {
        function Write-Host { }
    }
    # function Write-Host { }
    function Show-ParentList ($command) {
        $c = $command
        "`n`nCommand: $c" | Write-Host
        $(for ($ast = $c; $null -ne $ast; $ast = $ast.Parent) {
                $ast | Select-Object @{n = 'type'; e = { $_.GetType().Name } } , @{n = 'extent'; e = { $_.extent } }
            } ) | Format-Table type, extent | Out-String | Write-Host
    }

    if ($env:PESTER_CC_DEBUG -eq 1) {
        Write-Host "Processing '$command' at $($command.Extent.StartLineNumber):$($command.Extent.StartColumnNumber) which is $($command.GetType().Name)."
    }

    #    Show-ParentList $command
    $parent = $command
    $last = $parent
    while ($true) {

        # take
        if ($parent -is [System.Management.Automation.Language.CommandAst]) {
            # using pipeline ast for command correctly identifies it's pipeline location so we get foreach-object and similar commands
            # correctly in actual pipeline. We keep this as the $last. This will "incorrectly" hoist commands to their containing arrays
            # or hashtable even though we see them as separate in the tracer. This is okay, because the command would be invoked anyway
            # and we don't have to work hard to figure out if command is just standalone (e.g Get-Command in a pipeline), or part of pipeline
            # e.g. @(10) | ForEach-Object { "b" } where ForEach-Object will bind to the whole pipeline expression.
            $last = $parent.Parent
        }
        elseif ($parent -isnot [System.Management.Automation.Language.CommandExpressionAst] -or $parent.Expression -isnot [System.Management.Automation.Language.ConstantExpressionAst]) {
            # the current item is not a constant expression make it the new $last
            $last = $parent

        }

        if ($null -eq $parent) {
            # parent is null, we reached the end, use the last identified item as the hit location
            break
        }

        # we now know that we have a parent move one level up to look at it to see if we should search further, or we are child of a termination point (like if, or scriptblock)
        $parent = $parent.Parent

        # skip to avoid using the pipeline ast as the $last to not break if block statements, because we would get the whole { } instead of just the actual command
        # e.g. in if ($true) { "yes" } else { "no" } we would incorrectly get { "yes" } instead of just "yes"
        while ($parent -is [System.Management.Automation.Language.PipelineAst] -or $parent -is [System.Management.Automation.Language.NamedBlockAst] -or $parent -is [System.Management.Automation.Language.StatementBlockAst]) {
            $parent = $parent.Parent
        }

        # terminate when we find and if of scriptblock, those will always show up in the tracer if they are executed so they are are good termination point.
        # when a hitpoint is found, the $last is marked as hit point.
        # we also must avoid selecting a parent that is too high, otherwise we might mark code that was not covered as covered.
        if ($parent -is [System.Management.Automation.Language.IfStatementAst] -or
            $parent -is [System.Management.Automation.Language.ScriptBlockAst] -or
            $parent -is [System.Management.Automation.Language.LoopStatementAst] -or
            $parent -is [System.Management.Automation.Language.SwitchStatementAst] -or
            $parent -is [System.Management.Automation.Language.TryStatementAst] -or
            $parent -is [System.Management.Automation.Language.CatchClauseAst]) {

            if ($last -is [System.Management.Automation.Language.ParamBlockAst]) {
                # param block will not indicate that any of the default values in it executed,
                # and the block itself is not reported by the tracer. So we will land here with the parame block as the $last
                # and we need to take the containing scriptblock (be it actual scriptblock, or a function definition), which is the parent
                # of this param block.
                $last = $parent
            }

            break
        }
    }
    if ($env:PESTER_CC_DEBUG -eq 1) {
        Write-Host "It became: '$last' at $($last.Extent.StartLineNumber):$($last.Extent.StartColumnNumber) which is $($last.GetType().Name)."
    }
    return $last
}
