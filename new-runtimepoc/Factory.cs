using System.Management.Automation;
using System.Collections.Generic;


namespace Pester {
    ///<summary>Creates various types to avoid using New-Object cmdlet</summary>
    ///
    public static class Factory {
        public static PSNoteProperty CreateNoteProperty(string name, object value) {
            return new PSNoteProperty(name, value);
        }

        public static Dictionary<string, object> CreateDictionary() {
            return new Dictionary<string, object>();
        }
    }
}
