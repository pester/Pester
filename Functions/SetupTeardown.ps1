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
    Assert-DescribeInProgress -CommandName BeforeAll
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
}

function Invoke-TestCaseSetupBlocks {
    Invoke-Blocks -ScriptBlock $pester.GetTestCaseSetupBlocks()
}

function Invoke-TestCaseTeardownBlocks {
    Invoke-Blocks -ScriptBlock $pester.GetTestCaseTeardownBlocks()
}

function Invoke-TestGroupSetupBlocks {
    Invoke-Blocks -ScriptBlock $pester.GetCurrentTestGroupSetupBlocks()
}

function Invoke-TestGroupTeardownBlocks {
    Invoke-Blocks -ScriptBlock $pester.GetCurrentTestGroupTeardownBlocks()
}

function Invoke-Blocks {
    param ([scriptblock[]] $ScriptBlock)

    foreach ($block in $ScriptBlock) {
        if ($null -eq $block) {
            continue
        }
        $null = . $block
    }
}

function Add-SetupAndTeardown {
    param (
        [scriptblock] $ScriptBlock
    )

    if ($PSVersionTable.PSVersion.Major -le 2) {
        Add-SetupAndTeardownV2 -ScriptBlock $ScriptBlock
    }
    else {
        Add-SetupAndTeardownV3 -ScriptBlock $ScriptBlock
    }
}

function Add-SetupAndTeardownV3 {
    param (
        [scriptblock] $ScriptBlock
    )

    $pattern = '^(?:Before|After)(?:Each|All)$'
    $predicate = {
        param ([System.Management.Automation.Language.Ast] $Ast)

        $Ast -is [System.Management.Automation.Language.CommandAst] -and
        $Ast.CommandElements[0].ToString() -match $pattern -and
        $Ast.CommandElements[-1] -is [System.Management.Automation.Language.ScriptBlockExpressionAst]
    }

    $searchNestedBlocks = $false

    $calls = $ScriptBlock.Ast.FindAll($predicate, $searchNestedBlocks)

    foreach ($call in $calls) {
        # For some reason, calling ScriptBlockAst.GetScriptBlock() sometimes blows up due to failing semantics
        # checks, even though the code is perfectly valid.  So we'll poke around with reflection again to skip
        # that part and just call the internal ScriptBlock constructor that we need

        $iPmdProviderType = [scriptblock].Assembly.GetType('System.Management.Automation.Language.IParameterMetadataProvider')

        $flags = [System.Reflection.BindingFlags]'Instance, NonPublic'
        $constructor = [scriptblock].GetConstructor($flags, $null, [Type[]]@($iPmdProviderType, [bool]), $null)

        $block = $constructor.Invoke(@($call.CommandElements[-1].ScriptBlock, $false))

        Set-ScriptBlockScope -ScriptBlock $block -SessionState $pester.SessionState
        $commandName = $call.CommandElements[0].ToString()
        Add-SetupOrTeardownScriptBlock -CommandName $commandName -ScriptBlock $block
    }
}

function Add-SetupAndTeardownV2 {
    param (
        [scriptblock] $ScriptBlock
    )

    $codeText = $ScriptBlock.ToString()
    $tokens = @(ParseCodeIntoTokens -CodeText $codeText)

    for ($i = 0; $i -lt $tokens.Count; $i++) {
        $token = $tokens[$i]
        $type = $token.Type
        if ($type -eq [System.Management.Automation.PSTokenType]::Command -and
            (IsSetupOrTeardownCommand -CommandName $token.Content)) {
            $openBraceIndex, $closeBraceIndex = Get-BraceIndicesForCommand -Tokens $tokens -CommandIndex $i

            $block = Get-ScriptBlockFromTokens -Tokens $Tokens -OpenBraceIndex $openBraceIndex -CloseBraceIndex $closeBraceIndex -CodeText $codeText
            Add-SetupOrTeardownScriptBlock -CommandName $token.Content -ScriptBlock $block

            $i = $closeBraceIndex
        }
        elseif ($type -eq [System.Management.Automation.PSTokenType]::GroupStart) {
            # We don't want to parse Setup or Teardown commands in child scopes here, so anything
            # bounded by a GroupStart / GroupEnd token pair which is not immediately preceded by
            # a setup / teardown command name is ignored.
            $i = Get-GroupCloseTokenIndex -Tokens $tokens -GroupStartTokenIndex $i
        }
    }
}

