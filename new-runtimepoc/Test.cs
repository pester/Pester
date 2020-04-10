using System;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;
using System.Management.Automation.Language;

namespace Pester
{
    public class Test
    {
        public static Test Create()
        {
            var t = new Test();
            t.ItemType = "Test";
            t.PSTypeName = "DiscoveredTest";
            t.FrameworkData = new Hashtable();
            var runtime = new Hashtable();
            runtime.Add("Phase", null);
            runtime.Add("ExecutionStep", null);
            t.FrameworkData.Add("Runtime", runtime);
            return t;
        }

        //public static Test Create(string id, ScriptBlock scriptBlock, string name, string[] path, string[] tag, bool focus, bool skip, Hashtable data)
        //{
        //    var t = Create();

        //    t.Id = id;
        //    t.ScriptBlock = scriptBlock;
        //    t.Name = name;
        //    t.Path = path.ToList();
        //    t.Tag = tag.ToList();
        //    t.Focus = focus;
        //    t.Skip = skip;

        //    return t;
        //}

        public string ItemType;
        public string Id;
        public ScriptBlock ScriptBlock;
        public string Name;
        public List<string> Path;
        public List<string> Tag;
        public bool Focus;
        public bool Skip;
        public Hashtable Data = new Hashtable();

        public string ExpandedName;
        public object Block;

        public bool First = false;
        public bool Last = false;
        public bool Include = false;
        public bool Exclude = false;
        public bool Explicit = false;
        public bool ShouldRun = false;

        public bool Executed = false;
        public DateTime? ExecutedAt = null;
        public bool Passed = false;
        public bool Skipped = false;
        public string StandardOutput = null;
        public List<object> ErrorRecord = new List<object>();

        public TimeSpan Duration = TimeSpan.Zero;
        public TimeSpan FrameworkDuration = TimeSpan.Zero;
        public Hashtable PluginData = new Hashtable();
        public Hashtable FrameworkData;
        public string PSTypeName;

        public override string ToString() { return string.Join(".", this.Path); }
    }

    public class Block
    {
        public static Block Create()
        {
            return new Block();
        }
        //    function New-BlockObject {
        //[CmdletBinding()]
        //    param(
        //    [Parameter(Mandatory = $true)]
        //    [String] $Name,
        //    [string[]] $Path,
        //    [string[]] $Tag,
        //    [ScriptBlock] $ScriptBlock,
        //    [HashTable] $FrameworkData = @{ },
        //    [HashTable] $PluginData = @{ },
        //    [Switch] $Focus,
        //    [String] $Id,
        //    [Switch] $Skip
        //)



        public string ItemType = "Block";
        public string Id; // = $id
        public string Name; // = $Name 
        public List<string> Path; // =  $Path 
        public List<string> Tag;// = $Tag
        public ScriptBlock ScriptBlock; // = $ScriptBlock
        public Hashtable FrameworkData = new Hashtable(); // = $FrameworkData
        public Hashtable PluginData = new Hashtable(); // = $PluginData
        public bool Focus; //= [bool] $Focus
        public bool Skip; // = [bool] $Skip

        public List<object> Tests = new List<object>();

        // TODO: consider renaming this to just Container
        public object BlockContainer; // = $null
        public object Root; // =                 = $null
        public bool IsRoot; //               = $null
        public object Parent; //               = $null
        public ScriptBlock EachTestSetup;//        = $null
        public ScriptBlock OneTimeTestSetup; //     = $null
        public ScriptBlock EachTestTeardown; //    = $null
        public ScriptBlock OneTimeTestTeardown;// = $null
        public ScriptBlock EachBlockSetup;// = $null
        public ScriptBlock OneTimeBlockSetup; //    = $null
        public ScriptBlock EachBlockTeardown;// = $null
        public ScriptBlock OneTimeBlockTeardown;// = $null
        public List<object> Order = new List<object>();    //   = [Collections.Generic.List[Object]]@()
        public List<object> Blocks = new List<object>(); // [Collections.Generic.List[Object]]@()
        public bool Executed; // = $false
        public bool Passed; //            = $false
        public bool First; //              = $false
        public bool Last;//                 = $false
        public List<object> StandardOutput;  //     = $null
        public List<object> ErrorRecord = new List<object>();   //       = [Collections.Generic.List[Object]]@()
        public bool ShouldRun; // = $false
        public bool Exclude; //              = $false
        public bool Include;//            = $false
        public bool Explicit; //            = $false
        public DateTime ExecutedAt; //         = $null
        public TimeSpan Duration; //             = [timespan]::Zero
        public TimeSpan FrameworkDuration; // = [timespan]::Zero
        public TimeSpan OwnDuration; //          = [timespan]::Zero
        public TimeSpan DiscoveryDuration;// = [timespan]::Zero
        public bool OwnPassed;// = $false
        public int TotalCount; // = 0
        public int PassedCount; // = 0
        public int FailedCount; // = 0
        public int SkippedCount; // = 0
        public int PendingCount; // = 0
        public int NotRunCount; // = 0
        public int InconclusiveCount; // = 0
        public int OwnTotalCount; // = 0
        public int OwnPassedCount; // = 0
        public int OwnFailedCount; // = 0
        public int OwnSkippedCount; // = 0
        public int OwnPendingCount; // = 0
        public int OwnNotRunCount; // = 0
        public int OwnInconclusiveCount; // = 0
        public string PSTypeName = "DiscoveredBlock";

        public override string ToString() { return string.Join(".", this.Path); }
    }
}
