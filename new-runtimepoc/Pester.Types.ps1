$Paths = @(
    "$PSScriptRoot/Configuration.cs"
    "$PSScriptRoot/Factory.cs"
)

foreach ($path in $Paths) {
    # load the code and replace nameof() because we want type safety when writing
    # the code in Visual Studio but also be able to compile the code on load
    Add-Type -TypeDefinition ((Get-Content -Raw $path) -replace 'nameof\((.*?)\)', '"$1"') -ErrorAction Stop
}
