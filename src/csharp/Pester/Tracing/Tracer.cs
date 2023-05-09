using System;
using System.Management.Automation;
using System.Management.Automation.Host;
using System.Management.Automation.Language;
using System.Reflection;
using NonGeneric = System.Collections;

namespace Pester.Tracing
{
    public static class Tracer
    {
        private static Func<TraceLineInfo> GetTraceLineInfo;
        private static Action ResetUI = () => { };
        /// <summary>
        /// Primary tracer (slot1).
        /// </summary>
        public static ITracer Tracer1 { get; private set; }
        /// <summary>
        /// Secondary tracer (slot2).
        /// </summary>
        public static ITracer Tracer2 { get; private set; }

        [Obsolete("IsEnabled is obsolete because the internal state can become corrupted when script is cancelled, use ShouldRegisterTracer instead. The state of IsEnabled is set as before, but it won't be checked when using Patch or Register, to prevent the user session from being locked up by the incorrect state.")]
        public static bool IsEnabled { get; private set; }

        /// <summary>
        /// Check if we should call Register or Patch functions for the given tracer. It returns false when tracer is not present in slot 1,
        /// or if overwrite is true (default) and slot 1 has the same tracer as what we are registering. Use overwrite to check the type of the registered tracer
        /// and allow replacing it with the new tracer if the types are the same. (e.g you are adding tracer for Pester code coverage, and user aborted the run
        /// so Pester tracer from the previous run is still present, and you are now replacing it with another Pester code coverage tracer). You would rarely want
        /// overwrite set to false. But for example when you run Profiler in Profiler, you would want to register the second tracer into slot2 not even though slot1
        /// has tracer of the same type.
        /// </summary>
        /// <param name="tracer">The tracer to use.</param>
        /// <param name="overwrite">Allow overwriting the tracer in the main tracer slot if the tracer type we are adding is the same as the one that is already present.</param>
        /// <returns></returns>
        public static bool ShouldRegisterTracer(object tracer, bool overwrite = true)
        {
            if (tracer is null)
                throw new ArgumentNullException(nameof(tracer));

            if (overwrite)
            {
                // if there is a tracer in slot 1, and it is not the same as we are providing
                // we should use slot 2 and only register the tracer
                return HasDifferentTracer(Tracer1, tracer);
            }

            // we have tracer in slot 1, use slot 2 by registering the tracer
            return HasTracer(Tracer1);
        }

        private static bool HasTracer(ITracer currentTracer)
        {
            return currentTracer != null;
        }

        private static bool HasDifferentTracer(ITracer currentTracer, object newTracer)
        {
            if (currentTracer == null)
                return false;

            if (currentTracer is ExternalTracerAdapter adapted)
            {
                return adapted.Tracer.GetType().Name != newTracer.GetType().Name;
            }

            return currentTracer.GetType().Name != newTracer.GetType().Name;
        }

        /// <summary>
        /// Add a tracer to already setup session (to slot2). A tracer must implement ITracer or have a method `void Trace(string message, IScriptExtent extent, ScriptBlock scriptBlock, int level)`.
        /// </summary>
        /// <param name="tracer"></param>
        public static void Register(object tracer)
        {
            if (tracer is null)
                throw new ArgumentNullException(nameof(tracer));

            if (!HasTracer(Tracer1))
                throw new InvalidOperationException($"Tracer1 is null. If you want to activate tracing call {nameof(Patch)}.");

            if (HasDifferentTracer(Tracer2, tracer))
                throw new InvalidOperationException($"Tracer2 already has tracer {Tracer2.GetType().Name}, and you are registering {tracer.GetType().Name}.");

            Tracer2 = tracer is ITracer t ? t : new ExternalTracerAdapter(tracer);

            TraceLine(justTracer2: true);
        }

        /// <summary>
        /// Unregister tracer from an already setup session (slot2).
        /// </summary>
        public static void Unregister()
        {
            TraceLine(justTracer2: true);
            TraceLine(justTracer2: true);
            Tracer2 = null;
        }

