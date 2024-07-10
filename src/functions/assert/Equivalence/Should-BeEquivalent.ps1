function Test-Same ($Expected, $Actual) {
    [object]::ReferenceEquals($Expected, $Actual)
}

function Is-CollectionSize ($Expected, $Actual) {
    if ($Expected.Length -is [Int] -and $Actual.Length -is [Int]) {
        return $Expected.Length -eq $Actual.Length
    }
    else {
        return $Expected.Count -eq $Actual.Count
    }
}

function Is-DataTableSize ($Expected, $Actual) {
    return $Expected.Rows.Count -eq $Actual.Rows.Count
}

function Get-ValueNotEquivalentMessage ($Expected, $Actual, $Property, $Options) {
    $Expected = Format-Nicely2 -Value $Expected
    $Actual = Format-Nicely2 -Value $Actual
    $propertyInfo = if ($Property) { " property $Property with value" }
    $comparison = if ("Equality" -eq $Options.Comparator) { 'equal' } else { 'equivalent' }
    "Expected$propertyInfo $Expected to be $comparison to the actual value, but got $Actual."
}


function Get-CollectionSizeNotTheSameMessage ($Actual, $Expected, $Property) {
    $expectedLength = if ($Expected.Length -is [int]) { $Expected.Length } else { $Expected.Count }
    $actualLength = if ($Actual.Length -is [int]) { $Actual.Length } else { $Actual.Count }
    $Expected = Format-Collection2 -Value $Expected
    $Actual = Format-Collection2 -Value $Actual

    $propertyMessage = $null
    if ($property) {
        $propertyMessage = " in property $Property with values"
    }
    "Expected collection$propertyMessage $Expected with length $expectedLength to be the same size as the actual collection, but got $Actual with length $actualLength."
}

function Get-DataTableSizeNotTheSameMessage ($Actual, $Expected, $Property) {
    $expectedLength = $Expected.Rows.Count
    $actualLength = $Actual.Rows.Count
    $Expected = Format-Collection2 -Value $Expected
    $Actual = Format-Collection2 -Value $Actual

    $propertyMessage = $null
    if ($property) {
        $propertyMessage = " in property $Property with values"
    }
    "Expected DataTable$propertyMessage $Expected with length $expectedLength to be the same size as the actual DataTable, but got $Actual with length $actualLength."
}

function Compare-CollectionEquivalent ($Expected, $Actual, $Property, $Options) {
    if (-not (Is-Collection -Value $Expected)) {
        throw [ArgumentException]"Expected must be a collection."
    }

    if (-not (Is-Collection -Value $Actual)) {
        Write-EquivalenceResult -Difference "`$Actual is not a collection it is a $(Format-Nicely2 $Actual.GetType()), so they are not equivalent."
        $expectedFormatted = Format-Collection2 -Value $Expected
        $expectedLength = $expected.Length
        $actualFormatted = Format-Nicely2 -Value $actual
        return "Expected collection $expectedFormatted with length $expectedLength, but got $actualFormatted."
    }

    if (-not (Is-CollectionSize -Expected $Expected -Actual $Actual)) {
        Write-EquivalenceResult -Difference "`$Actual does not have the same size ($($Actual.Length)) as `$Expected ($($Expected.Length)) so they are not equivalent."
        return Get-CollectionSizeNotTheSameMessage -Expected $Expected -Actual $Actual -Property $Property
    }

    $eEnd = if ($Expected.Length -is [int]) { $Expected.Length } else { $Expected.Count }
    $aEnd = if ($Actual.Length -is [int]) { $Actual.Length } else { $Actual.Count }
    Write-EquivalenceResult "Comparing items in collection, `$Expected has lenght $eEnd, `$Actual has length $aEnd."
    $taken = @()
    $notFound = @()
    $anyDifferent = $false
    for ($e = 0; $e -lt $eEnd; $e++) {
        # todo: retest strict order
        Write-EquivalenceResult "`nSearching for `$Expected[$e]:"
        $currentExpected = $Expected[$e]
        $found = $false
        if ($StrictOrder) {
            $currentActual = $Actual[$e]
            if ($taken -notcontains $e -and (-not (Compare-Equivalent -Expected $currentExpected -Actual $currentActual -Path $Property -Options $Options))) {
                $taken += $e
                $found = $true
                Write-EquivalenceResult -Equivalence "`Found `$Expected[$e]."
            }
        }
        else {
            for ($a = 0; $a -lt $aEnd; $a++) {
                # we already took this item as equivalent to an item
                # in the expected collection, skip it
                if ($taken -contains $a) {
                    Write-EquivalenceResult "Skipping `$Actual[$a] because it is already taken."
                    continue
                }
                $currentActual = $Actual[$a]
                # -not, because $null means no differences, and some strings means there are differences
                Write-EquivalenceResult "Comparing `$Actual[$a] to `$Expected[$e] to see if they are equivalent."
                if (-not (Compare-Equivalent -Expected $currentExpected -Actual $currentActual -Path $Property -Options $Options)) {
                    # add the index to the list of taken items so we can skip it
                    # in the search, this way we can compare collections with
                    # arrays multiple same items
                    $taken += $a
                    $found = $true
                    Write-EquivalenceResult -Equivalence "`Found equivalent item for `$Expected[$e] at `$Actual[$a]."
                    # we already found the item we
                    # can move on to the next item in Exected array
                    break
                }
            }
        }
        if (-not $found) {
            Write-EquivalenceResult -Difference "`$Actual does not contain `$Expected[$e]."
            $anyDifferent = $true
            $notFound += $currentExpected
        }
    }

    # do not depend on $notFound collection here
    # failing to find a single $null, will return
    # @($null) which evaluates to false, even though
    # there was a single item that we did not find
    if ($anyDifferent) {
        Write-EquivalenceResult -Difference "`$Actual and `$Expected arrays are not equivalent."
        $Expected = Format-Nicely2 -Value $Expected
        $Actual = Format-Nicely2 -Value $Actual
        $notFoundFormatted = Format-Nicely2 -Value $notFound

        $propertyMessage = if ($Property) { " in property $Property which is" }
        return "Expected collection$propertyMessage $Expected to be equivalent to $Actual but some values were missing: $notFoundFormatted."
    }
    Write-EquivalenceResult -Equivalence "`$Actual and `$Expected arrays are equivalent."
}

