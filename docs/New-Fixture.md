---
external help file: Pester-help.xml
Module Name: Pester
online version:
schema: 2.0.0
---

# New-Fixture

## SYNOPSIS
This function generates two scripts, one that defines a function
and another one that contains its tests.

## SYNTAX

```
New-Fixture [[-Path] <String>] [-Name] <String> [<CommonParameters>]
```

## DESCRIPTION
This function generates two scripts, one that defines a function
and another one that contains its tests.
The files are by default
placed in the current directory and are called and populated as such:


The script defining the function: .\Clean.ps1:

function Clean {

}

The script containing the example test .\Clean.Tests.ps1:

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
.
"$here\$sut"

Describe "Clean" {

    It "does something useful" {
        $true | Should -Be $false
    }
}

## EXAMPLES

### EXAMPLE 1
```
New-Fixture -Name Clean
```

Creates the scripts in the current directory.

### EXAMPLE 2
```
New-Fixture C:\Projects\Cleaner Clean
```

Creates the scripts in the C:\Projects\Cleaner directory.

### EXAMPLE 3
```
New-Fixture Cleaner Clean
```

Creates a new folder named Cleaner in the current directory and creates the scripts in it.

## PARAMETERS

### -Path
Defines path where the test and the function should be created, you can use full or relative path.
If the parameter is not specified the scripts are created in the current directory.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: $PWD
Accept pipeline input: False
Accept wildcard characters: False
```

### -Name
Defines the name of the function and the name of the test to be created.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS

[Describe
Context
It
about_Pester
about_Should]()

