@{

# Script module or binary module file associated with this manifest.
ModuleToProcess = 'Pester.psm1'

# Version number of this module.
ModuleVersion = '3.0.0'

# ID used to uniquely identify this module
GUID = 'a699dea5-2c73-4616-a270-1f7abb777e71'

# Author of this module
Author = 'Pester Team'

# Company or vendor of this module
CompanyName = 'Pester'

# Description of the functionality provided by this module
Description = 'Pester provides a framework for running Unit Tests to execute and validate PowerShell commands inside of PowerShell.'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '2.0'

# Functions to export from this module
FunctionsToExport = @( 
    'Describe',
    'Context',
    'It',
    'Should',
    'Mock',
    'Assert-MockCalled',
    'Assert-VerifiableMocks',
    'New-Fixture',
    'Get-TestDriveItem',
    'Invoke-Pester',
    'Setup',
    'In',
    'InModuleScope',
    'Invoke-Mock',
    'BeforeEach',
    'AfterEach'
)
}

