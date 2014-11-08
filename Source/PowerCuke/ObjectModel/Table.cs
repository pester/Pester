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
using System.Dynamic;
using System.Linq;
using System.Management.Automation;
using gherkin.lexer;
using java.util;
using Hashtable = System.Collections.Hashtable;

namespace PoshCode.PowerCuke.ObjectModel
{
    public class Table : List<PSObject>
    {
        private string[] _headers;
        public void Add(List cells)
        {
            string[] values = cells.toArray().Select(cell => cell.ToString()).ToArray();
            if (this._headers == null)
            {
                this._headers = values;
            }
            else
            {
                var row = new PSObject();
                for (int c = 0; c < values.Length; c++)
                {
                    row.Properties.Add(new PSNoteProperty(_headers[c], values[c]));
                }
                this.Add(row);
            }
        }

        public Table(){}

        public Table(IEnumerable<PSObject> rows) : base(rows) {}
    }
}