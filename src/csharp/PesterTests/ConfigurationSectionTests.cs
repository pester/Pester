using System.Collections;
using System.Management.Automation;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Pester;

namespace PesterTests
{
    // Covers ConfigurationSection behaviour (ResolveEnabled auto-enabling and the
    // description ToString) plus the IDictionary-based construction of sections, which
    // exercises the DictionaryExtensions value/object/array conversions.
    [TestClass]
    public class ConfigurationSectionTests
    {
        [TestMethod]
        public void ToString_ReturnsSectionDescription()
        {
            Assert.AreEqual(
                "Options to control the behavior of the Pester's Should assertions.",
                new ShouldConfiguration().ToString());

            Assert.AreEqual(
                "Options to enable and configure Pester's code coverage feature.",
                new CodeCoverageConfiguration().ToString());
        }

        [TestMethod]
        public void ResolveEnabled_DoesNothingWhenNoOtherOptionModified()
        {
            var section = new CodeCoverageConfiguration();

            section.ResolveEnabled();

            Assert.IsFalse(section.Enabled.Value);
            Assert.IsFalse(section.Enabled.IsModified);
        }

        [TestMethod]
        public void ResolveEnabled_AutoEnablesWhenAnotherOptionModified()
        {
            var section = new CodeCoverageConfiguration();
            section.Path = new[] { "src" };

            section.ResolveEnabled();

            Assert.IsTrue(section.Enabled.Value);
            Assert.IsTrue(section.Enabled.IsModified);
        }

        [TestMethod]
        public void ResolveEnabled_DoesNotOverrideExplicitlySetEnabled()
        {
            var section = new CodeCoverageConfiguration();
            section.Enabled = false;      // explicitly set -> marked modified
            section.Path = new[] { "src" }; // another modified option

            section.ResolveEnabled();

            // Enabled was explicitly modified, so it must be left as-is.
            Assert.IsFalse(section.Enabled.Value);
        }

        [TestMethod]
        public void Section_Setter_MarksOptionAsModified()
        {
            var section = new ShouldConfiguration();
            Assert.IsFalse(section.ErrorAction.IsModified);

            section.ErrorAction = "Continue";

            Assert.IsTrue(section.ErrorAction.IsModified);
            Assert.AreEqual("Continue", section.ErrorAction.Value);
            // The default is preserved even after modification.
            Assert.AreEqual("Stop", section.ErrorAction.Default);
        }

        [TestMethod]
        public void Construct_FromEmptyHashtable_KeepsDefaultsUnmodified()
        {
            var section = new CodeCoverageConfiguration(new Hashtable());

            Assert.AreEqual("JaCoCo", section.OutputFormat.Value);
            Assert.IsFalse(section.OutputFormat.IsModified);
            Assert.IsFalse(section.Enabled.IsModified);
        }

        [TestMethod]
        public void Construct_FromHashtable_AssignsBoolOption()
        {
            var section = new CodeCoverageConfiguration(new Hashtable { ["Enabled"] = true });

            Assert.IsTrue(section.Enabled.Value);
            Assert.IsTrue(section.Enabled.IsModified);
        }

        [TestMethod]
        public void Construct_FromHashtable_ConvertsIntToDecimal()
        {
            var section = new CodeCoverageConfiguration(new Hashtable { ["CoveragePercentTarget"] = 50 });

            Assert.AreEqual(50m, section.CoveragePercentTarget.Value);
            Assert.IsTrue(section.CoveragePercentTarget.IsModified);
        }

        [TestMethod]
        public void Construct_FromHashtable_ConvertsDoubleToDecimal()
        {
            var section = new CodeCoverageConfiguration(new Hashtable { ["CoveragePercentTarget"] = 50.5d });

            Assert.AreEqual(50.5m, section.CoveragePercentTarget.Value);
        }

        [TestMethod]
        public void Construct_FromHashtable_AcceptsDecimalDirectly()
        {
            var section = new CodeCoverageConfiguration(new Hashtable { ["CoveragePercentTarget"] = 60m });

            Assert.AreEqual(60m, section.CoveragePercentTarget.Value);
        }

        [TestMethod]
        public void Construct_FromHashtable_ConvertsPSObjectToString()
        {
            var section = new ShouldConfiguration(new Hashtable
            {
                ["ErrorAction"] = PSObject.AsPSObject("Continue"),
            });

            Assert.AreEqual("Continue", section.ErrorAction.Value);
            Assert.IsTrue(section.ErrorAction.IsModified);
        }

        [TestMethod]
        public void Construct_FromHashtable_AcceptsStringArray()
        {
            var section = new CodeCoverageConfiguration(new Hashtable
            {
                ["Path"] = new[] { "a", "b" },
            });

            CollectionAssert.AreEqual(new[] { "a", "b" }, section.Path.Value);
            Assert.IsTrue(section.Path.IsModified);
        }

        [TestMethod]
        public void Construct_FromHashtable_ConvertsObjectListToStringArray()
        {
            var section = new CodeCoverageConfiguration(new Hashtable
            {
                ["Path"] = new object[] { "a", "b" },
            });

            CollectionAssert.AreEqual(new[] { "a", "b" }, section.Path.Value);
        }
    }
}
