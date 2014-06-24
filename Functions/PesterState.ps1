﻿function New-PesterState {
	param (
		[Parameter(Mandatory=$true)]
		[String]$Path,
		[String[]]$TagFilter,
		[String[]]$TestNameFilter,
        [System.Management.Automation.SessionState] $SessionState
	)
    
    if ($null -eq $SessionState) { $SessionState = $ExecutionContext.SessionState }

	New-Module -Name Pester -AsCustomObject -ScriptBlock {
		param ( 
			[String]$_path,
			[String[]]$_tagFilter,
			[String[]]$_testNameFilter,
            [System.Management.Automation.SessionState] $_sessionState
		)
		
		#public read-only
		$Path = $_path
		$TagFilter = $_tagFilter
		$TestNameFilter = $_testNameFilter

        $script:SessionState = $_sessionState
		$script:CurrentContext = "" 
		$script:CurrentDescribe = ""
        $script:CurrentTest = ""
        $script:Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $script:MostRecentTimestamp = 0
		
		$script:TestResult = @()
		
        function EnterDescribe ($Name){ 
            if ($CurrentDescribe)
            {
                throw Microsoft.PowerShell.Utility\New-Object InvalidOperationException "You already are in Describe, you cannot enter Describe twice"
            }
            $script:CurrentDescribe = $Name
        }
        function LeaveDescribe {
            if ( $CurrentContext ) {  
                throw Microsoft.PowerShell.Utility\New-Object InvalidOperationException "Cannot leave Describe before leaving Context"
            }
            $script:CurrentDescribe = $null
        }
        
        function EnterContext ($Name) {
            if ( -not $CurrentDescribe ) {  
                throw Microsoft.PowerShell.Utility\New-Object InvalidOperationException "Cannot enter Context before entering Describe"
            }
      
            if ( $CurrentContext ) {  
                throw Microsoft.PowerShell.Utility\New-Object InvalidOperationException "You already are in Context, you cannot enter Context twice"
            }

            if ($CurrentTest)
            {
                throw Microsoft.PowerShell.Utility\New-Object InvalidOperationException "You already are in It, you cannot enter Context inside It"
            }
			
            $Script:CurrentContext = $Name
        }
        function LeaveContext {
            if ($CurrentTest)
            {
                throw Microsoft.PowerShell.Utility\New-Object InvalidOperationException "Cannot leave Context before leaving It"
            }
            $script:CurrentContext = $null
        }
		
        function EnterTest([string]$Name)
        {
            if (-not $script:CurrentDescribe)
            {
                throw Microsoft.PowerShell.Utility\New-Object InvalidOperationException "Cannot enter Context before entering Describe"
            }

            if ($CurrentTest)
            {
                throw Microsoft.PowerShell.Utility\New-Object InvalidOperationException "You already are in It, you cannot enter It twice"
            }

            $script:CurrentTest = $Name
        }

        function LeaveTest()
        {
            $script:CurrentTest = $null
        }

        function AddTestResult ( [string]$Name, [bool]$Passed, [Nullable[TimeSpan]]$Time, [string]$FailureMessage, [String]$StackTrace ) {
            if ( -not $CurrentDescribe ) 
            {
                throw Microsoft.PowerShell.Utility\New-Object InvalidOperationException "Cannot add test result before entering Describe"
            }
            
            $previousTime = $script:MostRecentTimestamp
            $script:MostRecentTimestamp = $script:Stopwatch.Elapsed

            if ($null -eq $Time)
            {
                $Time = $script:MostRecentTimestamp - $previousTime
            }

            $Script:TestResult += Microsoft.PowerShell.Utility\New-Object -TypeName PsObject -Property @{
                Describe       = $CurrentDescribe
                Context        = $CurrentContext
                Name           = $Name
                Passed         = $Passed
                Time           = $Time
                FailureMessage = $FailureMessage
                StackTrace     = $StackTrace                
            } | Microsoft.PowerShell.Utility\Select-Object Describe, Context, Name, Passed, Time, FailureMessage, StackTrace 
        }
        
        $ExportedVariables = "Path", 
                             "TagFilter", 
                             "TestNameFilter", 
                             "TestResult", 
                             "CurrentContext", 
                             "CurrentDescribe",
                             "CurrentTest",
                             "SessionState"
        
        $ExportedFunctions = "EnterContext", 
                             "LeaveContext", 
                             "EnterDescribe", 
                             "LeaveDescribe",
                             "EnterTest",
                             "LeaveTest", 
                             "AddTestResult"
		
		Export-ModuleMember -Variable $ExportedVariables -function $ExportedFunctions
	} -ArgumentList $Path, $TagFilter, $TestNameFilter, $SessionState | Add-Member -MemberType ScriptProperty -Name TotalCount -Value { @($this.TestResult).Count } -PassThru |
    Add-Member -MemberType ScriptProperty -Name PassedCount -Value { @( $this.TestResult | where { $_.Passed }).count } -PassThru |
    Add-Member -MemberType ScriptProperty -Name FailedCount -Value { @( $this.TestResult | where { -not $_.Passed } ).count } -PassThru | 
    Add-Member -MemberType ScriptProperty -Name Time -Value { $this.TestResult | foreach { [timespan]$total=0 } { $total = $total + ($_.time) } { [timespan]$total} } -PassThru |
    Add-Member -Passthru -MemberType ScriptProperty -Name Scope -Value {
        if     ($this.CurrentTest)     { 'It'       }
        elseif ($this.CurrentContext)  { 'Context'  }
        elseif ($this.CurrentDescribe) { 'Describe' }
        else                           { $null      }
    } |
    Add-Member -PassThru -MemberType ScriptProperty -Name ParentScope -Value {
        $parentScope = $null
        $scope = $this.Scope

        if ($scope -eq 'It' -and $this.CurrentContext)
        {
            $parentScope = 'Context'
        }

        if ($null -eq $parentScope -and $scope -ne 'Describe' -and $this.CurrentDescribe) 
        {
            $parentScope = 'Describe'
        }

        return $parentScope
    }
    
}

