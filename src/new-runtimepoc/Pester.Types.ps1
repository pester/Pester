$Paths = @(
    "$PSScriptRoot/Configuration.cs"
    "$PSScriptRoot/Factory.cs"
    "$PSScriptRoot/Test.cs"
)

foreach ($path in $Paths) {
    Add-Type -TypeDefinition (Get-Content -Raw $path) -ErrorAction Stop
}
