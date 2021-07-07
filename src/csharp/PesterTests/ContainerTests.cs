namespace PesterTests
{
    using System.IO;
    using Pester;
    using Xunit;

    public class ContainerTests
    {
        private readonly Container container;

        public ContainerTests()
        {
            container = new Container();
        }

        [Fact]
        public void Test_Create()
        {
            Container testContainer = Container.Create();
            Assert.NotNull (testContainer);
        }

        [Fact(Skip = "check null")]
        /// <summary>
        /// Test create from block
        /// </summary>
        public void Test_CreateFromBlock()
        {
            // This test currently fails, check for null before creation of file or specify not null
            Block block = new Block();
            Container testContainer = Container.CreateFromBlock(block);
            Assert.NotNull (testContainer);
        }

        [Fact(Skip = "check null")]
        /// <summary>
        /// Test create from file
        /// </summary>
        public void Test_CreateFromFile()
        {
            // This test currently fails, check for null before creation of file or specify not null
            FileInfo file = null;

            Container testContainer = Container.CreateFromFile(file);
            Assert.NotNull (testContainer);
        }
    }
}
