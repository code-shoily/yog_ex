defmodule Yog.Flow.MinCutResultTest do
  use ExUnit.Case, async: true
  alias Yog.Flow.MinCutResult
  doctest MinCutResult

  describe "constructors" do
    test "new/3" do
      result = MinCutResult.new(10, 2, 3)
      assert result.cut_value == 10
      assert result.source_side_size == 2
      assert result.sink_side_size == 3
      assert result.algorithm == :stoer_wagner
    end

    test "new/5" do
      s_side = MapSet.new([1, 2])
      t_side = MapSet.new([3, 4, 5])
      result = MinCutResult.new(15, 2, 3, s_side, t_side)
      assert result.cut_value == 15
      assert result.source_side == s_side
      assert result.sink_side == t_side
    end
  end

  describe "helpers" do
    test "total_nodes/1" do
      result = MinCutResult.new(10, 5, 5)
      assert MinCutResult.total_nodes(result) == 10
    end

    test "partition_product/1" do
      result = MinCutResult.new(10, 3, 4)
      assert MinCutResult.partition_product(result) == 12
    end
  end
end
