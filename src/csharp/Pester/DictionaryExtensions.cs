using System;
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
        // A value we cannot use is never intentional, so we say so instead of leaving the option on
        // its default and letting the run behave as if the option was never set (#2975). A key that
        // is present but null keeps meaning "not set", because that is how it has always worked and
        // it is how an unset variable arrives here (#2219).
        private static ConfigurationValueException NotUsable(string key, object value, string expected)
        {
            return new ConfigurationValueException($"{key} expects {expected}, but got {Describe(value)}.");
        }

        // Name the type the way it is written in PowerShell, and show the value itself only when it
        // is something worth printing. 'the string 'yes'' helps, 'the hashtable
        // 'System.Collections.Hashtable'' does not.
        private static string Describe(object value)
        {
            if (value is PSObject pso)
                value = pso.BaseObject;

            if (value == null)
                return "nothing";

            var name = TypeName(value.GetType());
            return value is string || value.GetType().IsPrimitive || value is decimal
                ? $"the {name} '{value}'"
                : $"a {name}";
        }

        private static string TypeName(Type type)
        {
            if (type == typeof(bool)) return "bool";
            if (type == typeof(int)) return "int";
            if (type == typeof(decimal)) return "decimal";
            if (type == typeof(string)) return "string";
            if (type == typeof(ScriptBlock)) return "scriptblock";
            if (type == typeof(Hashtable)) return "hashtable";
            if (type == typeof(ContainerInfo)) return "container";
            return type.Name;
        }

        private static string ExpectedValue(Type type)
        {
            var name = TypeName(type);
            return name == "int" ? "an int" : $"a {name}";
        }

        private static string ExpectedArray(Type type)
        {
            if (type == typeof(string)) return "an array of strings";
            if (type == typeof(ScriptBlock)) return "an array of scriptblocks";
            if (type == typeof(ContainerInfo)) return "an array of containers";
            return $"an array of {TypeName(type)}";
        }

        public static T? GetValueOrNull<T>(this IDictionary dictionary, string key) where T : struct
        {
            if (!dictionary.Contains(key))
                return null;

            var value = dictionary[key];
            if (value is null)
                return null;

            if (value is PSObject unwrapped)
                value = unwrapped.BaseObject;

            if (typeof(T) == typeof(decimal))
            {
                if (value is int or double)
                    return (T)Convert.ChangeType(value, typeof(decimal));
            }

            var converted = value as T?;
            if (converted == null)
                throw NotUsable(key, value, ExpectedValue(typeof(T)));

            return converted;
        }

        public static T GetObjectOrNull<T>(this IDictionary dictionary, string key) where T : class
        {
            if (!dictionary.Contains(key))
                return null;

            var value = dictionary[key];
            if (value is null)
                return null;

            if (typeof(T) == typeof(string))
                if (value is PSObject o)
                    return (T) Convert.ChangeType(o.ToString(), typeof(string));

            var converted = value as T;
            if (converted == null)
                throw NotUsable(key, value, ExpectedValue(typeof(T)));

            return converted;
        }

        public static IDictionary GetIDictionaryOrNull(this IDictionary dictionary, string key)
        {
            if (!dictionary.Contains(key))
                return null;

            var value = dictionary[key];
            if (value is null)
                return null;

            if (value is PSObject pso)
                value = pso.BaseObject;

            var converted = value as IDictionary;
            if (converted == null)
                throw NotUsable(key, value, "a dictionary of options");

            return converted;
        }

        public static T[] GetArrayOrNull<T>(this IDictionary dictionary, string key) where T : class
        {
            if (!dictionary.Contains(key) || dictionary[key] is null)
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
                if (value is PSObject o)
                    return new[] { (T)Convert.ChangeType(o.ToString(), typeof(string)) };

            if (value is IList v)
            {
                try
                {
                    var arr = new T[v.Count];

                    var i = 0;
                    foreach (var j in v)
                    {
                        if (j is T t)
                        {
                            arr[i] = t;
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

            throw NotUsable(key, value, ExpectedArray(typeof(T)));
        }

        public static void AssignValueIfNotNull<T>(this IDictionary dictionary, string key, Action<T> assign)
        where T : struct
        {
            var value = GetValueOrNull<T>(dictionary, key);
            if (value != null)
            {
                assign(value.Value);
            }
        }

        public static void AssignObjectIfNotNull<T>(this IDictionary dictionary, string key, Action<T> assign)
        where T : class
        {
            var value = GetObjectOrNull<T>(dictionary, key);
            if (value != null)
            {
                assign(value);
            }
        }

        public static void AssignArrayIfNotNull<T>(this IDictionary dictionary, string key, Action<T[]> assign)
        where T : class
        {
            var value = GetArrayOrNull<T>(dictionary, key);
            if (value != null)
            {
                assign(value);
            }
        }
    }
}
