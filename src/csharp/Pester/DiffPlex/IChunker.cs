using System.Collections.Generic;

namespace Pester.DiffPlex
{
    /// <summary>
    /// Responsible for how to turn the document into pieces
    /// </summary>
    public interface IChunker
    {
        /// <summary>
        /// Divide text into sub-parts
        /// </summary>
        IReadOnlyList<string> Chunk(string text);
    }
}