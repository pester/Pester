namespace PesterTests
{
    using Pester;
    using Xunit;

    /// <summary>
    /// Factory Tests
    /// TODO test implementations
    /// </summary>
    public class FactoryTests
    {
        [Fact]
        /// <summary>
        /// Test CreateNoteProperty
        /// </summary>
        public void Test_CreateNoteProperty()
        {
            var name = "test";
            var value = "test";

            var actual = Factory.CreateNoteProperty(name, value);
        }

        [Fact]
        /// <summary>
        /// Test CreateNoteProperty
        /// </summary>
        public void Test_CreateDictionary()
        {
            var actual = Factory.CreateDictionary();
        }

        [Fact]
        /// <summary>
        /// Test CreateRuntimeDefinedParameterDictionary
        /// </summary>
        public void Test_CreateRuntimeDefinedParameterDictionary()
        {
            var actual = Factory.CreateDictionary();
        }

        [Fact]
        /// <summary>
        /// Test CreateCollection
        /// </summary>
        public void Test_CreateCollection()
        {
            var actual = Factory.CreateCollection();
        }

        [Fact]
        /// <summary>
        /// Test CreateShouldErrorRecord
        /// </summary>
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
        /// <summary>
        /// Test CreateErrorRecord
        /// </summary>
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
