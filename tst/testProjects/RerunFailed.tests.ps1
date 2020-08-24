Set-StrictMode -Version Latest

New-Block "rerun block1" -StartLine 3 {
    New-Test "test1" -StartLine 4 { "a" }
    New-Block "rerun block2" -StartLine 5 {
        New-Test "test2" -StartLine 6 {
            throw
        }
    }
}

New-Block "rerun block3" -StartLine 12 {
    New-Test "test3" -StartLine 13 {
        if (-not $willPass) { throw }
    }
}
