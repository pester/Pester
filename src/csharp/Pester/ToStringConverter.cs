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

        internal static string ContainerItemToString(string Type, object Item)
        {
            string path;
            switch (Type)
            {
                case Constants.File:
                    path = Item is FileInfo f ? f.FullName : Item.ToString();
                    break;
                case Constants.ScriptBlock:
                    path = "<ScriptBlock>";
                    if (Item is ScriptBlock s && !string.IsNullOrWhiteSpace(s.File))
                    {
                        path += $":{s.File}:{s.StartPosition.StartLine}";
                    }
                    break;
                default:
                    path = $"<{Type}>";
                    break;
            }

            return path;
        }

        internal static string ContainerToString(Container container)
        {
            return $"{ResultToString(container.Result)} {ContainerItemToString(container.Type, container.Item)}";
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
