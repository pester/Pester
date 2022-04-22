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
            $formatData.FormatViewDefinition[0].Control | Should -BeOfType [System.Management.Automation.ListControl]
        }

        It 'View includes all options' {
            $propertiesInView = @($formatData.FormatViewDefinition[0].Control.Entries.Items.DisplayEntry | Where-Object ValueType -eq 'Property')
            $propertiesInView.Count | Should -Be $options.Count
            $missingOptions = $options.Name | Where-Object { $propertiesInView.Value -notcontains $_ }
            $missingOptions | Should -Be @()
        }
    }
}

Describe 'PesterConfiguration' {
    It 'should convert arraylists' {
        $expectedPaths = @('one', 'two', 'three')
        $pathList = [Collections.ArrayList]$expectedPaths
        $config = [PesterConfiguration]@{ Run = @{ Path = $pathList } }
        $config.Run.Path.Value | Should -Be $expectedPaths
    }
}
