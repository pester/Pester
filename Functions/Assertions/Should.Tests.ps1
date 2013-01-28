
function PesterBe($expected, $value) {
  return ($expected -eq $value)
}

function PesterNotBe($expected, $value) {
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

  $testFailed = -not (& (gci "function:Pester$testMethod") $expected_value $value)

  if ($testFailed) {
    throw New-Object PesterFailure($expected_value, $value)
  }
}

Describe "Should" {

  Context("when comparing equal values") {
    It "does not return any errors" {
      1 | Should Be 1
    }
  }

  Context("when comparing unueqal values") {
    It "throws a PesterFailure" {
      try {
        2 | Should Be 1
        $failure_thrown = $false
      } catch {
        $failure_thrown = $true
      }

      $failure_thrown.should.be($true)
    }
  }

  Context("when comparing unequal values") {
    It "does not return any errors" {
      2 | Should NotBe 1
    }
  }

  Context("when comparing equal values") {
    It "throws a PesterFailure" {
      try {
        1 | Should NotBe 1
        $failure_thrown = $false
      } catch {
        $failure_thrown = $true
      }

      $failure_thrown.should.be($true)
    }
  }
}

