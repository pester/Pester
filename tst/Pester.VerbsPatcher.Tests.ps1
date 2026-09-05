Set-StrictMode -Version Latest

Describe "VerbsPatcher" {
    # Pester exports its own built-in Should-* assertions without triggering PowerShell's
    # unapproved-verb warning by briefly adding 'Should' to the internal approved-verb list at
    # import time (see the [Pester.VerbsPatcher]::AllowShouldVerb call in Module.ps1). This test
    # guards that internal helper against PowerShell internals changing.
    #
    # This helper is intentionally NOT surfaced as a public command. Module authors who want to
    # ship custom Should-* assertions without the warning should define Assert-* functions and add
    # Should-* aliases for them (aliases are not verb-checked); calling this .NET helper directly is
    # possible but unsupported and not recommended.
    It "temporarily marks 'Should' as an approved verb" {
        # Reach the internal approved-verb list the same way the helper does. The field name differs
        # between Windows PowerShell 5 and PowerShell 7+.
        $verbsType = [System.Management.Automation.VerbsCommon].Assembly.GetType('System.Management.Automation.Verbs')
        $fieldName = if ($PSVersionTable.PSVersion.Major -eq 5) { 'validVerbs' } else { 's_validVerbs' }
        $field = $verbsType.GetField($fieldName, [System.Reflection.BindingFlags] 'Static, NonPublic')
        $validVerbs = $field.GetValue($null)

        # Start from a known state so the assertion is deterministic regardless of the timed revert
        # that Pester schedules for its own import.
        $null = $validVerbs.Remove('Should')
        $validVerbs.ContainsKey('Should') | Verify-False

        [Pester.VerbsPatcher]::AllowShouldVerb($PSVersionTable.PSVersion.Major)

        $validVerbs.ContainsKey('Should') | Verify-True
    }
}
