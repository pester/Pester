function Invoke-PesterInJob ($ScriptBlock)
{        
	#TODO: there must be a safer way to determine this while I am in describe
	$PesterPath = Get-Module -Name Pester | Select -First 1 -ExpandProperty Path
	
	$job = Start-Job { 
		param ($PesterPath, $TestDrive, $ScriptBlock) 
		Import-Module $PesterPath -Force | Out-Null
		$ScriptBlock | Set-Content $TestDrive\Temp.Tests.ps1 | Out-Null
		
		Invoke-Pester -PassThru -Path $TestDrive
		
	} -ArgumentList  $PesterPath, $TestDrive, $ScriptBlock 
	$job | Wait-Job | Out-Null 
	
	#not using Recieve-Job to ignore any output to Host
	#TODO: how should this handle errors?
	#$job.Error | foreach { throw $_.Exception  } 
	$job.Output
	$job.ChildJobs| foreach { 
		$childJob = $_ 
		#$childJob.Error | foreach { throw $_.Exception }
		$childJob.Output 
	}
	$job | Remove-Job
}

Describe "Tests running in clean runspace" {   
    It "It - Skip and Pending tests" {
        #tests to be run in different runspace using different Pester instance
        $TestSuite = {
            Describe 'It - Skip and Pending tests' {
               
                It "Skip without ScriptBlock" -skip
                It "Skip with empty ScriptBlock" -skip {}
                It "Skip with not empty ScriptBlock" -Skip {"something"}
                
                It "Implicit pending" {}
                It "Pending without ScriptBlock" -Pending
                It "Pending with empty ScriptBlock" -Pending {}
                It "Pending with not empty ScriptBlock" -Pending {"something"} 
            }
        }
        
        $result = Invoke-PesterInJob -ScriptBlock $TestSuite 
        $result.SkippedCount | Should Be 3
        $result.PendingCount | Should Be 4
        $result.TotalCount | Should Be 7
    }
    
    It "It - It without ScriptBlock fails" {
        #tests to be run in different runspace using different Pester instance
        $TestSuite = {
            Describe 'It without ScriptBlock fails' {
               It "Fails whole describe"
               It "is not run" { "but it would pass if it was run" }
               
            }
        }
        
        $result = Invoke-PesterInJob -ScriptBlock $TestSuite 
        $result.PassedCount | Should Be 0
        $result.FailedCount | Should Be 1
        
        $result.TotalCount | Should Be 1
    }
    
    It "Invoke-Pester - PassThru output" {
        #tests to be run in different runspace using different Pester instance
        $TestSuite = {
            Describe 'PassThru output' {
               it "Passes" { "pass" }
               it "fails" { throw }
               it "Skipped" -Skip {}
               it "Pending" -Pending {}
            }
        }
        
        $result = Invoke-PesterInJob -ScriptBlock $TestSuite 
        $result.PassedCount | Should Be 1
        $result.FailedCount | Should Be 1
        $result.SkippedCount | Should Be 1
        $result.PendingCount | Should Be 1
        
        $result.TotalCount | Should Be 4
    }
}