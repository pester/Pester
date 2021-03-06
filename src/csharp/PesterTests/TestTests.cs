namespace PesterTests
{
    using Pester;
    using Xunit;

    /// <summary>
    /// Test the test class
    /// </summary>
    public class TestTests
    {
        public readonly Test test;
        public TestTests() => test = new Test();

        [Fact]
        /// <summary>
        /// Test the Test class return item type
        /// </summary>
        public void Test_Test_ShouldReturnItemType()
        {
            Assert.NotNull(test);
            Assert.Equal("Test", test.ItemType);
        }
    }
}
