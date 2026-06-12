Set-StrictMode -Version Latest

Describe "Module scope separation" {
    Context "When users define variables with the same name as Pester parameters" {
        BeforeAll {
            $test = "This is a test."
        }

        It "does not hide user variables" {
            $test | Should -Be 'This is a test.'
        }
    }

    It "Does not expose Pester implementation details to the SUT" {
        # Changing the ConvertTo-PesterResult function's name would cause this test to pass artificially.
        # TODO: : come up with a better way of verifying that only the desired commands from the Pester
        # module are visible to the SUT.

        (Get-Item function:\ConvertTo-PesterResult -ErrorAction SilentlyContinue) | Should -Be $null
    }
}

Describe "Executing test code inside a module" {
    # do not put this into BeforeAll this needs to be imported before calling InModuleScope
    # that is below, because it requires the module to be loaded
    Get-Module TestModule | Remove-Module
    New-Module -Name TestModule {
        function InternalFunction {
            'I am the internal function'
        }
        function PublicFunction {
            InternalFunction
        }
        Export-ModuleMember -Function PublicFunction
    } | Import-Module -Force

    It "Cannot call module internal functions, by default" {
        { InternalFunction } | Should -Throw
    }

    InModuleScope TestModule {
        It "Can call module internal functions using InModuleScope" {
            InternalFunction | Should -Be 'I am the internal function'
        }

        It "Can mock functions inside the module without using Mock -ModuleName" {
            Mock InternalFunction { 'I am the mock function.' }
            InternalFunction | Should -Be 'I am the mock function.'
        }
    }

    It "Can execute bound ScriptBlock inside the module scope" {
        $ScriptBlock = { Write-Output "I am a bound ScriptBlock" }
        InModuleScope TestModule $ScriptBlock | Should -BeExactly "I am a bound ScriptBlock"
    }

    It "Can execute unbound ScriptBlock inside the module scope" {
        $ScriptBlockString = 'Write-Output "I am an unbound ScriptBlock"'
        $ScriptBlock = [ScriptBlock]::Create($ScriptBlockString)
        InModuleScope TestModule $ScriptBlock | Should -BeExactly "I am an unbound ScriptBlock"
    }

    AfterAll {
        # keep this in AfterAll so we remove the module after tests are invoked
        # and not while the tests are discovered
        Remove-Module TestModule -Force
    }
}

