defmodule TidalTest do
  use ExUnit.Case, async: true

  test "application starts successfully" do
    assert Application.started_applications()
           |> Enum.any?(fn {app, _, _} -> app == :tidal end)
  end
end
