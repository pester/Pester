Provides logical grouping of `It` blocks within a single `Describe` block.  Any `Mock`s defined inside a `Context` are removed at the end of the `Context` scope, as are any files or folders added to the 'TestDrive:\' path during the `Context` block's execution.  Any `BeforeEach` or `AfterEach` blocks defined inside a `Context` also only apply to tests within that `Context`.

## Parameters

#### `Name`

The name of the Context. This is a phrase describing a set of tests within a describe.

#### `Fixture`

Script that is executed. This may include setup specific to the context and one or more It blocks that validate the expected outcomes.

## Example

```powershell
Describe "Description Name" {
    Context "Context Name #1" {
         It "..." { ... }
    }

    Context "Context Name #2" {
        It "..." { ... }
        It "..." { ... }
        It "..." { ... }
    }
}
```
