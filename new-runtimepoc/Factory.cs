using System.Management.Automation;
using System.Collections.Generic;
using System;

namespace Pester
{
    ///<summary>Creates various types to avoid using New-Object cmdlet</summary>
    ///
    public static class Factory
    {
        public static PSNoteProperty CreateNoteProperty(string name, object value)
        {
            return new PSNoteProperty(name, value);
        }

        public static Dictionary<string, object> CreateDictionary()
        {
            return new Dictionary<string, object>();
        }

        public static ErrorRecord CreateShouldErrorRecord(string message, string file, string line, string lineText, bool terminating)
        {
            var exception = new Exception(message);
            var errorId = "PesterAssertionFailed";
            var errorCategory = ErrorCategory.InvalidResult;
            // we use ErrorRecord.TargetObject to pass structured information about the error to a reporting system.
            var targetObject = new Dictionary<string, object> { };
            targetObject.Add("Message", message);
            targetObject.Add("File", file);
            targetObject.Add("Line", line);
            targetObject.Add("LineText", lineText);
            targetObject.Add("Terminating", terminating);
            var errorRecord = new ErrorRecord(exception, errorId, errorCategory, targetObject);
            return errorRecord;
        }
    }
}
