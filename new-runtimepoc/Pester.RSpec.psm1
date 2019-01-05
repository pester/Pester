function Find-RSpecTestFile ($Path) {
    Get-ChildItem -Path $Path -Filter *.Tests.ps1
}