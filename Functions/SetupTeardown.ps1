function BeforeEach {
    <#
    .SYNOPSIS
        Defines a series of steps to perform at the beginning of every It block within
        the current Context or Describe block.

    .DESCRIPTION
        BeforeEach, AfterEach, BeforeAll, and AfterAll are unique in that they apply
        to the entire Context or Describe block, regardless of the order of the
        statements in the Context or Describe.  For a full description of this
        behavior, as well as how multiple BeforeEach or AfterEach blocks interact
        with each other, please refer to the about_BeforeEach_AfterEach help file.

    .LINK
        https://github.com/pester/Pester/wiki/BeforeEach-and-AfterEach

    .LINK
        about_BeforeEach_AfterEach
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

    Pester.Runtime\New-EachTestSetup -ScriptBlock $Scriptblock
}

function AfterEach {
    <#
    .SYNOPSIS
        Defines a series of steps to perform at the end of every It block within
        the current Context or Describe block.

    .DESCRIPTION
        BeforeEach, AfterEach, BeforeAll, and AfterAll are unique in that they apply
        to the entire Context or Describe block, regardless of the order of the
        statements in the Context or Describe.  For a full description of this
        behavior, as well as how multiple BeforeEach or AfterEach blocks interact
        with each other, please refer to the about_BeforeEach_AfterEach help file.

    .LINK
        https://github.com/pester/Pester/wiki/BeforeEach-and-AfterEach

    .LINK
        about_BeforeEach_AfterEach
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

    Pester.Runtime\New-EachTestTeardown -ScriptBlock $Scriptblock
}

function BeforeAll {
    <#
    .SYNOPSIS
        Defines a series of steps to perform at the beginning of the current Context
        or Describe block.

    .DESCRIPTION
        BeforeEach, AfterEach, BeforeAll, and AfterAll are unique in that they apply
        to the entire Context or Describe block, regardless of the order of the
        statements in the Context or Describe.

    .LINK
        https://github.com/pester/Pester/wiki/BeforeEach-and-AfterEach

    .LINK
        about_BeforeEach_AfterEach
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

    Pester.Runtime\New-OneTimeTestSetup -ScriptBlock $Scriptblock
}

function AfterAll {
    <#
.SYNOPSIS
    Defines a series of steps to perform at the end of the current Context
    or Describe block.

.DESCRIPTION
    BeforeEach, AfterEach, BeforeAll, and AfterAll are unique in that they apply
    to the entire Context or Describe block, regardless of the order of the
    statements in the Context or Describe.

    .LINK
        https://github.com/pester/Pester/wiki/BeforeEach-and-AfterEach

    .LINK
    about_BeforeEach_AfterEach
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

    Pester.Runtime\New-OneTimeTestTeardown -ScriptBlock $Scriptblock
}
