function New-TestSuite
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    $suite = New-Object psobject -Property @{
        Steps        = @()
        BeforeAll    = @()
        BeforeEach   = @()
        AfterAll     = @()
        AfterEach    = @()
        Parent       = $null
        Name         = $Name
        Result       = 'NotExecuted'
        ErrorMessage = $null
        StackTrace   = $null
    }

    $suite.PSObject.TypeNames.Insert(0, 'Pester.TestSuite')

    return $suite
}

function New-TestCase
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [scriptblock] $ScriptBlock,

        [ValidateNotNull()]
        [System.Collections.IDictionary[]] $Parameters = @()
    )

    if ($Parameters.Count -gt 0)
    {
        foreach ($paramTable in $Parameters)
        {
            $newName = InterpolateTestName -Name $Name -ScriptBlock $ScriptBlock -Parameters $paramTable
            NewSingleTestCase -Name $newName -ScriptBlock $ScriptBlock -Parameters $paramTable
        }
    }
    else
    {
        NewSingleTestCase -Name $Name -ScriptBlock $ScriptBlock
    }
}

function NewSingleTestCase
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [scriptblock] $ScriptBlock,

        [ValidateNotNull()]
        [System.Collections.IDictionary] $Parameters = @{}
    )

    $testCase = New-Object psobject -Property @{
        Name         = $Name
        ScriptBlock  = $ScriptBlock
        Parent       = $null
        Result       = 'NotExecuted'
        ErrorMessage = $null
        StackTrace   = $null
    }

    $testCase.PSObject.TypeNames.Insert(0, 'Pester.TestCase')

    return $testCase
}

function New-Step
{
    
}