using System.Management.Automation;
using System.Collections.Generic;
using System;
using System.Text;
using System.IO;

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

        public static PSScriptMethod CreateScriptMethod(string name, ScriptBlock scriptBlock)
        {
            return new PSScriptMethod(name, scriptBlock);
        }

        public static Dictionary<string, object> CreateDictionary()
        {
            return new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        }

        public static RuntimeDefinedParameterDictionary CreateRuntimeDefinedParameterDictionary() {
            return new System.Management.Automation.RuntimeDefinedParameterDictionary();
        }

        public static List<object> CreateCollection()
        {
            return new List<object>();
        }

        public static ErrorRecord CreateShouldErrorRecord(string message, string file, string line, string lineText, bool terminating, string expectedValue = null, string actualValue = null, string becauseValue = null)
        {
            return CreateErrorRecord("PesterAssertionFailed", message, file, line, lineText, terminating, expectedValue, actualValue, becauseValue);
        }

        public static ErrorRecord CreateErrorRecord(string errorId, string message, string file, string line, string lineText, bool terminating, string expectedValue = null, string actualValue = null, string becauseValue = null)
        {
            var exception = new Exception(message);
            // we use ErrorRecord.TargetObject to pass structured information about the error to a reporting system.
            var targetObject = new Dictionary<string, object>
            {
                ["Message"] = message,
                ["File"] = file,
                ["Line"] = line,
                ["LineText"] = lineText,
                ["Terminating"] = terminating,
                ["ExpectedValue"] = expectedValue,
                ["ActualValue"] = actualValue,
                ["BecauseValue"] = becauseValue,
            };
            return new ErrorRecord(exception, errorId, ErrorCategory.InvalidResult, targetObject);
        }

        public static StringBuilder CreateStringBuilder()
        {
            return new StringBuilder();
        }

        public static StringWriter CreateStringWriter()
        {
            return new StringWriter();
        }
    }
}
