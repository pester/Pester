using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;

namespace Pester
{
    public class Container
    {
        public static Container Create() {
            return new Container();
        }

        public static Container CreateFromBlock (Block block) {
            return new Container
            {
                Result = block.Result,
                FailedCount = block.FailedCount,
                PassedCount = block.PassedCount,
                SkippedCount = block.SkippedCount,
                NotRunCount = block.NotRunCount,
                TotalCount = block.TotalCount,
                ErrorRecord = block.ErrorRecord ?? new List<object>(),
                DiscoveryDuration = block.DiscoveryDuration,
                UserDuration = block.UserDuration,
                FrameworkDuration = block.FrameworkDuration,
                Passed = block.Passed,
                OwnPassed = block.OwnPassed,
                Skip = block.Skip,
                ShouldRun = block.ShouldRun,
                Executed = block.Executed,
                ExecutedAt = block.ExecutedAt,
                Type = block.BlockContainer.Type,
                Item = block.BlockContainer.Item,
                Blocks = block.Blocks,
                Data = block.Data
        };
        }

        public static Container CreateFromFile(FileInfo file)
        {
            return new Container
            {
                Type = "File",
                Item = file
            };
        }

        public string Type { get; set; }
        public object Item { get; set; }
        public IDictionary Data { get; set; }
        public List<Block> Blocks { get; set; } = new List<Block>();
        public string Result { get; set; } = "NotRun";
        public TimeSpan Duration { get => DiscoveryDuration + UserDuration + FrameworkDuration; }
        public int FailedCount { get; set; }
        public int PassedCount { get; set; }
        public int SkippedCount { get; set; }
        public int NotRunCount { get; set; }
        public int TotalCount { get; set; }
        public List<object> ErrorRecord { get; set; } = new List<object>();
        public bool Passed { get; set; }
        public bool OwnPassed { get; set; }
        public bool Skip { get; set; }
        public bool ShouldRun { get; set; }
        public bool Executed { get; set; }
        public DateTime ExecutedAt { get; set; }

        public TimeSpan DiscoveryDuration { get; set; }
        public TimeSpan UserDuration { get; set; }
        public TimeSpan FrameworkDuration { get; set; }


        public override string ToString()
        {
            return ToStringConverter.ContainerToString(this);
        }
    }
}
