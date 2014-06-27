if ($PSVersionTable.PSVersion.Major -le 2)
{
    function Enter-CoverageAnalysis { Write-Error 'Code coverage analysis requires PowerShell 3.0 or later.' }
    function Exit-CoverageAnalysis { }
    function Show-CoverageReport { }
    function Get-CoverageMissedCommands { }

    return
}

function Enter-CoverageAnalysis
{
    [CmdletBinding()]
    param (
        [string[]] $Path = @()
    )

    $Pester.CommandCoverage = @(
        foreach ($filePath in $Path)
        {
            $filePath = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($filePath)
            if (-not (Test-Path -LiteralPath $filePath -PathType Leaf))
            {
                Write-Error "Coverage file '$filePath' does not exist."
                continue
            }

            $errors = $null
            $tokens = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref] $tokens, [ref] $errors)
        
            $predicate = { $args[0] -is [System.Management.Automation.Language.CommandBaseAst] }
            $searchNestedScriptBlocks = $true
            $commandsInFile = $ast.FindAll($predicate, $searchNestedScriptBlocks)

            foreach ($command in $commandsInFile)
            {
                $params = @{
                    Script = $command.Extent.File
                    Line   = $command.Extent.StartLineNumber
                    Column = $command.Extent.StartColumnNumber
                    Action = { }
                }
                $breakpoint = Set-PSBreakpoint @params

                [pscustomobject] @{
                    File       = $command.Extent.File
                    Line       = $command.Extent.StartLineNumber
                    Command    = Get-CoverageCommandText -Ast $command
                    Breakpoint = $breakpoint
                }
            }
        }
    )
}

function Get-CoverageCommandText
{
    param ([System.Management.Automation.Language.Ast] $Ast)

    $reportParentExtentTypes = @(
        [System.Management.Automation.Language.ReturnStatementAst]
        [System.Management.Automation.Language.ThrowStatementAst]
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

function Exit-CoverageAnalysis
{
    Set-StrictMode -Off

    $breakpoints = @($pester.CommandCoverage.Breakpoint)
    if ($breakpoints.Count -gt 0)
    {
        Remove-PSBreakpoint -Breakpoint $breakpoints
    }
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

    Write-Host ''
    Write-Host 'Code coverage report:'
    Write-Host "Covered $executedPercent of $totalCommandCount commands in $fileCount files."

    if ($missedCommands.Count -gt 0)
    {
        Write-Host ''
        Write-Host 'Missed commands:'
        $missedCommands | Format-Table File, Line, Command -AutoSize | Out-Host
    }
}