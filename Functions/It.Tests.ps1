$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\Describe.ps1"

function List-ExtraKeys($baseHash, $otherHash) {
    $extra_keys = @()
    $otherHash.Keys | ForEach-Object {
        if ( -not $baseHash.ContainsKey($_)) {
            $extra_keys += $_
        }
    }

    return $extra_keys
}

Describe "It" {

    It "does not pollute the global namespace" {
      $extra_keys = List-ExtraKeys $pester.starting_variables $(Get-VariableAsHash)
      $expected_keys = "here", "name", "test", "Matches", "fixture"
      $extra_keys.Count | Should Be $expected_keys.Count
    }

}

