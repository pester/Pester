using System;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;

namespace Pester
{
    public class Block
    {
        public static Block Create()
        {
            return new Block();
        }

        public Block()
        {
            ItemType = "Block";
            FrameworkData = new Hashtable();
            PluginData = new Hashtable();
            Tests = new List<Test>();
            Order = new List<object>();
            Blocks = new List<Block>();
            ErrorRecord = new List<object>();
        }

        public string Name { get; set; }
        public List<string> Path { get; set; }
        public object Data { get; set; }
        public string ExpandedName { get; set; }
        public string ExpandedPath { get; set; }
        public List<Block> Blocks { get; set; } = new List<Block>();
        public List<Test> Tests { get; set; } = new List<Test>();

        public string Result { get; set; } = "NotRun";
        public int FailedCount { get; set; }
        public int PassedCount { get; set; }
        public int SkippedCount { get; set; }
        public int NotRunCount { get; set; }
        public int TotalCount { get; set; }
        public List<object> ErrorRecord { get; set; }
        public TimeSpan Duration { get => DiscoveryDuration + FrameworkDuration + UserDuration; }

        [Obsolete("Id is obsolete and should no longer be used. Use GroupId instead.")]
        public string Id { get => GroupId; }
        public string GroupId { get; set; }
        public List<string> Tag { get; set; }
        public bool Focus { get; set; }
        public bool Skip { get; set; }

        public string ItemType { get; } = "Block";

        public ContainerInfo BlockContainer { get; set; }
        public object Root { get; set; }
        public bool IsRoot { get; set; }
        public object Parent { get; set; }
        public ScriptBlock EachTestSetup { get; set; }
        public ScriptBlock OneTimeTestSetup { get; set; }
        public ScriptBlock EachTestTeardown { get; set; }
        public ScriptBlock OneTimeTestTeardown { get; set; }
        public ScriptBlock EachBlockSetup { get; set; }
        public ScriptBlock OneTimeBlockSetup { get; set; }
        public ScriptBlock EachBlockTeardown { get; set; }
        public ScriptBlock OneTimeBlockTeardown { get; set; }
        public List<object> Order { get; set; } = new List<object>();

        public bool Passed { get; set; }
        public bool First { get; set; }
        public bool Last { get; set; }
        public object StandardOutput { get; set; }
        public bool ShouldRun { get; set; }
        public bool Executed { get; set; }
        public DateTime ExecutedAt { get; set; }
        public bool Exclude { get; set; }
        public bool Include { get; set; }
        public bool Explicit { get; set; }
        public TimeSpan DiscoveryDuration { get; set; }
        public TimeSpan FrameworkDuration { get; set; }
        public TimeSpan UserDuration { get; set; }
        public TimeSpan OwnDuration { get; set; }

        public ScriptBlock ScriptBlock { get; set; }
        public int StartLine { get; set; }
        public Hashtable FrameworkData { get; set; } = new Hashtable();
        public Hashtable PluginData { get; set; } = new Hashtable();

        public int InconclusiveCount { get; set; }

        public bool OwnPassed { get; set; }
        public int OwnTotalCount { get; set; }
        public int OwnPassedCount { get; set; }
        public int OwnFailedCount { get; set; }
        public int OwnSkippedCount { get; set; }
        public int OwnNotRunCount { get; set; }
        public int OwnInconclusiveCount { get; set; }

        public override string ToString()
        {
            return ToStringConverter.BlockToString(this);
        }
    }
}
