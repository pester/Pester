using System;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;

namespace Pester
{
    public class Test
    {
        public static Test Create()
        {
            return new Test();
        }

        public Test()
        {
            ItemType = "Test";
            PluginData = new Hashtable();
            ErrorRecord = new List<object>();

            var runtime = new Hashtable
            {
                ["Phase"] = null,
                ["ExecutionStep"] = null,
            };
            FrameworkData = new Hashtable
            {
                ["Runtime"] = runtime,
            };
        }

        public string Name { get; set; }
        public List<string> Path { get; set; }
        public object Data { get; set; }
        public string ExpandedName { get; set; }
        public string ExpandedPath { get; set; }
        public string Result { get; set; }
        public List<object> ErrorRecord { get; set; }
        public object StandardOutput { get; set; }
        public TimeSpan Duration { get => UserDuration + FrameworkDuration; }

        public string ItemType { get; private set; }

        [Obsolete("Id is obsolete and should no longer be used. Use GroupId instead.")]
        public string Id { get => GroupId; }
        public string GroupId { get; set; }
        public ScriptBlock ScriptBlock { get; set; }
        public List<string> Tag { get; set; }
        public bool Focus { get; set; }
        public bool Skip { get; set; }
        // IDictionary to allow users use [ordered]

        public object Block { get; set; }

        public bool First { get; set; }
        public bool Last { get; set; }
        public bool Include { get; set; }
        public bool Exclude { get; set; }
        public bool Explicit { get; set; }
        public bool ShouldRun { get; set; }

        public int StartLine { get; set; }

        public bool Executed { get; set; }
        public DateTime? ExecutedAt { get; set; }
        public bool Passed { get; set; }
        public bool Skipped { get; set; }
        public bool Inconclusive { get; set; }

        public TimeSpan UserDuration { get; set; }
        public TimeSpan FrameworkDuration { get; set; }
        public Hashtable PluginData { get; set; }
        public Hashtable FrameworkData { get; set; }

        public override string ToString() => ToStringConverter.TestToString(this);
    }
}
