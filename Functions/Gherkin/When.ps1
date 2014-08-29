Function When {
    param(
        [Parameter(Mandatory=$True, Position=0)]
        [String]$Name,

        [Parameter(Mandatory=$True, Position=1)]
        [ScriptBlock]$Test
    )

    Set-Content "function:global:${StepPrefix}${Name}" {
        $Alias = $MyInvocation.InvocationName
        $PesterException = $null
        try{
            $watch = [System.Diagnostics.Stopwatch]::new()
            $watch.Start()
            $null = .(gmo Pester) $Test @Args
            $watch.Stop()
        } catch {
            $PesterException = $_
        } finally {
            $watch.Stop()
        }
        return @{
            Time = $watch.Elapsed
            Test = $Test
            Exception = $PesterException
            # Name = $Alias.SubString($StepPrefix.Length)
        }
    }.GetNewClosure()
}


Set-Alias And When
Set-Alias But When
Set-Alias Given When
Set-Alias Then When
