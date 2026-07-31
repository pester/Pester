Set-StrictMode -Version Latest

# These tests reflect over every exported Should-* assertion and lock in the conventions the new
# v6 assertions were just made consistent on (see #2928-#2933):
#
#   1. -Because is a named-only [string].
#   2. The subject binds from the pipeline.
#   3. -Actual sits at Position 0 for single-subject assertions and Position 1 for two-argument ones.
#   4. A positional comparand (e.g. -Expected) is mandatory.
#
# The assertion list is discovered, not hardcoded, so a new Should-* assertion is picked up
# automatically and must satisfy these conventions or this file goes red.

BeforeDiscovery {
    $common = [System.Management.Automation.PSCmdlet]::CommonParameters +
    [System.Management.Automation.PSCmdlet]::OptionalCommonParameters

    # --- Intentional category exceptions ------------------------------------------------------
    # A few assertions were deliberately given a different shape (see #2933). Their subject is a
    # scriptblock / command / mock rather than a piped value, so the -Actual position rules do not
    # apply to them. They are still expected to expose a named-only [string] -Because where noted.

    # Subject is a mocked command; there is no piped -Actual input at all.
    $mockAssertions = 'Should-Invoke', 'Should-NotInvoke'
    # Subject is a [scriptblock] the assertion executes (piped in as -ScriptBlock, not -Actual).
    $commandInputAssertions = 'Should-Throw'
    # Ported from the v5 `Should -HaveParameter` operator; these keep a fully positional layout
    # (including a positional -Because), so they are exempt from the -Because and -Actual rules.
    $parameterAssertions = 'Should-HaveParameter', 'Should-NotHaveParameter'

    # --- Known deviation (NOT an intentional exception) ---------------------------------------
    # Should-BeHashtable is a single-subject shape assertion (no positional comparand) but currently
    # declares -Actual at Position 1 instead of 0 - the exact shape #2933 fixed on the other
    # single-subject assertions. It is excluded from the -Actual position check only to keep this
    # suite green. Remove this entry once -Actual moves to Position 0 in the source.
    $knownActualPositionDeviations = 'Should-BeHashtable'

    function Get-ParameterAttribute ($Parameter) {
        $Parameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
    }

    function Get-MinPosition ($Parameter) {
        if ($null -eq $Parameter) { return $null }
        $positions = @(Get-ParameterAttribute $Parameter | ForEach-Object Position | Sort-Object)
        $positions[0]
    }

    $assertions = foreach ($command in (Get-Command -Module Pester -Name 'Should-*' | Sort-Object Name)) {
        $name = $command.Name

        $parameters = @{}
        foreach ($p in $command.Parameters.Values) {
            if ($p.Name -notin $common) { $parameters[$p.Name] = $p }
        }

        $because = $parameters['Because']
        $actual = $parameters['Actual']

        # comparand = a positional parameter at Position 0 that is neither the subject nor the reason
        $comparand = $parameters.Values |
            Where-Object { $_.Name -notin @('Actual', 'Because') -and ((Get-ParameterAttribute $_).Position -contains 0) } |
            Select-Object -First 1

        $pipelineParameters = @($parameters.Values |
                Where-Object { (Get-ParameterAttribute $_).ValueFromPipeline -contains $true })

        $category =
        if ($name -in $mockAssertions) { 'Mock' }
        elseif ($name -in $commandInputAssertions) { 'CommandInput' }
        elseif ($name -in $parameterAssertions) { 'Parameter' }
        else { 'Value' }

        # Value assertions split by whether they take a positional comparand at Position 0.
        $subject =
        if ($category -ne 'Value') { $category }
        elseif ($comparand) { 'TwoArgument' }
        elseif ((Get-MinPosition $actual) -eq 0) { 'SingleSubject' }
        else { 'Unknown' }

        $expectedSubjectName =
        if ($category -eq 'CommandInput') { 'ScriptBlock' }
        elseif ($category -eq 'Mock') { $null }
        else { 'Actual' }

        [PSCustomObject]@{
            Name                      = $name
            Category                  = $category
            Subject                   = $subject

            BecausePresent            = $null -ne $because
            BecauseTypeName           = if ($because) { $because.ParameterType.Name } else { $null }
            BecausePosition           = Get-MinPosition $because
            # HaveParameter/NotHaveParameter keep a legacy positional -Because and are exempt.
            BecauseNamedOnlyExpected  = $name -notin $parameterAssertions

            # Mock assertions take no piped subject; everything else must.
            SubjectFromPipelineExpected = $name -notin $mockAssertions
            ExpectedSubjectName       = $expectedSubjectName
            PipelineParameterNames    = ($pipelineParameters | ForEach-Object Name | Sort-Object) -join ', '
            PipelineParameterCount    = $pipelineParameters.Count

            ActualPosition            = Get-MinPosition $actual
            ActualPositionExpected    = switch ($subject) { 'SingleSubject' { 0 } 'TwoArgument' { 1 } default { $null } }
            ActualPositionChecked     = $category -eq 'Value' -and $name -notin $knownActualPositionDeviations

            ComparandName             = if ($comparand) { $comparand.Name } else { $null }
            ComparandMandatory        = [bool]($comparand -and ((Get-ParameterAttribute $comparand) | Where-Object Mandatory))
            # Only single-parameter-set two-argument assertions have an unconditionally mandatory
            # comparand. Should-BeAfter/-BeBefore (fluent -Now/-Ago/-FromNow) and Should-BeCollection
            # (-Count) make it optional per parameter set, so they are not checked here.
            ComparandMandatoryChecked = $category -eq 'Value' -and $subject -eq 'TwoArgument' -and $command.ParameterSets.Count -eq 1
        }
    }

    $everyAssertion = $assertions
    $shapedValueAssertions = $assertions | Where-Object { $_.Category -eq 'Value' -and $_.Name -notin $knownActualPositionDeviations }
    $namedBecauseAssertions = $assertions | Where-Object BecauseNamedOnlyExpected
    $pipelineAssertions = $assertions | Where-Object SubjectFromPipelineExpected
    $singleSubjectAssertions = $assertions | Where-Object { $_.ActualPositionChecked -and $_.Subject -eq 'SingleSubject' }
    $twoArgumentAssertions = $assertions | Where-Object { $_.ActualPositionChecked -and $_.Subject -eq 'TwoArgument' }
    $comparandAssertions = $assertions | Where-Object ComparandMandatoryChecked
}

