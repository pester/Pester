using System.IO;
using System.Management.Automation;

namespace Pester
{
    static class ToStringConverter
    {
        static string ResultToString(string result)
        {
            return result switch
            {
                "Passed" => "[+]",
                "Failed" => "[-]",
                "Skipped" => "[!]",
                "Inconclusive" => "[?]",
                "NotRun" => "[ ]",
                _ => "[ERR]",
            };
        }

        internal static string ContainerItemToString(string type, object item)
        {
            return type switch
            {
                Constants.File => item is FileInfo f ? f.FullName : item.ToString(),
                Constants.ScriptBlock => item is ScriptBlock s && !string.IsNullOrWhiteSpace(s.File)
                    ? $"<ScriptBlock>:{s.File}:{s.StartPosition.StartLine}"
                    : "<ScriptBlock>",
                _ => $"<{type}>"
            };
        }

        internal static string ContainerToString(Container container)
        {
            return $"{ResultToString(container.Result)} {container.Name}";
        }

        internal static string ContainerInfoToString(ContainerInfo containerInfo)
        {
            return ContainerItemToString(containerInfo.Type, containerInfo.Item);
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
