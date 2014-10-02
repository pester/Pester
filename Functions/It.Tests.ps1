Set-StrictMode -Version Latest

Describe "It - Caller scoped tests" {
    It "should pass if assertions pass" {
        $test = 'something'
        $test | should be "something"
    }

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

    Describe 'It - Implementation' {
        $pesterState = New-PesterState -Path TestDrive:\

        #$pesterState.EnterDescribe('Mocked Describe')

        It 'Throws an error if It is called outside of Describe' {
            $scriptBlock = { ItImpl -Pester $pesterState 'Tries to enter a test without entering a Describe first' { } }
            $scriptBlock | Should Throw 'The It command may only be used inside a Describe block.'
        }
    }
}
