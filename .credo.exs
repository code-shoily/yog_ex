# This file contains the configuration for Credo.
#
# For more information, see: https://hexdocs.pm/credo/config_file.html

jump_tests = [
  {Jump.CredoChecks.AssertElementSelectorCanNeverFail, []},
  {Jump.CredoChecks.AvoidFunctionLevelElse, []},
  {Jump.CredoChecks.AvoidLoggerConfigureInTest, []},
  {Jump.CredoChecks.AvoidSocketAssignsInTest, excluded: ["test/app_web/plugs/"]},
  {Jump.CredoChecks.DoctestIExExamples,
   [
     derive_test_path: fn filename ->
       filename
       |> String.replace_leading("lib/", "test/")
       |> String.replace_trailing(".ex", "_test.exs")
     end
   ]},
  # {Jump.CredoChecks.ForbiddenFunction,
  #  functions: [
  #    {:erlang, :binary_to_term, "Use Plug.Crypto.non_executable_binary_to_term/2 instead."}
  #  ]},
  {Jump.CredoChecks.LiveViewFormCanBeRehydrated, excluded: []},
  {Jump.CredoChecks.PreferTextColumns, start_after: "20240101000000"},
  {Jump.CredoChecks.TestHasNoAssertions,
   custom_assertion_functions: [:await_has, :await_with_timeout]},
  {Jump.CredoChecks.TooManyAssertions, [max_assertions: 20]},
  {Jump.CredoChecks.TopLevelAliasImportRequire, []},
  {Jump.CredoChecks.UseObanProWorker, []},
  {Jump.CredoChecks.VacuousTest, []},
  {Jump.CredoChecks.WeakAssertion, []}
]

%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "src/"],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      plugins: [],
      requires: [],
      strict: false,
      parse_timeout: 5000,
      color: true,
      checks: jump_tests ++ [
        # Disable cyclomatic complexity check - graph algorithms are naturally complex
        {Credo.Check.Refactor.CyclomaticComplexity, false},
        {Credo.Check.Consistency.ExceptionNames, []},
        {Credo.Check.Consistency.LineEndings, []},
        {Credo.Check.Consistency.ParameterPatternMatching, []},
        {Credo.Check.Consistency.SpaceAroundOperators, []},
        {Credo.Check.Consistency.SpaceInParentheses, []},
        {Credo.Check.Consistency.TabsOrSpaces, []},
        {Credo.Check.Design.AliasUsage,
         [priority: :low, if_nested_deeper_than: 2, if_called_more_often_than: 0]},
        {Credo.Check.Design.DuplicatedCode, [nodes_threshold: 3]},
        {Credo.Check.Design.SkipTestWithoutComment, []},
        {Credo.Check.Readability.AliasOrder, []},
        {Credo.Check.Readability.FunctionNames, []},
        {Credo.Check.Readability.LargeNumbers, []},
        {Credo.Check.Readability.MaxLineLength, [priority: :low, max_length: 120]},
        {Credo.Check.Readability.ModuleAttributeNames, []},
        {Credo.Check.Readability.ModuleDoc, []},
        {Credo.Check.Readability.ModuleNames, []},
        {Credo.Check.Readability.ParenthesesInCondition, []},
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs, []},
        {Credo.Check.Refactor.FunctionArity, false},
        {Credo.Check.Readability.PredicateFunctionNames, []},
        {Credo.Check.Readability.PreferImplicitTry, []},
        {Credo.Check.Readability.RedundantBlankLines, []},
        {Credo.Check.Readability.Semicolons, []},
        {Credo.Check.Readability.SpaceAfterCommas, []},
        {Credo.Check.Readability.StringSigils, []},
        {Credo.Check.Readability.TrailingBlankLine, []},
        {Credo.Check.Readability.TrailingWhiteSpace, []},
        {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
        {Credo.Check.Readability.VariableNames, []},
        {Credo.Check.Readability.WithSingleClause, []},
        {Credo.Check.Refactor.ABCSize, false},
        {Credo.Check.Refactor.AppendSingleItem, []},
        {Credo.Check.Refactor.DoubleBooleanNegation, []},
        {Credo.Check.Refactor.FilterReject, []},
        {Credo.Check.Refactor.IoPuts, []},
        {Credo.Check.Refactor.MapJoin, []},
        {Credo.Check.Refactor.NegatedConditionsInUnless, []},
        {Credo.Check.Refactor.NegatedConditionsWithElse, []},
        {Credo.Check.Refactor.Nesting, [max_nesting: 5]},
        {Credo.Check.Refactor.RedundantWithClauseResult, []},
        {Credo.Check.Refactor.RejectFilter, []},
        {Credo.Check.Refactor.UnlessWithElse, []},
        {Credo.Check.Refactor.VariableRebinding, []},
        {Credo.Check.Refactor.WithClauses, []},
        {Credo.Check.Warning.ApplicationConfigInModuleAttribute, []},
        {Credo.Check.Warning.BoolOperationOnSameValues, []},
        {Credo.Check.Warning.ExpensiveEmptyEnumCheck, []},
        {Credo.Check.Warning.IExPry, []},
        {Credo.Check.Warning.IoInspect, []},
        {Credo.Check.Warning.MixEnv, []},
        {Credo.Check.Warning.OperationOnSameValues, []},
        {Credo.Check.Warning.OperationWithConstantResult, []},
        {Credo.Check.Warning.RaiseInsideRescue, []},
        {Credo.Check.Warning.SpecWithStruct, []},
        {Credo.Check.Warning.UnsafeExec, []},
        {Credo.Check.Warning.UnusedEnumOperation, []},
        {Credo.Check.Warning.UnusedFileOperation, []},
        {Credo.Check.Warning.UnusedKeywordOperation, []},
        {Credo.Check.Warning.UnusedListOperation, []},
        {Credo.Check.Warning.UnusedPathOperation, []},
        {Credo.Check.Warning.UnusedRegexOperation, []},
        {Credo.Check.Warning.UnusedStringOperation, []},
        {Credo.Check.Warning.UnusedTupleOperation, []},
        {Credo.Check.Warning.WrongTestFileExtension, []}
      ]
    }
  ]
}
