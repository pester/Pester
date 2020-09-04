using System;
using System.Collections;
using System.Management.Automation;

namespace Pester
{
    public abstract class TestContainer
    {
        public object Container { get; set; }
        public IDictionary[] Data { get; set; }
    }

    public class TestPath : TestContainer
    {
        public static TestPath Create(string path)
        {
            return new TestPath(path);
        }

        public static TestPath Create(string path, IDictionary[] data)
        {
            return new TestPath(path, data);
        }


        public TestPath(string path) : this(path, null)
        {

        }

        public TestPath(string path, IDictionary[] data)
        {
            Container = Path = path ?? throw new ArgumentNullException(nameof(path));
            Data = data;
        }

        public string Path { get; set; }
    }

    public class TestScriptBlock : TestContainer
    {
        public ScriptBlock ScriptBlock { get; set; }

        public static TestScriptBlock Create(ScriptBlock scriptBlock)
        {
            return new TestScriptBlock(scriptBlock);
        }

        public static TestScriptBlock Create(ScriptBlock scriptBlock, IDictionary[] data)
        {
            return new TestScriptBlock(scriptBlock, data);
        }
        public TestScriptBlock(ScriptBlock scriptBlock) : this(scriptBlock, null)
        {
        }

        public TestScriptBlock(ScriptBlock scriptBlock, IDictionary[] data)
        {
            Container = ScriptBlock = scriptBlock;
            Data = data;
        }
    }
}
