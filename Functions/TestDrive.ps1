#
function New-TestDrive ([Switch]$PassThru) {
    $Path = New-RandomTempDirectory
    $DriveName = "TestDrive"

    if (-not (& $SafeCommands['Test-Path'] -Path $Path))
    {
        & $SafeCommands['New-Item'] -ItemType Container -Path $Path | & $SafeCommands['Out-Null']
    }

    #setup the test drive
    if ( -not (& $SafeCommands['Test-Path'] "${DriveName}:\") )
    {
        & $SafeCommands['New-PSDrive'] -Name $DriveName -PSProvider FileSystem -Root $Path -Scope Global -Description "Pester test drive" | & $SafeCommands['Out-Null']
    }

    #publish the global TestDrive variable used in few places within the module
    if (-not (& $SafeCommands['Test-Path'] "Variable:Global:DriveName"))
    {
        & $SafeCommands['New-Variable'] -Name $DriveName -Scope Global -Value $Path
    }

    if ( $PassThru ) { & $SafeCommands['Get-PSDrive'] -Name $DriveName }
}


function Clear-TestDrive ([String[]]$Exclude) {
    $Path = (& $SafeCommands['Get-PSDrive'] -Name TestDrive).Root
    if (& $SafeCommands['Test-Path'] -Path $Path )
    {
        #Get-ChildItem -Exclude did not seem to work with full paths
        & $SafeCommands['Get-ChildItem'] -Recurse -Path $Path |
        & $SafeCommands['Sort-Object'] -Descending  -Property "FullName" |
        & $SafeCommands['Where-Object'] { $Exclude -NotContains $_.FullName } |
        & $SafeCommands['Remove-Item'] -Force -Recurse
    }
}

function New-RandomTempDirectory {
    do
    {
        $Path = & $SafeCommands['Join-Path'] -Path $env:TEMP -ChildPath ([Guid]::NewGuid())
    } until (-not (& $SafeCommands['Test-Path'] -Path $Path ))

    & $SafeCommands['New-Item'] -ItemType Container -Path $Path
}

function Get-TestDriveItem {
    #moved here from Pester.psm1
    param( [string]$Path )

    Assert-DescribeInProgress -CommandName Get-TestDriveItem
    & $SafeCommands['Get-Item'] $(& $SafeCommands['Join-Path'] $TestDrive $Path )
}

function Get-TestDriveChildItem {
    $Path = (& $SafeCommands['Get-PSDrive'] -Name TestDrive).Root
    if (& $SafeCommands['Test-Path'] -Path $Path )
    {
        & $SafeCommands['Get-ChildItem'] -Recurse -Path $Path
    }
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

    if ( $Drive )
    {
        $Drive | & $SafeCommands['Remove-PSDrive'] -Force -ErrorAction $script:IgnoreErrorPreference
    }

    if (& $SafeCommands['Test-Path'] -Path $Path)
    {
        & $SafeCommands['Remove-Item'] -Path $Path -Force -Recurse
    }

    if (& $SafeCommands['Get-Variable'] -Name $DriveName -Scope Global -ErrorAction $script:IgnoreErrorPreference) {
        & $SafeCommands['Remove-Variable'] -Scope Global -Name $DriveName -Force
    }
}

function Setup {
    #included for backwards compatibility
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

    if($PassThru) {
        return $item
    }
}