function Compare-DataTableEquivalent ($Expected, $Actual, $Property, $Options) {
    if (-not (Is-DataTable -Value $Expected)) {
        throw [ArgumentException]"Expected must be a DataTable."
    }

    if (-not (Is-DataTable -Value $Actual)) {
        $expectedFormatted = Format-Collection2 -Value $Expected
        $expectedLength = $expected.Rows.Count
        $actualFormatted = Format-Nicely2 -Value $actual
        return "Expected DataTable $expectedFormatted with length $expectedLength, but got $actualFormatted."
    }

    if (-not (Is-DataTableSize -Expected $Expected -Actual $Actual)) {
        return Get-DataTableSizeNotTheSameMessage -Expected $Expected -Actual $Actual -Property $Property
    }

    $eEnd = $Expected.Rows.Count
    $aEnd = $Actual.Rows.Count
    $taken = @()
    $notFound = @()
    for ($e = 0; $e -lt $eEnd; $e++) {
        $currentExpected = $Expected.Rows[$e]
        $found = $false
        if ($StrictOrder) {
            $currentActual = $Actual.Rows[$e]
            if ((-not (Compare-Equivalent -Expected $currentExpected -Actual $currentActual -Path $Property -Options $Options)) -and $taken -notcontains $e) {
                $taken += $e
                $found = $true
            }
        }
        else {
            for ($a = 0; $a -lt $aEnd; $a++) {
                $currentActual = $Actual.Rows[$a]
                if ((-not (Compare-Equivalent -Expected $currentExpected -Actual $currentActual -Path $Property -Options $Options)) -and $taken -notcontains $a) {
                    $taken += $a
                    $found = $true
                }
            }
        }
        if (-not $found) {
            $notFound += $currentExpected
        }
    }
    $Expected = Format-Nicely2 -Value $Expected
    $Actual = Format-Nicely2 -Value $Actual
    $notFoundFormatted = Format-Nicely2 -Value ( $notFound | & $SafeCommands['ForEach-Object'] { Format-Nicely2 -Value $_ } )

    if ($notFound) {
        $propertyMessage = if ($Property) { " in property $Property which is" }
        return "Expected DataTable$propertyMessage $Expected to be equivalent to $Actual but some values were missing: $notFoundFormatted."
    }
}

