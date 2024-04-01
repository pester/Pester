function Test-Like
{
    param (
        [String]$Expected,
        $Actual,
        [switch]$CaseSensitive
    )

    if (-not $CaseSensitive)
    {
        $Actual -like $Expected
    }
    else
    {
        $Actual -clike $Expected
    }
}

function Get-LikeDefaultFailureMessage ([String]$Expected, $Actual, [switch]$CaseSensitive)
{
    $caseSensitiveMessage = ""
    if ($CaseSensitive)
    {
        $caseSensitiveMessage = " case sensitively"
    }
    "Expected the string '$Actual' to$caseSensitiveMessage match '$Expected' but it did not."
}

function Assert-Like
{
    param (
        [Parameter(Position=1, ValueFromPipeline=$true)]
        $Actual,
        [Parameter(Position=0, Mandatory=$true)]
        [String]$Expected,
        [Switch]$CaseSensitive,
        [String]$CustomMessage
    )

    $Actual = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input

    if ($Actual -isnot [string])
    {
        throw [ArgumentException]"Actual is expected to be string, to avoid confusing behavior that -like operator exhibits with collections. To assert on collections use Assert-Any, Assert-All or some other collection assertion."
    }

    $stringsAreAlike = Test-Like -Expected $Expected -Actual $Actual -CaseSensitive:$CaseSensitive -IgnoreWhitespace:$IgnoreWhiteSpace
    if (-not ($stringsAreAlike))
    {
        if (-not $CustomMessage)
        {
            $formattedMessage = Get-LikeDefaultFailureMessage -Expected $Expected -Actual $Actual -CaseSensitive:$CaseSensitive
        }
        else
        {
            $formattedMessage = Get-CustomFailureMessage -Expected $Expected -Actual $Actual -CustomMessage $CustomMessage -CaseSensitive:$CaseSensitive
        }
        throw [Assertions.AssertionException]$formattedMessage
    }
}