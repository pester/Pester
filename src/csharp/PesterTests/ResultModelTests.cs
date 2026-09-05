using System;
using System.IO;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Pester;

namespace PesterTests
{
    // Covers the result model classes (Container, ContainerInfo, Test, Block, Run),
    // including container Type validation, the computed Duration properties and the
    // ToStringConverter result/name formatting surfaced through ToString and Name.
    [TestClass]
    public class ResultModelTests
    {
        [TestMethod]
        public void Container_DefaultType_IsFile()
        {
            Assert.AreEqual("File", new Container().Type);
        }

        [TestMethod]
        [DataRow("file", "File")]
        [DataRow("FILE", "File")]
        [DataRow("scriptblock", "ScriptBlock")]
        [DataRow("ScriptBlock", "ScriptBlock")]
        public void Container_Type_IsNormalizedCaseInsensitively(string input, string expected)
        {
            var container = new Container { Type = input };

            Assert.AreEqual(expected, container.Type);
        }

        [TestMethod]
        public void Container_Type_InvalidValueThrows()
        {
            var container = new Container();

            Assert.ThrowsExactly<ArgumentOutOfRangeException>(() => container.Type = "bogus");
        }

        [TestMethod]
        public void Container_CreateFromFile_SetsTypeAndItem()
        {
            var file = new FileInfo("/tmp/Example.Tests.ps1");

            var container = Container.CreateFromFile(file);

            Assert.AreEqual("File", container.Type);
            Assert.AreSame(file, container.Item);
            Assert.AreEqual(file.FullName, container.Name);
        }

        [TestMethod]
        public void Container_Name_ForScriptBlockWithoutFile_IsPlaceholder()
        {
            var container = new Container { Type = "ScriptBlock", Item = null };

            Assert.AreEqual("<ScriptBlock>", container.Name);
        }

        [TestMethod]
        [DataRow("Passed", "[+] File")]
        [DataRow("Failed", "[-] File")]
        [DataRow("Skipped", "[!] File")]
        [DataRow("Inconclusive", "[?] File")]
        [DataRow("NotRun", "[ ] File")]
        [DataRow("Whatever", "[ERR] File")]
        public void Container_ToString_PrefixesResultSymbol(string result, string expected)
        {
            var container = new Container { Type = "File", Item = "File", Result = result };

            Assert.AreEqual(expected, container.ToString());
        }

        [TestMethod]
        public void Container_CreateFromBlock_CopiesResultCountsAndContainer()
        {
            var block = new Block
            {
                Result = "Passed",
                FailedCount = 1,
                PassedCount = 2,
                TotalCount = 3,
                BlockContainer = new ContainerInfo { Type = "File", Item = "the-file" },
            };

            var container = Container.CreateFromBlock(block);

            Assert.AreEqual("Passed", container.Result);
            Assert.AreEqual(1, container.FailedCount);
            Assert.AreEqual(2, container.PassedCount);
            Assert.AreEqual(3, container.TotalCount);
            Assert.AreEqual("File", container.Type);
            Assert.AreEqual("the-file", container.Item);
        }

        [TestMethod]
        public void ContainerInfo_DefaultType_IsFile()
        {
            Assert.AreEqual("File", new ContainerInfo().Type);
        }

        [TestMethod]
        public void ContainerInfo_Type_InvalidValueThrows()
        {
            var info = new ContainerInfo();

            Assert.ThrowsExactly<ArgumentOutOfRangeException>(() => info.Type = "bogus");
        }

        [TestMethod]
        public void ContainerInfo_NameAndToString_UseItem()
        {
            var info = new ContainerInfo { Type = "File", Item = "my-file" };

            Assert.AreEqual("my-file", info.Name);
            Assert.AreEqual("my-file", info.ToString());
        }

        [TestMethod]
        public void Test_Duration_IsUserPlusFramework()
        {
            var test = new Test
            {
                UserDuration = TimeSpan.FromSeconds(2),
                FrameworkDuration = TimeSpan.FromSeconds(3),
            };

            Assert.AreEqual(TimeSpan.FromSeconds(5), test.Duration);
        }

        [TestMethod]
        public void Test_ToString_PrefersExpandedNameOverName()
        {
            var test = new Test { Result = "Passed", Name = "MyTest" };
            Assert.AreEqual("[+] MyTest", test.ToString());

            test.ExpandedName = "Expanded Name";
            Assert.AreEqual("[+] Expanded Name", test.ToString());
        }

        [TestMethod]
        public void Test_ItemType_DefaultsToTest()
        {
            Assert.AreEqual("Test", new Test().ItemType);
        }

        [TestMethod]
        public void Block_Duration_IsDiscoveryPlusFrameworkPlusUser()
        {
            var block = new Block
            {
                DiscoveryDuration = TimeSpan.FromSeconds(1),
                FrameworkDuration = TimeSpan.FromSeconds(2),
                UserDuration = TimeSpan.FromSeconds(3),
            };

            Assert.AreEqual(TimeSpan.FromSeconds(6), block.Duration);
        }

        [TestMethod]
        public void Block_ToString_UsesResultAndName()
        {
            var block = new Block { Name = "MyBlock" };
            Assert.AreEqual("[ ] MyBlock", block.ToString()); // default Result is NotRun

            block.Result = "Failed";
            Assert.AreEqual("[-] MyBlock", block.ToString());
        }

        [TestMethod]
        public void Run_ToString_IsResultSymbolPlusPester()
        {
            var run = new Run();
            Assert.AreEqual("[ ] Pester", run.ToString()); // default Result is NotRun

            run.Result = "Passed";
            Assert.AreEqual("[+] Pester", run.ToString());
        }
    }
}
