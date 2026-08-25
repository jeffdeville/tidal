defmodule Tidal.Case do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      import Arena.Case, only: [wrap!: 1, wrap!: 2]
    end
  end

  setup tags do
    Arena.Case.setup_isolation(tags)
  end
end
