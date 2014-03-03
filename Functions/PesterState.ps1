function New-PesterState {
	param (
		[Parameter(Mandatory=$true)]
		[String]$Path,
		[String[]]$TagFilter,
		[String[]]$TestNameFilter
	)
	New-Module -Name Pester -AsCustomObject -ScriptBlock {
		param ( 
			[String]$_path,
			[String[]]$_tagFilter,
			[String[]]$_testNameFilter
		)
		
		#public read-only
		$Path = $_path
		$TagFilter = $_tagFilter
		$TestNameFilter = $_testNameFilter
        
		$script:CurrentContext = "" 
		$script:CurrentDescribe = ""
		
		$script:TestResult = @()
		
    function EnterDescribe ($Name){ 
      if ($CurrentDescribe)
      {
        throw New-Object InvalidOperationException "You already are in Describe, you cannot enter Describe twice"
      }
      $script:CurrentDescribe = $Name
    }
    function LeaveDescribe {
        if ( $CurrentContext ) {  
				  throw New-Object InvalidOperationException "Cannot leave Describe before leaving Context"
			  }
      $script:CurrentDescribe = $null
    }
        
    function EnterContext ($Name) {
			if ( -not $CurrentDescribe ) {  
				throw New-Object InvalidOperationException "Cannot enter Context before entering Describe"
			}
      
      if ( $CurrentContext ) {  
				throw New-Object InvalidOperationException "You already are in Context, you cannot enter Context twice"
			}
			
      $Script:CurrentContext = $Name
    }
    function LeaveContext {
      $script:CurrentContext = $null
		}
		
		function AddTestResult ( [string]$Name, [bool]$Passed, [TimeSpan]$Time, [string]$FailureMessage, [String]$StackTrace ) {
			if ( -not $CurrentDescribe ) 
      {
        throw New-Object InvalidOperationException "Cannot add test result before entering Describe"
      }
            
    $Script:TestResult += New-Object -TypeName PsObject -Property @{
				Describe = $CurrentDescribe
        Context = $CurrentContext
        Name = $Name
				Passed = $Passed
				Time = $Time
				FailureMessage = $FailureMessage
        StackTrace = $StackTrace
                
			} | select Describe, Context, Name, Passed, Time, FailureMessage, StackTrace 
    }
        
		$ExportedVariables = "Path", 
			"TagFilter", 
			"TestNameFilter", 
			"TestResult", 
			"CurrentContext", 
			"CurrentDescribe"
            
		
		$ExportedFunctions = "EnterContext", 
			"LeaveContext", 
			"EnterDescribe", 
			"LeaveDescribe", 
			"AddTestResult"
		
		Export-ModuleMember -Variable $ExportedVariables -function $ExportedFunctions
	} -ArgumentList $Path, $TagFilter, $TestNameFilter | Add-Member -MemberType ScriptProperty -Name TotalCount -Value { @($this.TestResult).Count } -PassThru |
    Add-Member -MemberType ScriptProperty -Name PassedCount -Value { @( $this.TestResult | where { $_.Passed }).count } -PassThru |
    Add-Member -MemberType ScriptProperty -Name FailedCount -Value { @( $this.TestResult | where { -not $_.Passed } ).count } -PassThru | 
    Add-Member -MemberType ScriptProperty -Name Time -Value { $this.TestResult | foreach { [timespan]$total=0 } { $total = $total + ($_.time) } { [timespan]$total} } -PassThru |
    Add-Member -MemberType ScriptProperty -Name Scope -Value { if ($this.CurrentDescribe) { if ($this.CurrentContext) { "Context" } else { "Describe" } } else { $null } } -PassThru
    
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
		Write-Host ${margin}Context $Name -ForegroundColor Magenta
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
	        "$margin[+] $output $humanTime" | Write-Host -ForegroundColor DarkGreen
	    }
	    else {
	        "$margin[-] $output $humanTime" | Write-Host -ForegroundColor red
	         Write-Host -ForegroundColor red $error_margin$($TestResult.failureMessage)
	         Write-Host -ForegroundColor red $error_margin$($TestResult.stackTrace)
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
    

