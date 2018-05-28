<#
    .SYNOPSIS
        Add a test suppression entry to the global suppression list.

    .DESCRIPTION
        With this function, a suppression entry can be added to the global
        suppression list. The suppressed tests will be marked as skipped in the
        test results.
        The suppression entry must match the stack to the test itself. By
        default, the suppression will be used for all test scripts. It's
        requried to specify the Describe and Context blocks in correct order
        with the Group parameter as well as the It block. Wildcards can be used
        for the suppression, to suppress multiple tests.
        The suppression will consider the test 

    .PARAMETER Script
        Defint the script where the suppression will match.

    .PARAMETER Group
        Define the Describe and Context group block names.

    .PARAMETER It
        Define the test block name to suppress.

    .EXAMPLE
        PS C:\> Add-PesterSuppression -Group 'Get-Planet', 'Filtering by Name' -It '*'
        Suppress all test results in the groups 'Get-Planet', 'Filtering by
        Name' for all script files.

    .EXAMPLE
        PS C:\> Add-PesterSuppression -Group '*' -It "Given valid -Name '*', it returns '*'"
        Suppress all tests in every group level which matches the wildcards of
        the specified It block.

    .LINK
        about_Pester
        Describe
        Context
        It
#>
function Add-PesterSuppression
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false)]
        [System.String]
        $Script = '*',

        [Parameter(Mandatory = $true)]
        [System.String[]]
        $Group,

        [Parameter(Mandatory = $true)]
        [System.String]
        $It
    )

    $Script:PesterSuppression += [PSCustomObject] [Ordered] @{
        Script    = $Script
        Group     = $Group
        GroupFlat = $Group -join '\'
        It        = $It
    }
}

<#
    .SYNOPSIS
        Get all existing pester suppressions.

    .EXAMPLE
        PS C:\> Get-PesterSuppression
        Get all existing pester suppressions.

    .LINK
        about_Pester
        Describe
        Context
        It
#>
function Get-PesterSuppression
{
    [CmdletBinding()]
    param ()

    Write-Output $Script:PesterSuppression
}

<#
    .SYNOPSIS
        Remove all existing pester suppressions.

    .EXAMPLE
        PS C:\> Clear-PesterSuppression
        Remove all existing pester suppressions.

    .LINK
        about_Pester
        Describe
        Context
        It
#>
function Clear-PesterSuppression
{
    [CmdletBinding()]
    param ()

    $Script:PesterSuppression = @()
}

function Test-PesterSuppression
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Object[]]
        $TestGroupList,

        [Parameter(Mandatory = $true)]
        [System.String]
        $TestName
    )

    $script    = [System.String] ($TestGroupList | Where-Object { $_.Hint -eq 'Script' } | Select-Object -First 1 -ExpandProperty 'Name')
    $group     = [System.String[]] ($TestGroupList | Where-Object { $_.Hint -eq 'Describe' -or $_.Hint -eq 'Context' } | Select-Object -ExpandProperty 'Name')
    $groupFlat = $group -join '\'
    $it        = $TestName

    foreach ($suppression in $Script:PesterSuppression)
    {
        if ($script -like $suppression.Script -and
            $groupFlat -like $suppression.GroupFlat -and
            $it -like $suppression.It)
        {
            return $true
        }
    }

    return $false
}
