Set-StrictMode -Version Latest

Describe "PesterConfiguration.Format.ps1xml" {
    BeforeDiscovery {
        $configSections = [PesterConfiguration].Assembly.GetExportedTypes() | Where-Object { $_.BaseType -eq [Pester.ConfigurationSection] }
    }

    Context "Testing format data for '<_.FullName>'" -ForEach $configSections {
        BeforeAll {
            $section = $_
            $formatData = Get-FormatData -TypeName $_.FullName
            $options = @($section.GetProperties() | Where-Object { $_.PropertyType.IsSubclassOf([Pester.Option]) })
        }
        It 'Has a single view defined of type ListControl' {
            $formatData | Should -Not -BeNullOrEmpty
            $formatData.FormatViewDefinition.Count | Should -Be 1
            $formatData.FormatViewDefinition[0].Name | Should -BeExactly $section.FullName
            $formatData.FormatViewDefinition[0].Control | Should -BeOfType ([System.Management.Automation.ListControl])
        }

        It 'View includes all options' {
            $propertiesInView = @($formatData.FormatViewDefinition[0].Control.Entries.Items.DisplayEntry | Where-Object ValueType -eq 'Property')
            $propertiesInView.Count | Should -Be $options.Count
            $missingOptions = $options.Name | Where-Object { $propertiesInView.Value -notcontains $_ }
            $missingOptions | Should -Be @()
        }
    }

    Context "Testing format data for 'Pester.Option[T]'" {
        BeforeAll {
            $formatData = Get-FormatData -TypeName 'Pester.Option'
            $options = [Pester.Option[bool]].GetProperties() | Where-Object Name -notin 'IsModified'
        }
        It 'Has a single view defined of type TableControl' {
            $formatData | Should -Not -BeNullOrEmpty
            $formatData.FormatViewDefinition.Count | Should -Be 1
            $formatData.FormatViewDefinition[0].Name | Should -BeExactly 'Pester.Option'
            $formatData.FormatViewDefinition[0].Control | Should -BeOfType ([System.Management.Automation.TableControl])
        }

        It 'View includes all options' {
            $propertiesInView = @($formatData.FormatViewDefinition[0].Control.Rows.Columns.DisplayEntry | Where-Object ValueType -EQ 'Property')
            $propertiesInView.Count | Should -Be $options.Count
            $missingOptions = $options.Name | Where-Object { $propertiesInView.Value -notcontains $_ }
            $missingOptions | Should -Be @()
        }

        It 'View does not include IsModified' {
            $propertiesInView = @($formatData.FormatViewDefinition[0].Control.Rows.Columns.DisplayEntry | Where-Object ValueType -EQ 'Property')
            $propertiesInView.Value | Should -Not -Contain 'IsModified'
        }
    }
}

