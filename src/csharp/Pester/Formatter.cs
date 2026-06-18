using System;

namespace Pester
{
    public static class Formatter
    {
        private static readonly char[] ControlChars = BuildControlChars();

        private static char[] BuildControlChars()
        {
            var chars = new char[0x20];
            for (int i = 0; i < 0x20; i++)
            {
                chars[i] = (char)i;
            }
            return chars;
        }

        /// <summary>
        /// Replaces ASCII control characters (0x00..0x1F) in <paramref name="value"/>
        /// with the matching Unicode "Control Pictures" code point
        /// (U+2400..U+241F) so they are visible when printed. See
        /// https://github.com/pester/Pester/issues/2561.
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
            var buf = new char[len];
            value.CopyTo(0, buf, 0, len);

            // Everything before firstControl is known to be safe; start from there.
            for (int i = firstControl; i < len; i++)
            {
                char c = buf[i];
                if (c < 0x20)
                {
                    buf[i] = (char)(c + 0x2400);
                }
            }

            return new string(buf);
        }
    }
}
