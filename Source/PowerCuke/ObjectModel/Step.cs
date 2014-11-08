#region License

/*
    Copyright [2011] [Jeffrey Cameron]

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

#endregion

using System;
using System.Collections.Generic;
using System.Management.Automation;
using com.sun.tools.javac.util;

namespace PoshCode.PowerCuke.ObjectModel
{
    public class Step
    {
        public Keyword? Keyword { get; set; }
        public string NativeKeyword { get; set; }
        public string Name { get; set; }
        public Table TableArgument { get; set; }
        public string DocStringArgument { get; set; }

        public Step()
        {
            TableArgument = new Table();
        }

        public Step(Step other)
        {
            Keyword = other.Keyword;
            NativeKeyword = other.NativeKeyword;
            Name = other.Name;
            if (null != other.TableArgument)
            {
                TableArgument = new Table(other.TableArgument);
            }
            else
            {
                TableArgument = new Table();
            }
            DocStringArgument = other.DocStringArgument;
        }
    }
}