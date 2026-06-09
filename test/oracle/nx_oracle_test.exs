defmodule Yog.Oracle.NetworkXTest do
  use ExUnit.Case, async: true

  alias Yog.Oracle.NetworkX

  describe "adapter_health/0" do
    test "passes all 10 round-trip self-tests" do
      assert :ok = NetworkX.adapter_health()
    end
  end
end
