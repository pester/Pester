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

        public string Type { get; set; } = "File";
        public object Item { get; set; }
        public object Data { get; set; }

        public override string ToString()
        {
            return ToStringConverter.ContainerInfoToString(this);
        }
    }
}
