using System;
using System.Management.Automation;
using System.Management.Automation.Language;
using System.Reflection;

namespace Pester.Tracing
{
    class ExternalTracerAdapter : ITracer
    {
        private object _tracer;
        private MethodInfo _traceMethod;

        public ExternalTracerAdapter(object tracer)
        {
            _tracer = tracer ?? new NullReferenceException(nameof(tracer));
            var traceMethod = tracer.GetType().GetMethod("Trace", new Type[] { typeof(IScriptExtent), typeof(ScriptBlock), typeof(int)  });
            _traceMethod = traceMethod ?? throw new InvalidOperationException("The provided tracer does not have Trace method with this signature: Trace(IScriptExtent extent, ScriptBlock scriptBlock, int level)");
        }

        public void Trace(string message, IScriptExtent extent, ScriptBlock scriptBlock, int level)
        {
            _traceMethod.Invoke(_tracer, new object[] { extent, scriptBlock, level });
        }
    }
}
