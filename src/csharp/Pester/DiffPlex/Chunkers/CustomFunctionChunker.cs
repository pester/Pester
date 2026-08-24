// Vendored from DiffPlex 1.9.0, https://github.com/mmanela/diffplex
// Copyright (c) Matthew Manela. Licensed under the Apache License, Version 2.0.
// See LICENSE.txt and VENDORING.md in this folder.
// Modified by the Pester Team: the namespace is Pester.DiffPlex instead of DiffPlex.
using System;
using System.Collections.Generic;

namespace Pester.DiffPlex.Chunkers
{
    public class CustomFunctionChunker: IChunker
    {
        private readonly Func<string, IReadOnlyList<string>> customChunkerFunc;

        public CustomFunctionChunker(Func<string, IReadOnlyList<string>> customChunkerFunc)
        {
            if (customChunkerFunc == null) throw new ArgumentNullException(nameof(customChunkerFunc));
            this.customChunkerFunc = customChunkerFunc;
        }

        public IReadOnlyList<string> Chunk(string text)
        {
            return customChunkerFunc(text);
        }
    }
}