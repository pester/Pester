$jsonFileName = "gherkin-languages.json"
$url = "https://raw.githubusercontent.com/cucumber/cucumber/master/gherkin/$jsonFileName"
$localFileName = "lib/Gherkin/$jsonFileName"
try {
    Invoke-WebRequest -Uri $url -OutFile $localFileName
    Write-Output "JSON file stored to $localFileName"
}
catch {
    # Since the JSON file is already in the repository, we just print out a warning
    Write-Warning "Could not get $url`n$($_.Exception)"
}
