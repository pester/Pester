using System;
using System.Collections;
using System.Collections.Generic;
using System.Reflection;
using System.Management.Automation;

namespace Pester
{
// Result of recovering the left-hand side of a pipeline from inside an advanced function.
public sealed class PipelineSourceInfo
{
    public string Source;         // collection | scalar | range | stream | empty
    public string TypeName;       // runtime type of the recovered LHS (or a note)
    public long Count;
    public object Value;          // the actual object (same reference) when Reference == true
    public bool Reference;        // true => Value is the original instance, no copy / no re-run
    public string[] ElementTypes; // for stream: distinct element type names
    public object LowerBound;     // for range
    public object UpperBound;     // for range

    // Diagnostics (for PowerShell-internals analysis).
    public string EnumeratorType;
    public string BackingField;
    public string RuntimeType;
    public string PipeType;
}

public static class PipelineSource
{
    private const BindingFlags BF =
        BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public;

    // How the input enumerator relates to a recoverable source container.
    private enum EnumKind
    {
        Collection,
        Range,
        None
    }

    // One cache entry per concrete enumerator type — everything needed, resolved once.
    private sealed class EnumPlan
    {
        public EnumKind Kind;
        public FieldInfo Backing; // EnumKind.Collection
        public FieldInfo Lower;   // EnumKind.Range
        public FieldInfo Upper;   // EnumKind.Range
    }

    // The internal range-enumerator type, resolved once. Comparing Type references is faster than
    // (and avoids false positives of) a per-call name string comparison. Null on versions/editions
    // where the type cannot be found, in which case we fall back to the name comparison.
    private static readonly Type RangeEnumeratorType =
        typeof(PSObject).Assembly.GetType("System.Management.Automation.RangeEnumerator");

    // Reflection metadata caches. PowerShell drives the pipeline single-threaded, so plain
    // dictionaries are safe here and avoid the cost of GetProperty/GetField on every call.
    private static readonly Dictionary<Type, PropertyInfo> _inputPipeProp =
        new Dictionary<Type, PropertyInfo>();
    private static readonly Dictionary<Type, FieldInfo> _enumField =
        new Dictionary<Type, FieldInfo>();
    private static readonly Dictionary<Type, EnumPlan> _enumPlan =
        new Dictionary<Type, EnumPlan>();

    private static readonly string[] PreferredBackingNames =
    {
        "_array", "_list", "list", "array", "_collection",
        "_source", "_items", "m_array", "_set", "_values"
    };

    private static PropertyInfo FindProp(Type t, string name)
    {
        for (Type x = t; x != null; x = x.BaseType)
        {
            PropertyInfo p = x.GetProperty(name, BF);
            if (p != null)
            {
                return p;
            }
        }

        return null;
    }

    private static FieldInfo FindField(Type t, string name)
    {
        for (Type x = t; x != null; x = x.BaseType)
        {
            FieldInfo f = x.GetField(name, BF);
            if (f != null)
            {
                return f;
            }
        }

        return null;
    }

    // cmdlet      : pass $PSCmdlet.
    // inputBuffer : pass @($input). Only read on the fallback paths (scalar/stream); the common
    //               "recovered a container" path ignores it.
    public static PipelineSourceInfo Resolve(PSCmdlet cmdlet, IList inputBuffer)
    {
        PipelineSourceInfo r = new PipelineSourceInfo();

        object rt = (cmdlet == null) ? null : cmdlet.CommandRuntime;
        if (rt != null)
        {
            r.RuntimeType = rt.GetType().FullName;
        }

        object pipe = ReadInputPipe(rt);
        if (pipe != null)
        {
            r.PipeType = pipe.GetType().FullName;
        }

        object en = ReadEnumerator(pipe);
        if (en != null)
        {
            Type enType = en.GetType();
            r.EnumeratorType = enType.FullName;

            EnumPlan plan = GetPlan(en, enType);

            if (plan.Kind == EnumKind.Range)
            {
                return DescribeRange(r, en, enType, plan, inputBuffer);
            }

            if (plan.Kind == EnumKind.Collection && plan.Backing != null)
            {
                object src = plan.Backing.GetValue(en);
                if (src != null && (src is IEnumerable) && !(src is string))
                {
                    r.BackingField = plan.Backing.Name;
                    r.Source = "collection";
                    r.TypeName = src.GetType().FullName;
                    r.Value = src;
                    r.Reference = true;

                    ICollection c = src as ICollection;
                    r.Count = (c != null) ? c.Count : CountEnumerable(src);
                    return r;
                }
            }
        }

        return DescribeBuffer(r, inputBuffer);
    }

    // Reads f's own input pipe through the public Cmdlet.CommandRuntime property.
    private static object ReadInputPipe(object rt)
    {
        if (rt == null)
        {
            return null;
        }

        Type rtType = rt.GetType();
        PropertyInfo pp;
        if (!_inputPipeProp.TryGetValue(rtType, out pp))
        {
            pp = FindProp(rtType, "InputPipe");
            _inputPipeProp[rtType] = pp;
        }

        return (pp != null) ? pp.GetValue(rt, null) : null;
    }

