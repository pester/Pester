Set-StrictMode -Version Latest

function List-ExtraKeys($baseHash, $otherHash) {
    $extra_keys = @()
    $otherHash.Keys | ForEach-Object {
        if ( -not $baseHash.ContainsKey($_)) {
            $extra_keys += $_
        }
    }

    return $extra_keys
}

Describe "It - Caller scoped tests" {
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

    $result = $null
    try
    {
        It "no test block"
    }
    catch
    {
        $result = $_
    }

    It "throws if no test block given" {
        $result | Should Not Be $null
    }

    $result = $null
    try
    {
        It "empty test block" { }
    }
    catch
    {
        $result = $_
    }

    It "won't throw if success test block given" {
        $result | Should Be $null
    }    
}

InModuleScope Pester {
    Describe "It - Module scoped tests" {
	    It "records the correct stack line number of failed tests" {
		    #the $script scriptblock below is used as a position marker to determine 
		    #on which line the test failed.
            try{"something" | should be "nothing"}catch{ $ex=$_} ; $script={}
            $result = Get-PesterResult $script 0 $ex
            $result.Stacktrace | should match "at line: $($script.startPosition.StartLine) in "
        }
    }
}
