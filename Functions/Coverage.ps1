if ($PSVersionTable.PSVersion.Major -le 2)
{
    function Exit-CoverageAnalysis { }
    function Get-CoverageReport { }
    function Show-CoverageReport { }
    function Enter-CoverageAnalysis {
        param ( $CodeCoverage )

        if ($CodeCoverage) { Write-Error 'Code coverage analysis requires PowerShell 3.0 or later.' }
    }

    return
}

function Enter-CoverageAnalysis
{
    [CmdletBinding()]
    param (
        [object[]] $CodeCoverage,
        [object] $PesterState
    )

    $coverageInfo =
    foreach ($object in $CodeCoverage)
    {
        Get-CoverageInfoFromUserInput -InputObject $object
    }

    $PesterState.CommandCoverage = @(Get-CoverageBreakpoints -CoverageInfo $coverageInfo)
}

function Exit-CoverageAnalysis
{
    param ([object] $PesterState)

    Set-StrictMode -Off

    $breakpoints = @($PesterState.CommandCoverage.Breakpoint) -ne $null
    if ($breakpoints.Count -gt 0)
    {
        Remove-PSBreakpoint -Breakpoint $breakpoints
    }
}

function Get-CoverageInfoFromUserInput
{
    param (
        [Parameter(Mandatory = $true)]
        [object]
        $InputObject
    )

    if ($InputObject -is [System.Collections.IDictionary])
    {
        $unresolvedCoverageInfo = Get-CoverageInfoFromDictionary -Dictionary $InputObject
    }
    else
    {
        $unresolvedCoverageInfo = New-CoverageInfo -Path ([string]$InputObject)
    }

    Resolve-CoverageInfo -UnresolvedCoverageInfo $unresolvedCoverageInfo
}

function New-CoverageInfo
{
    param ([string] $Path, [string] $Function = $null, [int] $StartLine = 0, [int] $EndLine = 0)

    return [pscustomobject]@{
        Path = $Path
        Function = $Function
        StartLine = $StartLine
        EndLine = $EndLine
    }
}

function Get-CoverageInfoFromDictionary
{
    param ([System.Collections.IDictionary] $Dictionary)

    [string] $path = Get-DictionaryValueFromFirstKeyFound -Dictionary $Dictionary -Key 'Path', 'p'
    if ([string]::IsNullOrEmpty($path))
    {
        throw "Coverage value '$Dictionary' is missing required Path key."
    }

    $startLine = Get-DictionaryValueFromFirstKeyFound -Dictionary $Dictionary -Key 'StartLine', 'Start', 's'
    $endLine = Get-DictionaryValueFromFirstKeyFound -Dictionary $Dictionary -Key 'EndLine', 'End', 'e'
    [string] $function = Get-DictionaryValueFromFirstKeyFound -Dictionary $Dictionary -Key 'Function', 'f'

    $startLine = Convert-UnknownValueToInt -Value $startLine -DefaultValue 0
    $endLine = Convert-UnknownValueToInt -Value $endLine -DefaultValue 0

    return New-CoverageInfo -Path $path -StartLine $startLine -EndLine $endLine -Function $function
}

function Get-DictionaryValueFromFirstKeyFound
{
    param ([System.Collections.IDictionary] $Dictionary, [object[]] $Key)

    foreach ($keyToTry in $Key)
    {
        if ($Dictionary.Contains($keyToTry)) { return $Dictionary[$keyToTry] }
    }
}

function Convert-UnknownValueToInt
{
    param ([object] $Value, [int] $DefaultValue = 0)

    try
    {
        return [int] $Value
    }
    catch
    {
        return $DefaultValue
    }
}

function Resolve-CoverageInfo
{
    param ([psobject] $UnresolvedCoverageInfo)

    $path = $UnresolvedCoverageInfo.Path

    try
    {
        $resolvedPaths = Resolve-Path -Path $path -ErrorAction Stop
    }
    catch
    {
        Write-Error "Could not resolve coverage path '$path': $($_.Exception.Message)"
        return
    }

    $filePaths =
    foreach ($resolvedPath in $resolvedPaths)
    {
        $item = Get-Item -LiteralPath $resolvedPath
        if ($item -is [System.IO.FileInfo] -and ('.ps1','.psm1') -contains $item.Extension)
        {
            $item.FullName
        }
        elseif (-not $item.PsIsContainer)
        {
            Write-Warning "CodeCoverage path '$path' resolved to a non-PowerShell file '$($item.FullName)'; this path will not be part of the coverage report."
        }
    }

    $params = @{
        StartLine = $UnresolvedCoverageInfo.StartLine
        EndLine = $UnresolvedCoverageInfo.EndLine
        Function = $UnresolvedCoverageInfo.Function
    }

    foreach ($filePath in $filePaths)
    {
        $params['Path'] = $filePath
        New-CoverageInfo @params
    }
}

