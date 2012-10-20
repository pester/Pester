function Cleanup() {
    if (Test-Path $TestDrive) {
        Remove-Item $TestDrive -Recurse -Force
        Remove-PSDrive -Name TestDrive -Scope Global -Force
    }
    Clear-Mocks
}
