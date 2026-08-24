namespace Pester.DiffPlex.Chunkers
{
    public class WordChunker:DelimiterChunker
    {
        private static char[] WordSeparators { get; } = { ' ', '\t', '.', '(', ')', '{', '}', ',', '!', '?', ';' };

        /// <summary>
        /// Gets the default singleton instance of the chunker.
        /// </summary>
        public static WordChunker Instance { get; } = new WordChunker();

        public WordChunker() : base(WordSeparators)
        {
        }
    }
}