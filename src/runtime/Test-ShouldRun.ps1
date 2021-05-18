function Test-ShouldRun {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Item,
        $Filter
    )

    # see https://github.com/pester/Pester/issues/1442 for description of how this filtering works

    $result = @{
        Include  = $false
        Exclude  = $false
        Explicit = $false
    }

    $anyIncludeFilters = $false
    $fullDottedPath = $Item.Path -join "."
    if ($null -eq $Filter) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) is included, because there is no filters."
        }

        $result.Include = $true
        return $result
    }

    $parent = if ('Test' -eq $Item.ItemType) {
        $Item.Block
    }
    elseif ('Block' -eq $Item.ItemType) {
        # no need to check if we are root, we will not run these rules on Root block
        $Item.Parent
    }

    if ($parent.Exclude) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) is excluded, because it's parent is excluded."
        }
        $result.Exclude = $true
        return $result
    }

    # item is excluded when any of the exclude tags match
    $tagFilter = $Filter.ExcludeTag
    if ($tagFilter -and 0 -ne $tagFilter.Count) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Filter "($fullDottedPath) There is '$($tagFilter -join ", ")' exclude tag filter."
        }
        foreach ($f in $tagFilter) {
            foreach ($t in $Item.Tag) {
                if ($t -like $f) {
                    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                        Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) is excluded, because it's tag '$t' matches exclude tag filter '$f'."
                    }
                    $result.Exclude = $true
                    return $result
                }
            }
        }
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) did not match the exclude tag filter, moving on to the next filter."
        }
    }

    # - place exclude filters above this line and include below this line

    $lineFilter = $Filter.Line
    # use File for saved files or Id for ScriptBlocks without files
    # this filter has the ability to set the test to "explicit" so we can run
    # the test even if it is marked as skipped run this include as first so we figure it out
    # in one place and check if parent was included after this one to short circuit the other
    # filters in case parent already knows that it will run

    $line = "$(if ($Item.ScriptBlock.File) { $Item.ScriptBlock.File } else { $Item.ScriptBlock.Id }):$($Item.StartLine)" -replace '\\', '/'
    if ($lineFilter -and 0 -ne $lineFilter.Count) {
        $anyIncludeFilters = $true
        foreach ($l in $lineFilter -replace '\\', '/') {
            if ($l -eq $line) {
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) is included, because its path:line '$line' matches line filter '$lineFilter'."
                }

                # if ('Test' -eq $Item.ItemType ) {
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) is explicitly included, because it matched line filter, and will run even if -Skip is specified on it. Any skipped children will still be skipped."
                }

                $result.Explicit = $true
                # }

                $result.Include = $true
                return $result
            }
        }
    }

    if ($parent.Include) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) is included, because its parent is included."
        }

        $result.Include = $true
        return $result
    }

    # test is included when it has tags and the any of the tags match
    $tagFilter = $Filter.Tag
    if ($tagFilter -and 0 -ne $tagFilter.Count) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Filter "($fullDottedPath) There is '$($tagFilter -join ", ")' include tag filter."
        }
        $anyIncludeFilters = $true
        if ($null -eq $Item.Tag -or 0 -eq $Item.Tag) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) has no tags, moving to next include filter."
            }
        }
        else {
            foreach ($f in $tagFilter) {
                foreach ($t in $Item.Tag) {
                    if ($t -like $f) {
                        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                            Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) is included, because it's tag '$t' matches tag filter '$f'."
                        }

                        $result.Include = $true
                        return $result
                    }
                }
            }
        }
    }

    $allPaths = $Filter.FullName
    if ($allPaths -and 0 -ne $allPaths) {
        $anyIncludeFilters = $true
        foreach ($p in $allPaths) {
            if ($fullDottedPath -like $p) {
                $include = $true
                break
            }
        }
        if ($include) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) is included, because it matches fullname filter '$include'."
            }

            $result.Include = $true
            return $result
        }
        else {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) does not match the dotted path filter, moving to next include filter."
            }
        }
    }

    if ($anyIncludeFilters) {
        if ('Test' -eq $Item.ItemType) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) did not match any of the include filters, it will not be included in the run."
            }
        }
        elseif ('Block' -eq $Item.ItemType) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) did not match any of the include filters, but it will still be included in the run, it's children will determine if it will run."
            }
        }
        else {
            throw "Item type $($Item.ItemType) is not supported in filter."
        }
    }
    else {
        if ('Test' -eq $Item.ItemType) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) will be included in the run, because there were no include filters so all tests are included unless they match exclude rule."
            }

            $result.Include = $true
        } # putting the bool in both to avoid string comparison
        elseif ('Block' -eq $Item.ItemType) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) will be included in the run, because there were no include filters, and will let its children to determine whether or not it should run."
            }
        }
        else {
            throw "Item type $($Item.ItemType) is not supported in filter."
        }

        return $result
    }

    return $result
}
