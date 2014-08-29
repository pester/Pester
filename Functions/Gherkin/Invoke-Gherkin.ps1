Add-Type -Path "$PSScriptRoot\lib\PowerCuke.dll"

$StepPrefix = "Gherkin-Step "

function Invoke-Gherkin {
    param(
        [Parameter(Position=0,Mandatory=0)]
        [Alias('relative_path')]
        [string]$Path = $Pwd,

        [Parameter(Position=1,Mandatory=0)]
        [string]$TestName,

        [Parameter(Position=2,Mandatory=0)]
        [switch]$EnableExit,

        [Parameter(Position=3,Mandatory=0)]
        [string]$OutputXml,

        [Parameter(Position=4,Mandatory=0)]
        [Alias('Tags')]
        [string[]]$Tag,

        [switch]$PassThru
    )



    # Set-Alias

    $pester = New-PesterState -Path (Resolve-Path $Path) -TestNameFilter $TestName -TagFilter ($Tag -split "\s")

    Write-Host Testing all features in $($pester.Path)

    # Import all the steps (we're going to need them in a minute)
    foreach($StepFile in Get-ChildItem $pester.Path -Filter "*.steps.psm1" -Recurse){ Import-Module $StepFile.FullName }

    foreach($FeatureFile in Get-ChildItem $pester.Path -Filter "*.feature" -Recurse ) {
        $Feature = [PoshCode.PowerCuke.Parser]::Parse((gc $FeatureFile -Delim ([char]0)))

        $Pester.EnterDescribe($Feature)
        Write-Feature $Feature

        New-TestDrive

        if($Feature.Background) {
            Invoke-GherkinScenario $Pester $Feature.Background
        }

        foreach($Scenario in $Feature.FeatureElements | Where { !$pester.TagFilter -or @(Compare-Object $_.Tags $pester.TagFilter -IncludeEqual -ExcludeDifferent).count -gt 0 }) {
            $Pester.EnterContext($Scenario.Name)
            Invoke-GherkinScenario $Pester $Scenario
            $Pester.LeaveContext()
        }

        Remove-TestDrive
        Clear-Mocks
        $Pester.LeaveDescribe()
    }

    # Remove all the steps
    foreach($StepFile in Get-ChildItem $pester.Path -Filter "*.steps.psm1" -Recurse){ Remove-Module $StepFile.BaseName }

    $pester | Write-PesterReport


    if ($PassThru) {
        #remove all runtime properties like current* and Scope
        $pester | Select -Property "Path","TagFilter","TestNameFilter","TotalCount","PassedCount","FailedCount","Time","TestResult"
    }

}

function Invoke-GherkinScenario {
    param(
        $Pester, $Scenario
    )
    Write-Scenario $Scenario

    $TableSteps = $(
                if($Scenario.Examples) {
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
                                    $S = New-Object $Step
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
                })

    foreach($Step in $TableSteps | Where { !$pester.TagFilter -or @(Compare-Object $_.Tags $pester.TagFilter -IncludeEqual -ExcludeDifferent).count -gt 0 }) {
        . Invoke-GherkinStep $Pester $Step
    }
}


function Invoke-GherkinStep {
    param(
        $Pester, $Step
    )
        $StepCommand = Get-Command "${StepPrefix}*" | Where {
        $Step.Name -match $_.Name.SubString($StepPrefix.Length)
    } | Select -First 1

    if(!$StepCommand) {
        $Pester.AddTestResult($Step.Name, $False, [TimeSpan]0, "Could not find test for step!", $null )
    } else {

        $Null = $Step.Name -match $StepCommand.Name.SubString(8)
        $Parameters = $Matches.Values | % {
            $ExecutionContext.InvokeCommand.ExpandString($_)
        }

        $Results = . $StepCommand @Parameters

        $Result = Get-PesterResult @Results
        $Pester.AddTestResult($Step.Name, $Result.Success, $result.time, $result.failuremessage, $result.StackTrace )
    }

    $Pester.testresult[-1] | Write-PesterResult
}