function Compare-ValueEquivalent ($Actual, $Expected, $Property, $Options) {
    $Expected = $($Expected)
    if (-not (Is-Value -Value $Expected)) {
        throw [ArgumentException]"Expected must be a Value."
    }

    # we don't specify the options in some tests so here we make
    # sure that equivalency is used as the default
    # not ideal but better than rewriting 100 tests
    if (($null -eq $Options) -or
        ($null -eq $Options.Comparator) -or
        ("Equivalency" -eq $Options.Comparator)) {
        Write-EquivalenceResult "Equivalency comparator is used, values will be compared for equivalency."
        # fix that string 'false' becomes $true boolean
        if ($Actual -is [Bool] -and $Expected -is [string] -and "$Expected" -eq 'False') {
            Write-EquivalenceResult "`$Actual is a boolean, and `$Expected is a 'False' string, which we consider equivalent to boolean `$false. Setting `$Expected to `$false."
            $Expected = $false
            if ($Expected -ne $Actual) {
                Write-EquivalenceResult -Difference "`$Actual is not equivalent to $(Format-Nicely2 $Expected) because it is $(Format-Nicely2 $Actual)."
                return Get-ValueNotEquivalentMessage -Expected $Expected -Actual $Actual -Property $Property -Options $Options
            }
            Write-EquivalenceResult -Equivalence "`$Actual is equivalent to $(Format-Nicely2 $Expected) because it is $(Format-Nicely2 $Actual)."
            return
        }

        if ($Expected -is [Bool] -and $Actual -is [string] -and "$Actual" -eq 'False') {
            Write-EquivalenceResult "`$Actual is a 'False' string, which we consider equivalent to boolean `$false. `$Expected is a boolean. Setting `$Actual to `$false."
            $Actual = $false
            if ($Expected -ne $Actual) {
                Write-EquivalenceResult -Difference "`$Actual is not equivalent to $(Format-Nicely2 $Expected) because it is $(Format-Nicely2 $Actual)."
                return Get-ValueNotEquivalentMessage -Expected $Expected -Actual $Actual -Property $Property -Options $Options
            }
            Write-EquivalenceResult -Equivalence "`$Actual is equivalent to $(Format-Nicely2 $Expected) because it is $(Format-Nicely2 $Actual)."
            return
        }

        # fix that scriptblocks are compared by reference
        if (Is-ScriptBlock -Value $Expected) {
            Write-EquivalenceResult "`$Expected is a ScriptBlock, scriptblocks are considered equivalent when their content is equal. Converting `$Expected to string."
            # forcing scriptblock to serialize to string and then comparing that
            if ("$Expected" -ne $Actual) {
                # todo: difference on index?
                Write-EquivalenceResult -Difference "`$Actual is not equivalent to `$Expected because their contents differ."
                return Get-ValueNotEquivalentMessage -Expected $Expected -Actual $Actual -Property $Path -Options $Options
            }
            Write-EquivalenceResult -Equivalence "`$Actual is equivalent to `$Expected because their contents are equal."
            return
        }
    }
    else {
        Write-EquivalenceResult "Equality comparator is used, values will be compared for equality."
    }

    Write-EquivalenceResult "Comparing values as $(Format-Nicely2 $Expected.GetType()) because `$Expected has that type."
    # todo: shorter messages when both sides have the same type (do not compare by using -is, instead query the type and compare it) because -is is true even for parent types
    $type = $Expected.GetType()
    $coalescedActual = $Actual -as $type
    if ($Expected -ne $Actual) {
        Write-EquivalenceResult -Difference "`$Actual is not equivalent to $(Format-Nicely2 $Expected) because it is $(Format-Nicely2 $Actual), and $(Format-Nicely2 $Actual) coalesced to $(Format-Nicely2 $type) is $(Format-Nicely2 $coalescedActual)."
        return Get-ValueNotEquivalentMessage -Expected $Expected -Actual $Actual -Property $Property -Options $Options
    }
    Write-EquivalenceResult -Equivalence "`$Actual is equivalent to $(Format-Nicely2 $Expected) because it is $(Format-Nicely2 $Actual), and $(Format-Nicely2 $Actual) coalesced to $(Format-Nicely2 $type) is $(Format-Nicely2 $coalescedActual)."
}

