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
        It "Collects a misspelled option" {
            ([PesterConfiguration]@{ Run = @{ Paralel = $true } }).GetUnknownKeys() | Should -Be @('Run.Paralel')
        }

        It "Collects a misspelled section" {
            ([PesterConfiguration]@{ Runn = @{ Parallel = $true } }).GetUnknownKeys() | Should -Be @('Runn')
        }

        It "Collects nothing when every key is an option" {
            ([PesterConfiguration]@{ Run = @{ Parallel = $true }; Output = @{ Verbosity = 'None' } }).GetUnknownKeys() | Should -BeNullOrEmpty
        }

        It "Matches option names without regard to case" {
            ([PesterConfiguration]@{ run = @{ parallel = $true } }).GetUnknownKeys() | Should -BeNullOrEmpty
        }

        It "Survives the merge Invoke-Pester does before it reports them" {
            $merged = [PesterConfiguration]::Merge([PesterConfiguration]::Default, [PesterConfiguration]@{ Run = @{ Paralel = $true } })
            $merged.GetUnknownKeys() | Should -Be @('Run.Paralel')
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

        It "Warns about a key that matches no option" {
            $warnings = Invoke-Pester -Configuration @{ Run = @{ Path = $testFile; Paralel = $true }; Output = @{ Verbosity = 'None' } } 3>&1
            $warnings | Should -BeLike "*Ignoring configuration key 'Run.Paralel', there is no such option*"
        }

        It "Warns once, listing every key, when there are several" {
            $warnings = @(Invoke-Pester -Configuration @{ Nonsense = 1; Run = @{ Path = $testFile; Paralel = $true }; Output = @{ Verbosity = 'None' } } 3>&1)
            $warnings.Count | Should -Be 1
            $warnings[0].Message | Should -BeLike "*keys 'Run.Paralel', 'Nonsense', there are no such options*"
        }

        It "Does not warn when every key is an option" {
            $warnings = @(Invoke-Pester -Configuration @{ Run = @{ Path = $testFile }; Output = @{ Verbosity = 'None' } } 3>&1)
            $warnings | Should -BeNullOrEmpty
        }
    }
}
