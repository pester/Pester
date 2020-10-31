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
            c.Filter.FullName = null;
            c.Run.Path = null;
        }
    }
}
