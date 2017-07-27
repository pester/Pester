Set-StrictMode -Version Latest

InModuleScope Pester {

    Describe "MatchHashtable" {
        It "returns true for matching single item hashtable with same values" {
            @{"a" = 1} | Should MatchHashtable @{"a" = 1}
        }
        It "returns true for hashtable with the same contents" {
            @{"a" = 1; "b" = "test"} | Should MatchHashtable  @{"a" = 1; "b" = "test"}
        }
        It "returns true for hashtable with the same contents in different orders" {
            @{"a" = 1; "b" = "test"} | Should MatchHashtable  @{"b" = "test"; "a" = 1}
        }

        It "returns false if hashtable differ in content" {
            @{"a" = 1; "b" = "test"}  | Should Not MatchHashtable @{"a" = 1; "b" = "different value"}
        }
        It "returns false if hashtable differ in length - input2 longer" {
            @{"a" = 1} | Should Not MatchHashtable  @{"a" = 1; "b" = "test"}
        }
        It "returns false if hashtable differ in length - input1 longer" {
            @{"a" = 1; "b" = "test"}  | Should Not MatchHashtable  @{"a" = 1}
        }
    }
}
