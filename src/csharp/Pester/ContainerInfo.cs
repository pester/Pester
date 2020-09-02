using System;
using System.Collections;
using System.Collections.Generic;

namespace Pester
{
    public class ContainerInfo
    {
        public static ContainerInfo Create()
        {
            return new ContainerInfo();
        }

        public static ContainerInfo[] CreateFromTestContainer(TestContainer testContainer)
        {
            var containers = new List<ContainerInfo>();
            if (testContainer.Data != null && testContainer.Data.Length > 0)
            {
                // with data
                foreach (var d in testContainer.Data)
                {
                    var ci = FromContainer(testContainer);
                    ci.Data = d;
                    containers.Add(ci);
                }
            }
            else
            {
                // without any data
                containers.Add(FromContainer(testContainer));
            }

            return containers.ToArray();
        }

        private static ContainerInfo FromContainer(TestContainer testContainer)
        {
            switch (testContainer)
            {
                case TestFile _:
                    return new ContainerInfo
                    {
                        Type = Constants.File,
                        Item = testContainer.Container,
                    };
                case TestScriptBlock _:
                    return new ContainerInfo
                    {
                        Type = Constants.ScriptBlock,
                        Item = testContainer.Container,
                    };

                default:
                    throw new NotSupportedException($"Test container type {testContainer.GetType().Name} is not supported.");
            }
        }



        public string Type { get; set; } = "File";
        public object Item { get; set; }
        public IDictionary Data { get; set; }
    }
}
