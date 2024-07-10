using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Reflection;
using System.Threading.Tasks;

namespace Pester
{
    /// <summary>
    /// Modifies that list of recommended Verbs, so we can export Should-* functions directly without
    /// showing a warning to the user. Reverts the change after few seconds.
    /// </summary>
    public static class VerbsPatcher
    {
        // Keep the tasks we started so they finish and are not garbage collected.
        // Concurrent bag in case we start this multiple times, and god forbid in parallel.
        private static ConcurrentBag<Task> s_tasks = new ConcurrentBag<Task>();

        public static void AllowShouldVerb(int powershellVersion)
        {
            var should = "Should";

            var fieldName = powershellVersion == 5 ? "validVerbs" : "s_validVerbs";
            var verbsType = typeof(System.Management.Automation.VerbsCommon).Assembly.GetType("System.Management.Automation.Verbs");
            var verbsField = verbsType.GetField(fieldName, BindingFlags.Static | BindingFlags.NonPublic);

            // private static readonly Dictionary<string, bool> s_validVerbs;
            Dictionary<string, bool> validVerbs = (Dictionary<string, bool>)verbsField.GetValue(null);
            // Overwrite when we call this multiple times.
            validVerbs[should] = true; // The bool does not matter.

            s_tasks.Add(Task.Run(async () =>
            {
                await Task.Delay(5_000);
                try
                {
                    if (validVerbs.ContainsKey(should))
                    {
                        validVerbs.Remove(should);
                    }
                }
                catch { }
            }));
        }
    }
}
