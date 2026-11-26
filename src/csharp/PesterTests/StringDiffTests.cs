using System;
using System.Diagnostics;
using System.Text;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Pester;

namespace PesterTests
{
    // Covers the line diffing behind Should-BeString: how many regions it finds, how the regions
    // are grouped and capped, and the cases where the difference is not visible in the text
    // (trailing whitespace, tabs, line endings).
    [TestClass]
    public class StringDiffTests
    {
        private const int Context = 2;
        private const int MaxRegions = 5;

        private static StringDiffResult Compare(string expected, string actual)
        {
            return StringDiff.Compare(expected, actual, caseSensitive: true, context: Context, maxRegions: MaxRegions);
        }

        private static string Lines(params string[] lines)
        {
            return string.Join("\n", lines);
        }

        [TestMethod]
        public void EqualStrings_HaveNoRegions()
        {
            var result = Compare(Lines("a", "b", "c"), Lines("a", "b", "c"));

            Assert.AreEqual(0, result.RegionCount);
            Assert.AreEqual(string.Empty, result.Diff);
        }

        [TestMethod]
        public void SeparateChanges_AreReportedAsSeparateRegions()
        {
            // This is the whole point of the diff. A first differing line scan stops at the first
            // one, and comparing a snapshot usually means several things changed at once.
            var expected = Lines("1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12");
            var actual = Lines("1", "2", "CHANGED", "4", "5", "6", "7", "8", "9", "CHANGED", "11", "12");

            var result = Compare(expected, actual);

            Assert.AreEqual(2, result.RegionCount);
            Assert.AreEqual(2, result.ShownRegionCount);
            StringAssert.Contains(result.Diff, "- 3");
            StringAssert.Contains(result.Diff, "+ CHANGED");
            StringAssert.Contains(result.Diff, "- 10");
        }

        [TestMethod]
        public void ChangesCloseTogether_AreOneRegion()
        {
            // Two changes whose context windows touch belong together, otherwise the output puts a
            // separator between two lines that are one apart.
            var expected = Lines("1", "2", "3", "4", "5", "6", "7", "8");
            var actual = Lines("1", "X", "3", "Y", "5", "6", "7", "8");

            Assert.AreEqual(1, Compare(expected, actual).RegionCount);
        }

        [TestMethod]
        public void MoreRegionsThanTheCap_AreCountedButNotAllRendered()
        {
            var expected = new StringBuilder();
            var actual = new StringBuilder();
            for (int i = 1; i <= 120; i++)
            {
                expected.Append("setting").Append(i).Append(" = ").Append(i * 10).Append('\n');
                actual.Append("setting").Append(i).Append(" = ").Append(i % 10 == 3 ? i * 10 + 1 : i * 10).Append('\n');
            }

            var result = Compare(expected.ToString(), actual.ToString());

            Assert.AreEqual(12, result.RegionCount);
            Assert.AreEqual(MaxRegions, result.ShownRegionCount);
            Assert.IsFalse(result.Diff.Contains("setting53"), "a region past the cap was rendered");
        }

        [TestMethod]
        public void AddedLines_KeepBothSidesLineNumbers()
        {
            var expected = Lines("a", "b", "c");
            var actual = Lines("a", "new", "b", "c");

            var result = Compare(expected, actual);

            Assert.AreEqual(3, result.ExpectedLineCount);
            Assert.AreEqual(4, result.ActualLineCount);
            StringAssert.Contains(result.Diff, "+ new");
        }

        [TestMethod]
        public void TrailingSpace_IsMadeVisible()
        {
            // ignoreWhitespace defaults to true in DiffPlex, and with it this comparison finds
            // nothing at all. A regression here is silent, which is why it is tested.
            var result = Compare(Lines("value", "next"), Lines("value   ", "next"));

            Assert.AreEqual(1, result.RegionCount);
            StringAssert.Contains(result.Diff, "+ value" + new string('·', 3));
        }

        [TestMethod]
        public void Tab_IsMadeVisible()
        {
            var result = Compare(Lines("  indented", "next"), Lines("\tindented", "next"));

            StringAssert.Contains(result.Diff, "+ ␉indented");
        }

        [TestMethod]
        public void LineEndingsOnly_AreReportedAsSuch()
        {
            // The default line chunker throws the endings away, which makes this comparison come
            // back as two identical strings.
            var result = Compare("alpha\r\nbeta\r\ngamma\r\n", "alpha\nbeta\ngamma\n");

            Assert.IsTrue(result.OnlyLineEndingsDiffer);
            Assert.AreEqual(3, result.ExpectedLineCount);
            StringAssert.Contains(result.Diff, "- alpha␍␊");
            StringAssert.Contains(result.Diff, "+ alpha␊");
        }

        [TestMethod]
        public void InsertedBlankLine_IsNotALineEndingChange()
        {
            // An inserted blank line pairs an Imaginary placeholder against "\n", which has the same
            // empty text. Counting that as an ending change turns the ending markers on for the
            // whole message.
            var result = Compare(Lines("a", "b"), Lines("a", "", "b"));

            Assert.IsFalse(result.OnlyLineEndingsDiffer);
            Assert.IsFalse(result.Diff.Contains("␊"), "line ending markers were switched on");
        }

        [TestMethod]
        public void TextAndLineEndingsBothDiffer_IsNotReportedAsLineEndingsOnly()
        {
            var result = Compare("alpha\r\nbeta\r\n", "alpha\nCHANGED\n");

            Assert.IsFalse(result.OnlyLineEndingsDiffer);
        }

        [TestMethod]
        public void CaseSensitivity_IsHonoured()
        {
            Assert.AreEqual(1, StringDiff.Compare("Alpha", "alpha", true, Context, MaxRegions).RegionCount);
            Assert.AreEqual(0, StringDiff.Compare("Alpha", "alpha", false, Context, MaxRegions).RegionCount);
        }

        [TestMethod]
        public void NullInput_IsTreatedAsEmpty()
        {
            Assert.AreEqual(0, Compare(null, null).RegionCount);
            Assert.AreEqual(1, Compare(null, "a").RegionCount);
        }

        [TestMethod]
        public void OneDifferenceInATenThousandLineFile_IsFastAndShort()
        {
            // The case from #2951. If this ever becomes slow the comparison is no longer stripping
            // the matching head and tail before diffing.
            var expected = new StringBuilder();
            var actual = new StringBuilder();
            for (int i = 1; i <= 10000; i++)
            {
                expected.Append("line ").Append(i).Append('\n');
                actual.Append("line ").Append(i == 6371 ? "changed" : i.ToString()).Append('\n');
            }

            var stopwatch = Stopwatch.StartNew();
            var result = Compare(expected.ToString(), actual.ToString());
            stopwatch.Stop();

            Assert.AreEqual(1, result.RegionCount);
            // Six lines: the differing pair and two lines of context either side.
            Assert.AreEqual(6, result.Diff.Split('\n').Length);
            Assert.IsTrue(stopwatch.ElapsedMilliseconds < 2000,
                "comparing 10 000 lines took " + stopwatch.ElapsedMilliseconds + " ms");
        }

        [TestMethod]
        [DataRow("a\r\nb\r\n", "2 CRLF")]
        [DataRow("a\nb\n", "2 LF")]
        [DataRow("a\rb\r", "2 CR")]
        [DataRow("a\r\nb\n", "1 CRLF, 1 LF")]
        [DataRow("abc", "no line endings")]
        public void DescribeLineEndings_NamesWhatIsThere(string value, string expected)
        {
            Assert.AreEqual(expected, StringDiff.DescribeLineEndings(value));
        }
    }
}
