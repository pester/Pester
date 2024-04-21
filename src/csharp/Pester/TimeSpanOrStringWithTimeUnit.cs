using System;

namespace Pester
{
    public class TimeSpanOrStringWithTimeUnit
    {
        public TimeSpan DurationTimeSpan { get; private set; }
        public string DurationString { get; private set; }
        public static implicit operator TimeSpanOrStringWithTimeUnit(TimeSpan durationTimeSpan)
        {
            return new TimeSpanOrStringWithTimeUnit() { DurationTimeSpan = durationTimeSpan };
        }
        public static implicit operator TimeSpanOrStringWithTimeUnit(string durationTimeSpan)
        {
            return new TimeSpanOrStringWithTimeUnit() { DurationString = durationTimeSpan };
        }
    }
}
