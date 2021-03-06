namespace PesterTests
{
    using System;
    using System.Collections.Generic;
    using System.Management.Automation;
    using Pester;
    using Xunit;

    /// <summary>
    /// Invocation Result Tests
    /// </summary>
    public class InvocationResultTests
    {
        public readonly InvocationResult invocationResult;

        public InvocationResultTests()
        {
            var success = true;
            var errorRecords = new List<ErrorRecord>();
            var standardOutput = new Object();

            InvocationResult testInvocationResult =
                new InvocationResult(success, errorRecords, standardOutput);
            Assert.NotNull (testInvocationResult);
        }

        [Fact]
        /// <summary>
        /// Test create
        /// </summary>
        public void Test_Create()
        {
            var success = true;
            var errorRecord = new List<ErrorRecord>();
            var standardOutput = new Object();

            InvocationResult testInvocationResult =
                InvocationResult.Create(success, errorRecord, standardOutput);
            Assert.NotNull (testInvocationResult);
        }
    }
}
