using Xunit;
using Pester;

namespace PesterTests
{
    public class CoverageTests
    {
        public readonly CodeCoverage coverage;

        public CoverageTests()
        {
            coverage = new CodeCoverage();
        }

        [Fact]
        public void Test_Create()
        {
            CodeCoverage testCoverage = CodeCoverage.Create();
            Assert.NotNull(testCoverage);
        }

        [Fact]
        public void Test_ToString_ShouldReturnPercentStringForLiteralDecimal()
        {
            coverage.CoveragePercent = 1.000M;

            var coveragePercent = coverage.ToString();
            Assert.Equal("1% / 0%", coveragePercent);
        }

        [Fact]
        public void Test_ToString_ShouldReturnPercentStringForTypedDecimal()
        {
            coverage.CoveragePercent = (decimal)1.0;

            var coveragePercent = coverage.ToString();
            Assert.Equal("1% / 0%", coveragePercent);
        }

        [Fact]
        public void Test_ToString_ShouldReturnPercentStringForValidDecimal()
        {
            coverage.CoveragePercent = (decimal)1;

            var coveragePercent = coverage.ToString();
            Assert.Equal("1% / 0%", coveragePercent);
        }
    }
}