    // Reads Pipe._enumeratorToProcess — the live enumerator over the original left-hand side.
    private static object ReadEnumerator(object pipe)
    {
        if (pipe == null)
        {
            return null;
        }

        Type pType = pipe.GetType();
        FieldInfo ef;
        if (!_enumField.TryGetValue(pType, out ef))
        {
            ef = FindField(pType, "_enumeratorToProcess");
            _enumField[pType] = ef;
        }

        return (ef != null) ? ef.GetValue(pipe) : null;
    }

    private static EnumPlan GetPlan(object en, Type enType)
    {
        EnumPlan plan;
        if (!_enumPlan.TryGetValue(enType, out plan))
        {
            plan = BuildPlan(en, enType);
            _enumPlan[enType] = plan;
        }

        return plan;
    }

    private static EnumPlan BuildPlan(object en, Type enType)
    {
        EnumPlan p = new EnumPlan();

        bool isRange = (RangeEnumeratorType != null)
            ? (enType == RangeEnumeratorType)
            : (enType.Name == "RangeEnumerator");

        if (isRange)
        {
            p.Kind = EnumKind.Range;
            p.Lower = FindField(enType, "_lowerBound");
            p.Upper = FindField(enType, "_upperBound");
            return p;
        }

        FieldInfo backing = ResolveBackingField(en, enType);
        if (backing != null)
        {
            p.Kind = EnumKind.Collection;
            p.Backing = backing;
        }
        else
        {
            p.Kind = EnumKind.None;
        }

        return p;
    }

    private static FieldInfo ResolveBackingField(object en, Type enType)
    {
        // Prefer well-known source-collection field names.
        for (int i = 0; i < PreferredBackingNames.Length; i++)
        {
            FieldInfo f = FindField(enType, PreferredBackingNames[i]);
            if (f != null)
            {
                object v = f.GetValue(en);
                if (v != null && (v is IEnumerable) && !(v is string))
                {
                    return f;
                }
            }
        }

        // Fallback: the first field (other than the "current" element) holding a non-string
        // IEnumerable. Best-effort: ambiguous for enumerators with several IEnumerable fields.
        for (Type x = enType; x != null; x = x.BaseType)
        {
            FieldInfo[] fields = x.GetFields(BF);
            for (int i = 0; i < fields.Length; i++)
            {
                if (fields[i].Name.ToLowerInvariant().Contains("current"))
                {
                    continue;
                }

                object v = fields[i].GetValue(en);
                if (v != null && (v is IEnumerable) && !(v is string))
                {
                    return fields[i];
                }
            }
        }

        return null;
    }

    private static PipelineSourceInfo DescribeRange(
        PipelineSourceInfo r, object en, Type enType, EnumPlan plan, IList inputBuffer)
    {
        r.Source = "range";
        r.TypeName = "lazy 1..N (" + enType.Name + ")";
        r.LowerBound = (plan.Lower != null) ? plan.Lower.GetValue(en) : null;
        r.UpperBound = (plan.Upper != null) ? plan.Upper.GetValue(en) : null;
        r.Reference = false;

        if (r.LowerBound != null && r.UpperBound != null)
        {
            long lo = Convert.ToInt64(r.LowerBound);
            long hi = Convert.ToInt64(r.UpperBound);
            r.Count = Math.Abs(hi - lo) + 1;
        }
        else
        {
            r.Count = (inputBuffer == null) ? 0 : inputBuffer.Count;
        }

        return r;
    }

    private static PipelineSourceInfo DescribeBuffer(PipelineSourceInfo r, IList inputBuffer)
    {
        // The input arrived as discrete pipeline items (already buffered by the engine in $input).
        IList buf = (inputBuffer != null) ? inputBuffer : (IList)(new object[0]);

        if (buf.Count == 1)
        {
            // Non-enumerated single object (hashtable / dictionary / string / scalar).
            object v = Unwrap(buf[0]);
            r.Source = "scalar";
            r.TypeName = (v == null) ? "<null>" : v.GetType().FullName;
            r.Value = v;
            r.Count = 1;
            r.Reference = true;
            return r;
        }

        if (buf.Count == 0)
        {
            r.Source = "empty";
            r.TypeName = "<no input>";
            r.Count = 0;
            r.Reference = false;
            return r;
        }

        // A genuine stream (a command on the left): no container ever existed.
        r.Source = "stream";
        r.TypeName = "<streamed; no container>";
        r.Count = buf.Count;
        r.Value = buf;
        r.Reference = false;
        r.ElementTypes = ElementTypeNames(buf);
        return r;
    }

    private static object Unwrap(object v)
    {
        PSObject pso = v as PSObject;
        return (pso != null) ? pso.BaseObject : v;
    }

    private static int CountEnumerable(object e)
    {
        int n = 0;
        IEnumerator it = ((IEnumerable)e).GetEnumerator();
        while (it.MoveNext())
        {
            n++;
        }

        return n;
    }

    private static string[] ElementTypeNames(IList items)
    {
        List<string> names = new List<string>();
        foreach (object o in items)
        {
            object v = Unwrap(o);
            string n = (v == null) ? "null" : v.GetType().Name;
            if (!names.Contains(n))
            {
                names.Add(n);
            }
        }

        return names.ToArray();
    }
}
}
