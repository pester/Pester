using Pester;
using Xunit;

namespace PesterTests
{
    public class ContainerInfoTests
    {
        [Fact]
        public void Test_Create()
        {
            Container testContainer = Container.Create();
            Assert.NotNull (testContainer);
        }
    }
}
