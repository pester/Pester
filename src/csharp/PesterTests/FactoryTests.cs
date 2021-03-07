using Pester;
using Xunit;

namespace PesterTests
{
    /// <summary>
    /// Factory Tests
    /// TODO test implementations
    /// </summary>
    public class FactoryTests
    {
        [Fact]
        public void Test_CreateNoteProperty()
        {
            var name = "test";
            var value = "test";

            var actual = Factory.CreateNoteProperty(name, value);
        }

        [Fact]
        public void Test_CreateDictionary()
        {
            var actual = Factory.CreateDictionary();
        }

        [Fact]
        public void Test_CreateRuntimeDefinedParameterDictionary()
        {
            var actual = Factory.CreateDictionary();
        }

        [Fact]
        public void Test_CreateCollection()
        {
            var actual = Factory.CreateCollection();
        }

        [Fact]
        public void Test_CreateShouldErrorRecord()
        {
            string message = null;
            string file = null;
            string line = null;
            string lineText = null;
            bool terminating = false;

            var actual =
                Factory
                    .CreateShouldErrorRecord(message,
                    file,
                    line,
                    lineText,
                    terminating);
        }

        [Fact]
        public void Test_CreateErrorRecord()
        {
            string errorId = null;
            string message = null;
            string file = null;
            string line = null;
            string lineText = null;
            bool terminating = false;

            var actual =
                Factory
                    .CreateErrorRecord(errorId,
                    message,
                    file,
                    line,
                    lineText,
                    terminating);
        }
    }
}
