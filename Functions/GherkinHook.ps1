function BeforeEachFeature {
    <#
        .Synopsis
            Defines a ScriptBlock hook to run before each feature to set up the test environment
        .Description
            BeforeEachFeature hooks are run before each feature that is in (or above) the folder where the hook is defined.

            This is a convenience method, provided because unlike traditional RSpec Pester,
            there is not a simple test script where you can put setup and clean up.
        .Link
            AfterEachFeature
            BeforeEachScenario
            AfterEachScenario
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param(
        # Optional tags. If set, this hook only runs for features with matching tags
        [Parameter(Mandatory=$True, Position=0, ParameterSetName="Tags")]
        [String[]]$Tags = @(),

        # The ScriptBlock to run for the hook
        [Parameter(Mandatory=$True, Position=1, ParameterSetName="Tags")]
        [Parameter(Mandatory=$True, Position=0, ParameterSetName="All")]
        [ScriptBlock]$Script
    )

    ${Script:GherkinHooks}.BeforeEachFeature += @( @{ Tags = $Tags; Script = $Script } )
}

function AfterEachFeature {
    <#
        .Synopsis
            Defines a ScriptBlock hook to run at the very end of a test run
        .Description
            AfterEachFeature hooks are run after each feature that is in (or above) the folder where the hook is defined.

            This is a convenience method, provided because unlike traditional RSpec Pester,
            there is not a simple test script where you can put setup and clean up.
        .Link
            BeforeEachFeature
            BeforeEachScenario
            AfterEachScenario
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param(
        # Optional tags. If set, this hook only runs for features with matching tags
        [Parameter(Mandatory=$True, Position=0, ParameterSetName="Tags")]
        [String[]]$Tags,

        # The ScriptBlock to run for the hook
        [Parameter(Mandatory=$True, Position=1, ParameterSetName="Tags")]
        [Parameter(Mandatory=$True, Position=0, ParameterSetName="All")]
        [ScriptBlock]$Script
    )

    ${Script:GherkinHooks}.AfterEachFeature += @( @{ Tags = $Tags; Script = $Script } )
}

function BeforeEachScenario {
    <#
        .Synopsis
            Defines a ScriptBlock hook to run before each scenario to set up the test environment
        .Description
            BeforeEachScenario hooks are run before each scenario that is in (or above) the folder where the hook is defined.

            You should not normally need this, because it overlaps significantly with the "Background" feature in the gherkin language.

            This is a convenience method, provided because unlike traditional RSpec Pester,
            there is not a simple test script where you can put setup and clean up.
        .Link
            AfterEachFeature
            BeforeEachScenario
            AfterEachScenario
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param(
        # Optional tags. If set, this hook only runs for features with matching tags
        [Parameter(Mandatory=$True, Position=0, ParameterSetName="Tags")]
         [String[]]$Tags = @(),

        # The ScriptBlock to run for the hook
        [Parameter(Mandatory=$True, Position=1, ParameterSetName="Tags")]
        [Parameter(Mandatory=$True, Position=0, ParameterSetName="All")]
        [ScriptBlock]$Script
    )

    ${Script:GherkinHooks}.BeforeEachScenario += @( @{ Tags = $Tags; Script = $Script } )
}

function AfterEachScenario {
    <#
        .Synopsis
            Defines a ScriptBlock hook to run after each scenario to set up the test environment
        .Description
            AfterEachScenario hooks are run after each Scenario that is in (or above) the folder where the hook is defined.

            This is a convenience method, provided because unlike traditional RSpec Pester,
            there is not a simple test script where you can put setup and clean up.
        .Link
            BeforeEachFeature
            BeforeEachScenario
            AfterEachScenario
    #>
    [CmdletBinding(DefaultParameterSetName="All")]
    param(
        # Optional tags. If set, this hook only runs for features with matching tags
        [Parameter(Mandatory=$True, Position=0, ParameterSetName="Tags")]
        [String[]]$Tags = @(),

        # The ScriptBlock to run for the hook
        [Parameter(Mandatory=$True, Position=1, ParameterSetName="Tags")]
        [Parameter(Mandatory=$True, Position=0, ParameterSetName="All")]
        [ScriptBlock]$Script
    )

    ${Script:GherkinHooks}.AfterEachScenario += @( @{ Tags = $Tags; Script = $Script } )
}
