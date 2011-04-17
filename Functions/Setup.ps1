$global:TestDrive = "$env:Temp\pester"

function Initialize-Setup() {
    if (Test-Path TestDrive:) { return }

    New-Item -Name pester -Path $env:Temp -Type Container -Force | Out-Null
    New-PSDrive -Name TestDrive -PSProvider FileSystem -Root "$($env:Temp)\pester" -Scope Global | Out-Null
}

function Setup([switch] $Dir, [switch] $File, $Path, $Content = "") {
    Initialize-Setup

    if ($Dir) {
        New-Item -Name $Path -Path TestDrive: -Type Container -Force | Out-Null
    } elseif ($File) {
        $Content | New-Item -Name $Path -Path TestDrive: -Type File -Force | Out-Null
    }
}
