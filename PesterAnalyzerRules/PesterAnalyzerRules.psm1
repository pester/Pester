#Get list of SafeCommands
$SafeCommands = & { . "$PSScriptRoot/../src/functions/Pester.SafeCommands.ps1"; $Script:SafeCommands }
$PreferUnsafeCommands = @('Remove-Variable')
function Measure-AvoidUnsafeCommand {
    <#
    .SYNOPSIS
    Uses SafeCommand-variant of function when available.
    .DESCRIPTION
    Pester module defines a $SafeCommands dictionary for all external commands to avoid hijacking. All commands defined in the dictionary should only be called using that entry.
    To fix a violation of this rule, update the call to use SafeCoomands variant, ex. `& $SafeCommands['CommandName'] -Param1 Value1`.
    .EXAMPLE
    Measure-UnsafeCommands -CommandAst $CommandAst
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
        try {
            $commandName = $CommandAst.GetCommandName()

            # If command exists in $SafeCommands, write error
            if ($null -ne $commandName -and $commandName -in $SafeCommands.Keys -and $commandName -notin $PreferUnsafeCommands) {
                foreach ($cmd in $CommandAst.CommandElements) {
                    if(($cmd -is [System.Management.Automation.Language.StringConstantExpressionAst]) -and $cmd.Value -eq $commandName) {
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

                        $result = [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
                            'Message'              = "Unsafe call to '$commandName' found"
                            'Extent'               = $cmd.Extent
                            'RuleName'             = $PSCmdlet.MyInvocation.InvocationName
                            'Severity'             = 'Warning'
                            'RuleSuppressionID'    = 'PesterAvoidUnsafeCommands'
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

# $sbAst = {
# # if -not build
# Export-ModuleMember -Function @(
#     'Format-Collection'
#     'Format-Object'
#     'Format-Null'
#     'Format-Boolean'
#     'Format-String'
#     'Format-Date'
#     'Format-ScriptBlock'
#     'Format-Number'
#     'Format-Hashtable'
#     'Format-Dictionary'
#     'Format-Type'
#     'Format-Nicely'
#     'Get-DisplayProperty'
#     'Get-ShortType'
# )
# # endif

# }.Ast

# $cmdAsts = $sbAst.FindAll({$args[0] -is [System.Management.Automation.Language.CommandAst]},$true)

# $cmdAsts | % { Measure-AvoidUnsafeCommand -CommandAst $_ }

#Export-ModuleMember -Function 'Measure-*'
