function BeforeEach {
    <#
    .SYNOPSIS
        Defines a series of steps to perform at the beginning of every It block within
        the current Context or Describe block.

    .DESCRIPTION
        BeforeEach runs once before every test in the current or any child blocks.
        Typically this is used to create all the prerequisites for the current test,
        such as writing content to a file.

        BeforeEach and AfterEach are unique in that they apply to the entire Context
        or Describe block, regardless of the order of the statements in the
        Context or Describe.

    .PARAMETER ScriptBlock
        A scriptblock with steps to be executed during setup.

    .EXAMPLE
        ```powershell
        Describe "File parsing" {
            BeforeEach {
                # randomized path, to get fresh file for each test
                $file = "$([IO.Path]::GetTempPath())/$([Guid]::NewGuid())_form.xml"
                Copy-Item -Source $template -Destination $file -Force | Out-Null
            }

            It "Writes username" {
                Write-XmlForm -Path $file -Field "username" -Value "nohwnd"
                $content = Get-Content $file
                # ...
            }

            It "Writes name" {
                Write-XmlForm -Path $file -Field "name" -Value "Jakub"
                $content = Get-Content $file
                # ...
            }
        }
        ```

        The example uses BeforeEach to ensure a clean sample-file is used for each test.

    .LINK
        https://pester.dev/docs/commands/BeforeEach

    .LINK
        https://pester.dev/docs/usage/setup-and-teardown
    #>
    [CmdletBinding()]
    param
    (
        # the scriptblock to execute
        [Parameter(Mandatory = $true,
            Position = 1)]
        [Scriptblock]
        $Scriptblock
    )
    Assert-DescribeInProgress -CommandName BeforeEach
    Assert-BoundScriptBlockInput -ScriptBlock $Scriptblock

    New-EachTestSetup -ScriptBlock $Scriptblock
}

function AfterEach {
    <#
    .SYNOPSIS
        Defines a series of steps to perform at the end of every It block within
        the current Context or Describe block.

    .DESCRIPTION
        AfterEach runs once after every test in the current or any child blocks.
        Typically this is used to clean up resources created by the test or its setups.
        AfterEach runs in a finally block, and is guaranteed to run even if the test
        (or setup) fails.

        BeforeEach and AfterEach are unique in that they apply to the entire Context
        or Describe block, regardless of the order of the statements in the
        Context or Describe.

    .PARAMETER ScriptBlock
        A scriptblock with steps to be executed during teardown.

    .EXAMPLE
        ```powershell
        Describe "Testing export formats" {
            BeforeAll {
                $filePath = "$([IO.Path]::GetTempPath())/$([Guid]::NewGuid())"
            }
            It "Test Export-CSV" {
                Get-ChildItem | Export-CSV -Path $filePath -NoTypeInformation
                $dir = Import-CSV -Path $filePath
                # ...
            }
            It "Test Export-Clixml" {
                Get-ChildItem | Export-Clixml -Path $filePath
                $dir = Import-Clixml -Path $filePath
                # ...
            }

            AfterEach {
                if (Test-Path $file) {
                    Remove-Item $file -Force
                }
            }
        }
        ```

        The example uses AfterEach to remove a temporary file after each test.

    .LINK
        https://pester.dev/docs/commands/AfterEach

    .LINK
        https://pester.dev/docs/usage/setup-and-teardown
    #>
    [CmdletBinding()]
    param
    (
        # the scriptblock to execute
        [Parameter(Mandatory = $true,
            Position = 1)]
        [Scriptblock]
        $Scriptblock
    )
    Assert-DescribeInProgress -CommandName AfterEach
    Assert-BoundScriptBlockInput -ScriptBlock $Scriptblock

    New-EachTestTeardown -ScriptBlock $Scriptblock
}

