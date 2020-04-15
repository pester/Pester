$Paths = @(
    "$PSScriptRoot/csharp/Configuration.cs"
    "$PSScriptRoot/csharp/Factory.cs"
    "$PSScriptRoot/csharp/Test.cs"
)

foreach ($path in $Paths) {
    Add-Type -TypeDefinition (Get-Content -Raw $path) -ErrorAction Stop
}
