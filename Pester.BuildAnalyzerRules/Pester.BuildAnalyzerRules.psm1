# Get list of SafeCommands
$SafeCommands = & { . "$PSScriptRoot/../src/functions/Pester.SafeCommands.ps1"; $Script:SafeCommands }
# Workaround as RuleSuppressionID-based suppression is bugged. returns error.
# Should be replaced with the following line when PSScriptAnalyzer is fixed. See Invoke-Pester
# [Diagnostics.CodeAnalysis.SuppressMessageAttribute('Pester.BuildAnalyzerRules\Measure-SafeCommands', 'Remove-Variable')]
$IgnoreUnsafeCommands = @('Remove-Variable')
function Measure-SafeCommands {
    <#
    .SYNOPSIS
    Should use $SafeCommand-variant of external function when available.
    .DESCRIPTION
    Pester module defines a $SafeCommands dictionary for external commands to avoid hijacking. To fix a violation of this rule, update the call to use SafeCommands variant, ex. `& $SafeCommands['CommandName'] -Param1 Value1`.
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
            if ($null -ne $commandName -and $commandName -in $SafeCommands.Keys -and $commandName -notin $IgnoreUnsafeCommands) {
                foreach ($cmd in $CommandAst.CommandElements) {
                    # Find extent for command name only
                    if(($cmd -is [System.Management.Automation.Language.StringConstantExpressionAst]) -and $cmd.Value -eq $commandName) {

                        #Define fix-action
                        [int]$startLineNumber = $cmd.Extent.StartLineNumber
                        [int]$endLineNumber = $cmd.Extent.EndLineNumber
                        [int]$startColumnNumber = $cmd.Extent.StartColumnNumber
                        [int]$endColumnNumber = $cmd.Extent.EndColumnNumber
                        [string]$correction = "& `$SafeCommands['$commandName']"
                        [string]$file = $MyInvocation.MyCommand.Definition
                        [string]$description = 'Replacing with SafeCommands-type'
                        $correctionExtent = New-Object 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent' $startLineNumber, $endLineNumber, $startColumnNumber, $endColumnNumber, $correction, $file, $description
                        $suggestedCorrections = New-Object System.Collections.ObjectModel.Collection['Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent']
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

Export-ModuleMember -Function 'Measure-*'
