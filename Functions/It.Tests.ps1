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
	It "records the correct stack line number of failed tests" {
		#the $script scriptblock below is used as a position marker to determine 
		#on which line the test failed.
        try{"something" | should be "nothing"}catch{ $ex=$_} ; $script={}
        $result = Get-PesterResult $script 0 $ex
        $result.Stacktrace | should match "at line: $($script.startPosition.StartLine) in "
    }

    It "should pass if assertions pass" {
		$test = 'something'
        $test | should be "something"
    }
	<# TODO implement this to not use the Pester object to save its state
    It "does not pollute the global namespace" {
      $extra_keys = List-ExtraKeys $pester.starting_variables $(Get-VariableAsHash)
	  $expected_keys = "here", "name", "test", "Matches", "fixture", "script", "_", "psitem", "TestDrive"
      $extra_keys | ? { !($expected_keys -contains $_) } | Should BeNullOrEmpty
    }
	#>
    It "throws if no test block given" {
        { It "no test block" } | Should Throw
    }

    It "won't throw if success test block given" {
        { It "test block" {} } | Should Not Throw
    }
    
    it "Does not rewrite Test variable" {
        it "tests" { $true | should be $true }
        $test = "rewrite"
    }
    
    it "does not override the pester variable" {
        $pester = 0 
        #you can replace the $pester variable by going few scopes above 
        #Set-Variable -name pester -Value $null -Scope 6
    }

}