Describe "Building a configuration from a hashtable" {
    Context "Values the option cannot use" {
        It "Throws for <Key> with a <Description>" -ForEach @(
            @{ Key = 'Run.Parallel'; Description = 'string instead of a bool'; Hashtable = @{ Run = @{ Parallel = 'yes' } }; Expected = "*Run.Parallel expects a bool, but got the string 'yes'*" }
            @{ Key = 'Run.ParallelThrottleLimit'; Description = 'string instead of an int'; Hashtable = @{ Run = @{ ParallelThrottleLimit = 'five' } }; Expected = "*Run.ParallelThrottleLimit expects an int, but got the string 'five'*" }
            @{ Key = 'Output.Verbosity'; Description = 'int instead of a string'; Hashtable = @{ Output = @{ Verbosity = 42 } }; Expected = "*Output.Verbosity expects a string, but got the int '42'*" }
            @{ Key = 'Run.Path'; Description = 'hashtable instead of an array'; Hashtable = @{ Run = @{ Path = @{ a = 1 } } }; Expected = '*Run.Path expects an array of strings, but got a hashtable*' }
            @{ Key = 'Run'; Description = 'string instead of a section'; Hashtable = @{ Run = 'nonsense' }; Expected = "*Run expects a dictionary of options, but got the string 'nonsense'*" }
        ) {
            { [PesterConfiguration]$Hashtable } | Should -Throw -ExpectedMessage $Expected
        }

        It "Keeps the default when the value is null, so an unset variable does not throw" {
            $configuration = [PesterConfiguration]@{ Run = @{ Parallel = $null; Path = $null } }
            $configuration.Run.Parallel.Value | Should -BeFalse
            $configuration.Run.Path.Value | Should -Be '.'
        }

        It "Accepts an int for a decimal option" {
            ([PesterConfiguration]@{ CodeCoverage = @{ CoveragePercentTarget = 80 } }).CodeCoverage.CoveragePercentTarget.Value | Should -Be 80
        }
    }

    Context "Keys that match no option" {
        It "Rejects a misspelled option and says what it probably meant" {
            # #2975 only warned about it, which scrolls past in CI and leaves the run on the default,
            # which is the silent failure it was trying to stop (#3058).
            { [PesterConfiguration]@{ Run = @{ Paralel = $true } } } |
                Should -Throw -ExpectedMessage "*Run.Paralel: no such option, did you mean 'Run.Parallel'?*"
        }

        It "Rejects a misspelled section" {
            { [PesterConfiguration]@{ Runn = @{ Parallel = $true } } } |
                Should -Throw -ExpectedMessage "*Runn: no such section, did you mean 'Run'?*"
        }

        It "Leaves out the suggestion when nothing is close enough" {
            $err = { [PesterConfiguration]@{ Zzz = 1 } } | Should -Throw -PassThru
            $err.Exception.Message | Should -BeLike '*Zzz: no such section.*'
            $err.Exception.Message | Should -Not -BeLike '*did you mean*'
        }

        It "Accepts a configuration where every key is an option" {
            { [PesterConfiguration]@{ Run = @{ Parallel = $true }; Output = @{ Verbosity = 'None' } } } | Should -Not -Throw
        }

        It "Matches option names without regard to case" {
            { [PesterConfiguration]@{ run = @{ parallel = $true } } } | Should -Not -Throw
        }

        It "Points at the help" {
            { [PesterConfiguration]@{ Run = @{ Paralel = $true } } } |
                Should -Throw -ExpectedMessage "*'Get-Help about_PesterConfiguration' lists all the options*"
        }
    }

    Context "Reporting every problem at once" {
        It "Lists every unknown key and every unusable value, with a count" {
            # Reporting only the first one meant fixing a typo, rerunning, and finding the next.
            $err = { [PesterConfiguration]@{ Run = @{ Paralel = $true; Exit = 'yes'; Shufle = $true } } } | Should -Throw -PassThru
            $err.Exception.Message | Should -BeLike '*The configuration has 3 problems:*'
            $err.Exception.Message | Should -BeLike "*Run.Paralel: no such option, did you mean 'Run.Parallel'?*"
            $err.Exception.Message | Should -BeLike "*Run.Shufle: no such option, did you mean 'Run.Shuffle'?*"
            $err.Exception.Message | Should -BeLike "*Run.Exit expects a bool, but got the string 'yes'*"
        }

        It "Reports a bad value in more than one section" {
            $err = { [PesterConfiguration]@{ Run = @{ Exit = 'yes' }; Output = @{ Verbosity = @{} } } } | Should -Throw -PassThru
            $err.Exception.Message | Should -BeLike '*The configuration has 2 problems:*'
            $err.Exception.Message | Should -BeLike "*Run.Exit expects a bool, but got the string 'yes'*"
            $err.Exception.Message | Should -BeLike '*Output.Verbosity expects a string, but got a hashtable*'
        }

        It "Keeps a single problem as the sentence it is, with no list around it" {
            $err = { [PesterConfiguration]@{ Run = @{ Parallel = 'yes' } } } | Should -Throw -PassThru
            $err.Exception.Message | Should -BeLike "*Run.Parallel expects a bool, but got the string 'yes'.*"
            $err.Exception.Message | Should -Not -BeLike '*problems:*'
        }

        It "Lists the problems in a stable order, a hashtable does not enumerate in one" {
            $err = { [PesterConfiguration]@{ Zzz = 1; Run = @{ Paralel = $true }; Aaa = 1 } } | Should -Throw -PassThru
            $message = $err.Exception.Message
            $message.IndexOf('Aaa') | Should -BeLessThan $message.IndexOf('Run.Paralel')
            $message.IndexOf('Run.Paralel') | Should -BeLessThan $message.IndexOf('Zzz')
        }
    }

    Context "Invoke-Pester" {
        BeforeAll {
            $testFile = "$(Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().Guid)).Tests.ps1"
            Set-Content -Path $testFile -Value "Describe 'a' { It 'b' { 1 | Should -Be 1 } }"
        }

        AfterAll {
            Remove-Item -Path $testFile -Force
        }

        It "Fails the call for a key that matches no option" {
            { Invoke-Pester -Configuration @{ Run = @{ Path = $testFile; Paralel = $true }; Output = @{ Verbosity = 'None' } } } |
                Should -Throw -ExpectedMessage "*Run.Paralel: no such option*"
        }

        It "Lists every key when there are several" {
            { Invoke-Pester -Configuration @{ Nonsense = 1; Run = @{ Path = $testFile; Paralel = $true }; Output = @{ Verbosity = 'None' } } } |
                Should -Throw -ExpectedMessage '*The configuration has 2 problems:*'
        }

        It "Runs when every key is an option" {
            { Invoke-Pester -Configuration @{ Run = @{ Path = $testFile }; Output = @{ Verbosity = 'None' } } } | Should -Not -Throw
        }
    }
}
