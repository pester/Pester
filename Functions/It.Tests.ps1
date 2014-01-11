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
    [ScriptBlock]$script={"something"}
    $test="something"
    It "records the correct stack line number of failed tests" {
        try{"something" | should be "nothing"}catch{ $ex=$_} #line 1
        $result = Get-PesterResult $script $ex
        $result.Stacktrace | should match "at line: $($script.startPosition.StartLine+1) in "
        $test="something"
    }

    It "should pass if assertions pass" {
        $test | should be "something"
    }

    It "does not pollute the global namespace" {
      $extra_keys = List-ExtraKeys $pester.starting_variables $(Get-VariableAsHash)
      $expected_keys = "here", "name", "test", "Matches", "fixture", "script", "_", "psitem"
      $extra_keys | ? { !($expected_keys -contains $_) } | Should BeNullOrEmpty
    }

    It "throws if no test block given" {
        { It "no test block" } | Should Throw
    }

    It "won't throw if success test block given" {
        { It "test block" {} } | Should Not Throw
    }

}

