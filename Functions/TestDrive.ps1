#
function New-TestDrive ([Switch]$PassThru) {
    $Path = New-RandomTempDirectory
    $DriveName = "TestDrive"

    if (-not (Microsoft.PowerShell.Management\Test-Path -Path $Path))
    {
        New-Item -ItemType Container -Path $Path | Out-Null
    }

    #setup the test drive
    if ( -not (Test-Path "${DriveName}:\") )
    {
        New-PSDrive -Name $DriveName -PSProvider FileSystem -Root $Path -Scope Global -Description "Pester test drive" | Out-Null
    }

    #publish the global TestDrive variable used in few places within the module
    if (-not (Test-Path "Variable:Global:DriveName"))
    {
        New-Variable -Name $DriveName -Scope Global -Value $Path
    }

    if ( $PassThru ) { Get-PSDrive -Name $DriveName }
}


function Clear-TestDrive ([String[]]$Exclude) {
    $Path = (Microsoft.PowerShell.Management\Get-PSDrive -Name TestDrive).Root
    if (Microsoft.PowerShell.Management\Test-Path -Path $Path )
    {
        #Get-ChildItem -Exclude did not seem to work with full paths
        Microsoft.PowerShell.Management\Get-ChildItem -Recurse -Path $Path |
        Microsoft.PowerShell.Utility\Sort-Object -Descending  -Property "FullName" |
        Microsoft.PowerShell.Core\Where-Object { $Exclude -NotContains $_.FullName } |
        Microsoft.PowerShell.Management\Remove-Item -Force -Recurse
    }
}

function New-RandomTempDirectory {
    do
    {
        $Path = Join-Path -Path $env:TEMP -ChildPath ([Guid]::NewGuid())
    } until (-not (  Microsoft.PowerShell.Management\Test-Path -Path $Path ))

    New-Item -ItemType Container -Path $Path
}

function Get-TestDriveItem {
    #moved here from Pester.psm1
    param( [string]$Path )

    Assert-DescribeInProgress -CommandName Get-TestDriveItem
    Get-Item $(Join-Path $TestDrive $Path )
}

function Get-TestDriveChildItem {
    $Path = (Microsoft.PowerShell.Management\Get-PSDrive -Name TestDrive).Root
    if (Microsoft.PowerShell.Management\Test-Path -Path $Path )
    {
        Microsoft.PowerShell.Management\Get-ChildItem -Recurse -Path $Path
    }
}

function Remove-TestDrive {

    $DriveName = "TestDrive"
    $Drive = Get-PSDrive -Name $DriveName -ErrorAction $script:IgnoreErrorPreference
    $Path = ($Drive).Root


    if ($pwd -like "$DriveName*" ) {
        #will staying in the test drive cause issues?
        #TODO review this
        Write-Warning -Message "Your current path is set to ${pwd}:. You should leave ${DriveName}:\ before leaving Describe."
    }

    if ( $Drive )
    {
        $Drive | Remove-PSDrive -Force -ErrorAction $script:IgnoreErrorPreference
    }

    if (Microsoft.PowerShell.Management\Test-Path -Path $Path)
    {
        Microsoft.PowerShell.Management\Remove-Item -Path $Path -Force -Recurse
    }

    if (Get-Variable -Name $DriveName -Scope Global -ErrorAction $script:IgnoreErrorPreference) {
        Remove-Variable -Scope Global -Name $DriveName -Force
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

    $TestDriveName = Get-PSDrive TestDrive | Select -ExpandProperty Root

    if ($Dir) {
        $item = New-Item -Name $Path -Path "${TestDriveName}\" -Type Container -Force
    }
    if ($File) {
        $item = $Content | New-Item -Name $Path -Path "${TestDriveName}\" -Type File -Force
    }

    if($PassThru) {
        return $item
    }
}