Describe 'Get-CompatibleModule' {

    Context 'when module name matches imported script module' {
        It 'should return a single ModuleInfo object' {
            $moduleInfo = InPesterModuleScope { Get-CompatibleModule -ModuleName Pester }
            $moduleInfo | Should -Not -BeNullOrEmpty
            @($moduleInfo).Count | Should -Be 1
            $moduleInfo.Name | Should -Be 'Pester'
            $moduleInfo.ModuleType | Should -Be 'Script'
        }
    }

    Context 'when module name matches imported manifest module' {
        BeforeAll {
            $moduleName = 'testManifestModule'
            $moduleManifestPath = "TestDrive:/$moduleName.psd1"
            New-ModuleManifest -Path $moduleManifestPath
            Import-Module $moduleManifestPath -Force
        }

        AfterAll {
            Get-Module $moduleName -ErrorAction SilentlyContinue | Remove-Module
            Remove-Item $moduleManifestPath -Force -ErrorAction SilentlyContinue
        }

        It 'should return a single ModuleInfo object' {
            $moduleInfo = InPesterModuleScope { Get-CompatibleModule -ModuleName testManifestModule }
            $moduleInfo | Should -Not -BeNullOrEmpty
            @($moduleInfo).Count | Should -Be 1
            $moduleInfo.Name | Should -Be 'testManifestModule'
            $moduleInfo.ModuleType | Should -Be 'Manifest'
        }
    }

    Context 'when module name does not resolve to imported module' {
        It "should throw an exception" {
            $sb = { InPesterModuleScope { Get-CompatibleModule -ModuleName MyNonExistentModule } }
            $sb | Should -Throw "No modules named 'MyNonExistentModule' are currently loaded."
        }
    }

    Context 'when module name matches multiple imported modules' {
        BeforeAll {
            Get-Module 'MyDuplicateModule' -ErrorAction SilentlyContinue | Remove-Module
            New-Module -Name 'MyDuplicateModule' { } | Import-Module -Force
            New-Module -Name 'MyDuplicateModule' { } | Import-Module -Force
        }

        AfterAll {
            Get-Module 'MyDuplicateModule' -ErrorAction SilentlyContinue | Remove-Module
        }

        It "should throw an exception" {
            $sb = { InPesterModuleScope { Get-CompatibleModule -ModuleName MyDuplicateModule } }
            $sb | Should -Throw "Multiple script or manifest modules named 'MyDuplicateModule' are currently loaded. Make sure to remove any extra copies of the module from your session before testing."
        }
    }

    Context 'when module name uses slash notation RootModule/NestedModule' {
        BeforeAll {
            $nestedModuleName = 'NestedModule'
            $rootModuleName = 'RootWithNestedModule'
            $moduleManifestPath = "TestDrive:/$rootModuleName.psd1"
            $nestedScriptPath = "TestDrive:/$nestedModuleName.psm1"
            Set-Content -Path $nestedScriptPath -Value '[string]$Script:NestedVar = "NestedValue"'
            New-ModuleManifest -Path $moduleManifestPath -NestedModules ".\$nestedModuleName.psm1"
            Import-Module $moduleManifestPath -Force
        }

        AfterAll {
            Get-Module $rootModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
        }

        It 'should return the nested module via forward-slash delimiter' {
            $moduleInfo = InPesterModuleScope { Get-CompatibleModule -ModuleName 'RootWithNestedModule/NestedModule' }
            $moduleInfo | Should -Not -BeNullOrEmpty
            @($moduleInfo).Count | Should -Be 1
            $moduleInfo.Name | Should -Be 'NestedModule'
            $moduleInfo.ModuleType | Should -Be 'Script'
        }

        It 'should return the nested module via backslash delimiter' {
            $moduleInfo = InPesterModuleScope { Get-CompatibleModule -ModuleName 'RootWithNestedModule\NestedModule' }
            $moduleInfo | Should -Not -BeNullOrEmpty
            @($moduleInfo).Count | Should -Be 1
            $moduleInfo.Name | Should -Be 'NestedModule'
            $moduleInfo.ModuleType | Should -Be 'Script'
        }

        It 'should execute in the nested module session state' {
            $name = InModuleScope -ModuleName 'RootWithNestedModule/NestedModule' -ScriptBlock {
                $ExecutionContext.SessionState.Module.Name
            }
            $name | Should -Be 'NestedModule'
        }

        It 'should read a variable defined in the nested module' {
            InModuleScope -ModuleName 'RootWithNestedModule/NestedModule' -ScriptBlock {
                $Script:NestedVar | Should -Be 'NestedValue'
            }
        }

        It 'should throw when root module is not loaded' {
            $sb = { InPesterModuleScope { Get-CompatibleModule -ModuleName 'NonExistentRoot/NestedModule' } }
            $sb | Should -Throw "No modules named 'NonExistentRoot' are currently loaded."
        }

        It 'should throw with available names when nested module is not found in root' {
            $sb = { InPesterModuleScope { Get-CompatibleModule -ModuleName 'RootWithNestedModule/NoSuchNested' } }
            $sb | Should -Throw "No nested module named 'NoSuchNested' was found under 'RootWithNestedModule'*"
        }
    }

    Context 'when module name uses deep slash notation RootModule/NestedModule/LeafModule' {
        BeforeAll {
            $rootModuleName = 'DeepRootModule'
            $midModuleName = 'DeepMidModule'
            $leafModuleName = 'DeepLeafModule'

            $rootManifestPath = "TestDrive:/$rootModuleName.psd1"
            $midManifestPath = "TestDrive:/$midModuleName.psd1"
            $leafScriptPath = "TestDrive:/$leafModuleName.psm1"

            Set-Content -Path $leafScriptPath -Value '[string]$Script:DeepNestedVar = "DeepNestedValue"'
            New-ModuleManifest -Path $midManifestPath -NestedModules ".\$leafModuleName.psm1"
            New-ModuleManifest -Path $rootManifestPath -NestedModules ".\$midModuleName.psd1"

            Import-Module $rootManifestPath -Force
        }

        AfterAll {
            Get-Module $rootModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
        }

        It 'should resolve the leaf module via forward-slash deep path' {
            $moduleInfo = InPesterModuleScope { Get-CompatibleModule -ModuleName 'DeepRootModule/DeepMidModule/DeepLeafModule' }
            $moduleInfo | Should -Not -BeNullOrEmpty
            $moduleInfo.Name | Should -Be 'DeepLeafModule'
            $moduleInfo.ModuleType | Should -Be 'Script'
        }

        It 'should resolve the leaf module via mixed slash and backslash deep path' {
            $moduleInfo = InPesterModuleScope { Get-CompatibleModule -ModuleName 'DeepRootModule\DeepMidModule/DeepLeafModule' }
            $moduleInfo | Should -Not -BeNullOrEmpty
            $moduleInfo.Name | Should -Be 'DeepLeafModule'
            $moduleInfo.ModuleType | Should -Be 'Script'
        }

        It 'should execute in the deeply nested module session state' {
            $name = InModuleScope -ModuleName 'DeepRootModule/DeepMidModule/DeepLeafModule' -ScriptBlock {
                $ExecutionContext.SessionState.Module.Name
            }
            $name | Should -Be 'DeepLeafModule'
        }

        It 'should read a variable defined in the deeply nested module' {
            InModuleScope -ModuleName 'DeepRootModule/DeepMidModule/DeepLeafModule' -ScriptBlock {
                $Script:DeepNestedVar | Should -Be 'DeepNestedValue'
            }
        }

        It 'should throw with available names when a deeper nested segment is not found' {
            $sb = { InPesterModuleScope { Get-CompatibleModule -ModuleName 'DeepRootModule/DeepMidModule/NoSuchLeaf' } }
            $sb | Should -Throw "No nested module named 'NoSuchLeaf' was found under 'DeepRootModule/DeepMidModule'*"
        }
    }

    Context 'when two root modules share a nested module name (disambiguation use-case)' {
        BeforeAll {
            $sharedNestedName = 'SharedRepository'
            $rootA = 'ClientA'
            $rootB = 'ClientB'
            $manifestA = "TestDrive:/$rootA.psd1"
            $manifestB = "TestDrive:/$rootB.psd1"
            $nestedA = "TestDrive:/$sharedNestedName`_A.psm1"
            $nestedB = "TestDrive:/$sharedNestedName`_B.psm1"
            # Both root modules have a nested module called 'SharedRepository'
            Set-Content -Path $nestedA -Value '[string]$Script:RepoId = "RepoA"'
            Set-Content -Path $nestedB -Value '[string]$Script:RepoId = "RepoB"'
            # Rename nested copies so they each load as 'SharedRepository' (same base name)
            $nestedPathA = "TestDrive:/$sharedNestedName.psm1"
            $nestedPathB = "TestDrive:/B_$sharedNestedName.psm1"
            Set-Content -Path $nestedPathA -Value '[string]$Script:RepoId = "RepoA"'
            Set-Content -Path $nestedPathB -Value '[string]$Script:RepoId = "RepoB"'
            New-ModuleManifest -Path $manifestA -NestedModules ".\$sharedNestedName.psm1"
            New-ModuleManifest -Path $manifestB -NestedModules ".\B_$sharedNestedName.psm1"
            Import-Module $manifestA -Force
            Import-Module $manifestB -Force
        }

        AfterAll {
            Get-Module $rootA -ErrorAction SilentlyContinue | Remove-Module -Force
            Get-Module $rootB -ErrorAction SilentlyContinue | Remove-Module -Force
        }

        It 'should resolve to ClientA nested module via slash notation' {
            $name = InModuleScope -ModuleName "$rootA/$sharedNestedName" -ScriptBlock {
                $ExecutionContext.SessionState.Module.Name
            }
            $name | Should -Be $sharedNestedName
        }
    }
}

