$PesterDebugPreference = 1
(measure-command {
    foreach ($i in 1..10000) {
        $ExecutionContext.SessionState.PSVariable.GetValue('PesterDebugPreference')
    }
}).TotalMilliseconds

(measure-command {
    foreach ($i in 1..10000) {
        $PesterDebugPreference
    }
}).TotalMilliseconds

