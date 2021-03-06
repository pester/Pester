namespace PesterTests
{
    using Pester;
    using Xunit;

    /// <summary>
    /// Configuration Tests
    /// </summary>
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
