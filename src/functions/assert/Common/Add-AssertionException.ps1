$typeDefinition = Get-Content $PSScriptRoot/AssertionException.cs | Out-String
Add-Type -TypeDefinition $typeDefinition -WarningAction SilentlyContinue