function New-StepErrorRecord {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [string]$ErrorId,

        [Parameter(Position = 1, Mandatory = $True)]
        [string]$Message,

        [Parameter(Position = 2, Mandatory = $True)]
        [System.Management.Automation.Errorcategory]$ErrorCategory,

        [Parameter(Position = 3, Mandatory = $True, ValueFromPipeline = $True)]
        [Object]$TargetObject
    )

    $Exception = New-Object Exception $Message

    New-Object System.Management.Automation.ErrorRecord $Exception, $ErrorId, $ErrorCategory, $TargetObject
}

function New-StepFailedErrorRecord {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    Param(
        [Parameter(Position = 0, Mandatory = $True)]
        [Gherkin.Ast.Step]$Step,

        [Parameter(Position = 1, Mandatory = $True)]
        [string]$FeaturePath,

        [Parameter(Position = 2, Mandatory = $True, ValueFromPipeline = $True)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $Message = if ($ErrorRecord.TargetObject) {
        $ErrorRecord.TargetObject
    }
    else {
        $ErrorRecord.Exception.Message
    }

    $ErrorDetails = @{
        ErrorId = 'PesterGherkinStepFailed'
        Message = $Message
        ErrorCategory = $ErrorRecord.CategoryInfo.Category
        TargetObject = @{
            File             = $ErrorRecord.InvocationInfo.ScriptName
            Line             = $ErrorRecord.InvocationInfo.ScriptLineNumber
            LineText         = $ErrorRecord.InvocationInfo.Line
            FeaturePath      = $FeaturePath
            ScriptStackTrace = $ErrorRecord.ScriptStackTrace
            Step             = $Step
        }
    }

    New-StepErrorRecord @ErrorDetails
}

function New-StepPendingErrorRecord {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    Param(
        [Parameter(Position = 0, Mandatory = $True)]
        [string]$LineText,

        [Parameter(Position = 1, Mandatory = $True)]
        [string]$StepDefinitionFilePath,

        [Parameter(Position = 2, Mandatory = $True)]
        [int]$Line
    )

    $ErrorDetails = @{
        ErrorId       = 'PesterGherkinStepPending'
        Message       = 'TODO: (Pester::Pending)'
        ErrorCategory = [System.Management.Automation.ErrorCategory]::NotImplemented
        TargetObject  = @{
            File     = $StepDefinitionFilePath
            Line     = $Line
            LineText = $LineText
        }
    }

    New-StepErrorRecord @ErrorDetails
}

function New-StepSkippedErrorRecord {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    Param(
        [Parameter(Position = 0, Mandatory = $True)]
        [string]$LineText,

        [Parameter(Position = 1, Mandatory = $True)]
        [string]$StepDefinitionFilePath,

        [Parameter(Position = 2, Mandatory = $True)]
        [int]$Line,

        [Parameter(Position = 3, Mandatory = $True)]
        [string]$FeaturePath,

        [Parameter(Position = 4, Mandatory = $True)]
        [Gherkin.Ast.Step]$Step
    )

    $ErrorDetails = @{
        ErrorId       = 'PesterGherkinStepSkipped'
        Message       = 'Step skipped due to previous failing, pending, or undefined steps.'
        ErrorCategory = [System.Management.Automation.ErrorCategory]::ObjectNotFound
        TargetObject = @{
            File        = $StepDefinitionFilePath
            Line        = $Line
            LineText    = $LineText
            FeaturePath = $FeaturePath
            Step        = $Step
        }
    }

    New-StepErrorRecord @ErrorDetails
}

function New-UndefinedStepErrorRecord {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [string]$LineText,

        [Parameter(Position = 1, Mandatory = $True)]
        [string]$StepDefinitionFilePath,

        [Parameter(Position = 2, Mandatory = $True)]
        [int]$Line,

        [Parameter(Position = 3, Mandatory = $True)]
        [string]$FeaturePath,

        [Parameter(Position = 4, Mandatory = $True)]
        [Gherkin.Ast.Step]$Step
    )

    $ErrorDetails = @{
        ErrorId       = 'PesterGherkinStepUndefined'
        Message       = 'No matching step definition found.'
        ErrorCategory = [System.Management.Automation.ErrorCategory]::ObjectNotFound
        TargetObject = @{
            File        = $StepDefinitionFilePath
            Line        = $Line
            LineText    = $LineText
            FeaturePath = $FeaturePath
            Step        = $Step
        }
    }

    New-StepErrorRecord @ErrorDetails
}

function Set-StepPending {
    <#
    .SYNOPSIS
        Using Set-StepPending inside of Step Definition ScriptBlocks will cause those steps to be marked as
        Pending by the Pester Gherkin test runner.

    .DESCRIPTION
        If Set-StepPending is used inside of a Step Definition ScriptBlock, the step will be marked as pending,
        as well as any scenarios making use of the step which are not already failed.

    .EXAMPLE Mark a Gherkin step as Pending
        Given '^this step is not yet implemented$' {
            Set-StepPending
        }

        If you define a step definition such as the above, the output for this step will be:

            Given this step is not yet implemented
              TODO: (Pester:Pending)


    #>

    [CmdletBinding()]Param()

    Assert-DescribeInProgress -CommandName Set-StepPending
    $PendingStepDetails = @{
        StepDefinitionFilePath = $MyInvocation.ScriptName
        Line                   = $MyInvocation.ScriptLineNumber
        LineText               = $MyInvocation.Line.TrimEnd([System.Environment]::NewLine)
    }

    throw (New-StepPendingErrorRecord @PendingStepDetails)
}

function Set-StepSkipped {
    <#
    .SYNOPSIS
        Sets a step as skipped.

    .DESCRIPTION
        This function creates an ErrorRecord with an Exception object, allowing Pester to
        capture a stack trace for a skipped step, which could be a useful aid in debugging
        the Pester test framework, more so than debugging user tests. Otherwise, all that
        would be necessary is to call New-StepSkippedErrorRecord.

    .EXAMPLE Mark a Gherkin step as Skipped
        $Step | Set-StepSkipped $Scenario.FeaturePath

        This is called in the Gherkin Pester test runner to set a step as skipped,
        which provides a stack trace to aid in debugging Pester more than the test suite itself.


    #>
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory = $True)]
        [string]$FeaturePath,

        [Parameter(Position = 1, Mandatory = $True, ValueFromPipeline = $True)]
        [Gherkin.Ast.Step]$Step
    )

    Assert-DescribeInProgress -CommandName Set-StepUndefined
    $SkippedStepDetails = @{
        StepDefinitionFilePath = $MyInvocation.ScriptName
        Line                   = $MyInvocation.ScriptLineNumber
        LineText               = $MyInvocation.Line.TrimEnd([System.Environment]::NewLine)
        Step                   = $Step
        FeaturePath            = $FeaturePath
    }

    throw (New-StepSkippedErrorRecord @SkippedStepDetails)
}

