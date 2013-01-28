
function PesterBe($expected, $value) {
  return ($expected -eq $value)
}

function Should {

  process {
    $value = $_

    if ($args[0] -eq "Not") {
      $testMethod = $args[1]
      $expected_value = $args[2]
      $assertionFunction = "Pester$testMethod"
      $testFailed = (& $assertionFunction $expected_value $value)
    } else {
      $testMethod = $args[0]
      $expected_value = $args[1]
      $assertionFunction = "Pester$testMethod"
      $testFailed = -not (& $assertionFunction $expected_value $value)
    }

    if ($testFailed) {
      throw New-Object PesterFailure($expected_value, $value)
    }
  }
}

Describe "Should" {

  Context("when comparing equal values") {
    It "does not return any errors" {
      1 | Should Be (2 - 1)
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
      2 | Should Not Be 1
    }
  }

  Context("when comparing equal values") {
    It "throws a PesterFailure" {
      try {
        1 | Should Not Be 1
        $failure_thrown = $false
      } catch {
        $failure_thrown = $true
      }

      $failure_thrown.should.be($true)
    }
  }
}

