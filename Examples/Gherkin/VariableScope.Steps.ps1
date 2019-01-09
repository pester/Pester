When 'I (?:set|initialize) the variable (?<Name>[\w:]+) to "(?<Value>[^"]+)"' {
    param($Name, $Value)

    switch ($Name) {
        "One" {
            $One = $Value
        }
        "Two" {
            $Two = $Value
        }
        "Script:Two" {
            $Script:Two = $Value
        }
    }
}

Given 'I initialize variables One and (?<Script>.+:)?Two to "Uno" and "Dos"' {
    param($Script)
    $One = "Uno"

    if ($Script) {
        $Script:Two = "Dos"
    }
    else {
        $Two = "Dos"
    }
}


Then 'the variable ([\w:]+) should be "([^"]+)"' {
    param($Name, $Value)

    $Result = switch ($Name) {
        "One" {
            $One
        }
        "Two" {
            $Two
        }
        "Script:Two" {
            $Script:Two
        }
    }
    $Result | Should -Be $Value
}

Then "the variable ([\w:]+) should not exist" {
    param($Name)

    switch ($Name) {
        "One" {
            Test-Path Variable:One | Should -Be $False
        }
        "Two" {
            Test-Path Variable:Two | Should -Be $False
        }
        "Script:Two" {
            Test-Path Variable:Script:Two | Should -Be $False
        }
    }
}

BeforeEachFeature {
    Remove-Variable One -ErrorAction SilentlyContinue
    Remove-Variable Two -ErrorAction SilentlyContinue
    Remove-Variable Two -Scope Script -ErrorAction SilentlyContinue
}

# Not using this BACKGROUND Given anymore, we're using a BeforeEachFeature instead
# That way we only clear the variable at the beginning of the test
Given "I ensure variables ([\w:]+) and ([\w:]+) are not set" {
    param(
        [Parameter(ValueFromRemainingArguments = $True)]
        [string[]]$names
    )

    foreach ($name in $Names) {
        Remove-Variable -Name $Name -ErrorAction SilentlyContinue
    }
}
