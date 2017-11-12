Given "there is a background" {
    # does nothing
}

Given "it sets x to (\d+)" {
    param([int]$value)
    $script:x = $value
}

Given "it sets y to (\d+)" {
    param([int]$value)
    $script:y = $value
}

Given "we add y to x" {
    param([int]$value)
    $script:x += $script:y
}

Then "x should be (\d+)" {
    param([int]$value)
    $script:x | Should Be $value
}