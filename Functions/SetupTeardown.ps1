function BeforeEach
{
<#
.SYNOPSIS
    Defines a series of steps to perform at the beginning of every It block within
    the current Context or Describe block.

.DESCRIPTION
    BeforeEach and AfterEach are unique in that they apply to the entire Context
    or Describe block, even those that come before the BeforeEach or AfterEach
    definition within the Context or Describe.  For a full description of this
    behavior, as well as how multiple BeforeEach or AfterEach blocks interact
    with each other, please refer to the about_BeforeEach_AfterEach help file.

.LINK
    about_BeforeEach_AfterEach
#>
    Assert-DescribeInProgress -CommandName BeforeEach
}

function AfterEach
{
<#
.SYNOPSIS
    Defines a series of steps to perform at the end of every It block within
    the current Context or Describe block.

.DESCRIPTION
    BeforeEach and AfterEach are unique in that they apply to the entire Context
    or Describe block, even those that come before the BeforeEach or AfterEach
    definition within the Context or Describe.  For a full description of this
    behavior, as well as how multiple BeforeEach or AfterEach blocks interact
    with each other, please refer to the about_BeforeEach_AfterEach help file.

.LINK
    about_BeforeEach_AfterEach
#>
    Assert-DescribeInProgress -CommandName AfterEach
}

function Clear-SetupAndTeardown
{
    $pester.BeforeEach = @( $pester.BeforeEach | Where-Object { $_.Scope -ne $pester.Scope } )
    $pester.AfterEach  = @( $pester.AfterEach  | Where-Object { $_.Scope -ne $pester.Scope } )
}

function Invoke-SetupBlocks
{
    $orderedSetupBlocks = @(
        $pester.BeforeEach | Where-Object { $_.Scope -eq 'Describe' }
        $pester.BeforeEach | Where-Object { $_.Scope -eq 'Context'  }
    )

    foreach ($setupBlock in $orderedSetupBlocks)
    {
        try
        {
            . $setupBlock.ScriptBlock
        }
        catch
        {
            Write-Error -ErrorRecord $_
        }
    }
}

function Invoke-TeardownBlocks
{
    $orderedTeardownBlocks = @(
        $pester.AfterEach | Where-Object { $_.Scope -eq 'Context'  }
        $pester.AfterEach | Where-Object { $_.Scope -eq 'Describe' }
    )

    foreach ($teardownBlock in $orderedTeardownBlocks)
    {
        try
        {
            . $teardownBlock.ScriptBlock
        }
        catch
        {
            Write-Error -ErrorRecord $_
        }
    }
}

function Add-SetupAndTeardown
{
    param (
        [scriptblock] $ScriptBlock
    )

    $codeText = $ScriptBlock.ToString()
    $tokens = ParseCodeIntoTokens -CodeText $codeText

    for ($i = 0; $i -lt $tokens.Count; $i++)
    {
        if ($tokens[$i].Type -eq [System.Management.Automation.PSTokenType]::Command -and
            (IsSetupOrTeardownCommand -CommandName $tokens[$i].Content))
        {
            $openBraceIndex, $closeBraceIndex = Get-BraceIndecesForCommand -Tokens $tokens -CommandIndex $i
            Add-SetupTeardownFromTokens -Tokens $tokens -CommandIndex $i -OpenBraceIndex $openBraceIndex -CloseBraceIndex $closeBraceIndex -CodeText $codeText
            $i = $closeBraceIndex
        }
        elseif ($tokens[$i].Type -eq [System.Management.Automation.PSTokenType]::GroupStart)
        {
            # We don't want to parse Setup or Teardown commands in child scopes here, so anything
            # bounded by a GroupStart / GroupEnd token pair which is not immediately preceded by
            # a setup / teardown command name is ignored.
            $i = Get-GroupCloseTokenIndex -Tokens $tokens -GroupStartTokenIndex $i
        }
    }
}

function ParseCodeIntoTokens
{
    param ([string] $CodeText)

    $parseErrors = $null
    $tokens = [System.Management.Automation.PSParser]::Tokenize($CodeText, [ref] $parseErrors)

    if ($parseErrors.Count -gt 0)
    {
        $currentScope = $pester.Scope
        throw "The current $currentScope block contains syntax errors."
    }

    return $tokens
}

