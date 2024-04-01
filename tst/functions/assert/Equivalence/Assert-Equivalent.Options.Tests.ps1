InModuleScope -ModuleName Assert {
    Describe "Compare-Equivalent - Exclude path options" {
        Context "Full excluded paths" {

            It "Given a full path to a property it ignores it on the Expected object" -TestCases @(
                @{ Path = $null }
                @{ Path = "ParentProperty1" }
                @{ Path = "ParentProperty1.ParentProperty2" }
            ) {
                param ($Path)

            $expected = New-PSObject @{
                Name = "Jakub"
                Age = 30
            }

            $actual = New-PSObject @{
                Name = "Jakub"
            }

                $options = Get-EquivalencyOption -ExcludePath ("$Path.Age".Trim('.'))
                Compare-Equivalent -Actual $actual -Expected $expected -Path $Path -Options $options  | Verify-Null
            }

        It "Given a full path to a property it ignores it on the Actual object"  -TestCases @(
            @{ Path = $null }
            @{ Path = "ParentProperty1" }
            @{ Path = "ParentProperty1.ParentProperty2" }
        ) {
            param ($Path)
            $expected = New-PSObject @{
                Name = "Jakub"
            }

            $actual = New-PSObject @{
                Name = "Jakub"
                Age = 30
            }

                $options = Get-EquivalencyOption -ExcludePath ("$Path.Age".Trim('.'))
                Compare-Equivalent -Actual $actual -Expected $expected -Path $Path -Options $options | Verify-Null
            }


        It "Given a full path to a property on object that is in collection it ignores it on the Expected object" {
            $expected = New-PSObject @{
                ProgrammingLanguages = @(
                    (New-PSObject @{
                        Name = "C#"
                        Type = "OO"
                    }),
                    (New-PSObject @{
                        Name = "PowerShell"
                    })
                )
            }

            $actual = New-PSObject @{
                ProgrammingLanguages = @(
                    (New-PSObject @{
                        Name = "C#"
                    }),
                    (New-PSObject @{
                        Name = "PowerShell"
                    })
                )
            }


                $options = Get-EquivalencyOption -ExcludePath "ProgrammingLanguages.Type"
                Compare-Equivalent -Actual $actual -Expected $expected -Options $options | Verify-Null
            }

        It "Given a full path to a property on object that is in collection it ignores it on the Actual object" {
            $expected = New-PSObject @{
                ProgrammingLanguages = @(
                    (New-PSObject @{
                        Name = "C#"
                    }),
                    (New-PSObject @{
                        Name = "PowerShell"
                    })
                )
            }

            $actual = New-PSObject @{
                ProgrammingLanguages = @(
                    (New-PSObject @{
                        Name = "C#"
                        Type = "OO"
                    }),
                    (New-PSObject @{
                        Name = "PowerShell"
                    })
                )
            }


                $options = Get-EquivalencyOption -ExcludePath "ProgrammingLanguages.Type"
                Compare-Equivalent -Actual $actual -Expected $expected -Options $options | Verify-Null
            }

        It "Given a full path to a property on object that is in hashtable it ignores it on the Expected object" {
            $expected = New-PSObject @{
                ProgrammingLanguages = @{
                    Language1 = (New-PSObject @{
                        Name = "C#"
                        Type = "OO"
                    });
                    Language2 = (New-PSObject @{
                        Name = "PowerShell"
                    })
                }
            }

            $actual = New-PSObject @{
                ProgrammingLanguages =  @{
                    Language1 = (New-PSObject @{
                        Name = "C#"
                    });
                    Language2 = (New-PSObject @{
                        Name = "PowerShell"
                    })
                }
            }

                $options = Get-EquivalencyOption -ExcludePath "ProgrammingLanguages.Language1.Type"
                Compare-Equivalent -Actual $actual -Expected $expected -Options $options | Verify-Null
            }

            # in the above tests we are not testing all the possible options of skippin in all possible
            # emumerable objects, but this many tests should still be enough. The Path unifies how different
            # collections are handled, and we filter out based on the path on the start of Compare-Equivalent
            # so the same rules should apply transitively no matter the collection type


            It "Given a full path to a key on a hashtable it ignores it on the Expected hashtable" {
                $expected = @{
                    Name = "C#"
                    Type = "OO"
                }

                $actual = @{
                    Name = "C#"
                }

                $options = Get-EquivalencyOption -ExcludePath "Type"
                Compare-Equivalent -Actual $actual -Expected $expected -Options $options | Verify-Null
            }

            It "Given a full path to a key on a hashtable it ignores it on the Actual hashtable" {
                $expected = @{
                    Name = "C#"
                }

                $actual = @{
                    Name = "C#"
                    Type = "OO"
                }

                $options = Get-EquivalencyOption -ExcludePath "Type"
                Compare-Equivalent -Actual $actual -Expected $expected -Options $options | Verify-Null
            }

            It "Given a full path to a key on a dictionary it ignores it on the Expected dictionary" {
                $expected = New-Dictionary @{
                    Name = "C#"
                    Type = "OO"
                }

                $actual = New-Dictionary @{
                    Name = "C#"
                }

                $options = Get-EquivalencyOption -ExcludePath "Type"
                Compare-Equivalent -Actual $actual -Expected $expected -Options $options | Verify-Null
            }

            It "Given a full path to a key on a dictionary it ignores it on the Actual dictionary" {
                $expected = New-Dictionary @{
                    Name = "C#"
                }

                $actual = New-Dictionary @{
                    Name = "C#"
                    Type = "OO"
                }

                $options = Get-EquivalencyOption -ExcludePath "Type"
                Compare-Equivalent -Actual $actual -Expected $expected -Options $options | Verify-Null
            }

        It "Given options it passes them correctly from Assert-Equivalent" {
            $expected = New-PSObject @{
                Name = "Jakub"
                Location = "Prague"
                Age = 30
            }

            $actual = New-PSObject @{
                Name = "Jakub"
            }

                $options = Get-EquivalencyOption -ExcludePath "Age", "NonExisting"
                $err = { Assert-Equivalent -Actual $actual -Expected $expected -Options $options } | Verify-AssertionFailed

                $err.Exception.Message | Verify-Like "*Expected has property 'Location'*"
                $err.Exception.Message | Verify-Like "*Exclude path 'Age'*"
            }
        }

        Context "Wildcard path exclusions" {
            It "Given wildcarded path it ignores it on the expected object" {
                $expected = [PSCustomObject] @{
                    Name = "Jakub"
                    Location = "Prague"
                }

                $actual = [PSCustomObject] @{
                    Name = "Jakub"
                }

                $options = Get-EquivalencyOption -ExcludePath Loc*
                Assert-Equivalent -Actual $actual -Expected $expected -Options $Options
            }

            It "Given wildcarded path it ignores it on the actual object" {
                $expected = [PSCustomObject] @{
                    Name = "Jakub"
                }

                $actual = [PSCustomObject] @{
                    Name = "Jakub"
                    Location = "Prague"
                }

                $options = Get-EquivalencyOption -ExcludePath Loc*
                Assert-Equivalent -Actual $actual -Expected $expected -Options $Options
            }

            It "Given wildcarded path it ignores it on the expected hashtable" {
                $expected = @{
                    Name = "Jakub"
                    Location = "Prague"
                }

                $actual = @{
                    Name = "Jakub"
                }

                $options = Get-EquivalencyOption -ExcludePath Loc*
                Assert-Equivalent -Actual $actual -Expected $expected -Options $Options
            }

            It "Given wildcarded path it ignores it on the actual hashtable" {
                $expected = @{
                    Name = "Jakub"
                }

                $actual = @{
                    Name = "Jakub"
                    Location = "Prague"
                }

                $options = Get-EquivalencyOption -ExcludePath Loc*
                Assert-Equivalent -Actual $actual -Expected $expected -Options $Options
            }

            It "Given wildcarded path it ignores it on the expected dictionary" {
                $expected = New-Dictionary @{
                    Name = "Jakub"
                    Location = "Prague"
                }

                $actual = New-Dictionary @{
                    Name = "Jakub"
                }

                $options = Get-EquivalencyOption -ExcludePath Loc*
                Assert-Equivalent -Actual $actual -Expected $expected -Options $Options
            }

            It "Given wildcarded path it ignores it on the actual dictionary" {
                $expected = New-Dictionary @{
                    Name = "Jakub"
                }

                $actual = New-Dictionary @{
                    Name = "Jakub"
                    Location = "Prague"
                }

                $options = Get-EquivalencyOption -ExcludePath Loc*
                Assert-Equivalent -Actual $actual -Expected $expected -Options $Options
            }
        }

        Context "-ExcludePathsNotOnExpected" {
            It "Given actual object that has more properties that expected it skips them" {
                $expected = [PSCustomObject] @{
                    Name = "Jakub"
                }

                $actual = [PSCustomObject] @{
                    Name = "Jakub"
                    Location = "Prague"
                    Age = 30
                }

                $options = Get-EquivalencyOption -ExcludePathsNotOnExpected
                Assert-Equivalent -Actual $actual -Expected $expected -Options $Options
            }

            It "Given actual hashtable that has more keys that expected it skips them" {
                $expected = @{
                    Name = "Jakub"
                }

                $actual = @{
                    Name = "Jakub"
                    Location = "Prague"
                    Age = 30
                }

                $options = Get-EquivalencyOption -ExcludePathsNotOnExpected
                Assert-Equivalent -Actual $actual -Expected $expected -Options $Options
            }

            It "Given actual dictionary that has more keys that expected it skips them" {
                $expected = New-Dictionary @{
                    Name = "Jakub"
                }

                $actual = New-Dictionary @{
                    Name = "Jakub"
                    Location = "Prague"
                    Age = 30
                }

                $options = Get-EquivalencyOption -ExcludePathsNotOnExpected
                Assert-Equivalent -Actual $actual -Expected $expected -Options $Options
            }
        }
    }

    Describe "Compare-Equiavlent - equality comparison options" {
        It "Given objects that are equivalent and -Comparator Equality option it compares them as different" {
            $expected = New-PsObject @{
                LikesIfsInMocks = $false
            }

            $actual = New-PsObject @{
                LikesIfsInMocks = "False"
            }

            $options = Get-EquivalencyOption -Comparator Equality
            { Assert-Equivalent -Actual $actual -Expected $expected -Options $options } | Verify-AssertionFailed
        }
    }


    Describe "Printing Options into difference report" {

        It "Given options that exclude property it shows up in the difference report correctly" {
                $options = Get-EquivalencyOption -ExcludePath "Age", "Name", "Person.Age", "Person.Created*"
                Clear-WhiteSpace (Format-EquivalencyOptions -Options $options) | Verify-Equal (Clear-WhiteSpace "
                    Exclude path 'Age'
                    Exclude path 'Name'
                    Exclude path 'Person.Age'
                    Exclude path 'Person.Created*'")
        }

        It "Given options that exclude property it shows up in the difference report correctly" {
            $options = Get-EquivalencyOption -ExcludePathsNotOnExpected
            Clear-WhiteSpace (Format-EquivalencyOptions -Options $options) | Verify-Equal (Clear-WhiteSpace "
            Excluding all paths not found on Expected")
        }
    }

}