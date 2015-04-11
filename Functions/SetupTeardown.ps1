function BeforeEach
{
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
    BeforeEach, AfterEach, BeforeAll, and AfterAll are unique in that they apply
    to the entire Context or Describe block, regardless of the order of the
    statements in the Context or Describe.  For a full description of this
    behavior, as well as how multiple BeforeEach or AfterEach blocks interact
    with each other, please refer to the about_BeforeEach_AfterEach help file.

.LINK
    about_BeforeEach_AfterEach
#>
    Assert-DescribeInProgress -CommandName AfterEach
}

function BeforeAll
{
<#
.SYNOPSIS
    Defines a series of steps to perform at the beginning of the current Context
    or Describe block.

.DESCRIPTION
    BeforeEach, AfterEach, BeforeAll, and AfterAll are unique in that they apply
    to the entire Context or Describe block, regardless of the order of the
    statements in the Context or Describe.

.LINK
    about_BeforeEach_AfterEach
#>
    Assert-DescribeInProgress -CommandName BeforeAll
}

function AfterAll
{
<#
.SYNOPSIS
    Defines a series of steps to perform at the end of every It block within
    the current Context or Describe block.

.DESCRIPTION
    BeforeEach, AfterEach, BeforeAll, and AfterAll are unique in that they apply
    to the entire Context or Describe block, regardless of the order of the
    statements in the Context or Describe.

.LINK
    about_BeforeEach_AfterEach
#>
    Assert-DescribeInProgress -CommandName AfterAll
}

function Clear-SetupAndTeardown
{
    $pester.BeforeEach = @( $pester.BeforeEach | Where-Object { $_.Scope -ne $pester.Scope } )
    $pester.AfterEach  = @( $pester.AfterEach  | Where-Object { $_.Scope -ne $pester.Scope } )
    $pester.BeforeAll  = @( $pester.BeforeAll  | Where-Object { $_.Scope -ne $pester.Scope } )
    $pester.AfterAll   = @( $pester.AfterAll   | Where-Object { $_.Scope -ne $pester.Scope } )
}

function Invoke-TestCaseSetupBlocks
{
    $orderedSetupBlocks = @(
        $pester.BeforeEach | Where-Object { $_.Scope -eq 'Describe' } | Select-Object -ExpandProperty ScriptBlock
        $pester.BeforeEach | Where-Object { $_.Scope -eq 'Context'  } | Select-Object -ExpandProperty ScriptBlock
    )

    Invoke-Blocks -ScriptBlock $orderedSetupBlocks
}

function Invoke-TestCaseTeardownBlocks
{
    $orderedTeardownBlocks = @(
        $pester.AfterEach | Where-Object { $_.Scope -eq 'Context'  } | Select-Object -ExpandProperty ScriptBlock
        $pester.AfterEach | Where-Object { $_.Scope -eq 'Describe' } | Select-Object -ExpandProperty ScriptBlock
    )

    Invoke-Blocks -ScriptBlock $orderedTeardownBlocks
}

function Invoke-TestGroupSetupBlocks
{
    param ([string] $Scope)

    $scriptBlocks = $pester.BeforeAll |
                    Where-Object { $_.Scope -eq $Scope } |
                    Select-Object -ExpandProperty ScriptBlock

    Invoke-Blocks -ScriptBlock $scriptBlocks
}

function Invoke-TestGroupTeardownBlocks
{
    param ([string] $Scope)

    $scriptBlocks = $pester.AfterAll |
                    Where-Object { $_.Scope -eq $Scope } |
                    Select-Object -ExpandProperty ScriptBlock

    Invoke-Blocks -ScriptBlock $scriptBlocks
}

function Invoke-Blocks
{
    param ([scriptblock[]] $ScriptBlock)

    foreach ($block in $ScriptBlock)
    {
        if ($null -eq $block) { continue }

        try
        {
            . $block
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
        $token = $tokens[$i]
        $type = $token.Type
        if ($type -eq [System.Management.Automation.PSTokenType]::Command -and
            (IsSetupOrTeardownCommand -CommandName $token.Content))
        {
            $openBraceIndex, $closeBraceIndex = Get-BraceIndecesForCommand -Tokens $tokens -CommandIndex $i
            Add-SetupTeardownFromTokens -Tokens $tokens -CommandIndex $i -OpenBraceIndex $openBraceIndex -CloseBraceIndex $closeBraceIndex -CodeText $codeText
            $i = $closeBraceIndex
        }
        elseif ($type -eq [System.Management.Automation.PSTokenType]::GroupStart)
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
    return $CommandName -eq 'BeforeEach' -or $CommandName -eq 'BeforeAll'
}

function IsTeardownCommand
{
    param ([string] $CommandName)
    return $CommandName -eq 'AfterEach' -or $CommandName -eq 'AfterAll'
}

function IsTestGroupCommand
{
    param ([string] $CommandName)
    return $CommandName -eq 'BeforeAll' -or $CommandName -eq 'AfterAll'
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

Add-Type -TypeDefinition @'
    namespace Pester
    {
        using System;
        using System.Management.Automation;

        public static class ClosingBraceFinder
        {
            public static int GetClosingBraceIndex(PSToken[] tokens, int startIndex)
            {
                int groupLevel = 1;
                int len = tokens.Length;

                for (int i = startIndex + 1; i < len; i++)
                {
                    PSTokenType type = tokens[i].Type;
                    if (type == PSTokenType.GroupStart)
                    {
                        groupLevel++;
                    }
                    else if (type == PSTokenType.GroupEnd)
                    {
                        groupLevel--;

                        if (groupLevel <= 0) { return i; }
                    }
                }

                return -1;
            }
        }
    }
'@

function Get-GroupCloseTokenIndex
{
    param (
        [System.Management.Automation.PSToken[]] $Tokens,
        [int] $GroupStartTokenIndex
    )

    $closeIndex = [Pester.ClosingBraceFinder]::GetClosingBraceIndex($Tokens, $GroupStartTokenIndex)

    if ($closeIndex -lt 0)
    {
        throw 'No corresponding GroupEnd token was found.'
    }

    return $closeIndex
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

    $isSetupCommand = IsSetupCommand -CommandName $commandName
    $isGroupCommand = IsTestGroupCommand -CommandName $commandName

    if ($isSetupCommand)
    {
        if ($isGroupCommand)
        {
            Add-BeforeAll -ScriptBlock $setupOrTeardownBlock
        }
        else
        {
            Add-BeforeEach -ScriptBlock $setupOrTeardownBlock
        }
    }
    else
    {
        if ($isGroupCommand)
        {
            Add-AfterAll -ScriptBlock $setupOrTeardownBlock
        }
        else
        {
            Add-AfterEach -ScriptBlock $setupOrTeardownBlock
        }
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

function Add-BeforeAll
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

    $pester.BeforeAll += @(New-Object psobject -Property $props)
}

function Add-AfterAll
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

    $pester.AfterAll += @(New-Object psobject -Property $props)
}