function IsSetupOrTeardownCommand
{
    param ([string] $CommandName)
    return (IsSetupCommand -CommandName $CommandName) -or (IsTeardownCommand -CommandName $CommandName)
}

function IsSetupCommand
{
    param ([string] $CommandName)
    return $CommandName -eq 'BeforeEach'
}

function IsTeardownCommand
{
    param ([string] $CommandName)
    return $CommandName -eq 'AfterEach'
}

function Get-BraceIndecesForCommand
{
    param (
        [System.Management.Automation.PSToken[]] $Tokens,
        [int] $CommandIndex
    )

    $openingGroupTokenIndex = Get-GroupStartTokenForCommand -Tokens $Tokens -CommandIndex $CommandIndex
    $closingGroupTokenIndex = Get-GroupCloseTokenIndex -Tokens $Tokens -GroupStartTokenIndex $openingGroupTokenIndex

    return $openingGroupTokenIndex, $closingGroupTokenIndex
}

function Get-GroupStartTokenForCommand
{
    param (
        [System.Management.Automation.PSToken[]] $Tokens,
        [int] $CommandIndex
    )

    # We may want to allow newlines, other parameters, etc at some point.  For now it's good enough to
    # just verify that the next token after our BeforeEach or AfterEach command is an opening curly brace.

    $commandName = $Tokens[$CommandIndex].Content

    if ($CommandIndex + 1 -ge $tokens.Count -or
        $tokens[$CommandIndex + 1].Type -ne [System.Management.Automation.PSTokenType]::GroupStart -or
        $tokens[$CommandIndex + 1].Content -ne '{')
    {
        throw "The $commandName command must be immediately followed by the opening brace of a script block."
    }

    return $CommandIndex + 1
}

function Get-GroupCloseTokenIndex
{
    param (
        [System.Management.Automation.PSToken[]] $Tokens,
        [int] $GroupStartTokenIndex
    )

    $groupLevel = 1

    for ($i = $GroupStartTokenIndex + 1; $i -lt $Tokens.Count; $i++)
    {
        switch ($Tokens[$i].Type)
        {
            ([System.Management.Automation.PSTokenType]::GroupStart)
            {
                $groupLevel++
                break
            }

            ([System.Management.Automation.PSTokenType]::GroupEnd)
            {
                $groupLevel--

                if ($groupLevel -le 0)
                {
                    return $i
                }

                break
            }
        }
    }

    throw 'No corresponding GroupEnd token was found.'
}

function Add-SetupTeardownFromTokens
{
    param (
        [System.Management.Automation.PSToken[]] $Tokens,
        [int] $CommandIndex,
        [int] $OpenBraceIndex,
        [int] $CloseBraceIndex,
        [string] $CodeText
    )

    $commandName = $Tokens[$CommandIndex].Content

    $blockStart = $Tokens[$OpenBraceIndex + 1].Start
    $blockLength = $Tokens[$CloseBraceIndex].Start - $blockStart
    $setupOrTeardownCodeText = $codeText.Substring($blockStart, $blockLength)

    $setupOrTeardownBlock = [scriptblock]::Create($setupOrTeardownCodeText)
    Set-ScriptBlockScope -ScriptBlock $setupOrTeardownBlock -SessionState $pester.SessionState

    if (IsSetupCommand -CommandName $commandName)
    {
        Add-BeforeEach -ScriptBlock $setupOrTeardownBlock
    }
    else
    {
        Add-AfterEach -ScriptBlock $setupOrTeardownBlock
    }
}

function Add-BeforeEach
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    $props = @{
        Scope       = $pester.Scope
        ScriptBlock = $ScriptBlock
    }

    $pester.BeforeEach += @(New-Object psobject -Property $props)

}

function Add-AfterEach
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    $props = @{
        Scope       = $pester.Scope
        ScriptBlock = $ScriptBlock
    }

    $pester.AfterEach += @(New-Object psobject -Property $props)
}
