Add-Type -Path "$PSScriptRoot\lib\PowerCuke.dll"

$StepPrefix = "Gherkin-Step "
$GherkinSteps = @{}

function Invoke-Gherkin {
    param(
        [Parameter(Position=0,Mandatory=0)]
        [Alias('relative_path')]
        [string]$Path = $Pwd,

        [Parameter(Position=1,Mandatory=0)]
        [string]$ScenarioName,

        [Parameter(Position=2,Mandatory=0)]
        [switch]$EnableExit,

        [Parameter(Position=3,Mandatory=0)]
        [string]$OutputXml,

        [Parameter(Position=4,Mandatory=0)]
        [Alias('Tags')]
        [string[]]$Tag,

        [object[]] $CodeCoverage = @(),

        [switch]$PassThru
    )

    $message = "Testing all features in '$($Path)'"
    if ($ScenarioName) { $message += " matching scenario '$ScenarioName'" }
    if ($Tag) { $message += " with Tags: $Tag" }
    Write-Host $message


    # Clear mocks
    $script:mockTable = @{}

    $pester = New-PesterState -Path (Resolve-Path $Path) -TestNameFilter $ScenarioName -TagFilter @($Tag -split "\s+") -SessionState $PSCmdlet.SessionState
    Enter-CoverageAnalysis -CodeCoverage $CodeCoverage -PesterState $pester

    # Remove all the steps
    $Script:GherkinSteps.Clear()
    # Import all the steps (we're going to need them in a minute)
    foreach($StepFile in Get-ChildItem (Split-Path $pester.Path) -Filter "*.steps.psm1" -Recurse){
        Import-Module $StepFile.FullName -Force
    }

    foreach($FeatureFile in Get-ChildItem $pester.Path -Filter "*.feature" -Recurse ) {
        $Feature = [PoshCode.PowerCuke.Parser]::Parse((gc $FeatureFile -Delim ([char]0)))

        ## This is Pesters "Describe" function
        $Pester.EnterDescribe($Feature)
        Write-Feature $Feature
        New-TestDrive

        $Tagged = if($pester.TagFilter) {
                        foreach($Scenario in $Feature.Scenarios) {
                            $Tags = @($Scenario.Tags) + @($Feature.Tags) | Select-Object -Unique
                            if(Compare-Object $Tags $pester.TagFilter -IncludeEqual -ExcludeDifferent) {
                                $Scenario
                            }
                        }
                    } else {
                        $Feature.Scenarios
                    }

        foreach($Scenario in $Tagged) {
            # This is Pester's Context function
            $Pester.EnterContext($Scenario.Name)
            $TestDriveContent = Get-TestDriveChildItem

            Invoke-GherkinScenario $Pester $Scenario $Feature.Background

            Clear-TestDrive -Exclude ($TestDriveContent | select -ExpandProperty FullName)
            Exit-MockScope
            $Pester.LeaveContext()
        }

        ## This is Pesters "Describe" function again
        Remove-TestDrive
        Exit-MockScope
        $Pester.LeaveDescribe()
    }

    # Remove all the steps
    foreach($StepFile in Get-ChildItem $pester.Path -Filter "*.steps.psm1" -Recurse){
        Remove-Module $StepFile.BaseName
    }

    $pester | Write-TestReport
    $coverageReport = Get-CoverageReport -PesterState $pester
    Show-CoverageReport -CoverageReport $coverageReport
    Exit-CoverageAnalysis -PesterState $pester


    if ($PassThru) {
        #remove all runtime properties like current* and Scope
        $pester | Select -Property "Path","TagFilter","TestNameFilter","TotalCount","PassedCount","FailedCount","Time","TestResult"
    }

}

