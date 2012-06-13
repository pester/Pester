function Describe($name, [ScriptBlock] $fixture) {
    Setup

    $results = Get-GlobalTestResults
	$margin = " " * $results.TestDepth
    $results.TestDepth += 1
    $results.CurrentCategory = @{
        name = $name
        Tests = @()
    }
    

	$output = $margin + "Describing " + $name

    Write-Host -fore yellow $output
    & $fixture
    Cleanup
	$results.Categories += $results.CurrentCategory
    $results.TestDepth -= 1
}