        /// <summary>
        /// Enable tracing by patch the current session by replacing the UI host with another that triggers tracing on every statement. Set-PSDebug -Trace 1 needs to be called before this, and Set-PSDebug -Off needs to be called after Unpatch.
        /// </summary>
        /// <param name="powerShellVersion">Major PSVersion that is used `$PSVersionTable.PSVersion.Major`</param>
        /// <param name="context">ExecutionContext to be used `$ExecutionContext`</param>
        /// <param name="ui">UIHost to be replaced. `$host.UI`</param>
        /// <param name="tracer">The tracer to be used. For example ProfilerTracer.</param>
        public static void Patch(int powerShellVersion, EngineIntrinsics context, PSHostUserInterface ui, ITracer tracer)
        {
            if (context is null)
                throw new ArgumentNullException(nameof(context));

            if (ui is null)
                throw new ArgumentNullException(nameof(ui));

            Tracer1 = tracer ?? throw new ArgumentNullException(nameof(tracer));

            var uiFieldName = powerShellVersion >= 6 ? "_externalUI" : "externalUI";
            // we get InternalHostUserInterface, grab external ui from that and replace it with ours
            var externalUIField = ui.GetType().GetField(uiFieldName, BindingFlags.Instance | BindingFlags.NonPublic);
            var externalUI = (PSHostUserInterface)externalUIField.GetValue(ui);

            // replace it with out patched up UI that writes to profiler on debug
            externalUIField.SetValue(ui, new TracerHostUI(externalUI, (message) => TraceLine(message, false)));

            ResetUI = () => externalUIField.SetValue(ui, externalUI);

            // getting MethodInfo of context._context.Debugger.TraceLine
            var bf = BindingFlags.NonPublic | BindingFlags.Instance;
            var contextInternal = context.GetType().GetField("_context", bf).GetValue(context);
            var debugger = contextInternal.GetType().GetProperty("Debugger", bf).GetValue(contextInternal);
            var debuggerType = debugger.GetType();

            var callStackField = debuggerType.GetField("_callStack", BindingFlags.Instance | BindingFlags.NonPublic);
            var _callStack = callStackField.GetValue(debugger);

            var callStackType = _callStack.GetType();

            var countBindingFlags = BindingFlags.Instance | BindingFlags.NonPublic;
            if (powerShellVersion == 3)
            {
                // in PowerShell 3 callstack is List<CallStackInfo> not a struct CallStackList
                // Count is public property
                countBindingFlags = BindingFlags.Instance | BindingFlags.Public;
            }
            var countProperty = callStackType.GetProperty("Count", countBindingFlags);
            var getCount = countProperty.GetMethod;
            var empty = new object[0];
            var stack = callStackField.GetValue(debugger);
            var initialLevel = (int)getCount.Invoke(stack, empty);

            if (powerShellVersion == 3)
            {
                // we do the same operation as in the TraceLineAction below, but here
                // we resolve the static things like types and properties, and then in the
                // action we just use them to get the live data without the overhead of looking
                // up properties all the time. This might be internally done in the reflection code
                // did not measure the impact, and it is probably done for us in the reflection api itself
                // in modern versions of runtime
                var callStack1 = callStackField.GetValue(debugger);
                var callStackList1 = (NonGeneric.IList)callStack1;
                var level1 = callStackList1.Count - initialLevel;
                var last1 = callStackList1[callStackList1.Count - 1];
                var lastType = last1.GetType();
                var functionContextProperty = lastType.GetProperty("FunctionContext", BindingFlags.NonPublic | BindingFlags.Instance);
                var functionContext1 = functionContextProperty.GetValue(last1);
                var functionContextType = functionContext1.GetType();

                var scriptBlockField = functionContextType.GetField("_scriptBlock", BindingFlags.Instance | BindingFlags.NonPublic);
                var currentPositionProperty = functionContextType.GetProperty("CurrentPosition", BindingFlags.Instance | BindingFlags.NonPublic);

                var scriptBlock1 = (ScriptBlock)scriptBlockField.GetValue(functionContext1);
                var extent1 = (IScriptExtent)currentPositionProperty.GetValue(functionContext1);

                GetTraceLineInfo = () =>
                {
                    var callStack = callStackField.GetValue(debugger);
                    var callStackList = (NonGeneric.IList)callStack;
                    var level = callStackList.Count - initialLevel;
                    var last = callStackList[callStackList.Count - 1];
                    var functionContext = functionContextProperty.GetValue(last);

                    var scriptBlock = (ScriptBlock)scriptBlockField.GetValue(functionContext);
                    var extent = (IScriptExtent)currentPositionProperty.GetValue(functionContext);

                    return new TraceLineInfo(extent, scriptBlock, level);
                };
            }
            else
            {
                var lastFunctionContextMethod = callStackType.GetMethod("LastFunctionContext", BindingFlags.Instance | BindingFlags.NonPublic);

                object functionContext1 = lastFunctionContextMethod.Invoke(callStackField.GetValue(debugger), empty);
                var functionContextType = functionContext1.GetType();
                var scriptBlockField = functionContextType.GetField("_scriptBlock", BindingFlags.Instance | BindingFlags.NonPublic);
                var currentPositionProperty = functionContextType.GetProperty("CurrentPosition", BindingFlags.Instance | BindingFlags.NonPublic);

                var scriptBlock1 = (ScriptBlock)scriptBlockField.GetValue(functionContext1);
                var extent1 = (IScriptExtent)currentPositionProperty.GetValue(functionContext1);

                GetTraceLineInfo = () =>
                {
                    var callStack = callStackField.GetValue(debugger);
                    var level = (int)getCount.Invoke(callStack, empty) - initialLevel;
                    object functionContext = lastFunctionContextMethod.Invoke(callStack, empty);
                    var scriptBlock = (ScriptBlock)scriptBlockField.GetValue(functionContext);
                    var extent = (IScriptExtent)currentPositionProperty.GetValue(functionContext);

                    return new TraceLineInfo(extent, scriptBlock, level);
                };
            }

#pragma warning disable CS0618 // Type or member is obsolete
            IsEnabled = true;
#pragma warning restore CS0618 // Type or member is obsolete

            // Add another event to the top apart from the scriptblock invocation
            // in Trace-ScriptInternal, this makes it more consistently work on first
            // run. Without this, the triggering line sometimes does not show up as 99.9%
            TraceLine();
        }

