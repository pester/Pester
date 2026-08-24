// Vendored from DiffPlex 1.9.0, https://github.com/mmanela/diffplex
// Copyright (c) Matthew Manela. Licensed under the Apache License, Version 2.0.
// See LICENSE.txt and VENDORING.md in this folder.
// Modified by the Pester Team: the namespace is Pester.DiffPlex instead of DiffPlex.
using System;
using System.Collections.Generic;

namespace Pester.DiffPlex.Chunkers
{
    public class LineChunker:IChunker
    {
        private readonly string[] lineSeparators = new[] {"\r\n", "\r", "\n"};

        /// <summary>
        /// Gets the default singleton instance of the chunker.
        /// </summary>
        public static LineChunker Instance { get; } = new LineChunker();

        public IReadOnlyList<string> Chunk(string text)
        {
            return text.Split(lineSeparators, StringSplitOptions.None);
        }
    }
}