function Get-CoverageBreakpoints
{
    [CmdletBinding()]
    param (
        [object[]] $CoverageInfo
    )

    $fileGroups = @($CoverageInfo | Group-Object -Property Path)
    foreach ($fileGroup in $fileGroups)
    {
        Write-Verbose "Initializing code coverage analysis for file '$($fileGroup.Name)'"
        $totalCommands = 0
        $analyzedCommands = 0

        :commandLoop
        foreach ($command in Get-CommandsInFile -Path $fileGroup.Name)
        {
            $totalCommands++

            foreach ($coverageInfoObject in $fileGroup.Group)
            {
                if (Test-CoverageOverlapsCommand -CoverageInfo $coverageInfoObject -Command $command)
                {
                    $analyzedCommands++
                    New-CoverageBreakpoint -Command $command
                    continue commandLoop
                }
            }
        }

        Write-Verbose "Analyzing $analyzedCommands of $totalCommands commands in file '$($fileGroup.Name)' for code coverage"
    }
}

function Get-CommandsInFile
{
    param ([string] $Path)

    $errors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref] $tokens, [ref] $errors)

    if ($PSVersionTable.PSVersion.Major -ge 5)
    {
        # In PowerShell 5.0, dynamic keywords for DSC configurations are represented by the DynamicKeywordStatementAst
        # class.  They still trigger breakpoints, but are not a child class of CommandBaseAst anymore.

        $predicate = {
            $args[0] -is [System.Management.Automation.Language.DynamicKeywordStatementAst] -or
            $args[0] -is [System.Management.Automation.Language.CommandBaseAst]
        }
    }
    else
    {
        $predicate = { $args[0] -is [System.Management.Automation.Language.CommandBaseAst] }
    }

    $searchNestedScriptBlocks = $true
    $ast.FindAll($predicate, $searchNestedScriptBlocks)
}

function Test-CoverageOverlapsCommand
{
    param ([object] $CoverageInfo, [System.Management.Automation.Language.Ast] $Command)

    if ($CoverageInfo.Function)
    {
        Test-CommandInsideFunction -Command $Command -Function $CoverageInfo.Function
    }
    else
    {
        Test-CoverageOverlapsCommandByLineNumber @PSBoundParameters
    }

}

function Test-CommandInsideFunction
{
    param ([System.Management.Automation.Language.Ast] $Command, [string] $Function)

    for ($ast = $Command; $null -ne $ast; $ast = $ast.Parent)
    {
        $functionAst = $ast -as [System.Management.Automation.Language.FunctionDefinitionAst]
        if ($null -ne $functionAst -and $functionAst.Name -like $Function)
        {
            return $true
        }
    }

    return $false
}

function Test-CoverageOverlapsCommandByLineNumber
{
    param ([object] $CoverageInfo, [System.Management.Automation.Language.Ast] $Command)

    $commandStart = $Command.Extent.StartLineNumber
    $commandEnd = $Command.Extent.EndLineNumber
    $coverStart = $CoverageInfo.StartLine
    $coverEnd = $CoverageInfo.EndLine

    # An EndLine value of 0 means to cover the entire rest of the file from StartLine
    # (which may also be 0)
    if ($coverEnd -le 0) { $coverEnd = [int]::MaxValue }

    return (Test-RangeContainsValue -Value $commandStart -Min $coverStart -Max $coverEnd) -or
           (Test-RangeContainsValue -Value $commandEnd -Min $coverStart -Max $coverEnd)
}

function Test-RangeContainsValue
{
    param ([int] $Value, [int] $Min, [int] $Max)
    return $Value -ge $Min -and $Value -le $Max
}

function New-CoverageBreakpoint
{
    param ([System.Management.Automation.Language.Ast] $Command)

    if (IsIgnoredCommand -Command $Command) { return }

    $params = @{
        Script = $Command.Extent.File
        Line   = $Command.Extent.StartLineNumber
        Column = $Command.Extent.StartColumnNumber
        Action = { }
    }

    $breakpoint = Set-PSBreakpoint @params

    [pscustomobject] @{
        File       = $Command.Extent.File
        Function   = Get-ParentFunctionName -Ast $Command
        Line       = $Command.Extent.StartLineNumber
        Command    = Get-CoverageCommandText -Ast $Command
        Breakpoint = $breakpoint
    }
}