function ParseCodeIntoTokens {
    param ([string] $CodeText)

    $parseErrors = $null
    $tokens = [System.Management.Automation.PSParser]::Tokenize($CodeText, [ref] $parseErrors)

    if ($parseErrors.Count -gt 0) {
        $currentScope = $pester.CurrentTestGroup.Hint
        if (-not $currentScope) {
            $currentScope = 'test group'
        }
        throw "The current $currentScope block contains syntax errors."
    }

    return $tokens
}

function IsSetupOrTeardownCommand {
    param ([string] $CommandName)
    return (IsSetupCommand -CommandName $CommandName) -or (IsTeardownCommand -CommandName $CommandName)
}

function IsSetupCommand {
    param ([string] $CommandName)
    return $CommandName -eq 'BeforeEach' -or $CommandName -eq 'BeforeAll'
}

function IsTeardownCommand {
    param ([string] $CommandName)
    return $CommandName -eq 'AfterEach' -or $CommandName -eq 'AfterAll'
}

function IsTestGroupCommand {
    param ([string] $CommandName)
    return $CommandName -eq 'BeforeAll' -or $CommandName -eq 'AfterAll'
}

function Get-BraceIndicesForCommand {
    param (
        [System.Management.Automation.PSToken[]] $Tokens,
        [int] $CommandIndex
    )

    $openingGroupTokenIndex = Get-GroupStartTokenForCommand -Tokens $Tokens -CommandIndex $CommandIndex
    $closingGroupTokenIndex = Get-GroupCloseTokenIndex -Tokens $Tokens -GroupStartTokenIndex $openingGroupTokenIndex

    return $openingGroupTokenIndex, $closingGroupTokenIndex
}

function Get-GroupStartTokenForCommand {
    param (
        [System.Management.Automation.PSToken[]] $Tokens,
        [int] $CommandIndex
    )

    $commandName = $Tokens[$CommandIndex].Content

    # gets ScriptBlock from positional parameter e.g. BeforeEach { <code> }
    if ($CommandIndex + 1 -lt $tokens.Count -and
        ($tokens[$CommandIndex + 1].Type -eq [System.Management.Automation.PSTokenType]::GroupStart -or
            $tokens[$CommandIndex + 1].Content -eq '{')) {
        return $CommandIndex + 1
    }

    # gets ScriptBlock from named parameter e.g. BeforeEach -ScriptBlock { <code> }
    if ($CommandIndex + 2 -lt $tokens.Count -and
        ($tokens[$CommandIndex + 2].Type -eq [System.Management.Automation.PSTokenType]::GroupStart -or
            $tokens[$CommandIndex + 2].Content -eq '{')) {
        return $CommandIndex + 2
    }

    throw "The $commandName command must be followed by the script block as the first argument or named parameter value."
}

& $SafeCommands['Add-Type'] -TypeDefinition @'
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

function Get-GroupCloseTokenIndex {
    param (
        [System.Management.Automation.PSToken[]] $Tokens,
        [int] $GroupStartTokenIndex
    )

    $closeIndex = [Pester.ClosingBraceFinder]::GetClosingBraceIndex($Tokens, $GroupStartTokenIndex)

    if ($closeIndex -lt 0) {
        throw 'No corresponding GroupEnd token was found.'
    }

    return $closeIndex
}

function Get-ScriptBlockFromTokens {
    param (
        [System.Management.Automation.PSToken[]] $Tokens,
        [int] $OpenBraceIndex,
        [int] $CloseBraceIndex,
        [string] $CodeText
    )

    $blockStart = $Tokens[$OpenBraceIndex + 1].Start
    $blockLength = $Tokens[$CloseBraceIndex].Start - $blockStart
    $setupOrTeardownCodeText = $codeText.Substring($blockStart, $blockLength)

    $scriptBlock = [scriptblock]::Create($setupOrTeardownCodeText)
    Set-ScriptBlockHint -Hint "Unbound ScriptBlock from Get-ScriptBlockFromTokens" -ScriptBlock $scriptBlock
    Set-ScriptBlockScope -ScriptBlock $scriptBlock -SessionState $pester.SessionState

    return $scriptBlock
}

function Add-SetupOrTeardownScriptBlock {
    param (
        [string] $CommandName,
        [scriptblock] $ScriptBlock
    )

    $Pester.AddSetupOrTeardownBlock($ScriptBlock, $CommandName)
}
