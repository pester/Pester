
function PesterEqual($expected, $value) {
  return ($expected -eq $value)
}

function PesterNotEqual($expected, $value) {
  return ($expected -ne $value)
}

function Should {

  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline=$TRUE)]
    $value,
    [Parameter(Position=0,Mandatory=1)]
    $testMethod,
    [Parameter(Position=1,Mandatory=1)]
    $expected_value
  )

  $pesterTestMethod = "Pester$testMethod"
  $testFailed = -not (Invoke-Expression -Command "$pesterTestMethod $expected_value $value")

  if ($testFailed) {
    throw New-Object PesterFailure($expected_value, $value)
  }
}

Describe "Should" {

  Context("when comparing equal values") {
    It "does not return any errors" {
      1 | Should Equal 1
    }
  }

  Context("when comparing unueqal values") {
    It "throws a PesterFailure" {
      try {
        2 | Should Equal 1
        $failure_thrown = $false
      } catch {
        $failure_thrown = $true
      }

      $failure_thrown.should.be($true)
    }
  }
}

Describe "Should-Not" {

  Context("when comparing unequal values") {
    It "does not return any errors" {
      2 | Should NotEqual 1
    }
  }

  Context("when comparing equal values") {
    It "throws a PesterFailure" {
      try {
        1 | Should NotEqual 1
        $failure_thrown = $false
      } catch {
        $failure_thrown = $true
      }

      $failure_thrown.should.be($true)
    }
  }
}
