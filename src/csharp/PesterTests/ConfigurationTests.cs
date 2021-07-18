using Xunit;

namespace PesterTests
{
    public class ConfigurationTests
    {
        [Fact]
        public void Test_Init_Configuration()
        {
            var c = PesterConfiguration.Default;
            c.Filter.FullName = null;
            c.Run.Path = null;
        }
    }
}
