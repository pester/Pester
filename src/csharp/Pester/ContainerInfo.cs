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

        private string _type = Constants.File;
        public string Type
        {
            get => _type;
            set => Container.SetContainerType(ref _type, value);
        }
        public object Item { get; set; }
        public object Data { get; set; }

        public override string ToString()
        {
            return ToStringConverter.ContainerInfoToString(this);
        }
    }
}
