if ($PSVersionTable.PSVersion.Major -le 2)
{
    function Enter-CoverageAnalysis { Write-Error 'Code coverage analysis requires PowerShell 3.0 or later.' }
    function Exit-CoverageAnalysis { }
    function Suspend-CoverageAnalysis { }
    function Resume-CoverageAnalysis { }
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
                $breakpoint = Set-PSBreakpoint @params | Disable-PSBreakpoint -PassThru

                [pscustomobject] @{
                    File       = $command.Extent.File
                    Line       = $command.Extent.StartLineNumber
                    Command    = $command.Extent.Text
                    Breakpoint = $breakpoint
                }
            }
        }
    )
}

function Exit-CoverageAnalysis
{
    $breakpoints = @($pester.CommandCoverage | Select-Object -ExpandProperty Breakpoint)
    if ($breakpoints.Count -gt 0)
    {
        $breakpoints | Remove-PSBreakpoint
    }
}

function Suspend-CoverageAnalysis
{
    $breakpoints = @($pester.CommandCoverage | Select-Object -ExpandProperty Breakpoint)
    if ($breakpoints.Count -gt 0)
    {
        $breakpoints | Disable-PSBreakpoint
    }
}

function Resume-CoverageAnalysis
{
    $breakpoints = @($pester.CommandCoverage | Select-Object -ExpandProperty Breakpoint)
    if ($breakpoints.Count -gt 0)
    {
        $breakpoints | Enable-PSBreakpoint
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