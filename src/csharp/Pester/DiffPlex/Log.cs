using System.Diagnostics;

namespace Pester.DiffPlex
{
    static class Log
    {
        [Conditional("LOG")]
        public static void WriteLine(string format, params object[] args)
        {
            Debug.WriteLine(string.Format(format, args));
        }

        [Conditional("LOG")]
        public static void Write(string format, params object[] args)
        {
            // not implemented
        }
    }
}
