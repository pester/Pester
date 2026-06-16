function ConvertTo-CollectionItems {
    param ($Value)

    if ($null -eq $Value) {
        return @($null)
    }

    if (Is-Collection -Value $Value) {
        return @($Value)
    }

    return @($Value)
}

function Test-CollectionItemEquality {
    param (
        $Expected,
        $Actual
    )

    if ($null -eq $Expected -or $null -eq $Actual) {
        return $null -eq $Expected -and $null -eq $Actual
    }

    if ((Is-Collection -Value $Expected) -and (Is-Collection -Value $Actual)) {
        $expectedItems = ConvertTo-CollectionItems -Value $Expected
        $actualItems = ConvertTo-CollectionItems -Value $Actual

        if ($expectedItems.Count -ne $actualItems.Count) {
            return $false
        }

        for ($index = 0; $index -lt $expectedItems.Count; $index++) {
            if (-not (Test-CollectionItemEquality -Expected $expectedItems[$index] -Actual $actualItems[$index])) {
                return $false
            }
        }

        return $true
    }

    return $Expected -eq $Actual
}

function Test-CollectionContains {
    param (
        $Expected,
        $Actual
    )

    $expectedItems = ConvertTo-CollectionItems -Value $Expected
    $actualItems = ConvertTo-CollectionItems -Value $Actual

    if (0 -eq $expectedItems.Count) {
        return $true
    }

    if ($actualItems.Count -lt $expectedItems.Count) {
        return $false
    }

    for ($start = 0; $start -le ($actualItems.Count - $expectedItems.Count); $start++) {
        $match = $true

        for ($offset = 0; $offset -lt $expectedItems.Count; $offset++) {
            if (-not (Test-CollectionItemEquality -Expected $expectedItems[$offset] -Actual $actualItems[$start + $offset])) {
                $match = $false
                break
            }
        }

        if ($match) {
            return $true
        }
    }

    return $false
}
