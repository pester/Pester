function Cleanup {
    Clear-Mocks
	if (Test-Path $TestDrive) {
		Remove-Item $TestDrive -Recurse -Force -ErrorAction:SilentlyContinue
        Remove-PSDrive -Name TestDrive -Scope Global -Force -ErrorAction:SilentlyContinue
    }    
}
