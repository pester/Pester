# Contributing to Pester

Thanks for taking the time to contribute! We welcome and encourage contributions
to this project.

Please read the [contribution introduction](https://pester.dev/docs/contributing/introduction)
for more information.

## Building Pester

Pester is written in Powershell and C#. The C# solution requires .NET
Framework SDKs and Developer Packs in order to compile, see links below
how to install those prior to building.

The first time the repository is cloned, or when the C# code changes, the
assemblies are built by running the following from the root of the
repository:

```powershell
.\build.ps1 -Clean
```

To build the Pester PowerShell module when the PowerShell code is changed
run the following from the root of the repository:

```powershell
.\build.ps1
```

> ✏ You can also build the module into a single file: `.\build.ps1 -Inline`
> This is how the real build is done, but it is hard to debug and change the code because it runs
> from the Pester.psm1 but you need to change it in it's respective file. Use this only when
> necessary.

To use the built module you can run the below from the root of the
repository.

>**NOTE:** If the assemblies have been changed and a previous version of
>the assemblies exist (loaded) in the session, then a new PowerShell session
>must be started for the new assemblies to be loaded again.

```powershell
Import-Module .\bin\Pester.psd1 -Force
```

To get more information for the parameters that can be used, run the following:

```powershell
Get-Help ./build.ps1 -Detailed
```

## Required Software

Pester has a C# Solution which requires .NET Framework SDKs and Developer Packs in order to compile. The targeted frameworks can be found in `src\csharp\Pester\Pester.csproj`.

### Install .NET 8.0 SDK

[Download Link](https://dotnet.microsoft.com/en-us/download/dotnet/8.0)

## Running Tests

Pester uses two types of tests:

1. P tests (`*.ts.ps1`) written in the P module. These are used for unit testing the runtime itself and running acceptance tests for Pester
2. Pester tests (`*.tests.ps1`) for all functions in the module.

In Powershell, use `test.ps1`. The scripts runs a build and imports required helper-functions like `InPesterModuleScope` before starting.

Afterwards, each test can be run individually using Invoke-Pester.

Test.ps1 and optionally -skipPTests to skip the .ts.ps1 files.

## test.ps1

test.ps1 can be run locally with the following parameters:

```powershell
.\test.ps1 -File <filename>
```

To skip P tests:

```powershell
.\test.ps1 -File <filename> -SkipPTests
```

To get more information for the parameters that can be used, run the following:

```powershell
Get-Help ./test.ps1 -Detailed
```

## Continuous Integration

The Azure Devops Pipeline azure-pipelines.yml file contains the code definition used for builds, unit and integration tests in the CI pipeline.

Within the pipeline, tests are executed against PS7 and PS5.1, on Windows, Linux (Ubuntu) and MacOS.

## Documentation

Documentation is available in the repo, the [Pester wiki](https://github.com/pester/Pester/wiki), and at <https://pester.dev>

Documentation is written in Markdown. Comment-based Documentation and parts of the documentation web site are generated using Docusaurus Powershell.

Multi-line examples added to comments should use fenced code.

<https://docusaurus-powershell.netlify.app/docs/faq/multi-line-examples>
