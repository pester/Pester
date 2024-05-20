# Pester

> 💵 Please consider sponsoring [nohwnd](https://github.com/sponsors/nohwnd), [fflaten](https://github.com/sponsors/fflaten) or sponsoring [Pester](https://opencollective.com/pester) itself.


> 🌵 Documentation is available at [https://pester.dev/docs/quick-start](https://pester.dev/docs/quick-start).

> 📦🔐 Pester is now signed. `-SkipPublisherCheck` should no longer be used to install from PowerShell Gallery on Windows 10.

> 👩👨 We are looking for contributors! All issues labeled [help wanted](https://github.com/pester/Pester/labels/help%20wanted) are up for grabs. They further split up into [good first issue](https://github.com/pester/Pester/labels/good%20first%20issue) that are issues I hope are easy to solve. [Bad first issue](https://github.com/pester/Pester/labels/bad%20first%20issue) where I expect the implementation to be problematic or needs to be proposed and discussed beforehand. And the rest which is somewhere in the middle. If you decide to pick up an issue please comment in the issue thread so others don't waste their time working on the same issue as you.
> There is also [contributor's guide](https://pester.dev/docs/contributing/introduction) that will hopefully help you.

Pester is the ubiquitous test and mock framework for PowerShell.

```powershell
BeforeAll {
    # your function
    function Get-Planet ([string]$Name='*')
    {
        $planets = @(
            @{ Name = 'Mercury' }
            @{ Name = 'Venus'   }
            @{ Name = 'Earth'   }
            @{ Name = 'Mars'    }
            @{ Name = 'Jupiter' }
            @{ Name = 'Saturn'  }
            @{ Name = 'Uranus'  }
            @{ Name = 'Neptune' }
        ) | foreach { [PSCustomObject]$_ }

        $planets | where { $_.Name -like $Name }
    }
}

# Pester tests
Describe 'Get-Planet' {
  It "Given no parameters, it lists all 8 planets" {
    $allPlanets = Get-Planet
    $allPlanets.Count | Should -Be 8
  }

  Context "Filtering by Name" {
    It "Given valid -Name '<Filter>', it returns '<Expected>'" -TestCases @(
      @{ Filter = 'Earth'; Expected = 'Earth' }
      @{ Filter = 'ne*'  ; Expected = 'Neptune' }
      @{ Filter = 'ur*'  ; Expected = 'Uranus' }
      @{ Filter = 'm*'   ; Expected = 'Mercury', 'Mars' }
    ) {
      param ($Filter, $Expected)

      $planets = Get-Planet -Name $Filter
      $planets.Name | Should -Be $Expected
    }

    It "Given invalid parameter -Name 'Alpha Centauri', it returns `$null" {
      $planets = Get-Planet -Name 'Alpha Centauri'
      $planets | Should -Be $null
    }
  }
}
```

Save this code example in a file named `Get-Planet.Tests.ps1`, and run `Invoke-Pester Get-Planet.Tests.ps1`, or just press `F5` in VSCode.

Learn how to [start quick with Pester](https://pester.dev/docs/quick-start) in our docs.

The example above also has an [annotated and production ready version here](docs/Examples/Planets).

## Installation

Pester runs on Windows, Linux, MacOS and anywhere else thanks to PowerShell. It is compatible with Windows PowerShell 3, 4, 5, 6 and 7.

Pester 3 comes pre-installed with Windows 10, but we recommend updating, by running this PowerShell command _as administrator_:

```powershell
Install-Module -Name Pester -Force
```

Not running Windows 10 or facing problems? See the [full installation and update guide](https://pester.dev/docs/introduction/installation).

## Features

### Test runner

Pester runs your tests and prints a nicely formatted output to the screen.

![test run output](images/readme/output.PNG)

Command line output is not the only output option, Pester also integrates with Visual Studio Code, Visual Studio, and any tool that can consume nUnit XML output.

### Assertions

Pester comes with a suite of assertions that cover a lot of common use cases. Pester assertions range from very versatile, like `Should -Be`, to specialized like `Should -Exists`. Here is how you ensure that a file exists:

```powershell
Describe 'Notepad' {
    It 'Exists in Windows folder' {
        'C:\Windows\notepad.exe' | Should -Exist
    }
}
```

Learn more about assertions in [our documentation](https://pester.dev/docs/assertions/should-command).

### Mocking

Pester has mocking built-in. Using mocks you can easily replace functions with empty implementation to avoid changing the real environment.

```powershell
function Remove-Cache {
    Remove-Item "$env:TEMP\cache.txt"
}

Describe 'Remove-Cache' {
    It 'Removes cached results from temp\cache.text' {
        Mock -CommandName Remove-Item -MockWith {}

        Remove-Cache

        Should -Invoke -CommandName Remove-Item -Times 1 -Exactly
    }
}
```

Learn more [about Mocking here](https://pester.dev/docs/usage/mocking).

### Code coverage

Pester can measure how much of your code is covered by tests and export it to JaCoCo format that is easily understood by build servers.

![JaCoCo code coverage report](images/readme/jacoco.PNG)

Learn more about [code coverage here](https://pester.dev/docs/usage/code-coverage).

### Build server integration

Pester integrates nicely with TFS, AppVeyor, TeamCity, Jenkins and other CI servers.

Testing your scripts, and all pull requests on AppVeyor is extremely simple. Just commit this `appveyor.yml` file to your repository, and select your repository on the AppVeyor website:

```yml
version: 1.0.{build}
image:
  - Visual Studio 2017
  - Ubuntu
install:
  - ps: Install-Module Pester -Force -Scope CurrentUser
build: off
test_script:
  - ps: Invoke-Pester -EnableExit
```

See it [in action here!](https://ci.appveyor.com/project/nohwnd/planets)
If you do not need to test your scripts against PowerShell Core, just simply remove the entire line mentioning Ubuntu.

Pester itself is built on AzureDevOps, and distributed mainly via PowerShell gallery.

[![Build Status](https://nohwnd.visualstudio.com/Pester/_apis/build/status/Pester%20PR?branchName=main)](https://nohwnd.visualstudio.com/Pester/_build/latest?definitionId=6&branchName=main) [![latest version](https://img.shields.io/powershellgallery/v/Pester.svg?label=latest+version)](https://www.powershellgallery.com/packages/Pester) [![downloads](https://img.shields.io/powershellgallery/dt/Pester.svg?label=downloads)](https://www.powershellgallery.com/packages/Pester)

## Further reading

Do you like what you see? Learn how to use Pester with our [quick start guide](https://pester.dev/docs/quick-start).

## Got questions?

Got questions or you just want to get in touch? Use our issues page or one of these channels:

[![Pester Twitter](images/readme/twitter-64.PNG)](https://twitter.com/PSPester) [![Pester on StackOverflow](images/readme/stack-overflow-64.PNG)](https://stackoverflow.com/questions/tagged/pester) [![Testing channel on Powershell Slack](images/readme/slack-64.PNG)](https://powershell.slack.com/messages/C03QKTUCS) [![Testing channel on Powershell Discord](images/readme/discord-64.PNG)](https://discord.gg/powershell) or try github discussions <a href="https://github.com/pester/Pester/discussions"><img src="https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png" alt="GitHub discussions" height="64"></a>.

## Sponsored by

Pester is sponsored by [Octopus Deploy](https://octopus.com).

<a href="https://octopus.com"><img src="https://octopus.com/images/company/OctopusDeploy-logo-RGB.svg" alt="Octopus deploy"  height="150"></a>

As well as all the great folks on [OpenCollective](https://opencollective.com/pester) and [GitHub](https://github.com/users/nohwnd/sponsorship#sponsors).


## Contributors

### Code Contributors

This project exists thanks to all the people who contribute. [Contribute code](CONTRIBUTING.md).
<a href="https://github.com/pester/Pester/graphs/contributors"><img src="https://opencollective.com/Pester/contributors.svg?width=890&button=false" /></a>

### Financial Contributors on Open Collective

Become a financial contributor and help us sustain our community. [Contribute to Pester Open Collective](https://opencollective.com/Pester/contribute).

#### Individuals

<a href="https://opencollective.com/Pester"><img src="https://opencollective.com/Pester/individuals.svg?width=890"></a>

#### Organizations

Support this project with your organization. Your logo will show up here with a link to your website. [Contribute](https://opencollective.com/Pester/contribute)

<a href="https://opencollective.com/Pester/organization/0/website"><img src="https://opencollective.com/Pester/organization/0/avatar.svg"></a>
<a href="https://opencollective.com/Pester/organization/1/website"><img src="https://opencollective.com/Pester/organization/1/avatar.svg"></a>
<a href="https://opencollective.com/Pester/organization/2/website"><img src="https://opencollective.com/Pester/organization/2/avatar.svg"></a>
<a href="https://opencollective.com/Pester/organization/3/website"><img src="https://opencollective.com/Pester/organization/3/avatar.svg"></a>
<a href="https://opencollective.com/Pester/organization/4/website"><img src="https://opencollective.com/Pester/organization/4/avatar.svg"></a>
<a href="https://opencollective.com/Pester/organization/5/website"><img src="https://opencollective.com/Pester/organization/5/avatar.svg"></a>
<a href="https://opencollective.com/Pester/organization/6/website"><img src="https://opencollective.com/Pester/organization/6/avatar.svg"></a>
<a href="https://opencollective.com/Pester/organization/7/website"><img src="https://opencollective.com/Pester/organization/7/avatar.svg"></a>
<a href="https://opencollective.com/Pester/organization/8/website"><img src="https://opencollective.com/Pester/organization/8/avatar.svg"></a>
<a href="https://opencollective.com/Pester/organization/9/website"><img src="https://opencollective.com/Pester/organization/9/avatar.svg"></a>
