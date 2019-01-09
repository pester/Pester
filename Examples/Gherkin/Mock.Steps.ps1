function global:Test-Error {
    Write-Error "This is an error" -ErrorAction SilentlyContinue
}

Given "we mock Write-Error" {
    Mock Write-Error { } -Verifiable
}

When "we call a function that writes an error" {
    Test-Error
}

Then "we can verify the mock" {
    Assert-MockCalled Write-Error
    Assert-VerifiableMock
}

Then "we cannot verify the mock" {
    try {
        Assert-MockCalled Write-Error
    }
    catch {
        return
    }
    throw "Write-Error not called"
}
