Since version 4.1.0 Pester is compatible with [PowerShell Core 6.x](https://github.com/powershell/powershell) with some limitations listed below

- Pester unit tests for test a code coverage of DSC resources can't be executed - DSC is not supported on MacOSX, support on Linux [requires additional software to be installed](https://docs.microsoft.com/en-us/powershell/dsc/lnxgettingstarted). Please read also [DSC Future Direction Update](https://blogs.msdn.microsoft.com/powershell/2017/09/12/dsc-future-direction-update/) on the PowerShell Team Blog
- An error ```call depth overflow``` on macOS - [please check](https://github.com/PowerShell/PowerShell/issues/4268) - the one failing test (in the file Functions/Assertions/Be.Tests.ps1) in Pester is disabled due that bug

Please remember that not only Pester need to be aligned to work on PowerShell Core 6.x. Also your test need to be aligned - please check the reference [[Development rules - technical]] to read more.
