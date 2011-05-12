function Describe($name, [ScriptBlock] $fixture) {

    $results = Get-GlobalTestResults
	$margin = " " * $results.TestDepth
    $results.TestDepth += 1

	$output = $margin + "Describing " + $name

    Write-Host -fore yellow $output
    & $fixture
    Cleanup
	
    $results.TestDepth -= 1
}
