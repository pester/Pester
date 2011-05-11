function Context($name, [ScriptBlock] $fixture) {
	Write-Host -fore yellow "$name"
    & $fixture
    Cleanup
}
