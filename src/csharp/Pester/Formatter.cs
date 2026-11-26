using System;
using System.Text;

namespace Pester
{
    public static class Formatter
    {
        private static readonly char[] ControlChars = BuildControlChars();

        private static char[] BuildControlChars()
        {
            // C0 controls (0x00..0x1F), DEL (0x7F) and the C1 controls (0x80..0x9F).
            // C1 includes single-byte ANSI controls such as NEL (0x85) and CSI (0x9B)
            // that are otherwise invisible in output.
            var chars = new char[0x20 + 1 + 0x20];
            int idx = 0;
            for (int i = 0x00; i <= 0x1F; i++)
            {
                chars[idx++] = (char)i;
            }
            chars[idx++] = (char)0x7F;
            for (int i = 0x80; i <= 0x9F; i++)
            {
                chars[idx++] = (char)i;
            }
            return chars;
        }

        /// <summary>
        /// Makes invisible control characters in <paramref name="value"/> visible so
        /// they show up in error messages. See
        /// https://github.com/pester/Pester/issues/2561.
        ///
        /// C0 controls (0x00..0x1F) are replaced with the matching Unicode "Control
        /// Pictures" code point (U+2400..U+241F) and DEL (0x7F) with U+2421. The C1
        /// controls (0x80..0x9F) have no picture glyph, so they are rendered as an
        /// explicit "\u00XX" escape.
        ///
        /// Returns <paramref name="value"/> unchanged when it is null, empty, or
        /// contains no control characters — common case, no allocation beyond
        /// the IndexOfAny scan.
        /// </summary>
        public static string EscapeControlChars(string value)
        {
            if (string.IsNullOrEmpty(value))
            {
                return value;
            }

            int firstControl = value.IndexOfAny(ControlChars);
            if (firstControl < 0)
            {
                return value;
            }

            int len = value.Length;
            var sb = new StringBuilder(len + 8);
            // Everything before firstControl is known to be safe; copy it verbatim.
            sb.Append(value, 0, firstControl);

            for (int i = firstControl; i < len; i++)
            {
                char c = value[i];
                if (c <= 0x1F)
                {
                    // C0 controls -> Unicode Control Pictures.
                    sb.Append((char)(c + 0x2400));
                }
                else if (c == 0x7F)
                {
                    // DEL -> SYMBOL FOR DELETE.
                    sb.Append('\u2421');
                }
                else if (c >= 0x80 && c <= 0x9F)
                {
                    // C1 controls have no picture glyph; show an explicit escape.
                    sb.Append("\\u").Append(((int)c).ToString("X4"));
                }
                else
                {
                    sb.Append(c);
                }
            }

            return sb.ToString();
        }
    }
}
