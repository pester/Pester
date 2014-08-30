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


namespace PoshCode.PowerCuke.ObjectModel
{
    public class Scenario
    {
        public Scenario(Feature feature)
        {
            this.Steps = new List<Step>();
            this.Tags = new List<string>();
        }

        #region IFeatureElement Members

        public string Name { get; set; }
        public string Description { get; set; }
        public List<Step> Steps { get; set; }
        public List<string> Tags { get; set; }
        public TestResult Result { get; set; }
        public Feature Feature { get; set; }

        #endregion
    }
}