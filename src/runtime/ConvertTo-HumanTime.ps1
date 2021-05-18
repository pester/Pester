function ConvertTo-HumanTime {
    param ([TimeSpan]$TimeSpan)
    if ($TimeSpan.Ticks -lt [timespan]::TicksPerSecond) {
        "$([int]($TimeSpan.TotalMilliseconds))ms"
    }
    else {
        "$([int]($TimeSpan.TotalSeconds))s"
    }
}
