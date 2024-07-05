function New-Fixture {
    <#
    .SYNOPSIS
    This function generates two scripts, one that defines a function
    and another one that contains its tests.

    .DESCRIPTION
    This function generates two scripts, one that defines a function
    and another one that contains its tests. The files are by default
    placed in the current directory and are called and populated as such:

    The script defining the function: .\Clean.ps1:

    ```powershell
    function Clean {
        throw [NotImplementedException]'Clean is not implemented.'
    }
    ```

    The script containing the example test .\Clean.Tests.ps1:

    ```powershell
    BeforeAll {
        . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    }

    Describe "Clean" {

        It "Returns expected output" {
            Clean | Should -Be "YOUR_EXPECTED_VALUE"
        }
    }
    ```

    .PARAMETER Name
    Defines the name of the function and the name of the test to be created.

    .PARAMETER Path
    Defines path where the test and the function should be created, you can use full or relative path.
    If the parameter is not specified the scripts are created in the current directory.

    .EXAMPLE
    New-Fixture -Name Clean

    Creates the scripts in the current directory.

    .EXAMPLE
    New-Fixture Clean C:\Projects\Cleaner

    Creates the scripts in the C:\Projects\Cleaner directory.

    .EXAMPLE
    New-Fixture -Name Clean -Path Cleaner

    Creates a new folder named Cleaner in the current directory and creates the scripts in it.

    .LINK
    https://pester.dev/docs/commands/New-Fixture

    .LINK
    https://pester.dev/docs/commands/Describe

    .LINK
    https://pester.dev/docs/commands/Context

    .LINK
    https://pester.dev/docs/commands/It

    .LINK
    https://pester.dev/docs/commands/Should
    #>
    [OutputType([System.IO.FileInfo])]
    param (
        [Parameter(Mandatory = $true)]
        [String]$Name,
        [String]$Path = $PWD
    )

    $Name = $Name -replace '.ps(m?)1', ''

    if ($Name -notmatch '^\S+$') {
        throw 'Name is not valid. Whitespace are not allowed in a function name.'
    }

    #keep this formatted as is. the format is output to the file as is, including indentation
    $scriptCode = "function $Name {
    throw [NotImplementedException]'$Name is not implemented.'
}"

    $testCode = 'BeforeAll {
    . $PSCommandPath.Replace(''.Tests.ps1'', ''.ps1'')
}

Describe "#name#" {
    It "Returns expected output" {
        #name# | Should -Be "YOUR_EXPECTED_VALUE"
    }
}' -replace '#name#', $Name

    $Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)

    Create-File -Path $Path -Name "$Name.ps1" -Content $scriptCode
    Create-File -Path $Path -Name "$Name.Tests.ps1" -Content $testCode
}

function Create-File {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('Pester.BuildAnalyzerRules\Measure-SafeCommands', 'Write-Warning', Justification = 'Mocked in unit test for New-Fixture.')]
    [OutputType([System.IO.FileInfo])]
    param($Path, $Name, $Content)
    if (-not (& $SafeCommands['Test-Path'] -Path $Path)) {
        & $SafeCommands['New-Item'] -ItemType Directory -Path $Path | & $SafeCommands['Out-Null']
    }

    $FullPath = & $SafeCommands['Join-Path'] -Path $Path -ChildPath $Name
    if (-not (& $SafeCommands['Test-Path'] -Path $FullPath)) {
        & $SafeCommands['Set-Content'] -Path  $FullPath -Value $Content -Encoding UTF8
        & $SafeCommands['Get-Item'] -Path $FullPath
    }
    else {
        # This is deliberately not sent through $SafeCommands, because our own tests rely on
        # mocking Write-Warning, and it's not really the end of the world if this call happens to
        # be screwed up in an edge case.
        Write-Warning "Skipping the file '$FullPath', because it already exists."
    }
}
