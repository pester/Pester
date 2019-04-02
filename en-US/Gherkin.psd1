@{
    ReportStrings = @{
        HeaderMessage     = 'Pester v{0}'
        StartMessage      = 'Executing all feature scenarios in ''{0}'''
        FilterMessage     = ' for scenarios matching ''{0}'''
        TagMessage        = ' with Tags ''{0}'''
        MessageOfs        = ''', '''

        CoverageTitle     = 'Code coverage report:'
        CoverageMessage   = 'Covered { 2:P2 } of { 3:N0 } analyzed { 0 } in { 4:N0 } { 1 }.'
        MissedSingular    = 'Missed command:'
        MissedPlural      = 'Missed commands:'
        CommandSingular   = 'Command'
        CommandPlural     = 'Commands'
        FileSingular      = 'File'
        FilePlural        = 'Files'

        Feature           = 'Feature: {0}'
        Script            = 'Executing script {0}'
        Scenario          = 'Scenario: {0}'
        Margin            = '  '
        Timing            = 'Tests completed in { 0 }'

        # If this is set to an empty string, the count won't be printed
        ContextsPassed    = ''
        ContextsFailed    = ''

        TestsPassed       = 'Tests Passed: {0}, '
        TestsFailed       = 'Failed: {0}, '
        TestsSkipped      = 'Skipped: {0}, '
        TestsPending      = 'Pending: {0}, '
        TestsInconclusive = 'Inconclusive: {0} '
    }

    ReportTheme   = @{
        Describe         = 'Green'
        DescribeDetail   = 'DarkYellow'
        Context          = 'Cyan'
        ContextDetail    = 'DarkCyan'
        TableCellDivider = 'White'
        TableCellValue   = 'DarkCyan'
        Pass             = 'DarkGreen'
        PassArgument     = 'Green'
        PassTime         = 'DarkGray'
        Fail             = 'DarkRed'
        FailArgument     = 'Red'
        FailTime         = 'DarkGray'
        Skipped          = 'DarkCyan'
        SkippedArgument  = 'Cyan'
        SkippedTime      = 'DarkGray'
        Pending          = 'DarkYellow'
        PendingArgument  = 'Yellow'
        PendingTime      = 'DarkGray'
        Inconclusive     = 'DarkYellow'  # <-- These are left here temporarily for now...
        InconclusiveTime = 'DrakGray'    # <-- TODO: Remove the Inconclusive entries...
        Undefined        = 'DarkYellow'
        UndefinedTime    = 'DarkGray'
        Foreground       = 'White'
        Information      = 'DarkGray'
        Coverage         = 'White'
        CoverageWarn     = 'DarkRed'
    }
}
