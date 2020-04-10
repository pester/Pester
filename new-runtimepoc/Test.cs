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

        public string ItemType { get; private set; }
        public string Id { get; set; }
        public ScriptBlock ScriptBlock { get; set; }
        public string Name { get; set; }
        public List<string> Path { get; set; }
        public List<string> Tag { get; set; }
        public bool Focus { get; set; }
        public bool Skip { get; set; }
        // IDictionary to allow users use [ordered]
        public IDictionary Data { get; set; } = new Hashtable();

        public string ExpandedName { get; set; }
        public object Block { get; set; }

        public bool First { get; set; } = false;
        public bool Last { get; set; } = false;
        public bool Include { get; set; } = false;
        public bool Exclude { get; set; } = false;
        public bool Explicit { get; set; } = false;
        public bool ShouldRun { get; set; } = false;

        public bool Executed { get; set; } = false;
        public DateTime? ExecutedAt { get; set; } = null;
        public bool Passed { get; set; } = false;
        public bool Skipped { get; set; } = false;
        public object StandardOutput { get; set; } = null;
        public List<object> ErrorRecord { get; set; } = new List<object>();

        public TimeSpan Duration { get; set; } = TimeSpan.Zero;
        public TimeSpan FrameworkDuration { get; set; } = TimeSpan.Zero;
        public Hashtable PluginData { get; set; } = new Hashtable();
        public Hashtable FrameworkData { get; set; }
        public string PSTypeName { get; private set; }

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



        public string ItemType { get;  } = "Block";
        public string Id { get; set; } // = $id
        public string Name { get; set; } // = $Name 
        public List<string> Path { get; set; } // =  $Path 
        public List<string> Tag { get; set; }// = $Tag
        public ScriptBlock ScriptBlock { get; set; } // = $ScriptBlock
        public Hashtable FrameworkData { get; set; } = new Hashtable(); // = $FrameworkData
        public Hashtable PluginData { get; set; } = new Hashtable(); // = $PluginData
        public bool Focus { get; set; } //= [bool] $Focus
        public bool Skip { get; set; } // = [bool] $Skip

        public List<object> Tests { get; set; } = new List<object>();

        // TODO: consider renaming this to just Container
        public object BlockContainer { get; set; } // = $null
        public object Root { get; set; } // =                 = $null
        public bool IsRoot { get; set; } //               = $null
        public object Parent { get; set; } //               = $null
        public ScriptBlock EachTestSetup { get; set; }//        = $null
        public ScriptBlock OneTimeTestSetup { get; set; } //     = $null
        public ScriptBlock EachTestTeardown { get; set; } //    = $null
        public ScriptBlock OneTimeTestTeardown { get; set; }// = $null
        public ScriptBlock EachBlockSetup { get; set; }// = $null
        public ScriptBlock OneTimeBlockSetup { get; set; } //    = $null
        public ScriptBlock EachBlockTeardown { get; set; }// = $null
        public ScriptBlock OneTimeBlockTeardown { get; set; }// = $null
        public List<object> Order { get; set; } = new List<object>();    //   = [Collections.Generic.List[Object]]@()
        public List<object> Blocks { get; set; } = new List<object>(); // [Collections.Generic.List[Object]]@()
        public bool Executed { get; set; } // = $false
        public bool Passed { get; set; } //            = $false
        public bool First { get; set; } //              = $false
        public bool Last;//                 = $false
        public List<object> StandardOutput;  //     = $null
        public List<object> ErrorRecord = new List<object>();   //       = [Collections.Generic.List[Object]]@()
        public bool ShouldRun { get; set; } // = $false
        public bool Exclude { get; set; } //              = $false
        public bool Include { get; set; }//            = $false
        public bool Explicit { get; set; } //            = $false
        public DateTime ExecutedAt { get; set; } //         = $null
        public TimeSpan Duration { get; set; } //             = [timespan]::Zero
        public TimeSpan FrameworkDuration { get; set; } // = [timespan]::Zero
        public TimeSpan OwnDuration { get; set; } //          = [timespan]::Zero
        public TimeSpan DiscoveryDuration { get; set; }// = [timespan]::Zero
        public bool OwnPassed { get; set; }// = $false
        public int TotalCount { get; set; } // = 0
        public int PassedCount { get; set; } // = 0
        public int FailedCount { get; set; } // = 0
        public int SkippedCount { get; set; } // = 0
        public int PendingCount { get; set; } // = 0
        public int NotRunCount { get; set; } // = 0
        public int InconclusiveCount { get; set; } // = 0
        public int OwnTotalCount { get; set; } // = 0
        public int OwnPassedCount { get; set; } // = 0
        public int OwnFailedCount { get; set; } // = 0
        public int OwnSkippedCount { get; set; } // = 0
        public int OwnPendingCount { get; set; } // = 0
        public int OwnNotRunCount { get; set; } // = 0
        public int OwnInconclusiveCount { get; set; } // = 0
        public string PSTypeName = "DiscoveredBlock";

        public override string ToString() { return string.Join(".", this.Path); }
    }
}
