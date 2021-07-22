using System;
using Xunit;

namespace PesterTests
{
    public class UnitTest1
    {
        [Fact]
        public void Test1()
        {
            var c = PesterConfiguration.Default;
            c.TestResult.Enabled = false;
            c.TestResult.OutputPath = "sfsfs";

            Assert.False(c.TestResult.Enabled.Value);

        }
    }
}
