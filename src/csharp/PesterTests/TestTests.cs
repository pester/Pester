using Pester;
using Xunit;

namespace PesterTests
{
    public class TestTests
    {
        [Fact]
        public void Test_Test_ShouldReturnItemType()
        {
            Test test = new Test();
            Assert.NotNull (test);
            Assert.Equal("Test", test.ItemType);
        }
    }
}
