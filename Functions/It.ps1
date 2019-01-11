function It {
    <#
.SYNOPSIS
Validates the results of a test inside of a Describe block.

.DESCRIPTION
The It command is intended to be used inside of a Describe or Context Block.
If you are familiar with the AAA pattern (Arrange-Act-Assert), the body of
the It block is the appropriate location for an assert. The convention is to
assert a single expectation for each It block. The code inside of the It block
should throw a terminating error if the expectation of the test is not met and
thus cause the test to fail. The name of the It block should expressively state
the expectation of the test.

In addition to using your own logic to test expectations and throw exceptions,
you may also use Pester's Should command to perform assertions in plain language.

You can intentionally mark It block result as inconclusive by using Set-TestInconclusive
command as the first tested statement in the It block.

.PARAMETER Name
An expressive phrase describing the expected test outcome.

.PARAMETER Test
The script block that should throw an exception if the
expectation of the test is not met.If you are following the
AAA pattern (Arrange-Act-Assert), this typically holds the
Assert.

.PARAMETER Pending
Use this parameter to explicitly mark the test as work-in-progress/not implemented/pending when you
need to distinguish a test that fails because it is not finished yet from a tests
that fail as a result of changes being made in the code base. An empty test, that is a
test that contains nothing except whitespace or comments is marked as Pending by default.

.PARAMETER Skip
Use this parameter to explicitly mark the test to be skipped. This is preferable to temporarily
commenting out a test, because the test remains listed in the output. Use the Strict parameter
of Invoke-Pester to force all skipped tests to fail.

.PARAMETER TestCases
Optional array of hashtable (or any IDictionary) objects.  If this parameter is used,
Pester will call the test script block once for each table in the TestCases array,
splatting the dictionary to the test script block as input.  If you want the name of
the test to appear differently for each test case, you can embed tokens into the Name
parameter with the syntax 'Adds numbers <A> and <B>' (assuming you have keys named A and B
in your TestCases hashtables.)

.EXAMPLE
function Add-Numbers($a, $b) {
    return $a + $b
}

Describe "Add-Numbers" {
    It "adds positive numbers" {
        $sum = Add-Numbers 2 3
        $sum | Should -Be 5
    }

    It "adds negative numbers" {
        $sum = Add-Numbers (-2) (-2)
        $sum | Should -Be (-4)
    }

    It "adds one negative number to positive number" {
        $sum = Add-Numbers (-2) 2
        $sum | Should -Be 0
    }

    It "concatenates strings if given strings" {
        $sum = Add-Numbers two three
        $sum | Should -Be "twothree"
    }
}

.EXAMPLE
function Add-Numbers($a, $b) {
    return $a + $b
}

Describe "Add-Numbers" {
    $testCases = @(
        @{ a = 2;     b = 3;       expectedResult = 5 }
        @{ a = -2;    b = -2;      expectedResult = -4 }
        @{ a = -2;    b = 2;       expectedResult = 0 }
        @{ a = 'two'; b = 'three'; expectedResult = 'twothree' }
    )

    It 'Correctly adds <a> and <b> to get <expectedResult>' -TestCases $testCases {
        param ($a, $b, $expectedResult)

        $sum = Add-Numbers $a $b
        $sum | Should -Be $expectedResult
    }
}

.LINK
Describe
Context
Set-TestInconclusive
about_should
#>
    [CmdletBinding(DefaultParameterSetName = 'Normal')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Name,

        [Parameter(Position = 1)]
        [ScriptBlock] $Test = {},

        [System.Collections.IDictionary[]] $TestCases,

        [Parameter(ParameterSetName = 'Pending')]
        [Switch] $Pending,

        [Parameter(ParameterSetName = 'Skip')]
        [Alias('Ignore')]
        [Switch] $Skip
    )

    ItImpl -Pester $pester -OutputScriptBlock ${function:Write-PesterResult} @PSBoundParameters
}

