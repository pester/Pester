function Enable-ShouldVerb {
    <#
    .SYNOPSIS
    Temporarily marks `Should` as an approved PowerShell verb so a module can export
    `Should-*` assertions without an unapproved-verb warning.

    .DESCRIPTION
    `Should` is not on PowerShell's list of approved verbs, so importing a module that exports
    custom `Should-*` assertions normally prints an "unapproved verb" warning to whoever imports
    it. Pester avoids this for its own assertions, and `Enable-ShouldVerb` exposes the same
    mechanism to module authors.

    Call it near the top of your module (in the `.psm1`, before your `Should-*` functions are
    exported). It adds `Should` to the internal list of approved verbs and schedules the entry
    to be removed again a few seconds later, which is long enough for the import to finish
    without permanently changing the verb list.

    This only silences the warning shown when a module is imported. To also keep
    PSScriptAnalyzer's `PSUseApprovedVerbs` rule quiet at build time, suppress it on the
    assertion, for example:

    ```powershell
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '')]
    ```

    .EXAMPLE
    ```powershell
    # MyAssertions.psm1
    Import-Module Pester
    Enable-ShouldVerb

    function Should-BeAwesome {
        # ...
    }

    Export-ModuleMember -Function 'Should-BeAwesome'
    ```

    Importing `MyAssertions` no longer warns about the unapproved `Should` verb.

    .LINK
    https://pester.dev/docs/commands/Enable-ShouldVerb

    .LINK
    https://pester.dev/docs/assertions
    #>
    [CmdletBinding()]
    param ()

    [Pester.VerbsPatcher]::AllowShouldVerb($PSVersionTable.PSVersion.Major)
}