Describe 'InModuleScope arguments and parameter binding' {

    BeforeAll {
        Get-Module TestModule2 | Remove-Module
        New-Module -Name TestModule2 { } | Import-Module -Force
    }

    It 'Works with parameters while using advanced function/script' {
        # https://github.com/pester/Pester/issues/1809
        $inModuleScopeParameters = @{
            SomeParam = 'SomeValue'
        }

        $sb = {
            param
            (
                [Parameter()]
                [System.String]
                $SomeParam
            )
            "$SomeParam"
        }

        InModuleScope -ModuleName TestModule2 -Parameters $inModuleScopeParameters -ScriptBlock $sb | Should -Be $inModuleScopeParameters.SomeParam
    }

    It 'Works with parameters and arguments while using advanced function/script' {
        # https://github.com/pester/Pester/issues/1809
        $inModuleScopeParameters = @{
            SomeParam = 'SomeValue'
        }

        $myArgs = "foo", 123

        $sb = {
            param
            (
                [Parameter()]
                [System.String]
                $SomeParam,

                [Parameter(ValueFromRemainingArguments = $true)]
                $RemainingArgs
            )
            "$SomeParam"
            $RemainingArgs.Count
        }

        InModuleScope -ModuleName TestModule2 -Parameters $inModuleScopeParameters -ScriptBlock $sb -ArgumentList $myArgs | Should -Be @($inModuleScopeParameters.SomeParam, $myArgs.Count)
    }

    It 'Arguments are available in scriptblock' {
        $arguments = @(12345)

        $sb = {
            $args.Count
            $args[0]
        }

        InModuleScope -ModuleName TestModule2 -ArgumentList $arguments -ScriptBlock $sb | Should -Be $arguments.Count, $arguments
    }

    It 'single argument works' {
        $sb = {
            $args.Count
            $args[0]
        }

        InModuleScope -ModuleName TestModule2 -ArgumentList 'hello' -ScriptBlock $sb | Should -Be 1, 'hello'
    }

    It 'array argument works' {
        $arguments = [int[]](1, 2, 3), 'hello'
        $sb = {
            $args.Count
            $args[0].Count
            $args[1]
        }

        InModuleScope -ModuleName TestModule2 -ArgumentList $arguments -ScriptBlock $sb | Should -Be 2, 3, 'hello'
    }

    It 'Support $null as argument' {
        $sb = {
            $args.Count
            $args[0]
        }

        InModuleScope -ModuleName TestModule2 -ArgumentList $null -ScriptBlock $sb | Should -Be 1, $null
    }

    It 'Arguments are first in args when parameters are also used and no param-block exists' {
        # https://github.com/pester/Pester/pull/1957#discussion_r637891515
        $inModuleScopeParameters = @{
            SomeParam = 'SomeValue'
        }
        $arguments = 12345

        $sb = {
            $args[0]
        }

        InModuleScope -ModuleName TestModule2 -Parameters $inModuleScopeParameters -ArgumentList $arguments -ScriptBlock $sb | Should -Be $arguments
    }

    It '$args is empty when no arguments are provided' {
        # https://github.com/pester/Pester/pull/1957#discussion_r637772167
        $sb = {
            $args.Count
        }

        InModuleScope -ModuleName TestModule2 -ScriptBlock $sb | Should -Be 0
    }

    It 'Arguments bind to remaining parameters in param-block' {
        $sb = {
            param($param1, $param2)
            $param1
            $param2
            $args.Count
        }

        InModuleScope -ModuleName TestModule2 -ScriptBlock $sb -Parameters @{ param1 = 'foo' } -ArgumentList 123 | Should -Be 'foo', 123, 0
    }

    It 'internal variables used in InModuleScope wrapper does not leak into scriptblock' {
        $sb = {
            $null -eq $SessionState
        }

        InModuleScope -ModuleName TestModule2 -ScriptBlock $sb | Should -BeTrue
    }

    It 'Automatically imports parameters as variables in module scoped scriptblock' {
        # https://github.com/pester/Pester/issues/1603
        $inModuleScopeParameters = @{
            SomeParam2 = 'MyValue'
        }

        $sb = {
            "$SomeParam2"
        }

        $sb2 = {
            # Should return nothing. Making sure dynamic variable isn't persisted in module state.
            "$SomeParam2"
        }

        InModuleScope -ModuleName TestModule2 -ScriptBlock $sb -Parameters $inModuleScopeParameters | Should -Be $inModuleScopeParameters.SomeParam2
        InModuleScope -ModuleName TestModule2 -ScriptBlock $sb2 | Should -BeNullOrEmpty
    }

    AfterAll {
        Remove-Module TestModule2 -Force
    }
}

