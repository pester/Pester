Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterMatchArrayUnordered" {
        It "returns true for matching single item arrays" {
            , @("a") | Should MatchArrayUnordered @("a")
        }
        It "returns true for matching single item and single item array" {
            "a" | Should MatchArrayUnordered @("a")
        }
        It "returns true for matching single item array and single item" {
            , (@("a")) | Should MatchArrayUnordered "a"
        }
        It "returns true for arrays with the same contents" {
            , @("a", 1) | Should MatchArrayUnordered @("a", 1)
        }
        It "returns true for arrays with the same contents in different orders" {
            , (@("a", 1)) | Should MatchArrayUnordered @(1, "a")
        }

        It "returns false if arrays differ in content" {
            , (@(1)) | Should Not MatchArrayUnordered @(2)
        }
        It "returns false if arrays differ in length" {
            , (@(1)) | Should Not MatchArrayUnordered @(1, 1)
        }
    }


    Describe "PesterMatchArrayOrdered" {
        It "returns true for matching single item arrays" {
            , @("a") | Should MatchArrayOrdered @("a")
        }
        It "returns true for matching single item and single item array" {
            "a" | Should MatchArrayOrdered @("a")
        }
        It "returns true for matching single item array and single item" {
            , @("a") | Should MatchArrayOrdered  "a"
        }
        It "returns true for arrays with the same contents in the same order" {
            , @("a", 1)  | Should MatchArrayOrdered  @("a", 1)
        }
        It "returns false for arrays with the same contents in different orders" {
            , @("a", 1) | Should Not MatchArrayOrdered  @(1, "a")
        }

        It "returns false if arrays differ in content" {
            , @(1)  | Should Not MatchArrayOrdered  @(2)
        }
        It "returns false if arrays differ in length" {
            , @(1)  | Should Not MatchArrayOrdered  @(1, 1)
        }
    }
}