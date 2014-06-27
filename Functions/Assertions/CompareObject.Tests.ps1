Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "CompareObject" {
        It "return true  for things that are compared as equals" {
            PesterCompareObject @() @() | Should Be $true
            PesterCompareObject @(1) @(2) | Should Be $true
            PesterCompareObject @(10,12,25) @(10,12,25) | Should Be $true
            PesterCompareObject @(25,12,18) @(18,12,25) | Should Be $true
        }
        It "return false for things that are not compared as equals" {
            PesterCompareObject @("something","is","missed") @("something","is","missed","here") | Should Be $false
        }
    }
}
