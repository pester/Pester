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

        // s_validVerbs is PowerShell's own process-global static Dictionary (one instance per
        // process, shared by every runspace). Dictionary<TKey,TValue> is not thread-safe, so when
        // Run.Parallel imports Pester from several ForEach-Object -Parallel runspaces at once, the
        // concurrent writes can tear the internal bucket array and throw IndexOutOfRangeException.
        // VerbsPatcher lives in Pester.dll, which is loaded once per process, so this static lock
        // object is shared across all runspaces and serializes every mutation of that dictionary.
        private static readonly object s_lock = new object();

        public static void AllowShouldVerb(int powershellVersion)
        {
            var should = "Should";

            var fieldName = powershellVersion == 5 ? "validVerbs" : "s_validVerbs";
            var verbsType = typeof(System.Management.Automation.VerbsCommon).Assembly.GetType("System.Management.Automation.Verbs");
            var verbsField = verbsType.GetField(fieldName, BindingFlags.Static | BindingFlags.NonPublic);

            // private static readonly Dictionary<string, bool> s_validVerbs;
            Dictionary<string, bool> validVerbs = (Dictionary<string, bool>)verbsField.GetValue(null);
            // Only the first import structurally mutates the shared dictionary; later parallel
            // workers see the key already present and become no-ops. The lock prevents concurrent
            // writes from corrupting the dictionary. Do not use TryAdd, it is not available on the
            // net462 target.
            //
            // We deliberately do NOT double-check with an unlocked ContainsKey before taking the
            // lock. That would be an optimization to skip the lock once patched, but reading a
            // plain Dictionary outside the lock while another runspace is inserting inside the lock
            // is itself a data race: the insert can trigger an internal bucket-array resize, and a
            // concurrent unlocked read can observe the torn array and throw IndexOutOfRange, the
            // exact failure this lock exists to prevent. AllowShouldVerb runs once per runspace at
            // import time and the lock only holds a ContainsKey plus at most one insert, so there
            // is no contention worth optimizing here. A correct fast path would need a separate
            // volatile flag rather than an unlocked read of this non-thread-safe dictionary.
            lock (s_lock)
            {
                if (!validVerbs.ContainsKey(should))
                {
                    validVerbs[should] = true; // The bool does not matter.
                }
            }

            s_tasks.Add(Task.Run(async () =>
            {
                await Task.Delay(5_000);
                try
                {
                    // Serialize the removal behind the same process-global lock so it cannot race
                    // with a concurrent insert from another runspace. No await inside the lock.
                    lock (s_lock)
                    {
                        if (validVerbs.ContainsKey(should))
                        {
                            validVerbs.Remove(should);
                        }
                    }
                }
                catch { }
            }));
        }
    }
}
