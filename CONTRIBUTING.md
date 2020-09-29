# Contributing to Pester

Thanks for taking the time to contribute! We welcome and encourage contributions
to this project.

Please read the [contribution introduction](https://pester.dev/docs/contributing/introduction)
for more information.

## Building Pester

Pester is written in Powershell and C#. The C# solution requires .Net
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

To use the built module you can run the below from the root of the
repository.

>**NOTE:** If the assemblies have been changed and a previous version of
>the assemblies exist (loaded) in the session, then a new PowerShell session
>must be started for the new assemblies to be loaded again.

```powershell
Import-Module .\bin\Pester.psd1 -Force
```

## Required Software

Pester has a C# Solution which requires .NET Framework SDKs and Developer Packs in order to compile. The targeted frameworks can be found in `src\csharp\Pester\Pester.csproj`.

### Install .NET Core 3.1 SDK

[Download Link](https://dotnet.microsoft.com/download/dotnet-core/3.1)

### .Net Framework 4.5 Developer Pack

[Download Link](https://dotnet.microsoft.com/download/dotnet-framework/net452)
<https://aka.ms/msbuild/developerpacks>

## Running Tests

In Powershell, run test.ps1.  This defines the inherited function InPesterModuleScope and some types required for the tests.

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

### Test Parameters

```powershell
.PARAMETER CI
  Exits after run.  Enables test results and code coverage on `/src/*`. Enable exit with 1 if tests don't pass. Forces P Tests to fail when `dt` is left in the tests. `dt` only runs the specified test, so leaving it in code would run only one test from the file on the server.
.PARAMETER SkipPTests
  Skips Passthrough P tests. Skip the tests written using the P module, Unit Tests for the Runtime, and Acceptance Tests for Pester
.NoBuild
  Skips running build.ps1. Do not build the underlying csharp components. Used in CI pipeline since a clean build has already been run prior to Test.
.File
  If specified, set file path to test file, otherwise set to /tst folder. Pass the file to run Pester (not P) tests from.
  */demo/*, */examples/*, */testProjects/* are excluded from tests.
```

Tests are excluded with Tags VersionChecks, StyleRules, Help.

## Continuous Integration

The Azure Devops Pipeline azure-pipelines.yml file contains the code definition used for builds, unit and integration tests in the CI pipeline.

Within the pipeline, tests are executed against PS7 Core on a strategy matrix of machines, including Ubuntu 16.04, 18.04, macOS Mojave 10.14, Catalina 10.15, Windows Server 2016, 2019. Tests are also executed against PS6.2, PS4, PS3.

## Documentation

Documentation is available in the repo, the [Pester wiki](https://github.com/pester/Pester/wiki), and at <https://pester.dev>

Documentation is written in Markdown. Comment-based Documentation and parts of the documentation web site are generated using Docusaurus Powershell.

Multi-line examples added to comments should use fenced code.

<https://docusaurus-powershell.netlify.app/docs/faq/multi-line-examples>
