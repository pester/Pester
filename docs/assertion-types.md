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

When using the pipeline syntax, PowerShell unwraps the input and we lose the type of the collection on the left side. We are provided with a collection that can be either $null, empty or have items. Notably, we cannot distinguish between a single value being provided, and an array of single item:

```powershell
1 | Should-Be
@(1) | Should-Be
```

These will both be received by the assertion as `@(1)`.

For this reason a value assertion will handle this as `1`, but a collection assertion will handle this input as `@(1)`.

Another special case is `@()`. A value assertion will handle it as `$null`, but a collection assertion will handle it as `@()`.

`$null` remains `$null` in both cases.

```powershell
# Should-Be is a value assertion:
1 | Should-Be -Expected 1
@(1) | Should-Be -Expected 1
$null | Should-Be -Expected $null
@() | Should-Be -Expected $null #< --- TODO: this is not the case right now, we special case this as empty array, but is that correct? it does not play well with the value and collection assertion, and we special case it just because we can.
# $null | will give $local:input -> $null , and @() | will give $local:input -> @(), is that distinction important when we know that we will only check against values?

# This fails, because -Expected does not allow collections.
@() | Should-Be -Expected @()



```powershell
# Should-BeCollection is a collection assertion:
1 | Should-BeCollection -Expected @(1)
@(1) | Should-BeCollection -Expected @(1)
@() | Should-BeCollection -Expected @()

# This fails, because -Expected requires a collection.
$null | Should-BeCollection -Expected $null
```

### Using the -Actual syntax

The value provides to `-Actual`, is always exactly the same as provided.

```powershell
Should-Be -Actual 1 -Expected 1

# This fails, Actual is collection, while expected is int.
Should-Be -Actual @(1) -Expected 1
```

## Value assertions

### Generic value assertions

Generic value assertions, such as `Should-Be`, are for asserting on a single value. They behave quite similar to PowerShell operators, e.g. `Should-Be` maps to `-eq`.

The `$Expected` accepts any input that is not a collection.
The type of `$Expected` determines the type to be used for the comparison.
`$Actual` is automatically converted to that type.

```powershell
1 | Should-Be -Expected $true
Get-Process -Name Idle | Should-Be -Expected "System.Diagnostics.Process (Idle)"
```

The assertions in the above examples will both pass:
- `1` converts to `bool` `$true`, which is the expected value.
- `Get-Process` retrieves the Idle process (on Windows). This process object gets converted to `string`. The string is equal to the expected value.

### Type specific value assertions

Type specific assertions are for asserting on a single value of a given type. For example boolean. These assertions take the advantage of being more specialized, to provide a type specific functionality. Such as `Should-BeString -IgnoreWhitespace`.

The `$Expected` accepts input that has the same type as the assertion type. E.g. `Should-BeString -Expected "my string"`.

`$Actual` accepts input that has the same type as the assertion type. The input is not automatically converted to the destination type, unless the assertion specifies it, e.g. `Should-BeFalsy` will convert to `bool`.

## Collection assertions



These assertions are exported from the module as Assert-* functions and aliased to Should-*, this is because of PowerShell restricting multi word functions to a list of predefined approved verbs.
