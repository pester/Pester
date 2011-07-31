function Context($name, [ScriptBlock] $fixture) {

    Setup

    $results = Get-GlobalTestResults
	$margin = " " * $results.TestDepth
    $results.TestDepth += 1

	Write-Host -fore yellow $margin $name
    & $fixture

    Cleanup

	$results.TestDepth -= 1
}

