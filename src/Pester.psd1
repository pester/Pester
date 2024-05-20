﻿@{

    # Script module or binary module file associated with this manifest.
    RootModule        = 'Pester.psm1'

    # Version number of this module.
    ModuleVersion     = '6.0.0'

    # ID used to uniquely identify this module
    GUID              = 'a699dea5-2c73-4616-a270-1f7abb777e71'

    # Author of this module
    Author            = 'Pester Team'

    # Company or vendor of this module
    CompanyName       = 'Pester'

    # Copyright statement for this module
    Copyright         = 'Copyright (c) 2024 by Pester Team, licensed under Apache 2.0 License.'

    # Description of the functionality provided by this module
    Description       = 'Pester provides a framework for running BDD style Tests to execute and validate PowerShell commands inside of PowerShell and offers a powerful set of Mocking Functions that allow tests to mimic and mock the functionality of any command inside of a piece of PowerShell code being tested. Pester tests can execute any command or script that is accessible to a pester test file. This can include functions, Cmdlets, Modules and scripts. Pester can be run in ad hoc style in a console or it can be integrated into the Build scripts of a Continuous Integration system.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Type files (.ps1xml) to be loaded when importing this module
    TypesToProcess    = @()

    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess  = @('Pester.Format.ps1xml', 'PesterConfiguration.Format.ps1xml')

    # Functions to export from this module
    FunctionsToExport = @(
        'Invoke-Pester'

        # blocks
        'Describe'
        'Context'
        'It'

        # mocking
        'Mock'
        'InModuleScope'

        # setups
        'BeforeDiscovery'
        'BeforeAll'
        'BeforeEach'
        'AfterEach'
        'AfterAll'

        # should
        'Should'
        'Add-ShouldOperator'
        'Get-ShouldOperator'

        # export
        'Export-NUnitReport'
        'ConvertTo-NUnitReport'
        'Export-JUnitReport'
        'ConvertTo-JUnitReport'
        'ConvertTo-Pester4Result'

        # config
        'New-PesterContainer'
        'New-PesterConfiguration'

        # assert
        'Assert-False'
        'Assert-True'
        'Assert-Falsy'
        'Assert-Truthy'
        'Assert-All'
        'Assert-Any'
        'Assert-Contain'
        'Assert-NotContain'
        'Assert-Collection'
        'Assert-Equivalent'
        'Assert-Throw'
        'Assert-Equal'
        'Assert-GreaterThan'
        'Assert-GreaterThanOrEqual'
        'Assert-LessThan'
        'Assert-LessThanOrEqual'
        'Assert-NotEqual'
        'Assert-NotNull'
        'Assert-NotSame'
        'Assert-NotType'
        'Assert-Null'
        'Assert-Same'
        'Assert-Type'
        'Assert-Like'
        'Assert-NotLike'
        'Assert-StringEqual'
        'Assert-StringNotEqual'
        'Assert-StringEmpty'
        'Assert-StringNotWhiteSpace'
        'Assert-StringNotEmpty'
        'Assert-Faster'
        'Assert-Slower'
        'Assert-Before'
        'Assert-After'

        'Get-EquivalencyOption'

        # legacy
        'Assert-VerifiableMock'
        'Assert-MockCalled'
        'Set-ItResult'
        'New-MockObject'

        'New-Fixture'
    )

    # # Cmdlets to export from this module
    CmdletsToExport   = ''

    # Variables to export from this module
    VariablesToExport = @()

    # # Aliases to export from this module
    AliasesToExport   = @(
        'Add-AssertionOperator'
        'Get-AssertionOperator'

        # assertion functions
        # bool
        'Should-BeFalse'
        'Should-BeTrue'
        'Should-BeFalsy'
        'Should-BeTruthy'

        # collection
        'Should-All'
        'Should-Any'
        'Should-ContainCollection'
        'Should-NotContainCollection'
        'Should-BeCollection'
        'Should-BeEquivalent'
        'Should-Throw'
        'Should-Be'
        'Should-BeGreaterThan'
        'Should-BeGreaterThanOrEqual'
        'Should-BeLessThan'
        'Should-BeLessThanOrEqual'
        'Should-NotBe'
        'Should-NotBeNull'
        'Should-NotBeSame'
        'Should-NotHaveType'
        'Should-BeNull'
        'Should-BeSame'
        'Should-HaveType'

        # string
        'Should-BeString'
        'Should-NotBeString'

        'Should-BeEmptyString'

        'Should-NotBeNullOrWhiteSpaceString'
        'Should-NotBeNullOrEmptyString'

        'Should-BeLikeString'
        'Should-NotBeLikeString'

        'Should-BeFasterThan'
        'Should-BeSlowerThan'
        'Should-BeBefore'
        'Should-BeAfter'
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
        PSData                  = @{
            # The primary categorization of this module (from the TechNet Gallery tech tree).
            Category     = "Scripting Techniques"

            # Keyword tags to help users find this module via navigations and search.
            Tags         = @('powershell', 'unit_testing', 'bdd', 'tdd', 'mocking', 'PSEdition_Core', 'PSEdition_Desktop', 'Windows', 'Linux', 'MacOS')

            # The web address of an icon which can be used in galleries to represent this module
            IconUri      = 'https://raw.githubusercontent.com/pester/Pester/main/images/pester.PNG'

            # The web address of this module's project or support homepage.
            ProjectUri   = "https://github.com/Pester/Pester"

            # The web address of this module's license. Points to a page that's embeddable and linkable.
            LicenseUri   = "https://www.apache.org/licenses/LICENSE-2.0.html"

            # Release notes for this particular version of the module
            ReleaseNotes = 'https://github.com/pester/Pester/releases/tag/6.0.0-alpha1'

            # Prerelease string of this module
            Prerelease   = 'alpha1'
        }

        # Minimum assembly version required
        RequiredAssemblyVersion = '6.0.0'
    }

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''

}
