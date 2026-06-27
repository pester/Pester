using System.Collections;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Pester;

namespace PesterTests
{
    // Covers the top-level PesterConfiguration: default construction, building from a
    // hashtable (the cast-from-hashtable behaviour used from PowerShell), ShallowClone
    // and Merge (which in turn exercise Cloner and Merger).
    [TestClass]
    public class PesterConfigurationTests
    {
        [TestMethod]
        public void Default_CreatesAllSections()
        {
            var config = PesterConfiguration.Default;

            Assert.IsNotNull(config.Run);
            Assert.IsNotNull(config.Filter);
            Assert.IsNotNull(config.CodeCoverage);
            Assert.IsNotNull(config.TestResult);
            Assert.IsNotNull(config.Should);
            Assert.IsNotNull(config.Debug);
            Assert.IsNotNull(config.Output);
            Assert.IsNotNull(config.TestDrive);
            Assert.IsNotNull(config.TestRegistry);
        }

        [TestMethod]
        public void Default_ReturnsFreshInstanceEachTime()
        {
            Assert.AreNotSame(PesterConfiguration.Default, PesterConfiguration.Default);
        }

        [TestMethod]
        public void Default_HasExpectedDefaultsThatAreNotModified()
        {
            var config = PesterConfiguration.Default;

            Assert.AreEqual("Stop", config.Should.ErrorAction.Value);
            Assert.IsFalse(config.Should.ErrorAction.IsModified);

            Assert.IsFalse(config.CodeCoverage.Enabled.Value);
            Assert.IsFalse(config.CodeCoverage.Enabled.IsModified);
            Assert.AreEqual("JaCoCo", config.CodeCoverage.OutputFormat.Value);
            Assert.AreEqual(75m, config.CodeCoverage.CoveragePercentTarget.Value);
        }

        [TestMethod]
        public void Construct_FromHashtable_PopulatesNestedSections()
        {
            var hashtable = new Hashtable
            {
                ["Should"] = new Hashtable { ["ErrorAction"] = "Continue" },
                ["CodeCoverage"] = new Hashtable
                {
                    ["Enabled"] = true,
                    ["CoveragePercentTarget"] = 90,
                },
            };

            var config = new PesterConfiguration(hashtable);

            Assert.AreEqual("Continue", config.Should.ErrorAction.Value);
            Assert.IsTrue(config.Should.ErrorAction.IsModified);

            Assert.IsTrue(config.CodeCoverage.Enabled.Value);
            Assert.IsTrue(config.CodeCoverage.Enabled.IsModified);
            Assert.AreEqual(90m, config.CodeCoverage.CoveragePercentTarget.Value);
        }

        [TestMethod]
        public void Construct_FromHashtable_LeavesUnspecifiedOptionsAtDefault()
        {
            var hashtable = new Hashtable
            {
                ["CodeCoverage"] = new Hashtable { ["Enabled"] = true },
            };

            var config = new PesterConfiguration(hashtable);

            // OutputFormat was not specified, so it stays the default and unmodified.
            Assert.AreEqual("JaCoCo", config.CodeCoverage.OutputFormat.Value);
            Assert.IsFalse(config.CodeCoverage.OutputFormat.IsModified);
        }

        [TestMethod]
        public void ShallowClone_CopiesValuesAndModifiedState()
        {
            var source = PesterConfiguration.Default;
            source.Should.ErrorAction = "Continue";

            var clone = PesterConfiguration.ShallowClone(source);

            Assert.AreNotSame(source.Should, clone.Should);
            Assert.AreEqual("Continue", clone.Should.ErrorAction.Value);
            Assert.IsTrue(clone.Should.ErrorAction.IsModified);
        }

        [TestMethod]
        public void ShallowClone_ProducesIndependentSections()
        {
            var source = PesterConfiguration.Default;
            source.Should.ErrorAction = "Continue";

            var clone = PesterConfiguration.ShallowClone(source);
            clone.Should.ErrorAction = "Stop";

            // Mutating the clone must not change the source.
            Assert.AreEqual("Continue", source.Should.ErrorAction.Value);
            Assert.AreEqual("Stop", clone.Should.ErrorAction.Value);
        }

        [TestMethod]
        public void Merge_OverrideWinsWhenBothModified()
        {
            var baseConfig = PesterConfiguration.Default;
            baseConfig.CodeCoverage.OutputFormat = "JaCoCo";

            var overrideConfig = PesterConfiguration.Default;
            overrideConfig.CodeCoverage.OutputFormat = "Cobertura";

            var merged = PesterConfiguration.Merge(baseConfig, overrideConfig);

            Assert.AreEqual("Cobertura", merged.CodeCoverage.OutputFormat.Value);
        }

        [TestMethod]
        public void Merge_KeepsBaseValueWhenOverrideUnmodified()
        {
            var baseConfig = PesterConfiguration.Default;
            baseConfig.Should.ErrorAction = "Continue";

            var overrideConfig = PesterConfiguration.Default; // ErrorAction left at default

            var merged = PesterConfiguration.Merge(baseConfig, overrideConfig);

            Assert.AreEqual("Continue", merged.Should.ErrorAction.Value);
            Assert.IsTrue(merged.Should.ErrorAction.IsModified);
        }

        [TestMethod]
        public void Merge_TakesOverrideValueWhenOnlyOverrideModified()
        {
            var baseConfig = PesterConfiguration.Default; // DisableV5 left at default (false)

            var overrideConfig = PesterConfiguration.Default;
            overrideConfig.Should.DisableV5 = true;

            var merged = PesterConfiguration.Merge(baseConfig, overrideConfig);

            Assert.IsTrue(merged.Should.DisableV5.Value);
            Assert.IsTrue(merged.Should.DisableV5.IsModified);
        }

        [TestMethod]
        public void Merge_LeavesUntouchedOptionAtDefaultAndUnmodified()
        {
            var merged = PesterConfiguration.Merge(PesterConfiguration.Default, PesterConfiguration.Default);

            Assert.IsFalse(merged.Should.DisableV5.Value);
            Assert.IsFalse(merged.Should.DisableV5.IsModified);
        }
    }
}
