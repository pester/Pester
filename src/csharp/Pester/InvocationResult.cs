using System.Collections.Generic;
using System.Management.Automation;

namespace Pester
{
    public class InvocationResult
    {
        public static InvocationResult Create(bool success, List<ErrorRecord> errorRecord, object standardOutput)
        {
            return new InvocationResult(success, errorRecord, standardOutput);
        }

        public InvocationResult(bool success, List<ErrorRecord> errorRecords, object standardOutput)
        {
            Success = success;
            ErrorRecord = errorRecords ?? new List<ErrorRecord>();
            StandardOutput = standardOutput;
        }

        public bool Success { get; }
        public List<ErrorRecord> ErrorRecord {get;}
        public object StandardOutput { get; }
    }
}
