# Workaround as RuleSuppressionID-based suppression is bugged. returns error.
# Should be replaced with the following line when PSScriptAnalyzer is fixed. See Invoke-Pester
# [Diagnostics.CodeAnalysis.SuppressMessageAttribute('Pester.BuildAnalyzerRules\Measure-SafeCommands', 'Remove-Variable')]
$IgnoreUnsafeCommands = @('Remove-Variable', 'Write-PesterDebugMessage')
# Hardcoding SafeCommands-entries to avoid dependency on imported module and slow PSSA-performance when executing Pester.SafeCommands.ps1 (due to many reimports by PSSA).
# Consider making build.ps1 update this
$SafeCommands = [System.IO.File]::ReadAllLines([System.IO.Path]::Join($PSScriptRoot,'SafeCommands.txt'))

function Measure-SafeCommands {
    <#
    .SYNOPSIS
    Should use $SafeCommand-variant of external function when available.
    .DESCRIPTION
    Pester module defines a $SafeCommands dictionary for external commands to avoid hijacking. To fix a violation of this rule, update the call to use SafeCommands-variant, ex. `& $SafeCommands['CommandName'] -Param1 Value1`.
    .EXAMPLE
    Measure-SafeCommands -CommandAst $CommandAst
    .INPUTS
    [System.Management.Automation.Language.CommandAst]
    .OUTPUTS
    [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]]
    .NOTES
    None
    #>
    # TODO This warning is currently thrown for SafeCommand
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseOutputTypeCorrectly", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("Pester.BuildAnalyzerRules\Measure-SafeCommands", "")]
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    Param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.CommandAst]
        $CommandAst
    )

    Process {
        $results = @()
        try {
            $commandName = $CommandAst.GetCommandName()

            # If command exists in $SafeCommands, write error
            if ($null -ne $commandName -and $commandName -notin $IgnoreUnsafeCommands -and $commandName -in $SafeCommands) {
                foreach ($cmd in $CommandAst.CommandElements) {
                    # Find extent for command name only
                    if (($cmd -is [System.Management.Automation.Language.StringConstantExpressionAst]) -and $cmd.Value -eq $commandName) {
                        #Define fix-action
                        [int]$startLineNumber = $cmd.Extent.StartLineNumber
                        [int]$endLineNumber = $cmd.Extent.EndLineNumber
                        [int]$startColumnNumber = $cmd.Extent.StartColumnNumber
                        [int]$endColumnNumber = $cmd.Extent.EndColumnNumber
                        [string]$correction = "& `$SafeCommands['$commandName']"
                        [string]$file = $MyInvocation.MyCommand.Definition
                        [string]$description = 'Replacing with SafeCommands-type'
                        $correctionExtent = [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]::new($startLineNumber, $endLineNumber, $startColumnNumber, $endColumnNumber, $correction, $file, $description)
                        $suggestedCorrections = [System.Collections.ObjectModel.Collection[Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]]::new()
                        $suggestedCorrections.add($correctionExtent) > $null

                        # Output error
                        $result = [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
                            'Message'              = "Unsafe call to '$commandName' found. $((Get-Help $MyInvocation.MyCommand.Name).Description.Text)"
                            'Extent'               = $cmd.Extent
                            'RuleName'             = $PSCmdlet.MyInvocation.InvocationName
                            'Severity'             = 'Warning'
                            'RuleSuppressionID'    = $commandName
                            "SuggestedCorrections" = $suggestedCorrections
                        }
                        $results += $result
                        break;
                    }
                }
            }
            return $results
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
}

Function Measure-ObjectCmdlets {
    <#
    .SYNOPSIS
    Should avoid usage of New/Where/Foreach/Select-Object.
    .DESCRIPTION
    The built-in *-Object-cmdlets are slow compared to alternatives in .NET. To fix a violation of this rule, consider using an alternative like `foreach/for`-keyword etc.`.
    .EXAMPLE
    Measure-ObjectCmdlets -CommandAst $CommandAst
    .INPUTS
    [System.Management.Automation.Language.CommandAst]
    .OUTPUTS
    [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]]
    .NOTES
    None
    #>
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    Param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.CommandAst]
        $CommandAst
    )

    Process {
        $results = @()

        #StringConstantExpressionAst match (direct cmdlet usage)
        $objectCommands = "(?:New|Where|Foreach|Select)-Object"

        $result = [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
            'Message'  = "$((Get-Help $MyInvocation.MyCommand.Name).Description.Text)"
            'Extent'   = $CommandAst.Extent
            'RuleName' = $PSCmdlet.MyInvocation.InvocationName
            'Severity' = 'Information'
        }

        try {
            $commandName = $CommandAst.GetCommandName()

            if ($null -ne $commandName -and $commandName -match $objectCommands) {
                # Cmdlet used
                $results += $result

            }
            elseif ($CommandAst.InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Ampersand) {
                $invocatedCmd = $CommandAst.CommandElements[0]

                if ($invocatedCmd -is [System.Management.Automation.Language.IndexExpressionAst] -and
                    $invocatedCmd.Target -match 'SafeCommands' -and $invocatedCmd.Index -match $objectCommands) {
                    # SafeCommands
                    $results += $result
                }
            }

            return $results
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
}

Export-ModuleMember -Function 'Measure-*'
