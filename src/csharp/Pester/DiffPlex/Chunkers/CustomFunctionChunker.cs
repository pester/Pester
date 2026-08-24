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