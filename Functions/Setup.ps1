$global:TestDrive = "$env:Temp\pester"
$global:TestDrive = [System.IO.Path]::GetFullPath($TestDrive)

function Initialize-Setup {
    if (Test-Path TestDrive:) { return }

    New-Item -Name pester -Path $env:Temp -Type Container -Force | Out-Null
    New-PSDrive -Name TestDrive -PSProvider FileSystem -Root "$($env:Temp)\pester" -Scope Global | Out-Null
}

function Setup {
	param(
		[switch]$Dir, 
		[switch]$File, 
		$Path, 
		$Content = "",
		[switch]$PassThru
	)
    Initialize-Setup

    if ($Dir) {
        $item = New-Item -Name $Path -Path TestDrive: -Type Container -Force
    } elseif ($File) {
        $item = $Content | New-Item -Name $Path -Path TestDrive: -Type File -Force
    }
	
	if($PassThru) {
		return $item
	}
}
