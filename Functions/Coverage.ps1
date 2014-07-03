if ($PSVersionTable.PSVersion.Major -le 2)
{
    function Enter-CoverageAnalysis { Write-Error 'Code coverage analysis requires PowerShell 3.0 or later.' }
    function Exit-CoverageAnalysis { }
    function Show-CoverageReport { }

    return
}

function Enter-CoverageAnalysis
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [object[]]
        $InputObject
    )

    begin
    {
        $Pester.CommandCoverage = @()
    }

    process
    {
        $Pester.CommandCoverage += @(
            foreach ($object in $InputObject)
            {
                $coverageInfo = Get-CoverageInfoFromUserInput -InputObject $object
                if ($null -ne $coverageInfo)
                {
                    Get-CoverageBreakpoints -CoverageInfo $coverageInfo
                }
            }
        )
    }
}

function Exit-CoverageAnalysis
{
    Set-StrictMode -Off

    $breakpoints = @($pester.CommandCoverage.Breakpoint) -ne $null
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

    $resolvedPaths |
    Where-Object { $_.Provider.Name -ne 'FileSystem' } |
    ForEach-Object {
        Write-Error "Coverage path '$path' resolved to non-FileSystem path '$($_.Path)'; skipping this path."
    }
    
    $params = @{
        StartLine = $UnresolvedCoverageInfo.StartLine
        EndLine = $UnresolvedCoverageInfo.EndLine
        Function = $UnresolvedCoverageInfo.Function
    }

    $fileSystemPaths = $resolvedPaths | Where-Object { $_.Provider.Name -eq 'FileSystem' }
    foreach ($fileSystemPath in $fileSystemPaths)
    {
        $params['Path'] = $fileSystemPath
        New-CoverageInfo @params
    }
}

function Get-CoverageBreakpoints
{
    param ([object[]] $CoverageInfo)
    
    foreach ($coverageInfoObject in $CoverageInfo)
    {
        $filePath = $coverageInfoObject.Path

        $errors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref] $tokens, [ref] $errors)
        
        $predicate = { $args[0] -is [System.Management.Automation.Language.CommandBaseAst] }
        $searchNestedScriptBlocks = $true
        $commandsInFile = $ast.FindAll($predicate, $searchNestedScriptBlocks)

        foreach ($command in $commandsInFile)
        {
            if (Test-CoverageOverlapsCommand -CoverageInfo $coverageInfoObject -Command $command)
            {
                New-CoverageBreakpoint -Command $command
            }
        }
    }

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

    $params = @{
        Script = $Command.Extent.File
        Line   = $Command.Extent.StartLineNumber
        Column = $Command.Extent.StartColumnNumber
        Action = { }
    }
    $breakpoint = Set-PSBreakpoint @params

    [pscustomobject] @{
        File       = $Command.Extent.File
        Line       = $Command.Extent.StartLineNumber
        Command    = Get-CoverageCommandText -Ast $Command
        Breakpoint = $breakpoint
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

    if ($null -ne $parent -and $reportParentExtentTypes -contains $parent.GetType())
    {
        return $parent.Extent.Text
    }
    else
    {
        return $Ast.Extent.Text
    }
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

function Get-CoverageMissedCommands
{
    $pester.CommandCoverage | Where-Object { $_.Breakpoint.HitCount -eq 0 }
}

function Show-CoverageReport
{
    $totalCommandCount = $pester.CommandCoverage.Count
    if ($totalCommandCount -eq 0) { return }

    $missedCommands = @(Get-CoverageMissedCommands)
    $analyzedFiles = @($pester.CommandCoverage | Select-Object -ExpandProperty File -Unique)
    $fileCount = $analyzedFiles.Count

    $executedCommandCount = $totalCommandCount - $missedCommands.Count
    $executedPercent = ($executedCommandCount / $totalCommandCount).ToString("P2")

    $commandPlural = $filePlural = ''
    if ($totalCommandCount -gt 1) { $commandPlural = 's' }
    if ($fileCount -gt 1) { $filePlural = 's' }

    Write-Host ''
    Write-Host 'Code coverage report:'
    Write-Host "Covered $executedPercent of $totalCommandCount analyzed command$commandPlural in $fileCount file$filePlural."

    if ($missedCommands.Count -gt 0)
    {
        Write-Host ''
        Write-Host 'Missed commands:'
        $missedCommands | Format-Table File, Line, Command -AutoSize | Out-Host
    }
}
