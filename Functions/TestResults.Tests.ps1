Describe "Write nunit test results" {
    Setup -Dir "Results"
    
    It "should write a successful test result" {
        $testResults = @{}
        $testResults.Describes = @{
            name = 'Mocked Describe'
            Tests = @{
                testNumber = 1
                name = "Successful testcase"
                time = "1.0"
                success = $true
            };
        }

        $testFile = "$TestDrive\Results\Tests.xml"
        Write-NunitTestReport $testResults $testFile
        $xmlResult = [xml] (Get-Content $testFile)
        $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-case'
        $xmlTestCase.name.Should.Be("Successful testcase")
        $xmlTestCase.result.Should.Be("Success")
        $xmlTestCase.time.Should.Be("1.0")
    }

    It "should write a failed test result" {
        $testResults = @{}
        $testResults.Describes = @{
            name = 'Mocked Describe'
            Tests = @{
                name = "Failed testcase"
                time = "2.0"
                failureMessage = 'Assert failed: "Expected: Test. But was: Testing"';
                stackTrace = 'at line: 28 in  C:\Pester\Result.Tests.ps1'
                success = $false
            };
        }

        $testFile = "$TestDrive\Results\Tests.xml"
        Write-NunitTestReport $testResults $testFile
        $xmlResult = [xml] (Get-Content $testFile)
        $xmlTestCase = $xmlResult.'test-results'.'test-suite'.'results'.'test-case'
        $xmlTestCase.name.Should.Be("Failed testcase")
        $xmlTestCase.result.Should.Be("Failure")
        $xmlTestCase.time.Should.Be("2.0")
        $xmlTestCase.failure.message.Should.Be('Assert failed: "Expected: Test. But was: Testing"');
        $xmlTestCase.failure.'stack-trace'.should.be('at line: 28 in  C:\Pester\Result.Tests.ps1')

    }

     It "should write the test summary" {
        $testResults = @{}
        $testResults.Describes = @{
            name = 'Mocked Describe'
            Tests = @{
                name = "Testcase"
                time = "1.0"
                success = $true
            };
        }
        $testFile = "$TestDrive\Results\Tests.xml"
        Write-NunitTestReport $testResults $testFile
        $xmlResult = [xml] (Get-Content $testFile)
        $xmlTestResult = $xmlResult.'test-results'
        $xmlTestResult.total.Should.Be(0)
        $xmlTestResult.failures.Should.Be(0)
        $xmlTestResult.date.Should.Be($true)
        $xmlTestResult.time.Should.Be($true)
    }

    it "should write the test-suite information" {
        $testResults = @{}
        $testResults.Describes = @{
                name = 'Mocked Describe'
                Tests = @(
                    @{
                        name = "Successful testcase"
                        time = "1.0"
                        success = $true
                    },
                    @{
                        name = "Successful testcase"
                        time = "1.1"
                        success = $true
                    };
                );
        }
        $testFile = "$TestDrive\Results\Tests.xml"
        Write-NunitTestReport $testResults $testFile
        $xmlResult = [xml] (Get-Content $testFile)
        
        $xmlTestResult = $xmlResult.'test-results'.'test-suite'
        $xmlTestResult.type.Should.Be("Powershell")
        $xmlTestResult.name.Should.Be("Mocked Describe")
        $xmlTestResult.result.Should.Be("Success")
        $xmlTestResult.success.Should.Be("True")
        $xmlTestResult.time.Should.Be(2.1)
    }

    it "should write two test-suite elements for two describes" {
        $testResults = @{}
        $testResults.Describes = @( 
            @{
                name = 'Describe #1'
                Tests =  @{
                    name = "Successful testcase"
                    time = "1.0"
                    success = $true
                }
            },
            @{
                name = 'Describe #2'
                Tests = @{
                    name = "Failed testcase"
                    time = "2.0"
                    success = $false
                }
            }
        );
        
        $testFile = "$TestDrive\Results\Tests.xml"
        Write-NunitTestReport $testResults $testFile
        $xmlResult = [xml] (Get-Content $testFile)
        
        $xmlTestSuite1 = $xmlResult.'test-results'.'test-suite'[0]
        $xmlTestSuite1.name.Should.Be("Describe #1")
        $xmlTestSuite1.result.Should.Be("Success")
        $xmlTestSuite1.success.Should.Be("True")
        $xmlTestSuite1.time.Should.Be(1.0)
        $xmlTestSuite2 = $xmlResult.'test-results'.'test-suite'[1]
        $xmlTestSuite2.name.Should.Be("Describe #2")
        $xmlTestSuite2.result.Should.Be("Failure")
        $xmlTestSuite2.success.Should.Be("False")
        $xmlTestSuite2.time.Should.Be(2.0)
    }

    it "should write the environment information" {
        $testResults = @{}
        $testResults.Tests = @( "" );
        $testFile = "$TestDrive\Results\Tests.xml"
        Write-NunitTestReport $testResults $testFile
        $xmlResult = [xml] (Get-Content $testFile)

        $xmlEnvironment = $xmlResult.'test-results'.'environment'
        $xmlEnvironment.'os-Version'.Should.Be($true) #check if exists
        $xmlEnvironment.platform.Should.Be($true)
        $xmlEnvironment.cwd.Should.Be((Get-Location).Path)
        $xmlEnvironment.user.Should.Be($env:Username)
        $xmlEnvironment.'machine-name'.Should.Be($env:ComputerName)
    }

    $pscx =  Import-Module Pscx -AsCustomObject -ErrorAction SilentlyContinue
    if($pscx) {
        it "Should validate test results against the nunit 2.5 schema" {
            $testResults = @{}
            $testResults.Describes = @( 
                @{
                    name = 'Describe #1'
                    Tests =  @(@{
                        name = "Successful testcase"
                        time = "1.0"
                        success = $true
                    },
                    @{
                        name = "Failed testcase"
                        time = "1.0"
                        success = $true
                    });
                },
                @{
                    name = 'Describe #2'
                    Tests = @{
                        name = "Failed testcase"
                        time = "2.0"
                        success = $false
                    }
                }
            );
            $testFile = "$TestDrive\Results\Tests.xml"
            Write-NunitTestReport $testResults $testFile
            $valid = Test-Xml $testFile -SchemaPath '.\nunit_schema_2.5.xsd' -Verbose
            $valid.Should.Be($true)
        }
    }
    else {
        Write-Host "PowerShell Community Extensions not found, unable to validate nunit xml against schema. To run this test download http://pscx.codeplex.com"
    }
}

