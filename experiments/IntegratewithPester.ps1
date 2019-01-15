get-module Pester | Remove-Module 
Import-Module $PSScriptRoot\..\Pester.psd1

Describe "a" {
    It "b" {
        "hello"
    }
}