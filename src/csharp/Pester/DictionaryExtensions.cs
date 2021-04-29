﻿using System;
using System.Collections;
using System.Linq;
using System.Management.Automation;

// those types implement Pester configuration in a way that allows it to show information about each item
// in the powershell console without making it difficult to use. there are two tricks being used:
// - constructor taking IDictionary (most likely a hashtable) that will populate the object,
//   this allows the object to be constructed from a hashtable simply by casting to the type
//   both implicitly and explicitly, so the user does not have to care about what types are used
//   but will still get the benefit of the data annotation in the object. Usage is like this:
//   `$config.Debug = @{ WriteDebugMessages = $true; WriteDebugMessagesFrom = "Mock*" }`, which
//   will populate the config with the given values while keeping all other values to the default.
// - to be able to assign values like this: `$config.Should.ErrorAction = 'Continue'` but still
//   get the documentation when accessing the property, we use implicit casting to get an instance of
//   StringOption, and then populate it from the option object that is already assigned to the property
//
// lastly most of the types go to Pester namespace to keep them from the global namespace because they are
// simple to use by implicit casting, with the only exception of PesterConfiguration because that is helpful
// to have in "type accelerator" form, but without the hassle of actually adding it as a type accelerator
// that way you can easily do `[PesterConfiguration]::Default` and then inspect it, or cast a hashtable to it

namespace Pester
{
    internal static class DictionaryExtensions
    {
        public static T? GetValueOrNull<T>(this IDictionary dictionary, string key) where T : struct
        {
            return dictionary.Contains(key) ? dictionary[key] as T? : null;
        }

        public static T GetObjectOrNull<T>(this IDictionary dictionary, string key) where T : class
        {
            if (!dictionary.Contains(key))
                return null;

            if (typeof(T) == typeof(string))
                if (dictionary[key] is PSObject o)
                    return (T) Convert.ChangeType(o.ToString(), typeof(string));

            return dictionary[key] as T;
        }

        public static IDictionary GetIDictionaryOrNull(this IDictionary dictionary, string key)
        {
            return dictionary.Contains(key) ? dictionary[key] as IDictionary : null;
        }

        public static T[] GetArrayOrNull<T>(this IDictionary dictionary, string key) where T : class
        {
            if (!dictionary.Contains(key))
                return null;

            var value = dictionary[key];

            if (value.GetType() == typeof(T[]))
            {
                return (T[])value;
            }

            if (typeof(T) == typeof(string))
                if (value is PathInfo o)
                    return new[] { (T)Convert.ChangeType(o.ToString(), typeof(string)) };

            if (typeof(T) == typeof(string))
                if (dictionary[key] is PSObject o)
                    return new[] { (T)Convert.ChangeType(o.ToString(), typeof(string)) };

            if (value is object[] v)
            {
                try
                {
                    var arr = new T[v.Length];

                    var i = 0;
                    foreach (var j in v)
                    {
                        if (j is T)
                        {
                            arr[i] = (T) j;
                        }

                        if (j is PSObject || j is PathInfo)
                        {
                            if (typeof(T) == typeof(string))
                            {
                                arr[i] = (T)Convert.ChangeType(j.ToString(), typeof(string));
                            }                            
                        }
                        i++;
                    }
                    return arr;
                }
                catch { }
            }

            if (value.GetType() == typeof(T))
            {
                return new T[] { (T)value };
            }

            return null;
        }
    }
}
