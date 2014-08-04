
function PesterBeExactly($value, $expected) {
    $expectedArray = @($expected)
    $valueArray = @($value)
    
    if ($expectedArray.Count -ne $valueArray.Count) { return $false }
    
    for ($i = 0; $i -lt $expectedArray.Count; $i++)
    {
        if ($expectedArray[$i] -cne $valueArray[$i]) { return $false }
    }
    
    return $true
}

function PesterBeExactlyFailureMessage($value, $expected) {
    return "Expected exactly: {$expected}`nBut instead was:  {$value}"
}

function NotPesterBeExactlyFailureMessage($value, $expected) {
    return "Expected: value was {$value}, but should not have been exactly the same"
}

