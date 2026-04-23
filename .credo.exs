%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ~w[config lib priv test],
        excluded: []
      },
      strict: true,
      color: true,
      checks: [
        {Credo.Check.Design.TagTODO, [exit_status: 0]},
        {Credo.Check.Readability.MaxLineLength, max_length: 120},
        {Credo.Check.Refactor.LongQuoteBlocks, [ignore_comments: true]}
      ]
    }
  ]
}
