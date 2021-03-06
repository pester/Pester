namespace PesterTests
{
    using Pester;
    using Xunit;

    /// <summary>
    /// Block Tests
    /// </summary>
    public class BlockTests
    {
        public readonly Block block;
        public BlockTests() => block = new Block();

        [Fact]
        /// <summary>
        /// Test Item Type
        /// </summary>
        public void Test_ItemType_ShouldReturnItemTypeBlock() => Assert.Equal("Block", block.ItemType);

        [Fact]
        /// <summary>
        /// Test Block String
        /// </summary>
        public void Test_ToString_ShouldReturnBlockString()
        {
            block.Result = "test result";
            block.Name = "test name";
            var blockString = block.ToString();

            Assert.Equal("[ERR] test name", blockString);
        }
    }
}
