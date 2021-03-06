namespace PesterTests
{
    using Pester;
    using Xunit;

    /// <summary>
    /// Container Info Tests
    /// </summary>
    public class ContainerInfoTests
    {
        [Fact]
        /// <summary>
        /// Test create
        /// </summary>
        public void Test_Create()
        {
            Container testContainer = Container.Create();
            Assert.NotNull(testContainer);
        }
    }
}
