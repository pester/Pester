$Paths = @(
    "$PSScriptRoot/Configuration.cs"
    "$PSScriptRoot/Factory.cs"
)

foreach ($path in $Paths) {
    Add-Type -TypeDefinition (Get-Content -Raw $path) -ErrorAction Stop
}
