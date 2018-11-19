Given "the following DocString:?" {
    param([string]$DocString)
    #throw
    Set-StepPending
    $DocString | Should -Not -BeNull
}

When "this scenario is run" { #Set-StepPending 
}

Then "the DocString is displayed in the console" { }

GherkinStep "a (square|rectangular|single column) data table:?" { param($table) }
Then "the tables are displayed correctly in the console" { }

Given "a number '(\d+)' and a number '(\d+)" { param([int]$x, [int]$y) }
When "I add them together" { }
Then "I should get '(\d+)" { param([int]$result) }
