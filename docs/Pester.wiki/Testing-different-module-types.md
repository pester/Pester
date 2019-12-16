## Overview

This page describes Pester's support for various types of PowerShell modules, and workarounds for limitations in the [Mock](Mock.md) and [InModuleScope](InModuleScope.md) features for some module types.

## Types of Modules

PowerShell modules are a way of grouping related scripts and resources together to make it easier to use them. There are a number of different types of modules, each of which have slightly different characteristics:

* Script modules
* Binary modules
* Manifest modules
* Dynamic modules

To determine the type of a module you can use the `Get-Module` cmdlet.

```powershell
ModuleType Version    Name
---------- -------    ----
Script     4.1.0      Pester
Script     4.0.8      Pester
```

The `ModuleType` property will be one of the above values.

> To inspect your modules you might need to use `-ListAvailable` or load the module first, using `Import-Module` and then inspect it.

Note that module types are described more fully in the [Understanding a Windows PowerShell Module](https://technet.microsoft.com/en-us/library/dd878324(v=vs.85).aspx) page on the Microsoft TechNet website.

## Pester Support

Pester can be used to test the behavior of commands that are exported from all types of modules. For example the following test will call the ```Invoke-PublicMethod``` command regardless of whether it is defined in a Script, Binary, Manifest or Dynamic module:

```powershell
Describe "Invoke-PublicMethod" {
    It "returns a value" {
        $result = Invoke-PublicMethod
        $result | Should Be "Invoke-PublicMethod called!"
    }
}
```

However, the [Mock](Mock.md) and [InModuleScope](InModuleScope.md) features can only be used for commands in **Script** modules due to limitations in the way that other module types are implemented in PowerShell. As a result, you may see an error message when trying to use Mock or InModuleScope with non-Script modules:

```powershell
Module 'MyManifestModule' is not a Script module. Detected modules of the following types: 'Manifest'
```

## Usage and workarounds

The following sections describe Pester's support for the Mock and InModuleScope features for each type of module, and workarounds for the error above, if available.

### Script Modules

Pester fully supports Script modules, so the Mock and InModuleScope features can be used without any workarounds.

### Dynamic Modules

The Mock and InModuleScope features can be used with Dynamic modules if the module is first imported using ```Import-Module```. For example:

```powershell
# create a dynamic module
$myDynamicModule = New-Module -Name MyDynamicModule {
    function Invoke-PrivateFunction { 'I am the internal function' }
    function Invoke-PublicFunction  { Invoke-PrivateFunction }
    Export-ModuleMember -Function Invoke-PublicFunction
}

# import the dynamic module
$myDynamicModule | Import-Module -Force

# use InModuleScope and Mock for commands inside the dynamic module
Describe "Executing test code inside a dynamic module" {

    Context "Using the Mock command" {
        It "Can mock functions inside the module when using Mock -ModuleName" {
            Mock Invoke-PrivateFunction { 'I am the mock function.' } -ModuleName MyDynamicModule
            Invoke-PublicFunction | Should -Be 'I am the mock function.'
            Assert-MockCalled Invoke-PrivateFunction -ModuleName MyDynamicModule
        }
    }

    InModuleScope MyDynamicModule {
        It "Can call module internal functions using InModuleScope" {
            Invoke-PrivateFunction | Should -Be 'I am the internal function'
        }
        It "Can mock functions inside the module without using Mock -ModuleName" {
            Mock Invoke-PrivateFunction { 'I am the mock function.' }
            Invoke-PrivateFunction | Should -Be 'I am the mock function.'
        }
    }

}
```

### Manifest Modules

Commands that are exported from a manifest module can be tested with Pester, but the Mock and InModuleScope features cannot be used with Manifest modules.

There **is**, however, a simple workaround, which is to add an empty script module with a *.psm1 extension into the RootModule (or ModuleToProcess) attribute of the manifest *.psd1 file. This basically converts the Manifest module into a Script module instead.

For example, save the script below as "MyModule.psd1" to create a PowerShell **Manifest** module.

```powershell
@{
ModuleVersion     = '1.0'
NestedModules     = @( "Invoke-PrivateManifestMethod.ps1", "Invoke-PublicManifestMethod.ps1" )
FunctionsToExport = @( "Invoke-PublicManifestMethod" )
}
```

Then, to convert it into a Script module, create a new blank file called "MyModule.psm1" and modify the MyModule.psd1 as follows:

```powershell
@{
ModuleVersion     = '1.0'

RootModule        = "MyModule.psm1" # <-- add this line to convert a Manifest module into a Script module

NestedModules     = @( "Invoke-PrivateManifestMethod.ps1", "Invoke-PublicManifestMethod.ps1" )
FunctionsToExport = @( "Invoke-PublicManifestMethod" )
}
```

PowerShell will then load the module as a Script module instead, and Pester's Mock and InModuleScope features will work as per normal.

### Binary Modules

Commands that are exported from a Binary module can be tested with Pester, but the Mock and InModuleScope features cannot be used with Binary modules, and there are currently no workarounds.
