#
function New-TestDrive ([Switch]$PassThru, [string] $Path) {
    if ($Path -notmatch '\S') {
        $directory = New-RandomTempDirectory
    }
    else {
        if (-not (& $SafeCommands['Test-Path'] -Path $Path)) {
            $null = & $SafeCommands['New-Item'] -ItemType Container -Path $Path
        }

        $directory = & $SafeCommands['Get-Item'] $Path
    }

    $DriveName = "TestDrive"

    #setup the test drive
    if ( -not (& $SafeCommands['Test-Path'] "${DriveName}:\") ) {
        $null = & $SafeCommands['New-PSDrive'] -Name $DriveName -PSProvider FileSystem -Root $directory -Scope Global -Description "Pester test drive"
    }

    #publish the global TestDrive variable used in few places within the module
    if (-not (& $SafeCommands['Test-Path'] "Variable:Global:$DriveName")) {
        & $SafeCommands['New-Variable'] -Name $DriveName -Scope Global -Value $directory
    }

    if ( $PassThru ) {
        & $SafeCommands['Get-PSDrive'] -Name $DriveName
    }
}


function Clear-TestDrive ([String[]]$Exclude) {
    $Path = (& $SafeCommands['Get-PSDrive'] -Name TestDrive).Root
    if (& $SafeCommands['Test-Path'] -Path $Path ) {

        Remove-TestDriveSymbolicLinks -Path $Path

        #Get-ChildItem -Exclude did not seem to work with full paths
        & $SafeCommands['Get-ChildItem'] -Recurse -Path $Path |
            & $SafeCommands['Sort-Object'] -Descending  -Property "FullName" |
            & $SafeCommands['Where-Object'] { $Exclude -NotContains $_.FullName } |
            & $SafeCommands['Remove-Item'] -Force -Recurse

    }
}

function New-RandomTempDirectory {
    do {
        $tempPath = Get-TempDirectory
        $Path = & $SafeCommands['Join-Path'] -Path $tempPath -ChildPath ([Guid]::NewGuid())
    } until (-not (& $SafeCommands['Test-Path'] -Path $Path ))

    & $SafeCommands['New-Item'] -ItemType Container -Path $Path
}

function Get-TestDriveItem {
    <#
    .SYNOPSIS
    The Get-TestDriveItem cmdlet gets the item in Pester test drive.

    .DESCRIPTION
    The Get-TestDriveItem cmdlet gets the item in Pester test drive. It does not
    get the contents of the item at the location unless you use a wildcard
    character (*) to request all the contents of the item.

    The function Get-TestDriveItem is deprecated since Pester v. 4.0
    and will be deleted in the next major version of Pester.

    .PARAMETER Path
    Specifies the path to an item. The path need to be relative to TestDrive:.
    This cmdlet gets the item at the specified location. Wildcards are permitted.
    This parameter is required, but the parameter name ("Path") is optional.

    .EXAMPLE

    Get-TestDriveItem MyTestFolder\MyTestFile.txt

    This command returns the file MyTestFile.txt located in the folder MyTestFolder
    what is located under TestDrive.

    .LINK
    https://github.com/pester/Pester/wiki/TestDrive
    about_TestDrive
#>

    #moved here from Pester.psm1
    param ([string]$Path)

    & $SafeCommands['Write-Warning'] -Message "The function Get-TestDriveItem is deprecated since Pester 4.0.0 and will be removed from Pester 5.0.0."

    Assert-DescribeInProgress -CommandName Get-TestDriveItem
    & $SafeCommands['Get-Item'] $(& $SafeCommands['Join-Path'] $TestDrive $Path )
}

function Get-TestDriveChildItem {
    $Path = (& $SafeCommands['Get-PSDrive'] -Name TestDrive).Root
    if (& $SafeCommands['Test-Path'] -Path $Path ) {
        & $SafeCommands['Get-ChildItem'] -Recurse -Path $Path
    }
}

function Remove-TestDriveSymbolicLinks ([String] $Path) {

    # remove symbolic links to work around problem with Remove-Item.
    # see https://github.com/PowerShell/PowerShell/issues/621
    #     https://github.com/pester/Pester/issues/1100

    # powershell 5 and higher
    # & $SafeCommands["Get-ChildItem"] -Recurse -Path $Path -Attributes "ReparsePoint" |
    #    % { $_.Delete() }

    # powershell 2-compatible
    $reparsePoint = [System.IO.FileAttributes]::ReparsePoint
    & $SafeCommands["Get-ChildItem"] -Recurse -Path $Path |
        where-object { ($_.Attributes -band $reparsePoint) -eq $reparsePoint } |
        % { $_.Delete() }

}

function Remove-TestDrive {

    $DriveName = "TestDrive"
    $Drive = & $SafeCommands['Get-PSDrive'] -Name $DriveName -ErrorAction $script:IgnoreErrorPreference
    $Path = ($Drive).Root


    if ($pwd -like "$DriveName*" ) {
        #will staying in the test drive cause issues?
        #TODO review this
        & $SafeCommands['Write-Warning'] -Message "Your current path is set to ${pwd}:. You should leave ${DriveName}:\ before leaving Describe."
    }

    if ( $Drive ) {
        $Drive | & $SafeCommands['Remove-PSDrive'] -Force #This should fail explicitly as it impacts future pester runs
    }

    Remove-TestDriveSymbolicLinks -Path $Path

    if (& $SafeCommands['Test-Path'] -Path $Path) {
        & $SafeCommands['Remove-Item'] -Path $Path -Force -Recurse
    }

    if (& $SafeCommands['Get-Variable'] -Name $DriveName -Scope Global -ErrorAction $script:IgnoreErrorPreference) {
        & $SafeCommands['Remove-Variable'] -Scope Global -Name $DriveName -Force
    }
}

function Setup {
    <#
        .SYNOPSIS
        This command is included in the Pester Mocking framework for backwards compatibility.  You do not need to call it directly.
    #>
    param(
        [switch]$Dir,
        [switch]$File,
        $Path,
        $Content = "",
        [switch]$PassThru
    )

    Assert-DescribeInProgress -CommandName Setup

    $TestDriveName = & $SafeCommands['Get-PSDrive'] TestDrive |
        & $SafeCommands['Select-Object'] -ExpandProperty Root

    if ($Dir) {
        $item = & $SafeCommands['New-Item'] -Name $Path -Path "${TestDriveName}\" -Type Container -Force
    }
    if ($File) {
        $item = $Content | & $SafeCommands['New-Item'] -Name $Path -Path "${TestDriveName}\" -Type File -Force
    }

    if ($PassThru) {
        return $item
    }
}
