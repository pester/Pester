
function Should {

  process {
    $value = $_

    if ($args[0] -eq "Not") {
      $testMethod = $args[1]
      $expected_value = $args[2]
      $assertionFunction = "$testMethod"
      $testFailed = (& $assertionFunction $expected_value $value)
      if ($testFailed) {
        $errorMessage = (& "Not$($assertionFunction)ErrorMessage" $expected_value $value)
        throw $errorMessage
      }
    } else {
      $testMethod = $args[0]
      $expected_value = $args[1]
      $assertionFunction = "$testMethod"
      $testFailed = -not (& $assertionFunction $expected_value $value)
      if ($testFailed) {
        $errorMessage = (& "$($assertionFunction)ErrorMessage" $expected_value $value)
        throw $errorMessage
      }
    }
  }
}

