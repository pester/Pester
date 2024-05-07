# Assert assertions

Pester 6 preview comes with a new set of Should-* assertions. These new assertions are split these categories based on their usage:

- value
    - generic
    - type specific

- collection
    - generic
    - combinator

Each of these categories treats `$Actual` and `$Expected` values differently, to provide a consistent behavior when using the `|` syntax.

## Value vs. Collection assertions

The `$Actual` value can be provided by two syntaxes, either by pipeline (`|`) or by parameter (`-Actual`):

```powershell
1 | Should-Be -Expected 1
Should-Be -Actual 1 -Expected 1
```

### Using pipeline syntax
When using the pipeline syntax, PowerShell unwraps the input and we lose the type of the collection on the left side. We are provided with a collection that can be either $null, empty or have items.

A value assertion

A value assertsoin , meaning that single item input as a single item, including array that has single item:

```powershell
1 | Should-Be -Expected 1
@(1) | Should-Be -Expected 1
$null | Should-Be -Expected $null
@() | Should-Be -Expected $null #< --- TODO: this is not the case right now, we special case this as empty array, but is that correct? it does not play well with the value and collection assertion, and we special case it just because we can $null | will give $local:input -> $null , and @() | will give $local:input -> @(), is that distinction important when we know that we will only check against values?
```






## Collection

## Generic assertions

The `$Expected` accepts any input that is not a collection.
The type of `$Expected` determines the type to be used for the comparison:

```powershell
1 | Should-Be -Expected $true
Get-Process | Should-Be -Expected "System.Diagnostics.Process (Idle)"
```

The assertions in the above examples will both pass. The

Will

These assertions are exported from the module as Assert-* functions and aliased to Should-*, this is because of PowerShell restricting multi word functions to a list of predefined approved verbs.
