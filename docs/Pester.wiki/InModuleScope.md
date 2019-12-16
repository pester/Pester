The `InModuleScope` command allows you to perform white-box unit testing on the internal (non-exported) code of a Script Module.

Let's say you have code like this inside a script module named MyModule.psm1:

```powershell
function PublicFunction
{
    # Does something
}

function PrivateFunction
{
    return $true
}

Export-ModuleMember -Function PublicFunction
```

Normally, you cannot call the `PrivateFunction` command after importing the module; only `PublicFunction` would be exposed to the rest of the PowerShell session.  For example, this test would fail with an error of "The term 'PrivateFunction' is not recognized as the name of a cmdlet, function, script file, or operable program.":

```powershell
Import-Module MyModule

Describe 'Testing MyModule' {
    It 'Tests the Private function' {
        PrivateFunction | Should Be $true
    }
}
```

By using `InModuleScope`, you can execute test code inside the module, giving you access to its internal functions, variables, and aliases.  For example:

```powershell
Import-Module MyModule

InModuleScope MyModule {
    Describe 'Testing MyModule' {
        It 'Tests the Private function' {
            PrivateFunction | Should Be $true
        }
    }
}
```

You may place an `InModuleScope` command anywhere inside a Pester test script.  It can contain entire `Describe` blocks, as shown, or be limited to smaller groups of commands (including just the body of the `It` block).