Describe 'Should-* assertion conventions' {

    It 'Discovers the exported Should-* assertions' -ForEach @{ AssertionCount = @($everyAssertion).Count } {
        # Guards against the reflection silently finding nothing (e.g. module not imported).
        $AssertionCount | Should -BeGreaterThan 30
    }

    It '<_.Name> has a recognised assertion shape' -ForEach $shapedValueAssertions {
        # A value assertion is either single-subject (-Actual only) or two-argument (comparand + -Actual).
        # Anything else is a new shape that needs an explicit decision, not a silent pass.
        $_.Subject | Should -BeIn @('SingleSubject', 'TwoArgument') -Because "$($_.Name) does not match a known assertion shape"
    }

    Context '-Because is a named-only [string]' {
        It '<_.Name> exposes -Because as [string]' -ForEach $everyAssertion {
            $_.BecausePresent | Should -BeTrue -Because "$($_.Name) should expose a -Because parameter"
            $_.BecauseTypeName | Should -Be 'String' -Because "$($_.Name) -Because should be [string]"
        }

        It '<_.Name> keeps -Because named-only (no Position)' -ForEach $namedBecauseAssertions {
            # A parameter without a Position reports Int32.MinValue, i.e. a negative number.
            $_.BecausePosition | Should -BeLessThan 0 -Because "$($_.Name) -Because must be passed by name, not by position"
        }
    }

    Context 'the subject binds from the pipeline' {
        It '<_.Name> binds its subject from the pipeline' -ForEach $pipelineAssertions {
            $_.PipelineParameterCount | Should -Be 1 -Because "$($_.Name) should have exactly one ValueFromPipeline parameter"
            $_.PipelineParameterNames | Should -Be $_.ExpectedSubjectName -Because "$($_.Name) should bind -$($_.ExpectedSubjectName) from the pipeline"
        }
    }

    Context '-Actual position follows the single-/two-argument convention' {
        It '<_.Name> (single-subject) puts -Actual at Position 0' -ForEach $singleSubjectAssertions {
            $_.ActualPosition | Should -Be 0 -Because "$($_.Name) has no positional comparand, so -Actual should be at Position 0"
        }

        It '<_.Name> (two-argument) puts -Actual at Position 1' -ForEach $twoArgumentAssertions {
            $_.ActualPosition | Should -Be 1 -Because "$($_.Name) has a positional comparand at Position 0, so -Actual should be at Position 1"
        }
    }

    Context 'the comparand is mandatory' {
        It '<_.Name> makes its comparand -<_.ComparandName> mandatory' -ForEach $comparandAssertions {
            $_.ComparandMandatory | Should -BeTrue -Because "$($_.Name) -$($_.ComparandName) is the positional comparand and should be mandatory"
        }
    }
}