function Compare-HashtableEquivalent ($Actual, $Expected, $Property, $Options) {
    if (-not (Is-Hashtable -Value $Expected)) {
        throw [ArgumentException]"Expected must be a hashtable."
    }

    if (-not (Is-Hashtable -Value $Actual)) {
        Write-EquivalenceResult -Difference "`$Actual is not a hashtable it is a $(Format-Nicely2 $Actual.GetType()), so they are not equivalent."
        $expectedFormatted = Format-Nicely2 -Value $Expected
        $actualFormatted = Format-Nicely2 -Value $Actual
        return "Expected hashtable $expectedFormatted, but got $actualFormatted."
    }

    # todo: if either side or both sides are empty hashtable make the verbose output shorter and nicer

    $actualKeys = $Actual.Keys
    $expectedKeys = $Expected.Keys

    Write-EquivalenceResult "`Comparing all ($($expectedKeys.Count)) keys from `$Expected to keys in `$Actual."
    $result = @()
    foreach ($k in $expectedKeys) {
        if (-not (Test-IncludedPath -PathSelector Hashtable -Path $Property -Options $Options -InputObject $k)) {
            continue
        }

        $actualHasKey = $actualKeys -contains $k
        if (-not $actualHasKey) {
            Write-EquivalenceResult -Difference "`$Actual is missing key '$k'."
            $result += "Expected has key '$k' that the actual object does not have."
            continue
        }

        $expectedValue = $Expected[$k]
        $actualValue = $Actual[$k]
        Write-EquivalenceResult "Both `$Actual and `$Expected have key '$k', comparing thier contents."
        $result += Compare-Equivalent -Expected $expectedValue -Actual $actualValue -Path "$Property.$k" -Options $Options
    }

    if (!$Options.ExcludePathsNotOnExpected) {
        # fix for powershell 2 where the array needs to be explicit
        $keysNotInExpected = @( $actualKeys | & $SafeCommands['Where-Object'] { $expectedKeys -notcontains $_ })

        $filteredKeysNotInExpected = @( $keysNotInExpected | Test-IncludedPath -PathSelector Hashtable -Path $Property -Options $Options)

        # fix for powershell v2 where foreach goes once over null
        if ($filteredKeysNotInExpected | & $SafeCommands['Where-Object'] { $_ }) {
            Write-EquivalenceResult -Difference "`$Actual has $($filteredKeysNotInExpected.Count) keys that were not found on `$Expected: $(Format-Nicely2 @($filteredKeysNotInExpected))."
        }
        else {
            Write-EquivalenceResult "`$Actual has no keys that we did not find on `$Expected."
        }

        foreach ($k in $filteredKeysNotInExpected | & $SafeCommands['Where-Object'] { $_ }) {
            $result += "Expected is missing key '$k' that the actual object has."
        }
    }

    if ($result | & $SafeCommands['Where-Object'] { $_ }) {
        Write-EquivalenceResult -Difference "Hashtables `$Actual and `$Expected are not equivalent."
        $expectedFormatted = Format-Nicely2 -Value $Expected
        $actualFormatted = Format-Nicely2 -Value $Actual
        return "Expected hashtable $expectedFormatted, but got $actualFormatted.`n$($result -join "`n")"
    }

    Write-EquivalenceResult -Equivalence "Hastables `$Actual and `$Expected are equivalent."
}

function Compare-DictionaryEquivalent ($Actual, $Expected, $Property, $Options) {
    if (-not (Is-Dictionary -Value $Expected)) {
        throw [ArgumentException]"Expected must be a dictionary."
    }

    if (-not (Is-Dictionary -Value $Actual)) {
        Write-EquivalenceResult -Difference "`$Actual is not a dictionary it is a $(Format-Nicely2 $Actual.GetType()), so they are not equivalent."
        $expectedFormatted = Format-Nicely2 -Value $Expected
        $actualFormatted = Format-Nicely2 -Value $Actual
        return "Expected dictionary $expectedFormatted, but got $actualFormatted."
    }

    # todo: if either side or both sides are empty dictionary make the verbose output shorter and nicer

    $actualKeys = $Actual.Keys
    $expectedKeys = $Expected.Keys

    Write-EquivalenceResult "`Comparing all ($($expectedKeys.Count)) keys from `$Expected to keys in `$Actual."
    $result = @()
    foreach ($k in $expectedKeys) {
        if (-not (Test-IncludedPath -PathSelector Hashtable -Path $Property -Options $Options -InputObject $k)) {
            continue
        }

        $actualHasKey = $actualKeys -contains $k
        if (-not $actualHasKey) {
            Write-EquivalenceResult -Difference "`$Actual is missing key '$k'."
            $result += "Expected has key '$k' that the actual object does not have."
            continue
        }

        $expectedValue = $Expected[$k]
        $actualValue = $Actual[$k]
        Write-EquivalenceResult "Both `$Actual and `$Expected have key '$k', comparing thier contents."
        $result += Compare-Equivalent -Expected $expectedValue -Actual $actualValue -Path "$Property.$k" -Options $Options
    }
    if (!$Options.ExcludePathsNotOnExpected) {
        # fix for powershell 2 where the array needs to be explicit
        $keysNotInExpected = @( $actualKeys | & $SafeCommands['Where-Object'] { $expectedKeys -notcontains $_ } )
        $filteredKeysNotInExpected = @( $keysNotInExpected | Test-IncludedPath -PathSelector Hashtable -Path $Property -Options $Options )

        # fix for powershell v2 where foreach goes once over null
        if ($filteredKeysNotInExpected | & $SafeCommands['Where-Object'] { $_ }) {
            Write-EquivalenceResult -Difference "`$Actual has $($filteredKeysNotInExpected.Count) keys that were not found on `$Expected: $(Format-Nicely2 @($filteredKeysNotInExpected))."
        }
        else {
            Write-EquivalenceResult "`$Actual has no keys that we did not find on `$Expected."
        }

        foreach ($k in $filteredKeysNotInExpected | & $SafeCommands['Where-Object'] { $_ }) {
            $result += "Expected is missing key '$k' that the actual object has."
        }
    }

    if ($result) {
        Write-EquivalenceResult -Difference "Dictionaries `$Actual and `$Expected are not equivalent."
        $expectedFormatted = Format-Nicely2 -Value $Expected
        $actualFormatted = Format-Nicely2 -Value $Actual
        return "Expected dictionary $expectedFormatted, but got $actualFormatted.`n$($result -join "`n")"
    }
    Write-EquivalenceResult -Equivalence "Dictionaries `$Actual and `$Expected are equivalent."
}

function Compare-ObjectEquivalent ($Actual, $Expected, $Property, $Options) {

    if (-not (Is-Object -Value $Expected)) {
        throw [ArgumentException]"Expected must be an object."
    }

    if (-not (Is-Object -Value $Actual)) {
        Write-EquivalenceResult -Difference "`$Actual is not an object it is a $(Format-Nicely2 $Actual.GetType()), so they are not equivalent."
        $expectedFormatted = Format-Nicely2 -Value $Expected
        $actualFormatted = Format-Nicely2 -Value $Actual
        return "Expected object $expectedFormatted, but got $actualFormatted."
    }

    $actualProperties = $Actual.PsObject.Properties
    $expectedProperties = $Expected.PsObject.Properties

    Write-EquivalenceResult "Comparing ($(@($expectedProperties).Count)) properties of `$Expected to `$Actual."
    foreach ($p in $expectedProperties) {
        if (-not (Test-IncludedPath -PathSelector Property -InputObject $p -Options $Options -Path $Property)) {
            continue
        }

        $propertyName = $p.Name
        $actualProperty = $actualProperties | & $SafeCommands['Where-Object'] { $_.Name -eq $propertyName }
        if (-not $actualProperty) {
            Write-EquivalenceResult -Difference "Property '$propertyName' was not found on `$Actual."
            "Expected has property '$PropertyName' that the actual object does not have."
            continue
        }
        Write-EquivalenceResult "Property '$propertyName` was found on `$Actual, comparing them for equivalence."
        $differences = Compare-Equivalent -Expected $p.Value -Actual $actualProperty.Value -Path "$Property.$propertyName" -Options $Options
        if (-not $differences) {
            Write-EquivalenceResult -Equivalence "Property '$propertyName` is equivalent."
        }
        else {
            Write-EquivalenceResult -Difference "Property '$propertyName` is not equivalent."
        }
        $differences
    }

    if (!$Options.ExcludePathsNotOnExpected) {
        #check if there are any extra actual object props
        $expectedPropertyNames = $expectedProperties | Select-Object -ExpandProperty Name

        $propertiesNotInExpected = @( $actualProperties | & $SafeCommands['Where-Object'] { $expectedPropertyNames -notcontains $_.name })

        # fix for powershell v2 we need to make the array explicit
        $filteredPropertiesNotInExpected = $propertiesNotInExpected |
            Test-IncludedPath -PathSelector Property -Options $Options -Path $Property

        if ($filteredPropertiesNotInExpected) {
            Write-EquivalenceResult -Difference "`$Actual has ($(@($filteredPropertiesNotInExpected).Count)) properties that `$Expected does not have: $(Format-Nicely2 @($filteredPropertiesNotInExpected))."
        }
        else {
            Write-EquivalenceResult -Equivalence "`$Actual has no extra properties that `$Expected does not have."
        }

        # fix for powershell v2 where foreach goes once over null
        foreach ($p in $filteredPropertiesNotInExpected | & $SafeCommands['Where-Object'] { $_ }) {
            "Expected is missing property '$($p.Name)' that the actual object has."
        }
    }
}

