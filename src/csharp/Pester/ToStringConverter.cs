using System.Collections.Generic;
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

        internal static string ScriptBlockCollectionToString(System.Collections.Generic.List<ScriptBlock> scriptBlocks)
        {
            if (scriptBlocks == null || scriptBlocks.Count == 0)
                return string.Empty;

            // One is the common case, and printing just its body keeps the output identical to what
            // a plain ScriptBlock produced before these became collections.
            if (scriptBlocks.Count == 1)
                return scriptBlocks[0]?.ToString() ?? string.Empty;

            // More than one, so number them the same way multiple errors are numbered when they are
            // rendered (see Get-ErrorForXmlReport and Write-ErrorToScreen): a zero-based [n] prefix,
            // used only when there is actually more than one item.
            var numbered = new List<string>(scriptBlocks.Count);
            for (var i = 0; i < scriptBlocks.Count; i++)
                numbered.Add($"[{i}] {scriptBlocks[i]?.ToString() ?? string.Empty}");

            return string.Join(System.Environment.NewLine, numbered);
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