function Invoke-GherkinScenario {
    [CmdletBinding()]
    param(
        $Pester, $Scenario, $Background, [Switch]$Quiet
    )

    if(!$Quiet) { Write-Scenario $Scenario }
    if($Background) {
        Invoke-GherkinScenario $Pester $Background -Quiet
    }

    $TableSteps =   if($Scenario.Examples) {
                        foreach($ExampleSet in $Scenario.Examples) {
                            $Names = $ExampleSet | Get-Member -Type Properties | Select -Expand Name
                            $NamesPattern = "<(?:" + ($Names -join "|") + ")>"
                            foreach($Example in $ExampleSet) {
                                foreach ($Step in $Scenario.Steps) {
                                    $StepName = $Step.Name
                                    if($StepName -match $NamesPattern) {
                                        foreach($Name in $Names) {
                                            if($Example.$Name -and $StepName -match "<${Name}>") {
                                                Write-Verbose "$StepName -replace '<${Name}>', $Example.$Name ($($Example.$Name))"
                                                $StepName = $StepName -replace "<${Name}>", $Example.$Name
                                            }
                                        }
                                    }
                                    if($StepName -ne $Step.Name) {
                                        Write-Verbose "Step Name: $StepName"
                                        $S = New-Object PoshCode.PowerCuke.ObjectModel.Step $Step
                                        $S.Name = $StepName
                                        $S
                                    } else {
                                        Write-Verbose "Original Step: $($Step.Name)"
                                        $Step
                                    }
                                }
                            }
                        }
                    } else {
                        $Scenario.Steps
                    }

    foreach($Step in $TableSteps) {
        Invoke-GherkinStep $Pester $Step
    }
}


function Invoke-GherkinStep {
    param(
        $Pester, $Step
    )
    #  Pick the match with the least grouping wildcards in it...
    $StepCommand = $(
        foreach($StepCommand in $Script:GherkinSteps.Keys) {
            if($Step.Name -match $StepCommand) {
                $StepCommand | Add-Member MatchCount $Matches.Count -PassThru
            }
        }
    ) | Sort MatchCount | Select -First 1
    $StepName = "{0} {1}" -f $Step.Keyword, $Step.Name

    if(!$StepCommand) {
        $Pester.AddTestResult($Step.Name, $False, $null, "Could not find test for step!", $null )
    } else {
        $NamedArguments, $Parameters = Get-StepParameters $Step $StepCommand

        $Pester.EnterTest($StepName)
        $PesterException = $null
        $watch = New-Object System.Diagnostics.Stopwatch
        $watch.Start()
        try{
            if($NamedArguments.Count) {
                $null = & $Script:GherkinSteps.$StepCommand @NamedArguments @Parameters
            } else {
                $null = & $Script:GherkinSteps.$StepCommand @Parameters
            }
            $Success = $True
        } catch {
            $Success = $False
            $PesterException = $_
        }

        $watch.Stop()
        Exit-MockScope
        $Pester.LeaveTest()


        # if($PesterException) {
        #     if ($PesterException.FullyQualifiedErrorID -eq 'PesterAssertionFailed')
        #     {
        #         $failureMessage = $PesterException.exception.message  -replace "Exception calling", "Assert failed on"
        #         $stackTrace = $PesterException.ScriptStackTrace # -split "`n")[3] #-replace "<No File>:"
        #     }
        #     else {
        #         $failureMessage = $PesterException.ToString()
        #         $stackTrace = ($PesterException.ScriptStackTrace -split "`n")[0]
        #     }

        #     $Pester.AddTestResult($name, $False, $null, $failureMessage, $stackTrace)
        # } else {
        #     $Pester.AddTestResult($name, $True, $null, $null, $null )
        # }

        $Pester.AddTestResult($StepName, $Success, $watch.Elapsed, $PesterException.Exception.Message, ($PesterException.ScriptStackTrace -split "`n")[1] )
    }

    $Pester.testresult[-1] | Write-TestResult
}

function Get-StepParameters {
    param($Step, $CommandName)
    $Null = $Step.Name -match $CommandName

    $NamedArguments = @{}
    $Parameters = @{}
    foreach($kv in $Matches.GetEnumerator()) {
        switch ($kv.Name -as [int]) {
            0       {  } # toss zero (where it matches the whole string)
            $null   { $NamedArguments.($kv.Name) = $ExecutionContext.InvokeCommand.ExpandString($kv.Value)       }
            default { $Parameters.([int]$kv.Name) = $ExecutionContext.InvokeCommand.ExpandString($kv.Value) }
        }
    }
    $Parameters = @($Parameters.GetEnumerator() | Sort Name | Select -Expand Value)

    if($Step.TableArgument) {
        $NamedArguments.Table = $Step.TableArgument
    }
    if($Step.DocStringArgument) {
        $NamedArguments.DocString = $Step.DocStringArgument
    }

    return @($NamedArguments, $Parameters)
}
