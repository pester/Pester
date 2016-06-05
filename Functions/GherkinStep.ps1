function When {
    param(
        [Parameter(Mandatory=$True, Position=0)]
        [String]$Name,

        [Parameter(Mandatory=$True, Position=1)]
        [ScriptBlock]$Test
    )

    $Script:GherkinSteps.${Name} = $Test
}


Set-Alias And When
Set-Alias But When
Set-Alias Given When
Set-Alias Then When
