using System;

namespace Pester
{
    static class ToStringConverter
    {
        static string ResultToString(string result)
        {
            switch (result) {
                case "Passed" :
                    return "[+]";
                case "Failed":
                    return "[-]";
                case "Skipped":
                    return "[!]";
                case "NotRun":
                    return "[ ]";
                default: throw new NotSupportedException($"Not supported result '{result}'");
            }
        }

        internal static string ContainerToString(Container container)
        {
            string path;
            switch (container.Type)
            {
                case "File":
                    path = container.Item.ToString();
                    break;
                default:
                    path = $"<{container.Type}>";
                    break;
            }

            return $"{ResultToString(container.Result)} {path}";
        }

        internal static string TestToString(Test test)
        {
            return $"{ResultToString(test.Result)} {test.ExpandedName ?? test.Name}";
        } 

        internal static string BlockToString(Block block)
        {
            return $"{ResultToString(block.Result)} {block.Name}";
        }

        internal static string RunToString(Run run)
        {
            return $"{ResultToString(run.Result)} Pester";
        }
    }
}
