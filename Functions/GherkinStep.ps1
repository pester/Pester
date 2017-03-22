function GherkinStep {
    <#
        .Synopsis
            A step in a test, also known as a Given, When, or Then
        .Description
            Pester doesn't technically distinguish between the three kinds of steps.
            However, we strongly recommend that you do!
            These words were carefully selected to convey meaning which is crucial to get you into the BDD mindset.

            In BDD, we drive development by not first stating the requirements, and then defining steps which can be executed in a manner that is similar to unit tests.
        .Link
            about_gherkin
            Invoke-GherkinStep
            https://sites.google.com/site/unclebobconsultingllc/the-truth-about-bdd

    #>
    param(
        # The name of a gherkin step is actually a regular expression, from which capturing groups are cast and passed to the parameters in the ScriptBlock
        [Parameter(Mandatory=$True, Position=0)]
        [String]$Name,

        # The ScriptBlock which defines this step. May accept parameters from regular expression capturing groups (named or not), or from tables or multiline strings.
        [Parameter(Mandatory=$True, Position=1)]
        [ScriptBlock]$Test
    )
    # We need to be able to look up where this step is defined
    $Definition = (Get-PSCallStack)[1]
    $RelativePath = Resolve-Path $Definition.ScriptName -relative
    $Source = "{0}: line {1}" -f $RelativePath, $Definition.ScriptLineNumber

    $Script:GherkinSteps.${Name} = $Test | Add-Member -MemberType NoteProperty -Name Source -Value $Source -PassThru
}

Set-Alias Given GherkinStep
Set-Alias When GherkinStep
Set-Alias Then GherkinStep
Set-Alias And GherkinStep
Set-Alias But GherkinStep