Describe "Using variables within module scope" {
    BeforeAll {
        Get-Module TestModule2 | Remove-Module
        New-Module -Name TestModule2 { } | Import-Module -Force
    }

    It 'Only script-scoped variables should persist across InModuleScope calls' {
        $setup = {
            $script:myVar = 'bar'
            $myVar2 = 'bar'
        }
        InModuleScope -ModuleName TestModule2 -ScriptBlock $setup

        InModuleScope -ModuleName TestModule2 -ScriptBlock { $script:myVar } | Should -Be 'bar'
        InModuleScope -ModuleName TestModule2 -ScriptBlock { $myVar2 } | Should -BeNullOrEmpty
    }

    AfterAll {
        Remove-Module TestModule2 -Force
    }
}

Describe 'Working with manifest modules' {
    BeforeAll {
        $moduleName = 'inManifestModule'
        $moduleManifestPath = "TestDrive:/$moduleName.psd1"
        $scriptPath = "TestDrive:/$moduleName-functions.ps1"

        Set-Content -Path $scriptPath -Value {
            function myPublicFunction {
                myPrivateFunction
            }

            function myPrivateFunction {
                'real'
            }
        }

        New-ModuleManifest -Path $moduleManifestPath -NestedModules "$moduleName-functions.ps1" -FunctionsToExport 'myPublicFunction'
        Import-Module $moduleManifestPath -Force
    }

    AfterAll {
        Get-Module $moduleName -ErrorAction SilentlyContinue | Remove-Module
        Remove-Item $moduleManifestPath, $scriptPath -Force -ErrorAction SilentlyContinue
    }

    It "Should invoke inside module's sessions state" {
        $res = InModuleScope -ModuleName $moduleName -ScriptBlock { $ExecutionContext.SessionState.Module }
        $res.Name | Should -Be $moduleName
    }

    It 'Should be able to invoke private functions' {
        $res = InModuleScope -ModuleName $moduleName -ScriptBlock { myPrivateFunction }
        $res | Should -Be 'real'
    }
}
