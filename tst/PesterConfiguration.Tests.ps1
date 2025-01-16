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