function BeforeAll {
    <#
    .SYNOPSIS
        Defines a series of steps to perform at the beginning of the current container,
        Context or Describe block.

    .DESCRIPTION
        BeforeAll is used to share setup among all the tests in a container, Describe
        or Context including all child blocks and tests. BeforeAll runs during Run phase
        and runs only once in the current level.

        The typical usage is to setup the whole test script, most commonly to
        import the tested function, by dot-sourcing the script file that contains it.

        BeforeAll and AfterAll are unique in that they apply to the entire container,
        Context or Describe block regardless of the order of the statements compared to
        other Context or Describe blocks at the same level.

    .PARAMETER ScriptBlock
        A scriptblock with steps to be executed during setup.

    .EXAMPLE
        ```powershell
        BeforeAll {
            . $PSCommandPath.Replace('.Tests.ps1','.ps1')
        }

        Describe "API validation" {
            # ...
        }
        ```

        This example uses dot-sourcing in BeforeAll to make functions in the script-file
        available for the tests.

    .EXAMPLE
        ```powershell
        Describe "API validation" {
            BeforeAll {
                # this calls REST API and takes roughly 1 second
                $response = Get-Pokemon -Name Pikachu
            }

            It "response has Name = 'Pikachu'" {
                $response.Name | Should -Be 'Pikachu'
            }

            It "response has Type = 'electric'" {
                $response.Type | Should -Be 'electric'
            }
        }
        ```

        This example uses BeforeAll to perform an expensive operation only once, before validating
        the results in separate tests.

    .LINK
        https://pester.dev/docs/commands/BeforeAll

    .LINK
        https://pester.dev/docs/usage/setup-and-teardown
    #>
    [CmdletBinding()]
    param
    (
        # the scriptblock to execute
        [Parameter(Mandatory = $true,
            Position = 1)]
        [Scriptblock]
        $Scriptblock
    )
    Assert-BoundScriptBlockInput -ScriptBlock $Scriptblock

    New-OneTimeTestSetup -ScriptBlock $Scriptblock
}

function AfterAll {
    <#
    .SYNOPSIS
        Defines a series of steps to perform at the end of the current container,
        Context or Describe block.

    .DESCRIPTION
        AfterAll is used to share teardown after all the tests in a container, Describe
        or Context including all child blocks and tests. AfterAll runs during Run phase
        and runs only once in the current block. It's guaranteed to run even if tests
        fail.

        The typical usage is to clean up state or temporary used in tests.

        BeforeAll and AfterAll are unique in that they apply to the entire container,
        Context or Describe block regardless of the order of the statements compared to
        other Context or Describe blocks at the same level.

    .PARAMETER ScriptBlock
        A scriptblock with steps to be executed during teardown.

    .EXAMPLE
        ```powershell
        Describe "Validate important file" {
            BeforeAll {
                $samplePath = "$([IO.Path]::GetTempPath())/$([Guid]::NewGuid()).txt"
                Write-Host $samplePath
                1..100 | Set-Content -Path $samplePath
            }

            It "File Contains 100 lines" {
                @(Get-Content $samplePath).Count | Should -Be 100
            }

            It "First ten lines should be 1 -> 10" {
                @(Get-Content $samplePath -TotalCount 10) | Should -Be @(1..10)
            }

            AfterAll {
                Remove-Item -Path $samplePath
            }
        }
        ```

        This example uses AfterAll to clean up a sample-file generated only for
        the tests in the Describe-block.

    .LINK
        https://pester.dev/docs/commands/AfterAll

    .LINK
        https://pester.dev/docs/usage/setup-and-teardown
#>
    [CmdletBinding()]
    param
    (
        # the scriptblock to execute
        [Parameter(Mandatory = $true,
            Position = 1)]
        [Scriptblock]
        $Scriptblock
    )
    Assert-DescribeInProgress -CommandName AfterAll
    Assert-BoundScriptBlockInput -ScriptBlock $Scriptblock

    New-OneTimeTestTeardown -ScriptBlock $Scriptblock
}
