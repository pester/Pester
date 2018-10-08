function Show-PesterAssertion {
    <#
    #>
    [CmdletBinding()]
    param (
        [ValidateSet(
            'General',
            'Text',
            'Comparison',
            'Collection',
            'File',
            'Exceptions',
            'Negative',
            'Because'
        )]
        [string]$Category,

        [ValidateSet(
            'Be', 
            'Because', 
            'BeExactly', 
            'BeFalse', 
            'BeGreaterOrEqual', 
            'BeGreaterThan', 
            'BeIn', 
            'BeLessOrEqual', 
            'BeLessThan', 
            'BeLike', 
            'BeLikeExactly', 
            'BeNullOrEmpty', 
            'BeOfType, HaveType', 
            'BeTrue', 
            'Contain', 
            'Exist', 
            'FileContentMatch', 
            'FileContentMatchExactly', 
            'FileContentMatchMultiline', 
            'HaveCount', 
            'Match', 
            'MatchExactly', 
            'Not', 
            'Throw'
        )]
        [string]$Assertion
    )

    $help = (Get-Content -Path $PSScriptRoot\..\en-US\about_Should.help.txt) -Split [Environment]::NewLine
    Write-Verbose "about_Should line count is $($help.Count)"

    $IgnoreTopLevel = 'TOPIC|DESCRIPTION|ALSO'
    $IgnoreAssertions = 'USING SHOULD IN A TEST'

    $text = [System.Collections.Generic.List[string]]::new()

    for ($i = 0; $i -lt $help.Count; $i++) {
        $line = $help[$i]
    
        If ($line -match '^\S') {
            $TopLevel = $line
        }
    
        If ($TopLevel -match $IgnoreTopLevel) {
            continue
        }
    
        If ($CurrentAssertion -and $line -match '^\s{4}\S') {
            Write-Verbose "Break on $i"
    
            # Return the current object before we overwrite it
            # $Category should match or be empty; same with $Assertion
            If (($Category -eq $ObjectCategory -or -not $Category) -and ($Assertion -like $CurrentAssertion -or -not $Assertion)) {
                [PSCustomObject]@{
                    Assertion = $CurrentAssertion
                    Category  = $ObjectCategory
                    Text      = $text
                }
            }
        
            If ($cat -notin $IgnoreAssertions) {
                # Reset the list to empty for the next assertion's text
                $text = [System.Collections.Generic.List[string]]::new()
            } Else {
                # Assumes all the $IgnoreAssertions are at the end of the file
                # So we can exit the for loop and be done
                break
            }
        } ElseIf ($CurrentAssertion -and $cat -notin $IgnoreAssertions) {
            [void]$text.Add($line.Trim())
        }
        
        If ($line -match "^\s{4}\S.*$" -and $cat -notin $IgnoreAssertions) {
            Write-Verbose "Assertion on $i - $line"
            $CurrentAssertion = $line.Trim()
            # Lock in the next object's category. $cat might change by then
            $ObjectCategory = $cat
        }
    
        If ($line -match "^\s{2}\S.*$") {
            Write-Verbose "Category on $i - $line"
            $cat = $line.Trim()
        }
    } #for
}
