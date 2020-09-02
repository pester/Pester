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

    public class TestFile : TestContainer
    {
        public static TestFile Create(string path)
        {
            return new TestFile(path);
        }

        public static TestFile Create(string path, IDictionary[] data)
        {
            return new TestFile(path, data);
        }


        public TestFile(string path) : this(path, null)
        {

        }

        public TestFile(string path, IDictionary[] data)
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
