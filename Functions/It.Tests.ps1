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
        It "non-empty test block" { "anything" }
    }
    catch
    {
        $result = $_
    }

    It "won't throw if non-empty test block given" {
        $result | Should Be $null
    }
    
    #TODO: Test if empty It is marked as Pending
    #TODO: Test if scriptblock that contains comments only is marked as pending
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
InModuleScope Pester {
    Describe "Remove-Comments" {    
        It "Removes single line comments" {
            Remove-Comments -Text "code #comment" | Should Be "code "
        } 
        It "Removes multi line comments" {
            Remove-Comments -Text "code <#comment
            comment#> code" | Should Be "code  code"
        }
    }
}
