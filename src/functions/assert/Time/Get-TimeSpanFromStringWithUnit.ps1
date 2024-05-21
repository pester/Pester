function Get-TimeSpanFromStringWithUnit ([string] $Value) {
    if ($Value -notmatch "(?<value>^\d+(?:\.\d+)?)\s*(?<suffix>ms|mil|m|h|d|s|w)") {
        throw "String '$Value' is not a valid timespan string. It should be a number followed by a unit in short or long format (e.g. '1ms', '1s', '1m', '1h', '1d', '1w', '1sec', '1second', '1.5hours' etc.)."
    }

    $suffix = $Matches['suffix']
    $valueFromRegex = $Matches['value']
    switch ($suffix) {
        ms { [timespan]::FromMilliseconds($valueFromRegex) }
        mil { [timespan]::FromMilliseconds($valueFromRegex) }
        s { [timespan]::FromSeconds($valueFromRegex) }
        m { [timespan]::FromMinutes($valueFromRegex) }
        h { [timespan]::FromHours($valueFromRegex) }
        d { [timespan]::FromDays($valueFromRegex) }
        w { [timespan]::FromDays([double]$valueFromRegex * 7) }
        default { throw "Time unit '$suffix' in '$Value' is not supported." }
    }
}
