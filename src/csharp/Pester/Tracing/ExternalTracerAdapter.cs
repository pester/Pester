// Copied from Profiler module, branch: Fix-error-autodetection, commit: 150bbcf Fix error autodetection 

using System;
using System.Management.Automation;
using System.Management.Automation.Language;
using System.Reflection;


#if PESTER
namespace Pester.Tracing;
#else
namespace Profiler;
#endif

class ExternalTracerAdapter : ITracer
{
    private readonly object _tracer;
    private readonly MethodInfo _traceMethod;
    private readonly int _version = 0;

    public object Tracer => _tracer;

    public ExternalTracerAdapter(object tracer)
    {
        // We got tracer that is not using the same types that we use here. Find a method based on the signature
        // and use that. This enables tracers to register even when they don't take dependency on our types e.g. Pester CC tracer.

        _tracer = tracer ?? new NullReferenceException(nameof(tracer));
        _version = 2;
        var traceMethod = tracer.GetType().GetMethod("Trace", new Type[] {
                typeof(string), // message
                typeof(IScriptExtent), // extent
                typeof(ScriptBlock), // scriptblock
                typeof(int) }); // level

        if (traceMethod == null)
        {
            _version = 1;
            traceMethod = tracer.GetType().GetMethod("Trace", new Type[] {
                typeof(string), // message
                typeof(IScriptExtent), // extent
                typeof(ScriptBlock), // scriptblock
                typeof(int) }); // level
        }

        _traceMethod = traceMethod ??
            throw new InvalidOperationException("The provided tracer does not have Trace method with this signature: Trace(string message, IScriptExtent extent, ScriptBlock scriptBlock, int level) or Trace(IScriptExtent extent, ScriptBlock scriptBlock, int level)");
    }

    public void Trace(string message, IScriptExtent extent, ScriptBlock scriptBlock, int level, string functionName, string moduleName)
    {
        var parameters = _version == 2
            ? new object[] { message, extent, scriptBlock, level }
            : new object[] { extent, scriptBlock, level };
        _traceMethod.Invoke(_tracer, parameters);
    }
}