function Compare-DataRowEquivalent ($Actual, $Expected, $Property, $Options) {

    if (-not (Is-DataRow -Value $Expected)) {
        throw [ArgumentException]"Expected must be a DataRow."
    }

    if (-not (Is-DataRow -Value $Actual)) {
        $expectedFormatted = Format-Nicely2 -Value $Expected
        $actualFormatted = Format-Nicely2 -Value $Actual
        return "Expected DataRow '$expectedFormatted', but got '$actualFormatted'."
    }

    $actualProperties = $Actual.PsObject.Properties | & $SafeCommands['Where-Object'] { 'RowError', 'RowState', 'Table', 'ItemArray', 'HasErrors' -notcontains $_.Name }
    $expectedProperties = $Expected.PsObject.Properties | & $SafeCommands['Where-Object'] { 'RowError', 'RowState', 'Table', 'ItemArray', 'HasErrors' -notcontains $_.Name }

    foreach ($p in $expectedProperties) {
        $propertyName = $p.Name
        $actualProperty = $actualProperties | & $SafeCommands['Where-Object'] { $_.Name -eq $propertyName }
        if (-not $actualProperty) {
            "Expected has property '$PropertyName' that the actual object does not have."
            continue
        }

        Compare-Equivalent -Expected $p.Value -Actual $actualProperty.Value -Path "$Property.$propertyName" -Options $Options
    }

    #check if there are any extra actual object props
    $expectedPropertyNames = $expectedProperties | Select-Object -ExpandProperty Name

    $propertiesNotInExpected = @($actualProperties | & $SafeCommands['Where-Object'] { $expectedPropertyNames -notcontains $_.name })

    # fix for powershell v2 where foreach goes once over null
    foreach ($p in $propertiesNotInExpected | & $SafeCommands['Where-Object'] { $_ }) {
        "Expected is missing property '$($p.Name)' that the actual object has."
    }
}

