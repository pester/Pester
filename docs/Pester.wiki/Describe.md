Creates a logical group of tests.  All Mocks and TestDrive contents defined within a `Describe` block are scoped to that `Describe`; they will no longer be present when the `Describe` block exits.  A `Describe`
block may contain any number of `Context` and `It` blocks.

## Parameters

#### `Name`

The name of the test group. This is often an expressive phrase describing the scenario being tested.

#### `Fixture`

The actual test script. If you are following the AAA pattern (Arrange-Act-Assert), this typically holds the arrange and act sections. The Asserts will also lie in this block but are typically nested each in its own `It` block.  Assertions are typically performed by the `Should` command within the `It` blocks.

#### `Tags`

Optional parameter containing an array of strings.  When calling `Invoke-Pester`, it is possible to specify a `-Tag` parameter which will filter  `Describe` blocks containing the same Tag when the `-PassThru` parameter is enabled. In addition, if a `Describe` block has a tag, you can also use the `-ExcludeTag` when calling `Invoke-Pester` to exclude all `Describe` blocks with a certain tag.

## Example

```powershell
function Add-Numbers($a, $b) {
    return $a + $b
}

Describe "Add-Numbers" {
    It "adds positive numbers" {
        $sum = Add-Numbers 2 3
        $sum | Should -Be 5
    }

    It "adds negative numbers" {
        $sum = Add-Numbers (-2) (-2)
        $sum | Should -Be (-4)
    }

    It "adds one negative number to positive number" {
        $sum = Add-Numbers (-2) 2
        $sum | Should -Be 0
    }

    It "concatenates strings if given strings" {
        $sum = Add-Numbers two three
        $sum | Should -Be "twothree"
    }
}
```

## Example with Tags

```powershell
$tests = Invoke-Pester -ExcludeTag 'Disabled' -PassThru

Describe -Tag 'Disabled' "Add-Numbers" {
    It "adds positive numbers" {
        $sum = Add-Numbers 2 3
        $sum | Should -Be 5
    }
}
```
