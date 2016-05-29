function Set-Fixture {
    <#
    .SYNOPSIS
    This function generates a test scaffold based off an existing function.
    
    .DESCRIPTION
    This function generates a test scaffold based off an existing function. The test file is by default
    placed in the same directory as the function and are called and populated as such:


    The script defining the function: .\Clean.ps1:
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
    Defines the name of the function for the test to be created.

    .EXAMPLE
    Set-Fixture -Name Clean

    Creates the test script based off clean.ps1

    .LINK
    Describe
    Context
    It
    about_Pester
    about_Should
    #>

    param (
        # name of file
        [Parameter(Mandatory=$true)]
        [String]
        $Name
    )
    
    # Test if file exists, if not, fall back to New-Fixture
    if(!(Test-Path -path ./$name.ps1))    
        {
            New-Fixture -name $name -path $($pwd)
            Return 
        }    
        
    $path = Split-Path (get-item "./$name.ps1").FullName -Parent
    
            
    #region File contents
    #keep this formatted as is. the format is output to the file as is, including indentation

    $testCode = '$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace ''\.Tests\.'', ''.''
. "$here\$sut"

Describe "#name#" {
    It "does something useful" {
        $true | Should Be $false
    }
}' -replace "#name#",$name

    #endregion

    $Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)

    Create-File -Path $Path -Name "$Name.Tests.ps1" -Content $testCode
}

function Create-File ($Path,$Name,$Content) {
    if (-not (& $SafeCommands['Test-Path'] -Path $Path)) {
        & $SafeCommands['New-Item'] -ItemType Directory -Path $Path | & $SafeCommands['Out-Null']
    }

    $FullPath = & $SafeCommands['Join-Path'] -Path $Path -ChildPath $Name
    if (-not (& $SafeCommands['Test-Path'] -Path $FullPath)) {
        & $SafeCommands['Set-Content'] -Path  $FullPath -Value $Content -Encoding UTF8
        & $SafeCommands['Get-Item'] -Path $FullPath
    }
    else
    {
        # This is deliberately not sent through $SafeCommands, because our own tests rely on
        # mocking Write-Warning, and it's not really the end of the world if this call happens to
        # be screwed up in an edge case.
        Write-Warning "Skipping the file '$FullPath', because it already exists."
    }
}
