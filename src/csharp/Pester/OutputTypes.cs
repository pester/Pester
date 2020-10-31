using System;
namespace Pester
{
    [Flags]
    public enum OutputTypes
    {
        None = 0,
        Default = 1,
        Passed = 2,
        Failed = 4,
        Pending = 8,
        Skipped = 16,
        Inconclusive = 32,
        Describe = 64,
        Context = 128,
        Summary = 256,
        Header = 512,
        All = Default | Passed | Failed | Pending | Skipped | Inconclusive | Describe | Context | Summary | Header,
        Fails = Default | Failed | Pending | Skipped | Inconclusive | Describe | Context | Summary | Header
    }
}