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
            Tests = new List<object>();
            Order = new List<object>();
            Blocks = new List<object>();
            ErrorRecord = new List<object>();
        }

        public string ItemType { get; private set; }
        public string Id { get; set; } // = $id
        public string Name { get; set; } // = $Name 
        public List<string> Path { get; set; } // =  $Path 
        public List<string> Tag { get; set; }// = $Tag
        public ScriptBlock ScriptBlock { get; set; } // = $ScriptBlock
        public Hashtable FrameworkData { get; set; }// = $FrameworkData
        public Hashtable PluginData { get; set; }  // = $PluginData
        public bool Focus { get; set; } //= [bool] $Focus
        public bool Skip { get; set; } // = [bool] $Skip

        public List<object> Tests { get; set; }

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
        public List<object> Order { get; set; }  //   = [Collections.Generic.List[Object]]@()
        public List<object> Blocks { get; set; } // [Collections.Generic.List[Object]]@()
        public bool Executed { get; set; } // = $false
        public bool Passed { get; set; } //            = $false
        public bool First { get; set; } //              = $false
        public bool Last { get; set; }//                 = $false
        public object StandardOutput { get; set; }  //     = $null
        public List<object> ErrorRecord { get; set; }  //       = [Collections.Generic.List[Object]]@()
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
        public override string ToString() { return string.Join(".", this.Path); }
    }
}
