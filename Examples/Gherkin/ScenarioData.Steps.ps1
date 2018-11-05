Given "the following DocString:?" {
    param([string]$DocString)

    $DocString | Should -Not -BeNull
}

When "this scenario is run" { }

Then "the DocString is displayed in the console" { }

GherkinStep "a (square|rectangular|single column) data table:?" { param($table) }
Then "the tables are displayed correctly in the console" { }
