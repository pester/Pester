using System;
using System.Collections.Generic;
using System.Text;
using Pester.DiffPlex;
using Pester.DiffPlex.Chunkers;
using Pester.DiffPlex.DiffBuilder;
using Pester.DiffPlex.DiffBuilder.Model;

namespace Pester
{
    /// <summary>
    /// The outcome of comparing two strings line by line. Internal, the only thing Pester exposes
    /// is <see cref="StringDiff.Format"/>, which turns this into the text of a failure message.
    /// </summary>
    internal sealed class StringDiffResult
    {
        public int ExpectedLineCount { get; set; }
        public int ActualLineCount { get; set; }
        /// <summary>How many separate regions differ, counting the ones that were not printed.</summary>
        public int RegionCount { get; set; }
        /// <summary>How many regions <see cref="Diff"/> actually contains.</summary>
        public int ShownRegionCount { get; set; }
        /// <summary>Every line has the same text and only the line endings are different.</summary>
        public bool OnlyLineEndingsDiffer { get; set; }
        public string Diff { get; set; }
    }

    /// <summary>
    /// Compares two strings line by line and renders the regions that differ. A first differing
    /// line scan answers "one thing changed", this answers "many things changed", which is what
    /// comparing a whole generated file against an expected copy needs.
    /// </summary>
    public static class StringDiff
    {
        /// <summary>
        /// Compares two strings line by line and returns the part of the failure message that
        /// describes how they differ: the line counts, how many regions differ, and the regions
        /// themselves with their context.
        ///
        /// This is the only thing Pester exposes from the diffing. Everything under
        /// Pester.DiffPlex is internal, so the vendored library is not part of Pester's API and
        /// can be updated or replaced without that being a breaking change.
        /// </summary>
        public static string Format(string expected, string actual, bool caseSensitive, int context, int maxRegions)
        {
            var result = Compare(expected, actual, caseSensitive, context, maxRegions);
            var lines = new List<string>
            {
                "Expected " + result.ExpectedLineCount + " line(s), actual " + result.ActualLineCount + " line(s).",
            };

            if (result.RegionCount == 0)
            {
                return string.Join(Environment.NewLine, lines.ToArray());
            }

            if (result.OnlyLineEndingsDiffer)
            {
                // Printing the lines here would show two blocks that look identical, because what
                // differs is not in the text.
                lines.Add("Every line is the same, only the line endings differ.");
                lines.Add("Expected: " + DescribeLineEndings(expected));
                lines.Add("But was:  " + DescribeLineEndings(actual));
                lines.Add("Use -NormalizeLineEnding to ignore this.");
            }

            lines.Add(result.RegionCount == 1
                ? "1 region differs."
                : result.ShownRegionCount < result.RegionCount
                    ? result.RegionCount + " regions differ, showing the first " + result.ShownRegionCount + "."
                    : result.RegionCount + " regions differ.");

            lines.Add(string.Empty);
            lines.Add(result.Diff);

            if (result.ShownRegionCount < result.RegionCount)
            {
                lines.Add("  ...");
                lines.Add("  " + (result.RegionCount - result.ShownRegionCount) + " more region(s) differ, not shown.");
            }

            return string.Join(Environment.NewLine, lines.ToArray());
        }

        // ignoreWhitespace has to stay false. Its default in DiffPlex is true, and with it a
        // difference that is only a trailing space is reported as no difference at all.
        private const bool IgnoreWhitespace = false;

        // LineEndingsPreservingChunker instead of the default LineChunker. The default one splits
        // the endings off and throws them away, so CRLF against LF comes out as two identical
        // strings, which is the one difference the reader cannot work out on their own.
        private static readonly SideBySideDiffBuilder Builder =
            new SideBySideDiffBuilder(new Differ(), new LineEndingsPreservingChunker(), new WordChunker());