function Write-Describe { 
	param (
		[Parameter(mandatory=$true, valueFromPipeline=$true)]
		$Name
	)
	process {
		Write-Host Describing $Name -ForegroundColor Magenta
	}
}
function Write-Context { 
	param (
		[Parameter(mandatory=$true, valueFromPipeline=$true)]
		$Name
	)
	process {
		$margin = "   "
		Microsoft.PowerShell.Utility\Write-Host ${margin}Context $Name -ForegroundColor Magenta
	}
}
function Write-PesterResult {
	param (
		[Parameter(mandatory=$true, valueFromPipeline=$true)]
		$TestResult
	)
    process {
		$testDepth = if ( $TestResult.Context ) { 4 } 
            elseif ( $TestResult.Describe ) { 1 } 
            else { 0 }
            
		$margin = " " * $TestDepth
	    $error_margin = $margin + "  "
	    $output = $TestResult.name
	    $humanTime = Get-HumanTime $TestResult.Time.TotalSeconds
	    if($TestResult.Passed) {
	        "$margin[+] $output $humanTime" | Microsoft.PowerShell.Utility\Write-Host -ForegroundColor DarkGreen
	    }
	    else {
	        "$margin[-] $output $humanTime" | Microsoft.PowerShell.Utility\Write-Host -ForegroundColor red
	         Microsoft.PowerShell.Utility\Write-Host -ForegroundColor red $error_margin$($TestResult.failureMessage)
	         Microsoft.PowerShell.Utility\Write-Host -ForegroundColor red $error_margin$($TestResult.stackTrace)
	    }
	}
}
function Write-PesterReport {
    param (
		[Parameter(mandatory=$true, valueFromPipeline=$true)]
		$PesterState
	)
    
    Write-Host "Tests completed in $(Get-HumanTime $PesterState.Time.TotalSeconds)"
    Write-Host "Passed: $($PesterState.PassedCount) Failed: $($PesterState.FailedCount)"
}
    

