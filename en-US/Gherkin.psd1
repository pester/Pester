@{
    ReportStrings = @{
        StartMessage = "Testing all features in '{0}'"
        FilterMessage = " for scenarios matching '{0}'"
        TagMessage = " with tags: '{0}'"
        MessageOfs = "', '"

        CoverageTitle   = "Code coverage report:"
        CoverageMessage = "Covered {2:P2} of {3:N0} analyzed {0} in {4:N0} {1}."
        MissedSingular  = 'Missed command:'
        MissedPlural    = 'Missed commands:'
        CommandSingular = 'Command'
        CommandPlural   = 'Commands'
        FileSingular    = 'File'
        FilePlural      = 'Files'

        Describe = "Feature: {0}"
        Context  = "Scenario: {0}"
        Margin   = "  "
        Timing   = "Testing completed in {0}"

        # If this is set to an empty string, the count won't be printed
        ContextSummary    = '{0} scenarios ('
        ContextsFailed    = '{0} failed'
        ContextsUndefined = '{0} undefined'
        ContextsPending   = '{0} pending'
        ContextsPassed    = '{0} passed'
        TestsSummary      = '{0} steps ('
        TestsFailed       = '{0} failed'
        TestsInconclusive = '{0} undefined'
        TestsSkipped      = '{0} skipped'
        TestsPending      = '{0} pending'
        TestsPassed       = '{0} passed'
    }

    ReportTheme = @{
        Describe         = 'Green'
        DescribeDetail   = 'DarkYellow'
        Context          = 'Cyan'
        ContextDetail    = 'DarkCyan'
        Pass             = 'DarkGreen'
        PassTime         = 'DarkGray'
        Fail             = 'Red'
        FailTime         = 'DarkGray'
        Skipped          = 'Yellow'
        SkippedTime      = 'DarkGray'
        Pending          = 'Yellow'
        PendingTime      = 'DarkGray'
        Inconclusive     = 'Yellow'
        InconclusiveTime = 'DarkGray'
        Incomplete       = 'Yellow'
        IncompleteTime   = 'DarkGray'
        Foreground       = 'White'
        Information      = 'DarkGray'
        Coverage         = 'White'
        CoverageWarn     = 'DarkRed'
    }
}
