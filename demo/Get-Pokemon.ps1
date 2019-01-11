function Get-Pokemon ($Name) {

    Write-Host -ForegroundColor Blue "---------> Long call to external API"

    [Uri] $uri = "https://pokeapi.co/api/v2/pokemon/$($Name.ToLowerInvariant())/"
    $response = Invoke-WebRequest -Method GET -Uri $uri
    $content = $response.Content | ConvertFrom-Json

    [psCustomObject]@{
        Name = $content.name
        Height = $content.height
        Weight = $content.weight
        Type = $content.types.type.name
    }
}

Write-Host -ForegroundColor Blue "---------> File Get-Pokemon.ps1 was imported"