function ItImpl {
    [CmdletBinding(DefaultParameterSetName = 'Normal')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name,
        [Parameter(Position = 1)]
        [ScriptBlock] $Test,
        [System.Collections.IDictionary[]] $TestCases,
        [Parameter(ParameterSetName = 'Pending')]
        [Switch] $Pending,

        [Parameter(ParameterSetName = 'Skip')]
        [Alias('Ignore')]
        [Switch] $Skip,

        $Pester,
        [scriptblock] $OutputScriptBlock
    )

    Assert-DescribeInProgress -CommandName It

    # Jumping through hoops to make strict mode happy.
    if ($PSCmdlet.ParameterSetName -ne 'Skip') {
        $Skip = $false
    }
    if ($PSCmdlet.ParameterSetName -ne 'Pending') {
        $Pending = $false
    }

    #unless Skip or Pending is specified you must specify a ScriptBlock to the Test parameter
    if (-not ($PSBoundParameters.ContainsKey('test') -or $Skip -or $Pending)) {
        throw 'No test script block is provided. (Have you put the open curly brace on the next line?)'
    }

    #the function is called with Pending or Skipped set the script block if needed
    if ($null -eq $Test) {
        $Test = {}
    }

    #mark empty Its as Pending
    if ($PSVersionTable.PSVersion.Major -le 2 -and
        $PSCmdlet.ParameterSetName -eq 'Normal' -and
        [String]::IsNullOrEmpty((Remove-Comments $Test.ToString()) -replace "\s")) {
        $Pending = $true
    }
    elseIf ($PSVersionTable.PSVersion.Major -gt 2) {
        #[String]::IsNullOrWhitespace is not available in .NET version used with PowerShell 2
        # AST is not available also
        $testIsEmpty =
        [String]::IsNullOrEmpty($Test.Ast.BeginBlock.Statements) -and
        [String]::IsNullOrEmpty($Test.Ast.ProcessBlock.Statements) -and
        [String]::IsNullOrEmpty($Test.Ast.EndBlock.Statements)

        if ($PSCmdlet.ParameterSetName -eq 'Normal' -and $testIsEmpty) {
            $Pending = $true
        }
    }

    $pendingSkip = @{}

    if ($PSCmdlet.ParameterSetName -eq 'Skip') {
        $pendingSkip['Skip'] = $Skip
    }
    else {
        $pendingSkip['Pending'] = $Pending
    }

    if ($null -ne $TestCases -and $TestCases.Count -gt 0) {
        foreach ($testCase in $TestCases) {
            $expandedName = [regex]::Replace($Name, '<([^>]+)>', {
                    $capture = $args[0].Groups[1].Value
                    if ($testCase.Contains($capture)) {
                        $value = $testCase[$capture]
                        # skip adding quotes to non-empty strings to avoid adding junk to the
                        # test name in case you want to expand captures like 'because' or test name
                        if ($value -isnot [string] -or [string]::IsNullOrEmpty($value)) {
                            Format-Nicely $value
                        }
                        else {
                            $value
                        }
                    }
                    else {
                        "<$capture>"
                    }
                })

            $splat = @{
                Name                   = $expandedName
                Scriptblock            = $Test
                Parameters             = $testCase
                ParameterizedSuiteName = $Name
                OutputScriptBlock      = $OutputScriptBlock
            }

            Invoke-Test @splat @pendingSkip
        }
    }
    else {
        Invoke-Test -Name $Name -ScriptBlock $Test @pendingSkip -OutputScriptBlock $OutputScriptBlock
    }
}

function Invoke-Test {
    [CmdletBinding(DefaultParameterSetName = 'Normal')]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock,

        [scriptblock] $OutputScriptBlock,

        [System.Collections.IDictionary] $Parameters,
        [string] $ParameterizedSuiteName,

        [Parameter(ParameterSetName = 'Pending')]
        [Switch] $Pending,

        [Parameter(ParameterSetName = 'Skip')]
        [Alias('Ignore')]
        [Switch] $Skip
    )

    if ($null -eq $Parameters) {
        $Parameters = @{}
    }

    try {
        if ($Skip) {
            $Pester.AddTestResult($Name, "Skipped", $null)
        }
        elseif ($Pending) {
            $Pester.AddTestResult($Name, "Pending", $null)
        }
        else {
            #todo: disabling the progress for now, it adds a lot of overhead and breaks output on linux, we don't have a good way to disable it by default, or to show it after delay see: https://github.com/pester/Pester/issues/846
            # & $SafeCommands['Write-Progress'] -Activity "Running test '$Name'" -Status Processing

            $errorRecord = $null
            try {
                $pester.EnterTest()
                Invoke-TestCaseSetupBlocks

                do {
                    Write-ScriptBlockInvocationHint -Hint "It" -ScriptBlock $ScriptBlock
                    $null = & $ScriptBlock @Parameters
                } until ($true)
            }
            catch {
                $errorRecord = $_
            }
            finally {
                #guarantee that the teardown action will run and prevent it from failing the whole suite
                try {
                    if (-not ($Skip -or $Pending)) {
                        Invoke-TestCaseTeardownBlocks
                    }
                }
                catch {
                    $errorRecord = $_
                }

                $pester.LeaveTest()
            }

            $result = ConvertTo-PesterResult -Name $Name -ErrorRecord $errorRecord
            $orderedParameters = Get-OrderedParameterDictionary -ScriptBlock $ScriptBlock -Dictionary $Parameters
            $Pester.AddTestResult( $result.Name, $result.Result, $null, $result.FailureMessage, $result.StackTrace, $ParameterizedSuiteName, $orderedParameters, $result.ErrorRecord )
            #todo: disabling progress reporting see above & $SafeCommands['Write-Progress'] -Activity "Running test '$Name'" -Completed -Status Processing
        }
    }
    finally {
        Exit-MockScope -ExitTestCaseOnly
    }

    if ($null -ne $OutputScriptBlock) {
        $Pester.testresult[-1] | & $OutputScriptBlock
    }
}

function Get-OrderedParameterDictionary {
    [OutputType([System.Collections.IDictionary])]
    param (
        [scriptblock] $ScriptBlock,
        [System.Collections.IDictionary] $Dictionary
    )

    $parameters = Get-ParameterDictionary -ScriptBlock $ScriptBlock

    $orderedDictionary = & $SafeCommands['New-Object'] System.Collections.Specialized.OrderedDictionary

    foreach ($parameterName in $parameters.Keys) {
        $value = $null
        if ($Dictionary.ContainsKey($parameterName)) {
            $value = $Dictionary[$parameterName]
        }

        $orderedDictionary[$parameterName] = $value
    }

    return $orderedDictionary
}

function Get-ParameterDictionary {
    param (
        [scriptblock] $ScriptBlock
    )

    $guid = [Guid]::NewGuid().Guid

    try {
        & $SafeCommands['Set-Content'] function:\$guid $ScriptBlock
        $metadata = [System.Management.Automation.CommandMetadata](& $SafeCommands['Get-Command'] -Name $guid -CommandType Function)

        return $metadata.Parameters
    }
    finally {
        if (& $SafeCommands['Test-Path'] function:\$guid) {
            & $SafeCommands['Remove-Item'] function:\$guid
        }
    }
}
