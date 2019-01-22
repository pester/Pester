---
external help file: Pester-help.xml
Module Name: Pester
online version:
schema: 2.0.0
---

# Mock

## SYNOPSIS
Mocks the behavior of an existing command with an alternate
implementation.

## SYNTAX

```
Mock [[-CommandName] <String>] [[-MockWith] <ScriptBlock>] [-Verifiable] [[-ParameterFilter] <ScriptBlock>]
 [[-ModuleName] <String>] [<CommonParameters>]
```

## DESCRIPTION
This creates new behavior for any existing command within the scope of a
Describe or Context block.
The function allows you to specify a script block
that will become the command's new behavior.

Optionally, you may create a Parameter Filter which will examine the
parameters passed to the mocked command and will invoke the mocked
behavior only if the values of the parameter values pass the filter.
If
they do not, the original command implementation will be invoked instead
of a mock.

You may create multiple mocks for the same command, each using a different
ParameterFilter.
ParameterFilters will be evaluated in reverse order of
their creation.
The last one created will be the first to be evaluated.
The mock of the first filter to pass will be used.
The exception to this
rule are Mocks with no filters.
They will always be evaluated last since
they will act as a "catch all" mock.

Mocks can be marked Verifiable.
If so, the Assert-VerifiableMock command
can be used to check if all Verifiable mocks were actually called.
If any
verifiable mock is not called, Assert-VerifiableMock will throw an
exception and indicate all mocks not called.

If you wish to mock commands that are called from inside a script module,
you can do so by using the -ModuleName parameter to the Mock command.
This
injects the mock into the specified module.
If you do not specify a
module name, the mock will be created in the same scope as the test script.
You may mock the same command multiple times, in different scopes, as needed.
Each module's mock maintains a separate call history and verified status.

## EXAMPLES

### EXAMPLE 1
```
Mock Get-ChildItem { return @{FullName = "A_File.TXT"} }
```

Using this Mock, all calls to Get-ChildItem will return a hashtable with a
FullName property returning "A_File.TXT"

### EXAMPLE 2
```
Mock Get-ChildItem { return @{FullName = "A_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp) }
```

This Mock will only be applied to Get-ChildItem calls within the user's temp directory.

### EXAMPLE 3
```
Mock Set-Content {} -Verifiable -ParameterFilter { $Path -eq "some_path" -and $Value -eq "Expected Value" }
```

When this mock is used, if the Mock is never invoked and Assert-VerifiableMock is called, an exception will be thrown.
The command behavior will do nothing since the ScriptBlock is empty.

### EXAMPLE 4
```
Mock Get-ChildItem { return @{FullName = "A_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp\1) }
```

Mock Get-ChildItem { return @{FullName = "B_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp\2) }
Mock Get-ChildItem { return @{FullName = "C_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp\3) }

Multiple mocks of the same command may be used.
The parameter filter determines which is invoked.
Here, if Get-ChildItem is called on the "2" directory of the temp folder, then B_File.txt will be returned.

### EXAMPLE 5
```
Mock Get-ChildItem { return @{FullName="B_File.TXT"} } -ParameterFilter { $Path -eq "$env:temp\me" }
```

Mock Get-ChildItem { return @{FullName="A_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp) }

Get-ChildItem $env:temp\me

Here, both mocks could apply since both filters will pass.
A_File.TXT will be returned because it was the most recent Mock created.

### EXAMPLE 6
```
Mock Get-ChildItem { return @{FullName = "B_File.TXT"} } -ParameterFilter { $Path -eq "$env:temp\me" }
```

Mock Get-ChildItem { return @{FullName = "A_File.TXT"} }

Get-ChildItem c:\windows

Here, A_File.TXT will be returned.
Since no filter was specified, it will apply to any call to Get-ChildItem that does not pass another filter.

### EXAMPLE 7
```
Mock Get-ChildItem { return @{FullName = "B_File.TXT"} } -ParameterFilter { $Path -eq "$env:temp\me" }
```

Mock Get-ChildItem { return @{FullName = "A_File.TXT"} }

Get-ChildItem $env:temp\me

Here, B_File.TXT will be returned.
Even though the filterless mock was created more recently.
This illustrates that filterless Mocks are always evaluated last regardless of their creation order.

### EXAMPLE 8
```
Mock Get-ChildItem { return @{FullName = "A_File.TXT"} } -ModuleName MyTestModule
```

Using this Mock, all calls to Get-ChildItem from within the MyTestModule module
will return a hashtable with a FullName property returning "A_File.TXT"

### EXAMPLE 9
```
Get-Module -Name ModuleMockExample | Remove-Module
```

New-Module -Name ModuleMockExample  -ScriptBlock {
    function Hidden { "Internal Module Function" }
    function Exported { Hidden }

    Export-ModuleMember -Function Exported
} | Import-Module -Force

Describe "ModuleMockExample" {

    It "Hidden function is not directly accessible outside the module" {
        { Hidden } | Should -Throw
    }

    It "Original Hidden function is called" {
        Exported | Should -Be "Internal Module Function"
    }

    It "Hidden is replaced with our implementation" {
        Mock Hidden { "Mocked" } -ModuleName ModuleMockExample
        Exported | Should -Be "Mocked"
    }
}

This example shows how calls to commands made from inside a module can be
mocked by using the -ModuleName parameter.

## PARAMETERS

### -CommandName
The name of the command to be mocked.

```yaml
Type: System.String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MockWith
A ScriptBlock specifying the behavior that will be used to mock CommandName.
The default is an empty ScriptBlock.
NOTE: Do not specify param or dynamicparam blocks in this script block.
These will be injected automatically based on the signature of the command
being mocked, and the MockWith script block can contain references to the
mocked commands parameter variables.

```yaml
Type: System.Management.Automation.ScriptBlock
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: {}
Accept pipeline input: False
Accept wildcard characters: False
```

### -Verifiable
When this is set, the mock will be checked when Assert-VerifiableMock is
called.

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ParameterFilter
An optional filter to limit mocking behavior only to usages of
CommandName where the values of the parameters passed to the command
pass the filter.

This ScriptBlock must return a boolean value.
See examples for usage.

```yaml
Type: System.Management.Automation.ScriptBlock
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: {$True}
Accept pipeline input: False
Accept wildcard characters: False
```

### -ModuleName
Optional string specifying the name of the module where this command
is to be mocked. 
This should be a module that _calls_ the mocked
command; it doesn't necessarily have to be the same module which
originally implemented the command.

```yaml
Type: System.String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable.
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS

[Assert-MockCalled
Assert-VerifiableMock
Describe
Context
It
about_Should
about_Mocking]()

