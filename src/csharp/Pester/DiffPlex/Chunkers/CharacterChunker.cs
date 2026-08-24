using System.Collections.Generic;

namespace Pester.DiffPlex.Chunkers
{
    public class CharacterChunker:IChunker
    {
        /// <summary>
        /// Gets the default singleton instance of the chunker.
        /// </summary>
        public static CharacterChunker Instance { get; } = new CharacterChunker();

        public IReadOnlyList<string> Chunk(string text)
        {
            var s = new string[text.Length];
            for (int i = 0; i < text.Length; i++) s[i] = text[i].ToString();
            return s;
        }
    }
}