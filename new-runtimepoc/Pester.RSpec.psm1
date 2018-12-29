function Find-TestFiles ($Path) {
    Get-ChildItem -Path $Path -Filter *.Tests.ps1 | % FullName
}