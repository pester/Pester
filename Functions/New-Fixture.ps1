function New-Fixture {
    <#
    .SYNOPSIS
    This function generates two scripts, one that defines a function
    and another one that contains its tests.

    .DESCRIPTION
    This function generates two scripts, one that defines a function
    and another one that contains its tests. The files are by default
    placed in the current directory and are called and populated as such:


    The script defining the funciton: .\Clean.ps1:

    function Clean {

    }

    The script containg the example test .\Clean.Tests.ps1:

    $here = Split-Path -Parent $MyInvocation.MyCommand.Path
    $sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
    . "$here\$sut"

    Describe "Clean" {

        It "does something useful" {
            $false | Should Be $true
        }
    }


    .PARAMETER Name
    Defines the name of the function and the name of the test to be created.

    .PARAMETER Path
    Defines path where the test and the function should be created, you can use full or relative path.
    If the parameter is not specified the scripts are created in the current directory.

    .EXAMPLE
    New-Fixture -Name Clean

    Creates the scripts in the current directory.

    .EXAMPLE
    New-Fixture C:\Projects\Cleaner Clean

    Creates the scripts in the C:\Projects\Cleaner directory.

    .EXAMPLE
    New-Fixture Cleaner Clean

    Creates a new folder named Cleaner in the current directory and creates the scripts in it.

    .LINK
    Describe
    Context
    It
    about_Pester
    about_Should
    #>

    param (
        [String]$Path = $PWD,
        [Parameter(Mandatory=$true)]
        [String]$Name
    )
    #region File contents
    #keep this formatted as is. the format is output to the file as is, including indentation
    $scriptCode = "function $name {`r`n`r`n}"

    $testCode = '$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe "#name#" {
    It "does something useful" {
        $true | Should Be $false
    }
}' -replace "#name#",$name

    #endregion

    $Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)

    Create-File -Path $Path -Name "$Name.ps1" -Content $scriptCode
    Create-File -Path $Path -Name "$Name.Tests.ps1" -Content $testCode
}

function Create-File ($Path,$Name,$Content) {
    if (-not (Test-Path -Path $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }

    $FullPath = Join-Path -Path $Path -ChildPath $Name
    if (-not (Test-Path -Path $FullPath)) {
        Set-Content -Path  $FullPath -Value $Content -Encoding UTF8
        Get-Item -Path $FullPath
    }
    else
    {
        Write-Warning "Skipping the file '$FullPath', because it already exists."
    }
}
