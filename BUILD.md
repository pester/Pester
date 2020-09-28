# Building Pester

Pester is written in Powershell and C#.  The Microsoft .NET Framework 4.5.2 is required to build the Pester binaries.

Pester has a C# Solution which requires .NET Framework SDKs and Developer Packs in order to compile. The targeted frameworks can be found in `src\csharp\Pester\Pester.csproj`.

## Required Software

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

test.ps1 can be run with the following parameters:

```powershell
.\test.ps1 -CI -SkipPTests -NoBuild -File ${filename}
```

### Test Parameters

```powershell
.PARAMETER CI
  Exits after run.  Enables test results and code coverage on /src/*. 
.PARAMETER SkipPTests
  Skips Passthrough P tests
.NoBuild
  Skips running build.ps1
.File
  If specified, set file path to test file, otherwise set to /tst folder.
  */demo/*, */examples/*, */testProjects/* are excluded from tests.
```

Tests are excluded with Tags VersionChecks, StyleRules, Help.

## Continuous Integration

The Azure Devops Pipeline azure-pipelines.yml file contains the code definition used for builds, unit and integration tests in the CI pipeline.

## Documentation

Documentation is available in the repo, the wiki, and at <https://pester.dev>

Documentation is written in Markdown. Comment-based Documentation and parts of the documentation web site are generated using Docusaurus Powershell.

Multi-line examples added to comments should use fenced code.

<https://docusaurus-powershell.netlify.app/docs/faq/multi-line-examples>
