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
    // InvokeCommand.PreCommandLookupAction - a runspace-global callback fired on every parser-driven
    // command lookup - to redirect the lookup to the mock's bootstrap function no matter which module
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

        private static void OnCommandLookup(object sender, CommandLookupEventArgs e)
        {
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
