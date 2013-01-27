
function Should-NotBeNullOrEmpty {

  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline=$TRUE)]
    $value
  )             

  if (($value -eq $null) -or ($value -eq "") -or ($value.Count -eq 0)) {
    throw New-Object PesterFailure("Did not expect the value to be null or empty", "$value is null or empty")
  }
}

Describe "Should-NotBeNullOrEmpty" {

  It "throws a PesterFailure when the variable has not got a value" {
      $string = ""

      try {
       Should-NotBeNullOrEmpty $string
        $failure_thrown = $false
      } catch {
        $failure_thrown = $true
      }

      $failure_thrown.should.be($true)
    }

    It "throws a PesterFailure when the variable is empty array" {
      $nonNullArray = @()

      try {
       Should-NotBeNullOrEmpty $nonNullArray
        $failure_thrown = $false
      } catch {
        $failure_thrown = $true
      }

      $failure_thrown.should.be($true)
    }

    It "passes the test when the string is has a value" {
        $string = "this string has a value"

      try {
       Should-NotBeNullOrEmpty $string
        $failure_thrown = $false
      } catch {
        $failure_thrown = $true
      }

      $failure_thrown.should.be($false)
    }

    It "passes the test when the array has an element" {
        $emptyArray = @("element1")

      try {
       Should-NotBeNullOrEmpty $emptyArray
        $failure_thrown = $false
      } catch {
        $failure_thrown = $true
      }

      $failure_thrown.should.be($false)
    }

    
}
