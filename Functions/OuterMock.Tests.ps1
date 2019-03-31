# TODO: should this work in v5?
return
Set-StrictMode -Version Latest

function f () {}

Mock f {}

Describe 'Mock at script scope' {
    It 't' {
        1 | Should -Be 1
    }
}
