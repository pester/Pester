using Pester.DiffPlex.DiffBuilder.Model;

namespace Pester.DiffPlex.DiffBuilder
{
    /// <summary>
    /// Provides methods that generate differences between texts for displaying in a side by side view.
    /// </summary>
    public interface ISideBySideDiffBuilder
    {
        /// <summary>
        /// Builds a diff model for displaying diffs in a side by side view
        /// </summary>
        /// <param name="oldText">The old text.</param>
        /// <param name="newText">The new text.</param>
        /// <returns>The side by side diff model</returns>
        SideBySideDiffModel BuildDiffModel(string oldText, string newText);
    }
}