        internal static StringDiffResult Compare(string expected, string actual, bool caseSensitive, int context, int maxRegions)
        {
            if (expected == null) { expected = string.Empty; }
            if (actual == null) { actual = string.Empty; }

            var model = Builder.BuildDiffModel(expected, actual, IgnoreWhitespace, !caseSensitive);
            var oldLines = model.OldText.Lines;
            var newLines = model.NewText.Lines;
            int rows = Math.Max(oldLines.Count, newLines.Count);

            var result = new StringDiffResult
            {
                ExpectedLineCount = CountRealLines(model.OldText),
                ActualLineCount = CountRealLines(model.NewText),
            };

            var changedRows = new List<int>();
            bool anyTextChange = false;
            bool anyEndingChange = false;

            for (int i = 0; i < rows; i++)
            {
                var oldLine = At(oldLines, i);
                var newLine = At(newLines, i);
                if (BothUnchanged(oldLine, newLine)) { continue; }

                changedRows.Add(i);

                // Only two real lines can differ by their ending alone. An inserted blank line pairs
                // an Imaginary placeholder against "\n", which has the same empty text, and counting
                // that as an ending change turns the ending markers on for the whole message.
                bool bothReal = IsReal(oldLine) && IsReal(newLine);
                if (bothReal && TextOf(oldLine) == TextOf(newLine) && EndingOf(oldLine) != EndingOf(newLine))
                {
                    anyEndingChange = true;
                }
                else
                {
                    anyTextChange = true;
                }
            }

            result.OnlyLineEndingsDiffer = anyEndingChange && !anyTextChange;

            if (changedRows.Count == 0)
            {
                result.Diff = string.Empty;
                return result;
            }

            var regions = GroupIntoRegions(changedRows, context, rows);
            result.RegionCount = regions.Count;
            result.ShownRegionCount = Math.Min(regions.Count, maxRegions);

            // Line endings are only spelled out when they are part of what changed. Printing them on
            // every line turns a readable diff into a wall of escape codes.
            bool showEndings = anyEndingChange;
            int width = Math.Max(result.ExpectedLineCount, result.ActualLineCount).ToString().Length;
            var sb = new StringBuilder();

            for (int r = 0; r < result.ShownRegionCount; r++)
            {
                if (r > 0)
                {
                    sb.Append("  ").Append('.', Math.Max(3, width)).Append(Environment.NewLine);
                }

                for (int i = regions[r].Start; i <= regions[r].End; i++)
                {
                    var oldLine = At(oldLines, i);
                    var newLine = At(newLines, i);

                    if (BothUnchanged(oldLine, newLine))
                    {
                        AppendRow(sb, width, ' ', Position(oldLine), Position(newLine), Render(oldLine, false, showEndings));
                        continue;
                    }

                    if (IsReal(oldLine))
                    {
                        AppendRow(sb, width, '-', Position(oldLine), null, Render(oldLine, true, showEndings));
                    }

                    if (IsReal(newLine))
                    {
                        AppendRow(sb, width, '+', null, Position(newLine), Render(newLine, true, showEndings));
                    }
                }
            }

            result.Diff = sb.ToString().TrimEnd('\r', '\n');
            return result;
        }

        private struct Region
        {
            public int Start;
            public int End;
        }

        private static List<Region> GroupIntoRegions(List<int> changedRows, int context, int rows)
        {
            var regions = new List<Region>();
            int start = changedRows[0];
            int end = changedRows[0];

            for (int i = 1; i < changedRows.Count; i++)
            {
                // Two changed rows whose context windows would touch belong to the same region,
                // otherwise the output puts a separator between two lines that are one apart.
                if (changedRows[i] - end <= context * 2 + 1)
                {
                    end = changedRows[i];
                }
                else
                {
                    regions.Add(new Region { Start = start, End = end });
                    start = end = changedRows[i];
                }
            }

            regions.Add(new Region { Start = start, End = end });

            for (int i = 0; i < regions.Count; i++)
            {
                regions[i] = new Region
                {
                    Start = Math.Max(0, regions[i].Start - context),
                    End = Math.Min(rows - 1, regions[i].End + context),
                };
            }

            return regions;
        }

