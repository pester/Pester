@{

    # Script module or binary module file associated with this manifest.
    ModuleToProcess   = 'Pester.psm1'

    # Version number of this module.
    ModuleVersion     = '4.6.0'

    # ID used to uniquely identify this module
    GUID              = 'a699dea5-2c73-4616-a270-1f7abb777e71'

    # Author of this module
    Author            = 'Pester Team'

    # Company or vendor of this module
    CompanyName       = 'Pester'

    # Copyright statement for this module
    Copyright         = 'Copyright (c) 2017 by Pester Team, licensed under Apache 2.0 License.'

    # Description of the functionality provided by this module
    Description       = 'Pester provides a framework for running BDD style Tests to execute and validate PowerShell commands inside of PowerShell and offers a powerful set of Mocking Functions that allow tests to mimic and mock the functionality of any command inside of a piece of PowerShell code being tested. Pester tests can execute any command or script that is accessible to a pester test file. This can include functions, Cmdlets, Modules and scripts. Pester can be run in ad hoc style in a console or it can be integrated into the Build scripts of a Continuous Integration system.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '2.0'

    TypesToProcess    = @('.\Functions\Gherkin.types.ps1xml')

    # Functions to export from this module
    FunctionsToExport = @(
        'Describe'
        'Context'
        'It'
        'Should'
        'Mock'
        'Assert-MockCalled'
        'Assert-VerifiableMock'
        'Assert-VerifiableMocks'
        'New-Fixture'
        'Get-TestDriveItem'
        'Invoke-Pester'
        'Setup'
        'In'
        'InModuleScope'
        'Invoke-Mock'
        'BeforeEach'
        'AfterEach'
        'BeforeAll'
        'AfterAll'
        'Get-MockDynamicParameter'
        'Set-DynamicParameterVariable'
        'Set-TestInconclusive'
        'Set-ItResult'
        'SafeGetCommand'
        'New-PesterOption'
        'New-MockObject'
        'Add-AssertionOperator'
        'Get-ShouldOperator'

        # Gherkin Support:
        'Invoke-Gherkin'
        'Invoke-GherkinStep'
        'Find-GherkinStep'
        'GherkinStep'
        'BeforeEachFeature'
        'AfterEachFeature'
        'BeforeEachScenario'
        'AfterEachScenario'
    )

    # # Cmdlets to export from this module
    # CmdletsToExport = '*'

    # Variables to export from this module
    VariablesToExport = @(
        'Path'
        'TagFilter'
        'ExcludeTagFilter'
        'TestNameFilter'
        'TestResult'
        'CurrentContext'
        'CurrentDescribe'
        'CurrentTest'
        'SessionState'
        'CommandCoverage'
        'BeforeEach'
        'AfterEach'
        'Strict'
    )

    # # Aliases to export from this module
    AliasesToExport   = @(
        'Given'
        'When'
        'Then'
        'And'
        'But'

        'Add-ShouldOperator'
    )


    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    # FileList = @()

    PrivateData       = @{
        # PSData is module packaging and gallery metadata embedded in PrivateData
        # It's for rebuilding PowerShellGet (and PoshCode) NuGet-style packages
        # We had to do this because it's the only place we're allowed to extend the manifest
        # https://connect.microsoft.com/PowerShell/feedback/details/421837
        PSData = @{
            # The primary categorization of this module (from the TechNet Gallery tech tree).
            Category     = "Scripting Techniques"

            # Keyword tags to help users find this module via navigations and search.
            Tags         = @('powershell', 'unit_testing', 'bdd', 'tdd', 'mocking', 'PSEdition_Core', 'PSEdition_Desktop')

            # The web address of an icon which can be used in galleries to represent this module
            IconUri      = 'https://raw.githubusercontent.com/pester/Pester/master/images/pester.PNG'

            # The web address of this module's project or support homepage.
            ProjectUri   = "https://github.com/Pester/Pester"

            # The web address of this module's license. Points to a page that's embeddable and linkable.
            LicenseUri   = "https://www.apache.org/licenses/LICENSE-2.0.html"

            # Release notes for this particular version of the module
            ReleaseNotes = 'https://github.com/pester/Pester/releases/tag/4.6.0'

            # Prerelease string of this module
            Prerelease   = ''
        }
    }

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''

}
