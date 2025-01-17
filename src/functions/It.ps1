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

    You can intentionally mark It block result as inconclusive by using Set-ItResult -Inconclusive
    command as the first tested statement in the It block.

    .PARAMETER Name
    An expressive phrase describing the expected test outcome.

    .PARAMETER Test
    The script block that should throw an exception if the
    expectation of the test is not met.If you are following the
    AAA pattern (Arrange-Act-Assert), this typically holds the
    Assert.

    .PARAMETER Skip
    Use this parameter to explicitly mark the test to be skipped. This is preferable to temporarily
    commenting out a test, because the test remains listed in the output.

    .PARAMETER AllowNullOrEmptyForEach
    Allows empty or null values for -ForEach when Run.FailOnNullOrEmptyForEach is enabled.
    This might be excepted in certain scenarios like using external data.

    .PARAMETER ForEach
    (Formerly called TestCases.) Optional array of hashtable (or any IDictionary) objects.
    If this parameter is used, Pester will call the test script block once for each table in
    the ForEach array, splatting the dictionary to the test script block as input.  If you want
    the name of the test to appear differently for each test case, you can embed tokens into the Name
    parameter with the syntax 'Adds numbers <A> and <B>' (assuming you have keys named A and B
    in your ForEach hashtables.)

    .PARAMETER Tag
    Optional parameter containing an array of strings. When calling Invoke-Pester,
    it is possible to include or exclude tests containing the same Tag.

    .EXAMPLE
    ```powershell
    BeforeAll {
        function Add-Numbers($a, $b) {
            return $a + $b
        }
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
    ```

    Example of a simple Pester file. It-blocks are used to define the different tests.

    .EXAMPLE
    ```powershell
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

        It 'Correctly adds <a> and <b> to get <expectedResult>' -ForEach $testCases {
            $sum = Add-Numbers $a $b
            $sum | Should -Be $expectedResult
        }
    }
    ```

    Using It with -ForEach to run the same tests with different parameters and expected results.
    Each hashtable in the `$testCases`-array generates one tests to a total of four. Each key-value pair in the
    current hashtable are made available as variables inside It.

    .LINK
    https://pester.dev/docs/commands/It

    .LINK
    https://pester.dev/docs/commands/Describe

    .LINK
    https://pester.dev/docs/commands/Context

    .LINK
    https://pester.dev/docs/commands/Set-ItResult
    #>
    [CmdletBinding(DefaultParameterSetName = 'Normal')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Name,

        [Parameter(Position = 1)]
        [ScriptBlock] $Test,

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidAssignmentToAutomaticVariable', '', Justification = 'ForEach is not used in Foreach-Object loop')]
        [Alias("TestCases")]
        [object[]] $ForEach,

        [String[]] $Tag,

        [Parameter(ParameterSetName = 'Skip')]
        [Switch] $Skip,
        [Switch] $AllowNullOrEmptyForEach

        # [Parameter(ParameterSetName = 'Skip')]
        # [String] $SkipBecause,

        # [Switch]$Focus
    )

    $Focus = $false

    if ($null -eq $Test) {
        if ($Name.Contains("`n")) {
            throw "Test name has multiple lines and no test scriptblock is provided. Did you provide the test name?"
        }
        else {
            throw "No test scriptblock is provided. Did you put the opening curly brace on the next line?"
        }
    }

    Assert-BoundScriptBlockInput -ScriptBlock $Test

    if ($PSBoundParameters.ContainsKey('ForEach')) {
        if ($null -eq $ForEach -or 0 -eq @($ForEach).Count) {
            if ($PesterPreference.Run.FailOnNullOrEmptyForEach.Value -and -not $AllowNullOrEmptyForEach) {
                throw [System.ArgumentException]::new('Value can not be null or empty array. If this is expected, use -AllowNullOrEmptyForEach', 'ForEach')
            }
            # @() or $null is provided and allowed, do nothing
            return
        }

        New-ParametrizedTest -Name $Name -ScriptBlock $Test -StartLine $MyInvocation.ScriptLineNumber -StartColumn $MyInvocation.OffsetInLine -Data $ForEach -Tag $Tag -Focus:$Focus -Skip:$Skip
    }
    else {
        New-Test -Name $Name -ScriptBlock $Test -StartLine $MyInvocation.ScriptLineNumber -Tag $Tag -Focus:$Focus -Skip:$Skip
    }
}