function IsIgnoredCommand
{
    param ([System.Management.Automation.Language.Ast] $Command)

    if (-not $Command.Extent.File)
    {
        # This can happen if the script contains "configuration" or any similarly implemented
        # dynamic keyword.  PowerShell modifies the script code and reparses it in memory, leading
        # to AST elements with no File in their Extent.
        return $true
    }

    if ($PSVersionTable.PSVersion.Major -ge 4)
    {
        if ($Command.Extent.Text -eq 'Configuration')
        {
            # More DSC voodoo.  Calls to "configuration" generate breakpoints, but their HitCount
            # stays zero (even though they are executed.)  For now, ignore them, unless we can come
            # up with a better solution.
            return $true
        }

        if (IsChildOfHashtableDynamicKeyword -Command $Command)
        {
            # The lines inside DSC resource declarations don't trigger their breakpooints when executed,
            # just like the "configuration" keyword itself.  I don't know why, at this point, but just like
            # configuration, we'll ignore it so it doesn't clutter up the coverage analysis with useless junk.
            return $true
        }
    }

    if (IsClosingLoopCondition -Command $Command)
    {
        # For some reason, the closing expressions of do/while and do/until loops don't trigger their breakpoints.
        # To avoid useless clutter, we'll ignore those lines as well.
        return $true
    }

    return $false
}

function IsChildOfHashtableDynamicKeyword
{
    param ([System.Management.Automation.Language.Ast] $Command)

    for ($ast = $Command.Parent; $null -ne $ast; $ast = $ast.Parent)
    {
        if ($PSVersionTable.PSVersion.Major -ge 5)
        {
            # The ast behaves differently for DSC resources with version 5+.  There's a new DynamicKeywordStatementAst class,
            # and they no longer are represented by CommandAst objects.

            if ($ast -is [System.Management.Automation.Language.DynamicKeywordStatementAst] -and
                $ast.CommandElements[-1] -is [System.Management.Automation.Language.HashtableAst])
            {
                return $true
            }
        }
        else
        {
            if ($ast -is [System.Management.Automation.Language.CommandAst] -and
                $null -ne $ast.DefiningKeyword -and
                $ast.DefiningKeyword.BodyMode -eq [System.Management.Automation.Language.DynamicKeywordBodyMode]::Hashtable)
            {
                return $true
            }
        }
    }

    return $false
}

function IsClosingLoopCondition
{
    param ([System.Management.Automation.Language.Ast] $Command)

    $ast = $Command

    while ($null -ne $ast.Parent)
    {
        if (($ast.Parent -is [System.Management.Automation.Language.DoWhileStatementAst] -or
            $ast.Parent -is [System.Management.Automation.Language.DoUntilStatementAst]) -and
            $ast.Parent.Condition -eq $ast)
        {
            return $true
        }

        $ast = $ast.Parent
    }

    return $false
}

function Get-ParentFunctionName
{
    param ([System.Management.Automation.Language.Ast] $Ast)

    $parent = $Ast.Parent

    while ($null -ne $parent -and $parent -isnot [System.Management.Automation.Language.FunctionDefinitionAst])
    {
        $parent = $parent.Parent
    }

    if ($null -eq $parent)
    {
        return ''
    }
    else
    {
        return $parent.Name
    }
}

function Get-CoverageCommandText
{
    param ([System.Management.Automation.Language.Ast] $Ast)

    $reportParentExtentTypes = @(
        [System.Management.Automation.Language.ReturnStatementAst]
        [System.Management.Automation.Language.ThrowStatementAst]
        [System.Management.Automation.Language.AssignmentStatementAst]
        [System.Management.Automation.Language.IfStatementAst]
    )

    $parent = Get-ParentNonPipelineAst -Ast $Ast

    if ($null -ne $parent)
    {
        if ($parent -is [System.Management.Automation.Language.HashtableAst])
        {
            return Get-KeyValuePairText -HashtableAst $parent -ChildAst $Ast
        }
        elseif ($reportParentExtentTypes -contains $parent.GetType())
        {
            return $parent.Extent.Text
        }
    }

    return $Ast.Extent.Text
}

