using System;
using System.Collections;
using System.Management.Automation;

namespace Pester
{
    // Engine-level hook that makes a Pester mock apply across the whole runspace ("global" mock).
    //
    // A normal Pester mock defines a bootstrap function + alias in a single session state (the test's,
    // or the -ModuleName target's). Code in another module resolves the command in its own session
    // state and never sees that alias, which is why -ModuleName exists. This hook uses
    // InvokeCommand.PreCommandLookupAction, a runspace-global callback fired on every parser-driven
    // command lookup, to redirect the lookup to the mock's bootstrap function no matter which module
    // the call comes from.
    //
    // The callback does NOT fire for '& $capturedCommandInfo' (Get-Command / Pester's $SafeCommands
    // dispatch), so Pester's own internals are unaffected.
    //
    // Correctness note: we store the *base* CommandInfo (unwrapping any PSObject) both on register and
    // on lookup. Returning a PSObject-wrapped command from a compiled handler throws inside the engine,
    // which then silently falls through to the real command. The '.Mock' note property attached to the
    // bootstrap function resurrects off the base object, so it survives this round-trip.
    //
    // Threading: the registry is written only during mock setup/teardown (single writer on the Pester
    // thread) and read during command lookup. That matches Hashtable's documented "one writer, many
    // readers" thread-safety guarantee.
    public static class GlobalMockHook
    {
        private static readonly Hashtable _registry = new Hashtable(StringComparer.OrdinalIgnoreCase);

        // Name for which the redirect is temporarily suppressed on the current thread. Used while
        // Pester resolves the *original* command to discover its dynamic parameters: that resolution
        // looks the command up by name (InvokeCommand.GetCommand), which would otherwise be redirected
        // back to the mock's bootstrap function and hide the real command's dynamic parameters.
        [ThreadStatic]
        private static string _suppressedName;

        private static readonly EventHandler<CommandLookupEventArgs> _handler =
            new EventHandler<CommandLookupEventArgs>(OnCommandLookup);

        // A single cached delegate instance so the PowerShell side can install it once and remove
        // exactly that instance via [Delegate]::Remove.
        public static EventHandler<CommandLookupEventArgs> Handler
        {
            get { return _handler; }
        }

        public static int Count
        {
            get { return _registry.Count; }
        }

        // Temporarily stop redirecting lookups of 'name' on the current thread. Pair with EndSuppress
        // in a finally block. Only one name is suppressed at a time, which is all the dynamic-parameter
        // resolution needs (it resolves a single command).
        public static void BeginSuppress(string name)
        {
            _suppressedName = name;
        }

        public static void EndSuppress()
        {
            _suppressedName = null;
        }

        // Identity of the Pester run whose mocks are currently effective on this thread. A mock's bootstrap
        // records the run that created it (see Create-MockHook) and compares it to this value; when they
        // differ the bootstrap belongs to another run that leaked in via its script-scope alias, so it
        // defers to the original command instead of applying the mock. Invoke-Pester sets this in its begin
        // block and restores the previous value when it ends, so nested runs each get their own id.
        [ThreadStatic]
        private static string _currentRunId;

        public static string CurrentRunId
        {
            get { return _currentRunId; }
        }

        // Set the current run id, returning the previous value so a nested run can restore it on exit.
        public static string SetCurrentRun(string runId)
        {
            var previous = _currentRunId;
            _currentRunId = runId;
            return previous;
        }

        public static void Register(string name, object command)
        {
            if (string.IsNullOrEmpty(name) || command == null)
            {
                return;
            }

            _registry[name] = Unwrap(command);
        }

        public static void Unregister(string name)
        {
            if (string.IsNullOrEmpty(name))
            {
                return;
            }

            _registry.Remove(name);
        }

        public static bool IsRegistered(string name)
        {
            return !string.IsNullOrEmpty(name) && _registry.ContainsKey(name);
        }

        public static void Clear()
        {
            _registry.Clear();
        }

        // Copy of the current registrations. Used to save the outer run's global mocks before a nested
        // Pester run clears the shared state for itself, so they can be restored when the nested run ends.
        public static Hashtable GetSnapshot()
        {
            return (Hashtable)_registry.Clone();
        }

        private static void OnCommandLookup(object sender, CommandLookupEventArgs e)
        {
            if (_suppressedName != null && string.Equals(_suppressedName, e.CommandName, StringComparison.OrdinalIgnoreCase))
            {
                return;
            }

            var command = _registry[e.CommandName];
            if (command == null)
            {
                return;
            }

            var commandInfo = Unwrap(command) as CommandInfo;
            if (commandInfo != null)
            {
                e.Command = commandInfo;
                e.StopSearch = true;
            }
        }

        private static object Unwrap(object command)
        {
            var pso = command as PSObject;
            return pso != null ? pso.BaseObject : command;
        }
    }
}
