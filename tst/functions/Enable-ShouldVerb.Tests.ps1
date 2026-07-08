Set-StrictMode -Version Latest

Describe "Enable-ShouldVerb" {
    It "marks 'Should' as an approved verb so Should-* functions export without a warning" {
        # Reach the internal approved-verb list the same way the underlying VerbsPatcher does. The
        # field name differs between Windows PowerShell 5 and PowerShell 7+.
        $verbsType = [System.Management.Automation.VerbsCommon].Assembly.GetType('System.Management.Automation.Verbs')
        $fieldName = if ($PSVersionTable.PSVersion.Major -eq 5) { 'validVerbs' } else { 's_validVerbs' }
        $field = $verbsType.GetField($fieldName, [System.Reflection.BindingFlags] 'Static, NonPublic')
        $validVerbs = $field.GetValue($null)

        # Start from a known state so the assertion is deterministic regardless of the timed revert
        # that Pester schedules for its own import and for this call.
        $null = $validVerbs.Remove('Should')
        $validVerbs.ContainsKey('Should') | Verify-False

        Enable-ShouldVerb

        $validVerbs.ContainsKey('Should') | Verify-True
    }
}