function Write-EquivalenceResult {
    [CmdletBinding()]
    param(
        [String] $String,
        [Switch] $Difference,
        [Switch] $Equivalence,
        [Switch] $Skip
    )

    # we are using implict variable $Path
    # from the parent scope, this is ugly
    # and bad practice, but saves us ton of
    # coding and boilerplate code

    $p = ""
    $p += if ($null -ne $Path) {
        "($Path)"
    }

    $p += if ($Difference) {
        " DIFFERENCE"
    }

    $p += if ($Equivalence) {
        " EQUIVALENCE"
    }

    $p += if ($Skip) {
        " SKIP"
    }

    $p += if ("" -ne $p) {
        " - "
    }

    & $SafeCommands['Write-Verbose'] ("$p$String".Trim() + " ")
}

# compares two objects for equivalency and returns $null when they are equivalent
# or a string message when they are not
function Compare-Equivalent {
    [CmdletBinding()]
    param(
        $Actual,
        $Expected,
        $Path,
        $Options
    )

    if (-not $PSBoundParameters.ContainsKey('Options')) {
        throw [System.ArgumentException]::new('-Options must be provided. If you see this and you are not developing Pester, please file issue at https://github.com/pester/Pester/issues', 'Options')
    }

    if ($null -ne $Options.ExcludedPaths -and $Options.ExcludedPaths -contains $Path) {
        Write-EquivalenceResult -Skip "Current path '$Path' is excluded from the comparison."
        return
    }

    # start by null checks to avoid implementing null handling
    # logic in the functions that follow
    if ($null -eq $Expected) {
        Write-EquivalenceResult "`$Expected is `$null, so we are expecting `$null."
        if ($Expected -ne $Actual) {
            Write-EquivalenceResult -Difference "`$Actual is not equivalent to $(Format-Nicely2 $Expected), because it has a value of type $(Format-Nicely2 $Actual.GetType())."
            return Get-ValueNotEquivalentMessage -Expected $Expected -Actual $Actual -Property $Path -Options $Options
        }
        # we terminate here, either we passed the test and return nothing, or we did not
        # and the previous statement returned message
        Write-EquivalenceResult -Equivalence "`$Actual is equivalent to `$null, because it is `$null."
        return
    }

    if ($null -eq $Actual) {
        Write-EquivalenceResult -Difference "`$Actual is $(Format-Nicely2), but `$Expected has value of type $(Format-Nicely2 $Expected.GetType()), so they are not equivalent."
        return Get-ValueNotEquivalentMessage -Expected $Expected -Actual $Actual -Property $Path
    }

    Write-EquivalenceResult "`$Expected has type $(Format-Nicely2 $Expected.GetType()), `$Actual has type $(Format-Nicely2 $Actual.GetType()), they are both non-null."

    # test value types, strings, and single item arrays with values in them as values
    # expand the single item array to get to the value in it
    if (Is-Value -Value $Expected) {
        Write-EquivalenceResult "`$Expected is a value (value type, string, single value array, or a scriptblock), we will be comparing `$Actual to value types."
        Compare-ValueEquivalent -Actual $Actual -Expected $Expected -Property $Path -Options $Options
        return
    }

    # are the same instance
    if (Test-Same -Expected $Expected -Actual $Actual) {
        Write-EquivalenceResult -Equivalence "`$Expected and `$Actual are equivalent because they are the same object (by reference)."
        return
    }

    if (Is-Hashtable -Value $Expected) {
        Write-EquivalenceResult "`$Expected is a hashtable, we will be comparing `$Actual to hashtables."
        Compare-HashtableEquivalent -Expected $Expected -Actual $Actual -Property $Path -Options $Options
        return
    }

    # dictionaries? (they are IEnumerable so they must go before collections)
    if (Is-Dictionary -Value $Expected) {
        Write-EquivalenceResult "`$Expected is a dictionary, we will be comparing `$Actual to dictionaries."
        Compare-DictionaryEquivalent -Expected $Expected -Actual $Actual -Property $Path -Options $Options
        return
    }

    #compare DataTable
    if (Is-DataTable -Value $Expected) {
        # todo add verbose output to data table
        Write-EquivalenceResult "`$Expected is a datatable, we will be comparing `$Actual to datatables."
        Compare-DataTableEquivalent -Expected $Expected -Actual $Actual -Property $Path -Options $Options
        return
    }

    #compare collection
    if (Is-Collection -Value $Expected) {
        Write-EquivalenceResult "`$Expected is a collection, we will be comparing `$Actual to collections."
        Compare-CollectionEquivalent -Expected $Expected -Actual $Actual -Property $Path -Options $Options
        return
    }

    #compare DataRow
    if (Is-DataRow -Value $Expected) {
        # todo add verbose output to data row
        Write-EquivalenceResult "`$Expected is a datarow, we will be comparing `$Actual to datarows."
        Compare-DataRowEquivalent -Expected $Expected -Actual $Actual -Property $Path -Options $Options
        return
    }

    Write-EquivalenceResult "`$Expected is an object of type $(Format-Nicely2 $Expected.GetType()), we will be comparing `$Actual to objects."
    Compare-ObjectEquivalent -Expected $Expected -Actual $Actual -Property $Path -Options $Options
}

