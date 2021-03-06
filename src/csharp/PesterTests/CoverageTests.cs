namespace PesterTests
{
    using System.IO;
    using Pester;
    using Xunit;

    /// <summary>
    /// Coverage Tests
    /// </summary>
    public class CoverageTests
    {
        Coverage coverage;

        public CoverageTests()
        {
            coverage = new Coverage();
        }

        [Fact]
        /// <summary>
        /// Test create
        /// </summary>
        public void Test_Create()
        {
            Coverage testCoverage = Coverage.Create();
            Assert.NotNull (testCoverage);
        }

        [Fact]
        /// <summary>
        /// Test Coverage String
        /// </summary>
        public void Test_ToString_ShouldReturnPercentStringForLiteralDecimal()
        {
            coverage.CoveragePercent = 1.000M;

            var coveragePercent = coverage.ToString();
            Assert.Equal("100%", coveragePercent);
        }

        [Fact]
        /// <summary>
        /// Test Coverage String
        /// </summary>
        public void Test_ToString_ShouldReturnPercentStringForTypedDecimal()
        {
            coverage.CoveragePercent = (decimal)1.0;

            var coveragePercent = coverage.ToString();
            Assert.Equal("100%", coveragePercent);
        }

                [Fact]
        /// <summary>
        /// Test Coverage String
        /// </summary>
        public void Test_ToString_ShouldReturnPercentStringForValidDecimal()
        {
            coverage.CoveragePercent = (decimal)1;

            var coveragePercent = coverage.ToString();
            Assert.Equal("100%", coveragePercent);
        }
    }
}
