Set-StrictMode -Version Latest

# Tests has to be placed in file to make predictable as New-Block/-Test
# requires the parameter for line filter to work

New-Block "rerun block1" -StartLine 6 {
    New-Test "test1" -StartLine 7 { "a" }
    New-Block "rerun block2" -StartLine 8 {
        New-Test "test2" -StartLine 9 {
            throw
        }
    }
}

New-Block "rerun block3" -StartLine 15 {
    New-Test "test3" -StartLine 16 {
        if (-not $willPass) { throw }
    }
}
