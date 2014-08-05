Add-Type -Path "$PSScriptRoot\lib\PowerCuke.dll"

$StepPrefix = "Gherkin-Step "
$GherkinSteps = @{}

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

    $pester = New-PesterState -Path (Resolve-Path $Path) -TestNameFilter $TestName -TagFilter @($Tag -split "\s+")

    Write-Host Testing all features in $($pester.Path)

    # Remove all the steps
    $Script:GherkinSteps.Clear()
    # Import all the steps (we're going to need them in a minute)
    foreach($StepFile in Get-ChildItem $pester.Path -Filter "*.steps.psm1" -Recurse){
        Import-Module $StepFile.FullName -Force
    }


    foreach($FeatureFile in Get-ChildItem $pester.Path -Filter "*.feature" -Recurse ) {
        $Feature = [PoshCode.PowerCuke.Parser]::Parse((gc $FeatureFile -Delim ([char]0)))

        $Pester.EnterDescribe($Feature)
        Write-Feature $Feature

        New-TestDrive


        $Tagged = if($pester.TagFilter) {
                        foreach($Scenario in $Feature.FeatureElements) {
                            $Tags = @($Scenario.Tags) + @($Feature.Tags) | Select-Object -Unique
                            if(Compare-Object $Tags $pester.TagFilter -IncludeEqual -ExcludeDifferent) {
                                $Scenario
                            }
                        }
                    } else {
                        $Feature.FeatureElements
                    }

        foreach($Scenario in $Tagged) {
            $Pester.EnterContext($Scenario.Name)

            Invoke-GherkinScenario $Pester $Scenario $Feature.Background
            $Pester.LeaveContext()
        }

        Remove-TestDrive
        Clear-Mocks
        $Pester.LeaveDescribe()
    }

    # Remove all the steps
    foreach($StepFile in Get-ChildItem $pester.Path -Filter "*.steps.psm1" -Recurse){
        Remove-Module $StepFile.BaseName
    }

    $pester | Write-PesterReport


    if ($PassThru) {
        #remove all runtime properties like current* and Scope
        $pester | Select -Property "Path","TagFilter","TestNameFilter","TotalCount","PassedCount","FailedCount","Time","TestResult"
    }

}

function Invoke-GherkinScenario {
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
                    }

    foreach($Step in $TableSteps) {
        . Invoke-GherkinStep $Pester $Step
    }
}


function Invoke-GherkinStep {
    param(
        $Pester, $Step
    )
    #  Pick the match with the least grouping wildcards in it...
    $StepCommand = $Script:GherkinSteps.Keys | Where { $Step.Name -match $_ } | Sort { $Matches.Count } -Descending | Select -First 1

    if(!$StepCommand) {
        $Pester.AddTestResult($Step.Name, $False, [TimeSpan]0, "Could not find test for step!", $null )
    } else {

        $Arguments, $Parameters = Get-StepParameters $Step.Name $StepCommand

        $PesterException = $null
        try{
            $watch = [System.Diagnostics.Stopwatch]::new()
            $watch.Start()

            if($Arguments.Count) {
                $null = . $Script:GherkinSteps.$StepCommand @Arguments @Parameters
            } else {
                $null = . $Script:GherkinSteps.$StepCommand @Parameters
            }

            $watch.Stop()
        } catch {
            $PesterException = $_
        } finally {
            $watch.Stop()
        }

        $Results = @{
            Time = $watch.Elapsed
            Test = $Test
            Exception = $PesterException
        }

        $Result = Get-PesterResult @Results
        $Pester.AddTestResult($Step.Name, $Result.Success, $result.time, $result.failuremessage, $result.StackTrace )
    }

    $Pester.testresult[-1] | Write-PesterResult
}

function Get-StepParameters {
    param($StepName, $CommandName)
    $Null = $Step.Name -match $CommandName

    $Arguments = @{}
    $Parameters = @{}
    foreach($kv in $Matches.GetEnumerator()) {
        switch ($kv.Name -as [int]) {
            0       {  } # toss zero (where it matches the whole string)
            $null   { $Arguments.($kv.Name) = $ExecutionContext.InvokeCommand.ExpandString($kv.Value)       }
            default { $Parameters.([int]$kv.Name) = $ExecutionContext.InvokeCommand.ExpandString($kv.Value) }
        }
    }
    $Parameters = @($Parameters.GetEnumerator() | Sort Name | Select -Expand Value)

    return @($Arguments, $Parameters)
}