        private static void AppendRow(StringBuilder sb, int width, char marker, int? expectedLine, int? actualLine, string text)
        {
            sb.Append("  ")
              .Append(Number(expectedLine, width))
              .Append(' ')
              .Append(Number(actualLine, width))
              .Append(" | ")
              .Append(marker)
              .Append(' ')
              .Append(text)
              .Append(Environment.NewLine);
        }

        private static string Number(int? line, int width)
        {
            return line.HasValue ? line.Value.ToString().PadLeft(width) : new string(' ', width);
        }

        private static DiffPiece At(IList<DiffPiece> lines, int i)
        {
            return i < lines.Count ? lines[i] : null;
        }

        private static bool IsReal(DiffPiece piece)
        {
            return piece != null && piece.Type != ChangeType.Imaginary;
        }

        private static bool BothUnchanged(DiffPiece a, DiffPiece b)
        {
            return a != null && b != null && a.Type == ChangeType.Unchanged && b.Type == ChangeType.Unchanged;
        }

        private static int? Position(DiffPiece piece)
        {
            return IsReal(piece) ? piece.Position : null;
        }

        private static int CountRealLines(DiffPaneModel pane)
        {
            int count = 0;
            foreach (var line in pane.Lines)
            {
                if (line.Type != ChangeType.Imaginary) { count++; }
            }

            return count;
        }

        private static string TextOf(DiffPiece piece)
        {
            string value = piece == null ? string.Empty : (piece.Text ?? string.Empty);
            int end = value.Length;
            while (end > 0 && (value[end - 1] == '\n' || value[end - 1] == '\r')) { end--; }

            return value.Substring(0, end);
        }

        private static string EndingOf(DiffPiece piece)
        {
            string value = piece == null ? string.Empty : (piece.Text ?? string.Empty);
            return value.Substring(TextOf(piece).Length);
        }

        private static string Render(DiffPiece piece, bool changed, bool showEndings)
        {
            string text = TextOf(piece);

            // Only the lines that differ are expanded. A trailing space or a stray CR has to be
            // visible, but doing it to the context lines as well makes all of them harder to read.
            if (!changed) { return text; }

            text = Formatter.EscapeControlChars(text);

            int lastNonSpace = text.Length;
            while (lastNonSpace > 0 && text[lastNonSpace - 1] == ' ') { lastNonSpace--; }
            if (lastNonSpace < text.Length)
            {
                // A space is not a control character so EscapeControlChars leaves it alone, and a
                // trailing one is exactly the difference nobody can see.
                text = text.Substring(0, lastNonSpace) + new string('·', text.Length - lastNonSpace);
            }

            if (showEndings)
            {
                text += Formatter.EscapeControlChars(EndingOf(piece));
            }

            return text;
        }

        /// <summary>
        /// Counts the line endings on each side, for the message that says the text is the same and
        /// only the endings differ.
        /// </summary>
        internal static string DescribeLineEndings(string value)
        {
            if (value == null) { value = string.Empty; }

            int crlf = 0, cr = 0, lf = 0;
            for (int i = 0; i < value.Length; i++)
            {
                if (value[i] == '\r')
                {
                    if (i + 1 < value.Length && value[i + 1] == '\n') { crlf++; i++; }
                    else { cr++; }
                }
                else if (value[i] == '\n')
                {
                    lf++;
                }
            }

            var parts = new List<string>();
            if (crlf > 0) { parts.Add(crlf + " CRLF"); }
            if (cr > 0) { parts.Add(cr + " CR"); }
            if (lf > 0) { parts.Add(lf + " LF"); }

            return parts.Count == 0 ? "no line endings" : string.Join(", ", parts.ToArray());
        }
    }
}
