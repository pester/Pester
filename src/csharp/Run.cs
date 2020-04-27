using System;
using System.Collections;
using System.Collections.Generic;
using System.Text;

namespace Pester
{
    public class Run
    {
        public static Run Create()
        {
            return new Run();
        }


        /*
        ExecutedAt = $ExecutedAt
        Containers = [Collections.ArrayList]@($BlockContainer)
        PSBoundParameters = $BoundParameters
        Plugins = $Plugins
        PluginConfiguration = $PluginConfiguration
        PluginData = $PluginData
        Configuration = $Configuration

        Duration = [TimeSpan]::Zero
        FrameworkDuration = [TimeSpan]::Zero
        DiscoveryDuration = [TimeSpan]::Zero

        Passed = [Collections.ArrayList]@()
        PassedCount = 0
        Failed = [Collections.ArrayList]@()
        FailedCount = 0
        Skipped = [Collections.ArrayList]@()
        SkippedCount = 0
        NotRun = [Collections.ArrayList]@()
        NotRunCount = 0
        Tests = [Collections.ArrayList]@()
        TotalCount = 0

        FailedBlocks = [Collections.ArrayList]@()
        FailedBlocksCount = 0
         */

        public string Result { get; set; } = "NotRun";
        public int FailedCount { get; set; }
        public int PassedCount { get; set; }
        public int SkippedCount { get; set; }
        public int NotRunCount { get; set; }
        public int TotalCount { get; set; }

        public TimeSpan Duration { get; set; }
        public List<Container> Containers { get; set; } = new List<Container>();

        public bool Executed { get; set; }
        public DateTime ExecutedAt { get; set; }


        public object PSBoundParameters { get; set; }
        public List<object> Plugins { get; set; } = new List<object>();
        public Hashtable PluginConfiguration { get; set; } = new Hashtable();
        public Hashtable PluginData { get; set; } = new Hashtable();
        public PesterConfiguration Configuration { get; set; }

        public TimeSpan DiscoveryDuration { get; set; }
        public TimeSpan UserDuration { get; set; }
        public TimeSpan FrameworkDuration { get; set; }

        public List<Test> Passed { get; set; } = new List<Test>();
        public List<Test> Failed { get; set; } = new List<Test>();
        public List<Test> Skipped { get; set; } = new List<Test>();
        public List<Test> NotRun { get; set; } = new List<Test>();
        public List<Test> Tests { get; set; } = new List<Test>();
        
        public List<Block> FailedBlocks { get; set; } = new List<Block>();
        public int FailedBlocksCount { get; set; }

        public override string ToString()
        {
            return ToStringConverter.RunToString(this);
        }
    }
}