        /// <summary>
        /// Put the original UI host in place and stop tracing.  Set-PSDebug -Trace 0 (or Set-PSDebug -Off) needs to be called before this.
        /// </summary>
        public static void Unpatch()
        {
#pragma warning disable CS0618 // Type or member is obsolete
            IsEnabled = false;
#pragma warning restore CS0618 // Type or member is obsolete

            // Add Set-PSDebug -Trace 0 event and also another one for the internal disable
            // this make first run more consistent for some reason
            TraceLine();
            TraceLine();
            ResetUI();
            Tracer1 = null;
            Tracer2 = null;
        }

        private static void TraceLine(string message = null, bool justTracer2 = false)
        {
            if (GetTraceLineInfo == null)
                return;

            var traceLineInfo = GetTraceLineInfo();
            if (!justTracer2)
            {
                Tracer1?.Trace(message, traceLineInfo.Extent, traceLineInfo.ScriptBlock, traceLineInfo.Level);
            }
            Tracer2?.Trace(message, traceLineInfo.Extent, traceLineInfo.ScriptBlock, traceLineInfo.Level);
        }

        private struct TraceLineInfo
        {
            public IScriptExtent Extent;
            public ScriptBlock ScriptBlock;
            public int Level;

            public TraceLineInfo(IScriptExtent extent, ScriptBlock scriptBlock, int level)
            {
                Extent = extent;
                ScriptBlock = scriptBlock;
                Level = level;
            }
        }
    }
}
