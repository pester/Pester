Checks if a Mocked command has been called a certain number of times and throws an exception if it has not.  If the call history of the mocked command does not match the parameters passed to `Assert-MockCalled`, `Assert-MockCalled` will throw an exception.

## Parameters

#### `CommandName`

The mocked command whose call history should be checked.

#### `ModuleName`

The module where the mock being checked was injected.  This is optional, and must match the ModuleName that was used when setting up the Mock.

#### `Times`

The number of times that the mock must be called to avoid an exception from throwing.

#### `Exactly`

If this switch is present, the number specified in Times must match exactly the number of times the mock has been called. Otherwise it must match "at least" the number of times specified.  If the value passed to the Times parameter is zero, the Exactly switch is implied.

#### `ParameterFilter`

An optional filter to qualify which calls should be counted. Only those calls to the mock whose parameterscause this filter to return true will be counted.

#### `Scope`

An optional parameter specifying the Pester scope in which to check for calls to the mocked command.  By default, `Assert-MockCalled` will find all calls to the mocked command in the current `Context` block (if present), or the current `Describe` block (if there is no active `Context`.)  Valid values are `Describe`, `Context` and `It`. If you use a scope of `Describe` or `Context`, the command will identify all calls to the mocked command in the current `Describe` / `Context` block, as well as all child scopes of that block.

## Example 1

```powershell
C:\PS>Mock Set-Content {}

{... Some Code ...}

C:\PS>Assert-MockCalled Set-Content
```

This will throw an exception and cause the test to fail if `Set-Content` is not called in Some Code.

## Example 2

```powershell
C:\PS>Mock Set-Content -ParameterFilter {$path.StartsWith("$env:temp\")}

{... Some Code ...}

C:\PS>Assert-MockCalled Set-Content 2 -ParameterFilter { $path -eq "$env:temp\test.txt" }
```

This will throw an exception if some code calls `Set-Content` on `$path=$env:temp\test.txt` less than 2 times

## Example 3

```powershell
C:\PS>Mock Set-Content {}

{... Some Code ...}

C:\PS>Assert-MockCalled Set-Content 0
```

This will throw an exception if some code calls Set-Content at all

## Example 4

```powershell
C:\PS>Mock Set-Content {}

{... Some Code ...}

C:\PS>Assert-MockCalled Set-Content -Exactly 2
```

This will throw an exception if some code does not call Set-Content Exactly two times.

## Example 5

```powershell
Describe 'Assert-MockCalled Scope behavior' {
    Mock Set-Content { }

    It 'Calls Set-Content at least once in the It block' {
        {... Some Code ...}
        Assert-MockCalled Set-Content -Exactly 0 -Scope It
    }
}
```

Checks for calls only within the current It block.

## Example 6

```powershell
Describe 'Describe' {
    Mock -ModuleName SomeModule Set-Content { }

    {... Some Code ...}

    It 'Calls Set-Content at least once in the Describe block' {
        Assert-MockCalled -ModuleName SomeModule Set-Content
    }
}
```

Checks for calls to the mock within the SomeModule module.  Note that both the `Mock`and `Assert-MockCalled` commands use the same module name.

## Additional Notes

The parameter filter passed to `Assert-MockCalled` does not necessarily have to match the parameter filter
(if any) which was used to create the Mock.  `Assert-MockCalled` will find any entry in the command history
which matches its parameter filter, regardless of how the Mock was created.  However, if any calls to the
mocked command are made which did not match any mock's parameter filter (resulting in the original command
being executed instead of a mock), these calls to the original command are not tracked in the call history.
In other words, `Assert-MockCalled` can only be used to check for calls to the mocked implementation, not
to the original.

Parameter names can be aliased and thus available via an unexpected variable.  Within the `-ParameterFilter` block one can `Write-Host` all available parameter variable names and values:

```powershell
Assert-MockCalled CommandName -Times 1 -ParameterFilter {
  Write-Host (Get-Variable | Select-Object -Property Name,Value)
}            
```