function Get-ParentNonPipelineAst
{
    param ([System.Management.Automation.Language.Ast] $Ast)

    $parent = $null
    if ($null -ne $Ast) { $parent = $Ast.Parent }

    while ($parent -is [System.Management.Automation.Language.PipelineAst])
    {
        $parent = $parent.Parent
    }

    return $parent
}

function Get-KeyValuePairText
{
    param (
        [System.Management.Automation.Language.HashtableAst] $HashtableAst,
        [System.Management.Automation.Language.Ast] $ChildAst
    )

    Set-StrictMode -Off

    foreach ($keyValuePair in $HashtableAst.KeyValuePairs)
    {
        if ($keyValuePair.Item2.PipelineElements -contains $ChildAst)
        {
            return '{0} = {1}' -f $keyValuePair.Item1.Extent.Text, $keyValuePair.Item2.Extent.Text
        }
    }

    # This shouldn't happen, but just in case, default to the old output of just the expression.
    return $ChildAst.Extent.Text
}

function Get-CoverageMissedCommands
{
    param ([object[]] $CommandCoverage)
    $CommandCoverage | Where-Object { $_.Breakpoint.HitCount -eq 0 }
}

function Get-CoverageReport
{
    param ([object] $PesterState)

    $totalCommandCount = $PesterState.CommandCoverage.Count

    $missedCommands = @(Get-CoverageMissedCommands -CommandCoverage $PesterState.CommandCoverage | Select-Object File, Line, Function, Command)
    $analyzedFiles = @($PesterState.CommandCoverage | Select-Object -ExpandProperty File -Unique)
    $fileCount = $analyzedFiles.Count

    $executedCommandCount = $totalCommandCount - $missedCommands.Count

    [pscustomobject] @{
        NumberOfCommandsAnalyzed = $totalCommandCount
        NumberOfFilesAnalyzed    = $fileCount
        NumberOfCommandsExecuted = $executedCommandCount
        NumberOfCommandsMissed   = $missedCommands.Count
        MissedCommands           = $missedCommands
        AnalyzedFiles            = $analyzedFiles
    }
}

function Show-CoverageReport
{
    param ([object] $CoverageReport)

    if ($null -eq $CoverageReport -or $CoverageReport.NumberOfCommandsAnalyzed -eq 0)
    {
        return
    }

    $totalCommandCount = $CoverageReport.NumberOfCommandsAnalyzed
    $fileCount = $CoverageReport.NumberOfFilesAnalyzed
    $executedPercent = ($CoverageReport.NumberOfCommandsExecuted / $CoverageReport.NumberOfCommandsAnalyzed).ToString("P2")

    $commandPlural = $filePlural = ''
    if ($totalCommandCount -gt 1) { $commandPlural = 's' }
    if ($fileCount -gt 1) { $filePlural = 's' }

    $commonParent = Get-CommonParentPath -Path $CoverageReport.AnalyzedFiles
    $report = $CoverageReport.MissedCommands | Select-Object -Property @(
        @{ Name = 'File'; Expression = { Get-RelativePath -Path $_.File -RelativeTo $commonParent } }
        'Function'
        'Line'
        'Command'
    )

    Write-Screen ''
    Write-Screen 'Code coverage report:'
    Write-Screen "Covered $executedPercent of $totalCommandCount analyzed command$commandPlural in $fileCount file$filePlural."

    if ($CoverageReport.MissedCommands.Count -gt 0)
    {
        Write-Screen ''
        Write-Screen 'Missed commands:'
        $report | Format-Table -AutoSize | Out-String | Write-Screen
    }
}

function Get-CommonParentPath
{
    param ([string[]] $Path)

    $pathsToTest = @( $Path | Select-Object -Unique )

    if ($pathsToTest.Count -gt 0)
    {
        $parentPath = Split-Path -Path $pathsToTest[0] -Parent

        while ($parentPath.Length -gt 0)
        {
            $nonMatches = $pathsToTest -notmatch "^$([regex]::Escape($parentPath))"

            if ($nonMatches.Count -eq 0)
            {
                return $parentPath
            }
            else
            {
                $parentPath = Split-Path -Path $parentPath -Parent
            }
        }
    }

    return [string]::Empty
}

function Get-RelativePath
{
    param ( [string] $Path, [string] $RelativeTo )
    return $Path -replace "^$([regex]::Escape($RelativeTo))\\?"
}
