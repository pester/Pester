using System.Collections;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Pester;

namespace PesterTests
{
    // Covers the strongly-typed Option<T> wrappers (BoolOption, IntOption, StringOption,
    // DecimalOption, StringArrayOption) including their implicit conversions and the
    // IsModified bookkeeping that the configuration merge logic relies on.
    [TestClass]
    public class OptionTests
    {
        [TestMethod]
        public void Option_DefaultConstructor_IsNotModified()
        {
            var option = new BoolOption("desc", defaultValue: false, value: true);

            Assert.IsFalse(option.IsModified);
            Assert.AreEqual("desc", option.Description);
            Assert.IsFalse(option.Default);
            Assert.IsTrue(option.Value);
        }

        [TestMethod]
        public void Option_CopyConstructor_MarksModifiedAndKeepsDefaultAndDescription()
        {
            var original = new BoolOption("desc", defaultValue: false);
            var modified = new BoolOption(original, value: true);

            Assert.IsTrue(modified.IsModified);
            Assert.IsTrue(modified.Value);
            // Default and Description are carried over from the original option.
            Assert.IsFalse(modified.Default);
            Assert.AreEqual("desc", modified.Description);
        }

        [TestMethod]
        public void Option_ToString_UsesDescriptionValueAndDefault()
        {
            var option = new BoolOption("desc", defaultValue: false, value: true);

            Assert.AreEqual("desc (True, default: False)", option.ToString());
        }

        [TestMethod]
        public void BoolOption_ImplicitFromBool_SetsValueAndDefaultAndIsNotModified()
        {
            BoolOption option = true;

            Assert.IsTrue(option.Value);
            Assert.IsTrue(option.Default);
            Assert.IsFalse(option.IsModified);
        }

        [TestMethod]
        public void IntOption_ImplicitFromInt_SetsValueAndDefault()
        {
            IntOption option = 42;

            Assert.AreEqual(42, option.Value);
            Assert.AreEqual(42, option.Default);
            Assert.IsFalse(option.IsModified);
        }

        [TestMethod]
        public void StringOption_ImplicitFromString_SetsValueAndDefault()
        {
            StringOption option = "hello";

            Assert.AreEqual("hello", option.Value);
            Assert.AreEqual("hello", option.Default);
            Assert.IsFalse(option.IsModified);
        }

        [TestMethod]
        public void DecimalOption_ImplicitFromDecimal_SetsValue()
        {
            DecimalOption option = 12.5m;

            Assert.AreEqual(12.5m, option.Value);
            Assert.AreEqual(12.5m, option.Default);
        }

        [TestMethod]
        public void DecimalOption_ImplicitFromInt_ConvertsToDecimal()
        {
            DecimalOption option = 75;

            Assert.AreEqual(75m, option.Value);
            Assert.AreEqual(75m, option.Default);
        }

        [TestMethod]
        public void DecimalOption_ImplicitFromDouble_ConvertsToDecimal()
        {
            DecimalOption option = 75.5d;

            Assert.AreEqual(75.5m, option.Value);
            Assert.AreEqual(75.5m, option.Default);
        }

        [TestMethod]
        public void StringArrayOption_ImplicitFromArray_SetsValue()
        {
            StringArrayOption option = new[] { "a", "b" };

            CollectionAssert.AreEqual(new[] { "a", "b" }, option.Value);
            Assert.IsFalse(option.IsModified);
        }

        [TestMethod]
        public void StringArrayOption_ImplicitFromSingleString_WrapsInArray()
        {
            StringArrayOption option = "only";

            CollectionAssert.AreEqual(new[] { "only" }, option.Value);
        }

        [TestMethod]
        public void StringArrayOption_FromIList_ConvertsEachItemToString()
        {
            var option = new StringArrayOption((IList)new ArrayList { "a", 2, "c" });

            CollectionAssert.AreEqual(new[] { "a", "2", "c" }, option.Value);
        }
    }
}