function Set-StepUndefined {
    <#
    .SYNOPSIS
        Sets a step as undefined.

    .DESCRIPTION
        This function creates an ErrorRecord with an Exception object, allowing Pester to
        capture a stack trace for an undefined step, which could be a useful aid in debugging
        the Pester test framework, more so than debugging user tests. Otherwise, all that
        would be necessary is to call New-UndefiniedStepErrorRecord.

    .EXAMPLE Mark a Gherkin step as Undefined
        $Step | Set-StepUndefined $Scenario.FeaturePath

        This is called in the Gherkin Pester test runner to set a step as undefined,
        which provides a stack trace to aid in debugging Pester more than the test suite itself.


    #>
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$FeaturePath,

        [Parameter(Position = 1, Mandatory = $True, ValueFromPipeline = $True)]
        [Gherkin.Ast.Step]$Step
    )

    Assert-DescribeInProgress -CommandName Set-StepUndefined
    $UndefinedStepDetails = @{
        StepDefinitionFilePath = $MyInvocation.ScriptName
        Line                   = $MyInvocation.ScriptLineNumber
        LineText               = $MyInvocation.Line.TrimEnd([System.Environment]::NewLine)
        Step                   = $Step
        FeaturePath            = $FeaturePath
    }

    throw (New-UndefinedStepErrorRecord @UndefinedStepDetails)
}