function Should-BeEquivalent {
    <#
    .SYNOPSIS
    Compares two objects for equivalency, by recursively comparing their properties for equivalency.

    .PARAMETER Actual
    The actual object to compare.

    .PARAMETER Expected
    The expected object to compare.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .PARAMETER ExcludePath
    An array of strings specifying the paths to exclude from the comparison. Each path should correspond to a property name or a chain of property names separated by dots for nested properties. The paths use dot notation to navigate to a child property, such as "user.name".

    .PARAMETER ExcludePathsNotOnExpected
    A switch parameter that, when set, excludes any paths from the comparison that are not present on the expected object. This is useful for ignoring extra properties on the actual object that are not relevant to the comparison.

    .PARAMETER Comparator
    Specifies the comparison strategy to use. The options are 'Equivalency' for a deep comparison that considers the structure and values of objects, and 'Equality' for a simple equality comparison. The default is 'Equivalency'.

    .EXAMPLE
    ```powershell
        Should-BeEquivalent ...  -ExcludePath 'Id', 'Timestamp' -Comparator 'Equality'
    ```
    This example generates an equivalency option object that excludes the 'Id' and 'Timestamp' properties from the comparison and uses a simple equality comparison strategy.

    .EXAMPLE
    ```powereshell
        Should-BeEquivalent ... -ExcludePathsNotOnExpected
    ```
    This example generates an equivalency option object that excludes any paths not present on the expected object from the comparison, using the default deep comparison strategy.

    .EXAMPLE
    ```powershell
        $expected = [PSCustomObject] @{
            Name = "Thomas"
        }

        $actual = [PSCustomObject] @{
            Name = "Jakub"
            Age = 30
        }

        $actual | Should-BeEquivalent $expected
    ```

    This will throw an error because the actual object has an additional property Age and the Name values are not equivalent.

    .EXAMPLE
    ```powershell
        $expected = [PSCustomObject] @{
            Name = "Thomas"
        }

        $actual = [PSCustomObject] @{
            Name = "Thomas"
        }

        $actual | Should-BeEquivalent $expected
    ```

    This will pass because the actual object has the same properties as the expected object and the Name values are equivalent.

    .LINK
    https://pester.dev/docs/commands/Should-BeEquivalent

    .LINK
    https://pester.dev/docs/assertions
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Position = 0, Mandatory)]
        $Expected,
        [String]$Because,
        [string[]] $ExcludePath = @(),
        [switch] $ExcludePathsNotOnExpected,
        [ValidateSet('Equivalency', 'Equality')]
        [string] $Comparator = 'Equivalency'
        # TODO: I am not sure this works.
        # [Switch] $StrictOrder
    )

    $options = Get-EquivalencyOption -ExcludePath:$ExcludePath -ExcludePathsNotOnExpected:$ExcludePathsNotOnExpected -Comparator:$Comparator

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual

    $areDifferent = Compare-Equivalent -Actual $Actual -Expected $Expected -Options $Options | & $SafeCommands['Out-String']

    if ($areDifferent) {
        $optionsFormatted = Format-EquivalencyOptions -Options $Options
        # the paremeter is -Option not -Options
        $message = Get-AssertionMessage -Actual $actual -Expected $Expected -Option $optionsFormatted -Pretty -CustomMessage "Expected and actual are not equivalent!`nExpected:`n<expected>`n`nActual:`n<actual>`n`nSummary:`n$areDifferent`n<options>"
        throw [Pester.Factory]::CreateShouldErrorRecord($message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }

    Write-EquivalenceResult -Equivalence "`$Actual and `$Expected are equivalent."
}

