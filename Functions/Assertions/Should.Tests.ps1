
function Should {

  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline=$TRUE)]
    $value,
    [alias("Equal")]
    $expected_value
  )

  $equal = ($value -eq $expected_value)

  if (-not $equal) {
    throw New-Object PesterFailure($expected_value, $value)
  }
}

function Should-Not {

  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline=$TRUE)]
    $value,
    [alias("Equal")]
    $unexpected_value
  )

  $equal = ($value -eq $unexpected_value)

  if ($equal) {
    throw New-Object PesterFailure($unexpected_value, $value)
  }
}


Describe "Should" {

  Context("when comparing equal values") {
    It "does not return any errors" {
      1 | Should -Equal 1
    }
  }

  Context("when comparing unueqal values") {
    It "throws a PesterFailure" {
      try {
        2 | Should -Equal 1
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
      2 | Should-Not -Equal 1
    }
  }

  Context("when comparing equal values") {
    It "throws a PesterFailure" {
      try {
        1 | Should-Not -Equal 1
        $failure_thrown = $false
      } catch {
        $failure_thrown = $true
      }

      $failure_thrown.should.be($true)
    }
  }
}
