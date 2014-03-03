function Get-HumanTime($Seconds) {
    if($Seconds -gt 0.99) {
        $time = [math]::Round($Seconds, 2)
        $unit = "s"
    }
    else {
        $time = [math]::Floor($Seconds * 1000)
        $unit = "ms"
    }
    return "$time$unit"
}

function ConvertTo-NUnitReport {
  param (
    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [PSObject]$InputObject
  )
	#TODO clean this mess up
	$results = $InputObject
	
	$outputFile = $Path
  $report = @{
    runDate = (Get-Date -format "yyyy-MM-dd")
    runTime = (Get-Date -format "HH:mm:ss")
    total = 0;
    failures = 0;
	}
	$report.total = $results.TotalCount
  $report.failures = $results.FailedCount
  $report.TestSuites = (Get-TestSuites $results.TestResult)
  $report.Environment = (Get-RunTimeEnvironment)
	$report = New-Object -TypeName Psobject -Property $report
	Invoke-Template 'TestResults.template.xml' $report 
}
function Export-NUnitReport {
  param (
    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [PSObject]$InputObject,
		[parameter(Mandatory=$true)]
    [String]$Path
	)
	
	ConvertTo-NUnitReport -InputObject $InputObject | Set-Content $Path -Force
}

function Get-TestSuites ($describes) {
    $describes | Group-Object -Property Describe | foreach {
        $suite = @{  
            resultMessage = "Failure"
            totalTime = "0.0"
            name = $_.name
        }
				#calculate the time first, I am converting the time into string in the TestCases
				$suite.totalTime = (Get-TestTime $_.Group)
        $suite.testCases = (Get-TestResults $_.Group)  
        $suite.success = (Get-TestSuccess $_.Group)
        if($suite.success -eq "True") 
        {
            $suite.resultMessage = "Success" 
        }
        Invoke-Template 'TestSuite.template.xml' $suite
    }
    return $testSuites
}

function Convert-TimeSpan {
	param (
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
		[TimeSpan]$TimeSpan
	)
	process {
		[string][math]::round($TimeSpan.totalseconds,4)
	}
}
function Get-TestTime($tests) {
    [TimeSpan]$totalTime = 0;
    $tests | %{
        $totalTime += $_.time
    }
    $totalTime | Convert-TimeSpan
}

function Get-TestSuccess($tests) {
    #if any fails, the whole suite fails
		$result = $true
		$tests | foreach {
			if (-not $_.Passed) {
				$result = $false
			}
    }
		[String]$result
}

function Get-TestResults($Test) {
	$Test | %{ 
	  $result = $_
		$result.Time = $result.Time | Convert-TimeSpan
	  if($result.Passed) {
	    Invoke-Template 'TestCaseSuccess.template.xml' $result
	  }
	  else {
	    Invoke-Template  'TestCaseFailure.template.xml' $result
	  }
	}
}

function Get-RunTimeEnvironment() {
    $osSystemInformation = (Get-WmiObject Win32_OperatingSystem)
    $currentCulture = ([System.Threading.Thread]::CurrentThread.CurrentCulture).Name
    $data = @{
        osVersion = $osSystemInformation.Version
        platform = $osSystemInformation.Name
        runPath = (Get-Location).Path
        machineName = $env:ComputerName
        userName = $env:Username
        userDomain = $env:userDomain
        currentCulture = $currentCulture
    }
    return Invoke-Template 'TestEnvironment.template.xml' $data
}



function Exit-WithCode ($FailedCount) {
    $host.SetShouldExit($FailedCount)
}

