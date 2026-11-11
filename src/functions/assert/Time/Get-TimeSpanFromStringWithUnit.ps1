function Get-TimeSpanFromStringWithUnit ([string] $Value) {
    # The whole string has to be a number and a unit and nothing else, and the unit has to be
    # spelled out in full. The pattern this replaces matched a prefix: it had no anchor at the end,
    # and it matched the unit by its first letters, so it accepted strings it then read as something
    # else. '1sfoo' and '1 s junk' were one second, with the rest dropped. Worse, 'month' starts
    # with 'm', so '1month' was quietly read as one minute, and '1 week ago' as one week. Guessing
    # at a value is worse than refusing the string (#3038).
    # An ordered list, not a hashtable, because the spellings go into the pattern in this order and
    # a longer spelling has to come before a shorter one it starts with, or 'ms' would win over
    # 'milliseconds' and leave 'illiseconds' unmatched.
    $units = @(
        @{ Unit = 'Milliseconds'; Names = @('milliseconds', 'millisecond', 'millis', 'milli', 'mil', 'ms') }
        @{ Unit = 'Seconds'; Names = @('seconds', 'second', 'secs', 'sec', 's') }
        @{ Unit = 'Minutes'; Names = @('minutes', 'minute', 'mins', 'min', 'm') }
        @{ Unit = 'Hours'; Names = @('hours', 'hour', 'hrs', 'hr', 'h') }
        @{ Unit = 'Days'; Names = @('days', 'day', 'd') }
        @{ Unit = 'Weeks'; Names = @('weeks', 'week', 'w') }
    )

    $suffixes = ($units.Names) -join '|'
    if ($Value -notmatch "^(?<value>\d+(?:\.\d+)?)\s*(?<suffix>$suffixes)\s*`$") {
        throw "String '$Value' is not a valid timespan string. It should be a number followed by a unit in short or long format (e.g. '1ms', '1s', '1m', '1h', '1d', '1w', '1sec', '1second', '1.5hours' etc.), and nothing else."
    }

    $suffix = $Matches['suffix']
    $valueFromRegex = [double] $Matches['value']
    $unit = $null
    foreach ($u in $units) {
        if ($suffix -in $u.Names) {
            $unit = $u.Unit
            break
        }
    }

    switch ($unit) {
        'Milliseconds' { [timespan]::FromMilliseconds($valueFromRegex); break }
        'Seconds' { [timespan]::FromSeconds($valueFromRegex); break }
        'Minutes' { [timespan]::FromMinutes($valueFromRegex); break }
        'Hours' { [timespan]::FromHours($valueFromRegex); break }
        'Days' { [timespan]::FromDays($valueFromRegex); break }
        'Weeks' { [timespan]::FromDays($valueFromRegex * 7); break }
        # Not reachable, the pattern is built from the same table, but an unhandled unit must not
        # fall through to returning nothing, which the caller would compare against as zero.
        default { throw "Time unit '$suffix' in '$Value' is not supported." }
    }
}
