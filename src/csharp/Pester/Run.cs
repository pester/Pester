using System;
using System.Collections;
using System.Collections.Generic;

namespace Pester
{
    public class Run
    {
        public static Run Create()
        {
            return new Run();
        }

        public List<Container> Containers { get; set; } = new List<Container>();

        public string Result { get; set; } = "NotRun";
        public int FailedCount { get; set; }
        public int FailedBlocksCount { get; set; }
        public int FailedContainersCount { get; set; }

        public int PassedCount { get; set; }
        public int SkippedCount { get; set; }
        public int InconclusiveCount { get; set; }
        public int NotRunCount { get; set; }
        public int TotalCount { get; set; }

        public TimeSpan Duration { get; set; }

        public bool Executed { get; set; }
        public DateTime ExecutedAt { get; set; }

        public string Version { get; set; }
        public string PSVersion { get; set; }

        public object PSBoundParameters { get; set; }
        public List<object> Plugins { get; set; } = new List<object>();
        public Hashtable PluginConfiguration { get; set; } = new Hashtable();
        public Hashtable PluginData { get; set; } = new Hashtable();
        public PesterConfiguration Configuration { get; set; }

        public TimeSpan DiscoveryDuration { get; set; }
        public TimeSpan UserDuration { get; set; }
        public TimeSpan FrameworkDuration { get; set; }

        public List<Test> Failed { get; set; } = new List<Test>();
        public List<Block> FailedBlocks { get; set; } = new List<Block>();
        public List<Container> FailedContainers { get; set; } = new List<Container>();

        public List<Test> Passed { get; set; } = new List<Test>();
        public List<Test> Skipped { get; set; } = new List<Test>();
        public List<Test> Inconclusive { get; set; } = new List<Test>();
        public List<Test> NotRun { get; set; } = new List<Test>();
        public List<Test> Tests { get; set; } = new List<Test>();

        public CodeCoverage CodeCoverage { get; set; }

        public override string ToString()
        {
            return ToStringConverter.RunToString(this);
        }
    }
}
