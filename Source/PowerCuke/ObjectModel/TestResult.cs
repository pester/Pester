using System;
using System.Diagnostics;

namespace PoshCode.PowerCuke.ObjectModel
{
    public class TestResult
    {
        public Step Step;
        public bool Passed;
        public DateTime Time;
        public string FailureMessage;
        public StackTrace StackTrace;
    }
}