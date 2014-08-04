
function PesterBe($value, $expected) {
    $expectedArray = @($expected)
    $valueArray = @($value)
    
    if ($expectedArray.Count -ne $valueArray.Count) { return $false }
    
    for ($i = 0; $i -lt $expectedArray.Count; $i++)
    {
        if ($expectedArray[$i] -ne $valueArray[$i]) { return $false }
    }
    
    return $true
}

function PesterBeFailureMessage($value, $expected) {
    return "Expected: {$expected}`nBut was:  {$value}"
}

function NotPesterBeFailureMessage($value, $expected) {
    return "Expected: value was {$value}, but should not have been the same"
}

