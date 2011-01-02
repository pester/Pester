function Describe($name, [ScriptBlock] $fixture) {
    Write-Host -fore yellow Describing $name
    & $fixture
}
