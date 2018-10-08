function Show-PesterAssertion {
    <#
    .SYNOPSIS
    Display the assertions available for use with Should.

    .DESCRIPTION
    Pester uses dynamic parameters to populate Should arguments.
    This limits the user's ability to discover the available assertions.

    Show-PesterAssertion is a basic attempt to provide that information.
    It displays the parameters, categories, and examples made available
    to help you craft the tests you need.

    .NOTES
    This command parses the about_Should help file to provide a summarized view.
    It is highly dependent on proper formatting to return accurate results.

    .EXAMPLE
    Show-PesterAssertion
    Return the Name, Category, and Text (examples) of available Should parameters.

    .EXAMPLE
    Show-PesterAssertion -Category Collection
    Return objects containing more info on the available collection assertions.

    .EXAMPLE
    Show-PesterAssertion -Assertion Match
    Return only the multi-line text example of the Match assertion.

    .LINK
    https://github.com/Pester/Pester
    about_Should
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
            If ($Assertion -eq $CurrentAssertion) {
                # If $Assertion was specified, return the text only
                $text
            } ElseIf (($Category -eq $ObjectCategory -or -not $Category) -and -not $Assertion) {
                # If $Category was specified, or neither were, return an object
                [PSCustomObject]@{
                    Name     = $CurrentAssertion
                    Category = $ObjectCategory
                    Text     = $text
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
