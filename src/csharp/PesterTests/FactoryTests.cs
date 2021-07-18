using Pester;
using System.Management.Automation;
using Xunit;

namespace PesterTests
{
    public class FactoryTests
    {
        [Fact]
        public void Test_CreateNoteProperty()
        {
            var name = "test";
            var value = "test";

            var actual = Factory.CreateNoteProperty(name, value);
            Assert.IsType<PSNoteProperty>(actual);
            Assert.Equal(name, actual.Name);
            Assert.Equal(value, actual.Value);
        }
    }
}