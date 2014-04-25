#
function New-TestDrive ([Switch]$PassThru) {
	
    
	$Path = New-RandomTempDirectory
	$DriveName = "TestDrive"
	
	if (-not (Test-Path -Path $Path))
	{
		New-Item -ItemType Container -Path $Path | Out-Null
	}
	
	#setup the test drive
	if ( -not (Get-PSDrive -Name $DriveName -ErrorAction SilentlyContinue) ) 
	{
		New-PSDrive -Name $DriveName -PSProvider FileSystem -Root $Path -Scope Global -Description "Pester test drive" | Out-Null
	}
	
    #publish the global TestDrive variable used in few places within the module
	if (-not (Get-Variable -Name $DriveName -Scope Global -ErrorAction SilentlyContinue)) 
	{
		New-Variable -Name $DriveName -Scope Global -Value $Path
	}
	
	if ( $PassThru ) { Get-PSDrive -Name $DriveName }
}


function Clear-TestDrive ([String[]]$Exclude) {
    
    $Path = (Get-PSDrive -Name TestDrive).Root
	if (Test-Path -Path $Path )
	{
		#Get-ChildItem -Exclude did not seem to work with full paths
		Get-ChildItem -Recurse -Path $Path |
			Sort-Object -Descending  -Property "FullName" |
			where { $Exclude -NotContains $_.FullName } |
			Microsoft.PowerShell.Management\Remove-Item -Force -Recurse
	}
}

function New-RandomTempDirectory {
    do 
    {
        $Path = Join-Path -Path $env:TEMP -ChildPath ([Guid]::NewGuid())
	} until (-not ( Test-Path -Path $Path ))
    
    New-Item -ItemType Container -Path $Path
}

function Get-TestDriveItem {
    #moved here from Pester.psm1
	param( [string]$Path )
    $result = Get-Item $(Join-Path $TestDrive $Path )
    return $result
}

function Get-TestDriveChildItem {
	$Path = (Get-PSDrive -Name TestDrive).Root
	if (Test-Path -Path $Path )
	{
		Get-ChildItem -Recurse -Path $Path
	}
}

function Remove-TestDrive {
    
	$DriveName = "TestDrive"
    $Drive = Get-PSDrive -Name $DriveName -ErrorAction SilentlyContinue
    $Path = ($Drive).Root
    
	
	if ($pwd -like "$DriveName*" ) {
		#will staying in the test drive cause issues?
		#TODO review this
		Write-Warning -Message "Your current path is set to ${pwd}:. You should leave ${DriveName}:\ before leaving Describe."
	}
	
	if ( $Drive ) 
	{
		$Drive | Remove-PSDrive -Force -ErrorAction SilentlyContinue
	}

	if (Test-Path -Path $Path)
	{
		Microsoft.PowerShell.Management\Remove-Item -Path $Path -Force -Recurse 
	}
	
	if (Get-Variable -Name $DriveName -Scope Global -ErrorAction SilentlyContinue) {
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
    $TestDriveName = "TestDrive"

    if ($Dir) {
        $item = New-Item -Name $Path -Path "${TestDriveName}:" -Type Container -Force
    }
	if ($File) {
        $item = $Content | New-Item -Name $Path -Path "${TestDriveName}:" -Type File -Force
    }

    if($PassThru) {
        return $item
    }
}


	

