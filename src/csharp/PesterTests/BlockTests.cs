    using Pester;
    using Xunit;
namespace PesterTests
{
    public class BlockTests
    {
        public readonly Block block;
        public BlockTests() => block = new Block();

        [Fact]
        public void Test_ItemType_ShouldReturnItemTypeBlock() => Assert.Equal("Block", block.ItemType);

        [Fact]
        public void Test_ToString_ShouldReturnBlockString()
        {
            block.Result = "test result";
            block.Name = "test name";
            var blockString = block.ToString();

            Assert.Equal("[ERR] test name", blockString);
        }
    }
}
