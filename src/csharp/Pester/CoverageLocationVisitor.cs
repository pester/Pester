using System.Collections.Generic;
using System.Diagnostics.CodeAnalysis;
using System.Management.Automation.Language;

namespace Pester
{
    public class CoverageVisitor : AstVisitor2
    {
        public readonly List<Ast> CoverageLocations = [];

        public override AstVisitAction VisitScriptBlock(ScriptBlockAst scriptBlockAst)
        {
            if (scriptBlockAst.ParamBlock?.Attributes != null)
            {
                foreach (var attribute in scriptBlockAst.ParamBlock.Attributes)
                {
                    if (attribute.TypeName.GetReflectionType() == typeof(ExcludeFromCodeCoverageAttribute))
                    {
                        return AstVisitAction.SkipChildren;
                    }
                }
            }
            return AstVisitAction.Continue;
        }

        public override AstVisitAction VisitCommand(CommandAst commandAst)
        {
            CoverageLocations.Add(commandAst);
            return AstVisitAction.Continue;
        }

        public override AstVisitAction VisitCommandExpression(CommandExpressionAst commandExpressionAst)
        {
            CoverageLocations.Add(commandExpressionAst);
            return AstVisitAction.Continue;
        }

        public override AstVisitAction VisitDynamicKeywordStatement(DynamicKeywordStatementAst dynamicKeywordStatementAst)
        {
            CoverageLocations.Add(dynamicKeywordStatementAst);
            return AstVisitAction.Continue;
        }

        public override AstVisitAction VisitBreakStatement(BreakStatementAst breakStatementAst)
        {
            CoverageLocations.Add(breakStatementAst);
            return AstVisitAction.Continue;
        }

        public override AstVisitAction VisitContinueStatement(ContinueStatementAst continueStatementAst)
        {
            CoverageLocations.Add(continueStatementAst);
            return AstVisitAction.Continue;
        }

        public override AstVisitAction VisitExitStatement(ExitStatementAst exitStatementAst)
        {
            CoverageLocations.Add(exitStatementAst);
            return AstVisitAction.Continue;
        }

        public override AstVisitAction VisitThrowStatement(ThrowStatementAst throwStatementAst)
        {
            CoverageLocations.Add(throwStatementAst);
            return AstVisitAction.Continue;
        }

        // ReturnStatementAst is excluded as it's not behaving consistent.
        // "return" is not hit in 5.1 but fixed in a later version. Using "return 123" we get hit on 123 but not return.
        // See https://github.com/pester/Pester/issues/1465#issuecomment-604323645
    }
}
