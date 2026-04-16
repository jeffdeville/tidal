# synced_from_colony: true
# sync_pack: elixir
# sync_source: packs/elixir/.credo.exs
# sync_version: d3fefcef
alias Credo.Check.Design.TagFIXME
alias Credo.Check.Design.TagTODO
alias Credo.Check.Refactor.ABCSize
alias Credo.Check.Refactor.CondStatements
alias Credo.Check.Refactor.CyclomaticComplexity
alias Credo.Check.Refactor.FilterCount
alias Credo.Check.Refactor.FilterFilter
alias Credo.Check.Refactor.FunctionArity
alias Credo.Check.Refactor.LongQuoteBlocks
alias Credo.Check.Refactor.Nesting
alias Credo.Check.Refactor.RedundantWithClauseResult
alias Credo.Check.Refactor.WithClauses
alias Credo.Check.Warning.Dbg
alias Credo.Check.Warning.IExPry
alias Credo.Check.Warning.IoInspect
alias ProjectChecks.FunctionLength
alias ProjectChecks.ModuleLength
alias ProjectChecks.NoBareMapParams
alias ProjectChecks.NoNestedControlFlow

%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/", "checks/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      plugins: [],
      requires: [
        "checks/no_nested_control_flow.ex",
        "checks/no_bare_map_params.ex",
        "checks/module_length.ex",
        "checks/function_length.ex"
      ],
      strict: false,
      parse_timeout: 5000,
      color: true,
      checks: %{
        enabled: [
          {Credo.Check.Consistency.ExceptionNames, []},
          {Credo.Check.Consistency.LineEndings, []},
          {Credo.Check.Consistency.ParameterPatternMatching, []},
          {Credo.Check.Consistency.SpaceAroundOperators, []},
          {Credo.Check.Consistency.SpaceInParentheses, []},
          {Credo.Check.Consistency.TabsOrSpaces, []},
          {Credo.Check.Design.AliasUsage, [priority: :low, if_nested_deeper_than: 2, if_called_more_often_than: 0]},
          {TagFIXME, []},
          {TagTODO, [exit_status: 2]},
          {Credo.Check.Readability.FunctionNames, []},
          {Credo.Check.Readability.LargeNumbers, []},
          {Credo.Check.Readability.MaxLineLength, [priority: :low, max_length: 120]},
          {Credo.Check.Readability.ModuleAttributeNames, []},
          {Credo.Check.Readability.ModuleNames, []},
          {Credo.Check.Readability.ParenthesesInCondition, []},
          {Credo.Check.Readability.PipeIntoAnonymousFunctions, []},
          {Credo.Check.Readability.PredicateFunctionNames, []},
          {Credo.Check.Readability.PreferImplicitTry, []},
          {Credo.Check.Readability.Semicolons, []},
          {Credo.Check.Readability.SpaceAfterCommas, []},
          {Credo.Check.Readability.StringSigils, []},
          {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
          {Credo.Check.Readability.VariableNames, []},
          {Credo.Check.Readability.WithSingleClause, []},
          {ABCSize, []},
          {Credo.Check.Refactor.Apply, []},
          {CondStatements, []},
          {CyclomaticComplexity, [max_complexity: 9]},
          {FilterCount, []},
          {FilterFilter, []},
          {FunctionArity, []},
          {LongQuoteBlocks, []},
          {Credo.Check.Refactor.MapJoin, []},
          {Credo.Check.Refactor.MatchInCondition, []},
          {Credo.Check.Refactor.NegatedConditionsInUnless, []},
          {Credo.Check.Refactor.NegatedConditionsWithElse, []},
          {Nesting, [max_nesting: 3]},
          {RedundantWithClauseResult, []},
          {Credo.Check.Refactor.RejectReject, []},
          {Credo.Check.Refactor.UnlessWithElse, []},
          {WithClauses, []},
          {Credo.Check.Warning.ApplicationConfigInModuleAttribute, []},
          {Credo.Check.Warning.BoolOperationOnSameValues, []},
          {Dbg, []},
          {Credo.Check.Warning.ExpensiveEmptyEnumCheck, []},
          {IExPry, []},
          {IoInspect, []},
          {Credo.Check.Warning.MissedMetadataKeyInLoggerConfig, []},
          {Credo.Check.Warning.OperationOnSameValues, []},
          {Credo.Check.Warning.OperationWithConstantResult, []},
          {Credo.Check.Warning.RaiseInsideRescue, []},
          {Credo.Check.Warning.SpecWithStruct, []},
          {Credo.Check.Warning.StructFieldAmount, []},
          {Credo.Check.Warning.UnsafeExec, []},
          {Credo.Check.Warning.UnusedEnumOperation, []},
          {Credo.Check.Warning.UnusedFileOperation, []},
          {Credo.Check.Warning.UnusedKeywordOperation, []},
          {Credo.Check.Warning.UnusedListOperation, []},
          {Credo.Check.Warning.UnusedMapOperation, []},
          {Credo.Check.Warning.UnusedPathOperation, []},
          {Credo.Check.Warning.UnusedRegexOperation, []},
          {Credo.Check.Warning.UnusedStringOperation, []},
          {Credo.Check.Warning.UnusedTupleOperation, []},
          {Credo.Check.Warning.WrongTestFileExtension, []},
          {NoNestedControlFlow, []},
          {NoBareMapParams, []},
          {ModuleLength, [max_lines: 300]},
          {FunctionLength, [max_lines: 20]}
        ],
        disabled: [
          {Credo.Check.Refactor.UtcNowTruncate, []},
          {Credo.Check.Consistency.MultiAliasImportRequireUse, []},
          {Credo.Check.Consistency.UnusedVariableNames, []},
          {Credo.Check.Design.DuplicatedCode, []},
          {Credo.Check.Design.SkipTestWithoutComment, []},
          {Credo.Check.Readability.AliasAs, []},
          {Credo.Check.Readability.BlockPipe, []},
          {Credo.Check.Readability.ImplTrue, []},
          {Credo.Check.Readability.MultiAlias, []},
          {Credo.Check.Readability.NestedFunctionCalls, []},
          {Credo.Check.Readability.OneArityFunctionInPipe, []},
          {Credo.Check.Readability.OnePipePerLine, []},
          {Credo.Check.Readability.SeparateAliasRequire, []},
          {Credo.Check.Readability.SingleFunctionToBlockPipe, []},
          {Credo.Check.Readability.SinglePipe, []},
          {Credo.Check.Readability.Specs, []},
          {Credo.Check.Readability.StrictModuleLayout, []},
          {Credo.Check.Readability.WithCustomTaggedTuple, []},
          {Credo.Check.Refactor.AppendSingleItem, []},
          {Credo.Check.Refactor.DoubleBooleanNegation, []},
          {Credo.Check.Refactor.FilterReject, []},
          {Credo.Check.Refactor.IoPuts, []},
          {Credo.Check.Refactor.MapMap, []},
          {Credo.Check.Refactor.ModuleDependencies, []},
          {Credo.Check.Refactor.NegatedIsNil, []},
          {Credo.Check.Refactor.PassAsyncInTestCases, []},
          {Credo.Check.Refactor.PipeChainStart, []},
          {Credo.Check.Refactor.RejectFilter, []},
          {Credo.Check.Refactor.VariableRebinding, []},
          {Credo.Check.Warning.LazyLogging, []},
          {Credo.Check.Warning.LeakyEnvironment, []},
          {Credo.Check.Warning.MapGetUnsafePass, []},
          {Credo.Check.Warning.MixEnv, []},
          {Credo.Check.Warning.UnsafeToAtom, []}
        ]
      }
    },
    %{
      name: "refactor",
      files: %{
        included: ["lib/", "test/", "checks/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      plugins: [],
      requires: [
        "checks/no_nested_control_flow.ex",
        "checks/no_bare_map_params.ex",
        "checks/module_length.ex",
        "checks/function_length.ex"
      ],
      strict: true,
      parse_timeout: 5000,
      color: true,
      checks: %{
        enabled: [
          {CyclomaticComplexity, [max_complexity: 6]},
          {Nesting, [max_nesting: 2]},
          {FunctionArity, [max_arity: 4]},
          {ABCSize, [max_size: 20]},
          {ModuleLength, [max_lines: 200]},
          {FunctionLength, [max_lines: 15]},
          {NoNestedControlFlow, [priority: :normal]},
          {NoBareMapParams, [priority: :normal]},
          {CondStatements, []},
          {FilterCount, []},
          {FilterFilter, []},
          {LongQuoteBlocks, []},
          {RedundantWithClauseResult, []},
          {WithClauses, []},
          {Dbg, []},
          {IoInspect, []},
          {IExPry, []},
          {TagFIXME, []},
          {TagTODO, [exit_status: 0]}
        ],
        disabled: []
      }
    }
  ]
}
