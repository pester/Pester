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
        private static Action ResetUI;
        private static ITracer _tracer;
        private static ITracer _tracer2;

        public static bool IsEnabled { get; private set; }

        public static bool HasTracer2 => _tracer2 != null;

        public static void Register(object tracer)
        {
            if (!IsEnabled)
                throw new InvalidOperationException($"Tracer is not active, if you want to activate it call {nameof(Patch)}.");

            if (HasTracer2)
                throw new InvalidOperationException("Tracer2 is already present.");

            _tracer2 = new ExternalTracerAdapter(tracer) ?? throw new ArgumentNullException(nameof(tracer));
            TraceLine(justTracer2: true);
        }

        public static void Unregister()
        {
            if (!IsEnabled)
                throw new InvalidOperationException("Tracer is not active.");

            if (!HasTracer2)
                throw new InvalidOperationException("Tracer2 is not present.");

            TraceLine(justTracer2: true);
            TraceLine(justTracer2: true);
            _tracer2 = null;
        }

        public static void Patch(int version, EngineIntrinsics context, PSHostUserInterface ui, ITracer tracer)
        {
            if (IsEnabled)
                throw new InvalidOperationException($"Tracer is already active, if you want to add another tracer call {nameof(Register)}.");

            _tracer = tracer ?? throw new ArgumentNullException(nameof(tracer));

            var uiFieldName = version >= 7 ? "_externalUI" : "externalUI";
            // we get InternalHostUserInterface, grab external ui from that and replace it with ours
            var externalUIField = ui.GetType().GetField(uiFieldName, BindingFlags.Instance | BindingFlags.NonPublic);
            var externalUI = (PSHostUserInterface)externalUIField.GetValue(ui);

            // replace it with out patched up UI that writes to profiler on debug
            externalUIField.SetValue(ui, new TracerHostUI(externalUI, () => TraceLine(false)));

            ResetUI = () =>
            {
                externalUIField.SetValue(ui, externalUI);
            };

            // getting MethodInfo of context._context.Debugger.TraceLine
            var bf = BindingFlags.NonPublic | BindingFlags.Instance;
            var contextInternal = context.GetType().GetField("_context", bf).GetValue(context);
            var debugger = contextInternal.GetType().GetProperty("Debugger", bf).GetValue(contextInternal);
            var debuggerType = debugger.GetType();

            var callStackField = debuggerType.GetField("_callStack", BindingFlags.Instance | BindingFlags.NonPublic);
            var _callStack = callStackField.GetValue(debugger);

            var callStackType = _callStack.GetType();

            var countBindingFlags = BindingFlags.Instance | BindingFlags.NonPublic;
            if (version == 3)
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

            if (version == 3 || version == 4)
            {
                // we do the same operation as in the TraceLineAction below, but here 
                // we resolve the static things like types and properties, and then in the 
                // action we just use them to get the live data without the overhead of looking 
                // up properties all the time. This might be internally done in the reflection code
                // did not measure the impact, and it is probably done for us in the reflection api itself
                // in modern verisons of runtime
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

            IsEnabled = true;

            // Add another event to the top apart from the scriptblock invocation
            // in Trace-ScriptInternal, this makes it more consistently work on first
            // run. Without this, the triggering line sometimes does not show up as 99.9%
            TraceLine();
        }

        public static void Unpatch()
        {
            IsEnabled = false;
            // Add Set-PSDebug -Trace 0 event and also another one for the internal disable
            // this make first run more consistent for some reason
            TraceLine();
            TraceLine();
            ResetUI();
            _tracer = null;
            _tracer2 = null;
        }

        // keeping this public so I can write easier repros when something goes wrong, 
        // in that case we just need to patch, trace and unpatch and if that works then 
        // maybe the UI host does not work
        public static void TraceLine(bool justTracer2 = false)
        {
            var traceLineInfo = GetTraceLineInfo();
            if (!justTracer2)
            {
                _tracer.Trace(traceLineInfo.Extent, traceLineInfo.ScriptBlock, traceLineInfo.Level);
            }
            _tracer2?.Trace(traceLineInfo.Extent, traceLineInfo.ScriptBlock, traceLineInfo.Level);
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
