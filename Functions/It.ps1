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

.PARAMETER Name
An expressive phsae describing the expected test outcome.

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
        $sum | Should Be 5
    }

    It "adds negative numbers" {
        $sum = Add-Numbers (-2) (-2)
        $sum | Should Be (-4)
    }

    It "adds one negative number to positive number" {
        $sum = Add-Numbers (-2) 2
        $sum | Should Be 0
    }

    It "concatenates strings if given strings" {
        $sum = Add-Numbers two three
        $sum | Should Be "twothree"
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
        $sum | Should Be $expectedResult
    }
}

.LINK
Describe
Context
about_should
#>
    [CmdletBinding(DefaultParameterSetName = 'Normal')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$name,

        [Parameter(Position = 1)]
        [ScriptBlock] $test = {},

        [System.Collections.IDictionary[]] $TestCases,

        [Parameter(ParameterSetName = 'Pending')]
        [Switch] $Pending,

        [Parameter(ParameterSetName = 'Skip')]
        [Alias('Ignore')]
        [Switch] $Skip
    )

    ItImpl -Pester $pester -OutputScriptBlock ${function:Write-PesterResult} @PSBoundParameters
}

function ItImpl
{
    [CmdletBinding(DefaultParameterSetName = 'Normal')]
    param(
        [Parameter(Mandatory = $true, Position=0)]
        [string]$name,
        [Parameter(Position = 1)]
        [ScriptBlock] $test,
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
    if ($PSCmdlet.ParameterSetName -ne 'Skip') { $Skip = $false }
    if ($PSCmdlet.ParameterSetName -ne 'Pending') { $Pending = $false }

    #unless Skip or Pending is specified you must specify a ScriptBlock to the Test parameter
    if (-not ($PSBoundParameters.ContainsKey('test') -or $Skip -or $Pending))
    {
        throw 'No test script block is provided. (Have you put the open curly brace on the next line?)'
    }

    #the function is called with Pending or Skipped set the script block if needed
    if ($null -eq $test) { $test = {} }

    #mark empty Its as Pending
    #[String]::IsNullOrWhitespace is not available in .NET version used with PowerShell 2
    if ($PSCmdlet.ParameterSetName -eq 'Normal' -and
       [String]::IsNullOrEmpty((Remove-Comments $test.ToString()) -replace "\s"))
    {
        $Pending = $true
    }

    $pendingSkip = @{}

    if ($PSCmdlet.ParameterSetName -eq 'Skip')
    {
        $pendingSkip['Skip'] = $Skip
    }
    else
    {
        $pendingSkip['Pending'] = $Pending
    }

    if ($null -ne $TestCases -and $TestCases.Count -gt 0)
    {
        foreach ($testCase in $TestCases)
        {
            $expandedName = [regex]::Replace($name, '<([^>]+)>', {
                $capture = $args[0].Groups[1].Value
                if ($testCase.Contains($capture))
                {
                    $testCase[$capture]
                }
                else
                {
                    "<$capture>"
                }
            })

            $splat = @{
                Name = $expandedName
                Scriptblock = $test
                Parameters = $testCase
                ParameterizedSuiteName = $name
                OutputScriptBlock = $OutputScriptBlock
            }

            Invoke-Test @splat @pendingSkip
        }
    }
    else
    {
        Invoke-Test -Name $name -ScriptBlock $test @pendingSkip -OutputScriptBlock $OutputScriptBlock
    }
}

function Invoke-Test
{
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

    if ($null -eq $Parameters) { $Parameters = @{} }

    $Pester.EnterTest($Name)

    if ($Skip)
    {
        $Pester.AddTestResult($Name, "Skipped", $null)
    }
    elseif ($Pending)
    {
        $Pester.AddTestResult($Name, "Pending", $null)
    }
    else
    {
        Write-Progress -Activity "Running test '$Name'" -Status Processing

        $errorRecord = $null
        try
        {
            Invoke-TestCaseSetupBlocks

            do
            {
                $null = & $ScriptBlock @Parameters
            } until ($true)
        }
        catch
        {
            $errorRecord = $_
        }
        finally
        {
            #guarantee that the teardown action will run and prevent it from failing the whole suite
            try
            {
                if (-not ($Skip -or $Pending))
                {
                    Invoke-TestCaseTeardownBlocks
                }
            }
            catch
            {
                $errorRecord = $_
            }
        }


        $result = Get-PesterResult -ErrorRecord $errorRecord
        $orderedParameters = Get-OrderedParameterDictionary -ScriptBlock $ScriptBlock -Dictionary $Parameters
        $Pester.AddTestResult( $result.name, $result.Result, $null, $result.FailureMessage, $result.StackTrace, $ParameterizedSuiteName, $orderedParameters )
        Write-Progress -Activity "Running test '$Name'" -Completed -Status Processing
    }

    if ($null -ne $OutputScriptBlock)
    {
        $Pester.testresult[-1] | & $OutputScriptBlock
    }

    Exit-MockScope
    $Pester.LeaveTest()
}

function Get-PesterResult {
    param(
        [Nullable[TimeSpan]] $Time,
        [System.Management.Automation.ErrorRecord] $ErrorRecord
    )

    $testResult = @{
        name = $name
        time = $time
        failureMessage = ""
        stackTrace = ""
        success = $false
        result = "Failed"
    };

    if(-not $ErrorRecord)
    {
        $testResult.Result = "Passed"
        $testResult.success = $true
        return $testResult
    }

    if ($ErrorRecord.FullyQualifiedErrorID -eq 'PesterAssertionFailed')
    {
        # we use TargetObject to pass structured information about the error.
        $details = $ErrorRecord.TargetObject

        $failureMessage = $details.Message
        $file = $details.File
        $line = $details.Line
        $lineText = "`n$line`: $($details.LineText)"
    }
    else
    {
        $failureMessage = $ErrorRecord.ToString()
        $file = $ErrorRecord.InvocationInfo.ScriptName
        $line = $ErrorRecord.InvocationInfo.ScriptLineNumber
        $lineText = ''
    }

    $testResult.failureMessage = $failureMessage
    $testResult.stackTrace = "at line: $line in ${file}${lineText}"

    return $testResult
}

function Remove-Comments ($Text)
{
    $text -replace "(?s)(<#.*#>)" -replace "\#.*"
}

function Get-OrderedParameterDictionary
{
    [OutputType([System.Collections.IDictionary])]
    param (
        [scriptblock] $ScriptBlock,
        [System.Collections.IDictionary] $Dictionary
    )

    $parameters = Get-ParameterDictionary -ScriptBlock $ScriptBlock

    $orderedDictionary = New-Object System.Collections.Specialized.OrderedDictionary

    foreach ($parameterName in $parameters.Keys)
    {
        $value = $null
        if ($Dictionary.ContainsKey($parameterName))
        {
            $value = $Dictionary[$parameterName]
        }

        $orderedDictionary[$parameterName] = $value
    }

    return $orderedDictionary
}

function Get-ParameterDictionary
{
    param (
        [scriptblock] $ScriptBlock
    )

    $guid = [guid]::NewGuid().Guid

    try
    {
        Set-Content function:\$guid $ScriptBlock
        $metadata = [System.Management.Automation.CommandMetadata](Get-Command -Name $guid -CommandType Function)

        return $metadata.Parameters
    }
    finally
    {
        if (Test-Path function:\$guid) { Remove-Item function:\$guid }
    }
}
