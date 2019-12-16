## General rules

- any new feature requires tests for itself
- any new publicly exposed (exported) function need to have comment based help fulfilled
- any file needs to end with an empty line
- no trailing space in any lines
- for indentation please use spaces, not tabs
- use Pester v4 notation for assertions e.g. ```1 | Should -Be 1``` not ```1 | Should Be 1```
- avoid using aliases - specially ```?```,```%``` and other "one letters"
- before push code to the Pester GitHub repository run tests for Pester code
- all tests need to be run with ```Set-StrictMode -Version Latest```
- supported versions of Windows PowerShell 2.0 - 5.x and PowerShell Core 6.x, please make your code compatible with them

## PowerShell Core compatibility rules

Due that Pester is now supported (since v. 4.1.0) also on PowerShell Core 6.x is now available for operating system different than Windows, please:

- use ```[System.Environment]::NewLine``` instead of `` `n``, `\n`, `` `r``, `\r` or combination of them
- remember that the EOL (end of a line) chars in files added to the Pester repository will be converted to Windows style automatically by git - it's configured by attributes set in [.gitattributes](https://git-scm.com/docs/gitattributes) so you can see something like

```cmd
PS <FOLDER_PATH>/Pester> git add .
warning: LF will be replaced by CRLF in Examples/Calculator/Add-Numbers.Tests.ps1.
The file will have its original line endings in your working directory.
```

- remember that if you would like to add any binary file e.g. graphics file to the Pester repository you need to align settings in the .gitattributes file
- use ```Join-Path``` or String constructors containing ```[System.IO.Path]::DirectorySeparatorChar``` instead of direct use of ```\```
- remember that in some cases references in the code are case sensitive e.g. in paths PowerShell on Linux and macOS (?)

Please read also [[Pester on PSCore -limitations|Pester-on-PSCore-limitations.md]].

## Working on non-Windows systems - remarks

If you share your local repository folder between Windows and Linux (e.g. by mounting/sharing it to a virtual machine) please set in the repository settings ```filemode = false``` - it needs to be done in the file .git\config. If you don't do it permissions on files will be changed what cause that files will be recognized by Git as modified.