function Get-EquivalencyOption {
    <#
    .SYNOPSIS
    Generates an object containing options for checking equivalency.

    .DESCRIPTION
    The `Get-EquivalencyOption` function creates a custom object with options that determine how equivalency between two objects is assessed. This can be used in scenarios where a deep comparison of objects is required, with the ability to exclude specific paths from the comparison and to choose between different comparison strategies.

    .PARAMETER ExcludePath
    An array of strings specifying the paths to exclude from the comparison. Each path should correspond to a property name or a chain of property names separated by dots for nested properties.

    .PARAMETER ExcludePathsNotOnExpected
    A switch parameter that, when set, excludes any paths from the comparison that are not present on the expected object. This is useful for ignoring extra properties on the actual object that are not relevant to the comparison.

    .PARAMETER Comparator
    Specifies the comparison strategy to use. The options are 'Equivalency' for a deep comparison that considers the structure and values of objects, and 'Equality' for a simple equality comparison. The default is 'Equivalency'.

    .EXAMPLE
    $option = Get-EquivalencyOption -ExcludePath 'Id', 'Timestamp' -Comparator 'Equality'
    This example generates an equivalency option object that excludes the 'Id' and 'Timestamp' properties from the comparison and uses a simple equality comparison strategy.

    .EXAMPLE
    $option = Get-EquivalencyOption -ExcludePathsNotOnExpected
    This example generates an equivalency option object that excludes any paths not present on the expected object from the comparison, using the default deep comparison strategy.

    .LINK
    https://pester.dev/docs/commands/Get-EquivalencyOption

    .LINK
    https://pester.dev/docs/assertions
    #>

    [CmdletBinding()]
    param(
        [string[]] $ExcludePath = @(),
        [switch] $ExcludePathsNotOnExpected,
        [ValidateSet('Equivalency', 'Equality')]
        [string] $Comparator = 'Equivalency'
    )

    [PSCustomObject]@{
        ExcludedPaths             = [string[]] $ExcludePath
        ExcludePathsNotOnExpected = [bool] $ExcludePathsNotOnExpected
        Comparator                = [string] $Comparator
    }
}

function Test-IncludedPath {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $InputObject,
        [String]
        $Path,
        $Options,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Property", "Hashtable")]
        $PathSelector
    )

    begin {
        $selector = switch ($PathSelector) {
            "Property" { { param($InputObject) $InputObject.Name } }
            "Hashtable" { { param($InputObject) $InputObject } }
            Default { throw "Unsupported path selector." }
        }
    }

    process {
        if ($null -eq $Options.ExcludedPaths) {
            return $InputObject
        }

        $subPath = &$selector $InputObject
        $fullPath = "$Path.$subPath".Trim('.')


        if ($fullPath | Like-Any $Options.ExcludedPaths) {
            Write-EquivalenceResult -Skip "Current path $fullPath is excluded from the comparison."
        }
        else {
            $InputObject
        }
    }
}

function Format-EquivalencyOptions ($Options) {
    $Options.ExcludedPaths | & $SafeCommands['ForEach-Object'] { "Exclude path '$_'" }
    if ($Options.ExcludePathsNotOnExpected) { "Excluding all paths not found on Expected" }
}

function Like-Any {
    param(
        [String[]] $PathFilters,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [String] $Path
    )
    process {
        foreach ($pathFilter in $PathFilters | & $SafeCommands['Where-Object'] { $_ }) {
            $r = $Path -like $pathFilter
            if ($r) {
                Write-EquivalenceResult -Skip "Path '$Path' matches filter '$pathFilter'."
                return $true
            }
        }

        return $false
    }
}
