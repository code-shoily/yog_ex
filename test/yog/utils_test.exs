defmodule Yog.UtilsTest do
  use ExUnit.Case

  alias Yog.Utils

  doctest Yog.Utils

  describe "to_label/2" do
    test "returns string data directly" do
      assert Utils.to_label(1, "Alice") == "Alice"
    end

    test "returns integer data as string" do
      assert Utils.to_label(1, 42) == "42"
    end

    test "returns atom data as string" do
      assert Utils.to_label(1, :active) == "active"
    end

    test "returns label key from map with string key" do
      assert Utils.to_label(1, %{"label" => "Alice", "age" => 30}) == "Alice"
    end

    test "returns label key from map with atom key" do
      assert Utils.to_label(1, %{label: "Alice", age: 30}) == "Alice"
    end

    test "falls back to node id for empty map" do
      assert Utils.to_label(1, %{}) == "1"
      assert Utils.to_label(:start, %{}) == "start"
    end

    test "falls back to node id for nil data" do
      assert Utils.to_label(1, nil) == "1"
    end

    test "falls back to node id for empty string" do
      assert Utils.to_label(1, "") == "1"
    end

    test "prefers string label key over atom label key" do
      assert Utils.to_label(1, %{"label" => "string", label: "atom"}) == "string"
    end

    test "returns node id when map has no label key" do
      assert Utils.to_label(1, %{"name" => "Alice"}) == "1"
    end
  end

  describe "to_weight_label/1" do
    test "returns integer weight as string" do
      assert Utils.to_weight_label(5) == "5"
    end

    test "returns string weight directly" do
      assert Utils.to_weight_label("heavy") == "heavy"
    end

    test "returns weight key from map with string key" do
      assert Utils.to_weight_label(%{"weight" => "10", "type" => "road"}) == "10"
    end

    test "returns weight key from map with atom key" do
      assert Utils.to_weight_label(%{weight: "10", type: "road"}) == "10"
    end

    test "returns label key when weight key is missing" do
      assert Utils.to_weight_label(%{"label" => "friend"}) == "friend"
    end

    test "returns atom label key when weight key is missing" do
      assert Utils.to_weight_label(%{label: "friend"}) == "friend"
    end

    test "returns empty string for empty map" do
      assert Utils.to_weight_label(%{}) == ""
    end

    test "returns empty string for nil" do
      assert Utils.to_weight_label(nil) == ""
    end

    test "prefers string weight over atom weight" do
      assert Utils.to_weight_label(%{"weight" => "str", weight: "atom"}) == "str"
    end

    test "prefers weight over label when both present" do
      assert Utils.to_weight_label(%{"weight" => "10", "label" => "5"}) == "10"
    end
  end

  describe "compare/2" do
    test "compares integers" do
      assert Utils.compare(10, 20) == :lt
      assert Utils.compare(20, 20) == :eq
      assert Utils.compare(30, 20) == :gt
    end

    test "compares floats" do
      assert Utils.compare(1.5, 3.2) == :lt
      assert Utils.compare(2.0, 2.0) == :eq
      assert Utils.compare(3.5, 1.0) == :gt
    end

    test "compares mixed integers and floats" do
      assert Utils.compare(1, 2.5) == :lt
      assert Utils.compare(2.0, 2) == :eq
      assert Utils.compare(3, 1.5) == :gt
    end
  end

  describe "compare_desc/2" do
    test "reverse compares numbers" do
      assert Utils.compare_desc(100, 50) == :lt
      assert Utils.compare_desc(50, 100) == :gt
      assert Utils.compare_desc(100, 100) == :eq
    end

    test "handles infinity" do
      assert Utils.compare_desc(:infinity, 100) == :lt
      assert Utils.compare_desc(100, :infinity) == :gt
      assert Utils.compare_desc(:infinity, :infinity) == :eq
    end
  end

  describe "fisher_yates/2" do
    test "shuffles deterministically with seed" do
      assert Utils.fisher_yates([1, 2, 3, 4, 5], 42) == [3, 2, 5, 4, 1]
    end

    test "returns empty list for empty input" do
      assert Utils.fisher_yates([], 123) == []
    end

    test "returns single element" do
      assert Utils.fisher_yates([42], 123) == [42]
    end
  end

  describe "combinations/2" do
    test "generates all k-combinations" do
      assert Utils.combinations([1, 2, 3], 2) == [[1, 2], [1, 3], [2, 3]]
    end

    test "returns empty combination for k=0" do
      assert Utils.combinations([1, 2, 3], 0) == [[]]
    end

    test "returns empty list when k > length" do
      assert Utils.combinations([1, 2], 3) == []
    end
  end

  describe "map_fold/3" do
    test "folds over map" do
      map = %{a: 1, b: 2, c: 3}
      result = Utils.map_fold(map, 0, fn _k, v, acc -> acc + v end)
      assert result == 6
    end

    test "transforms map" do
      map = %{a: 1, b: 2}
      result = Utils.map_fold(map, %{}, fn k, v, acc -> Map.put(acc, k, v * 2) end)
      assert result == %{a: 2, b: 4}
    end
  end

  describe "norm_diff/3" do
    test "computes l1 norm" do
      assert Utils.norm_diff(%{a: 1, b: 2}, %{a: 3, b: 4}, :l1) == 4.0
    end

    test "computes l2 norm" do
      result = Utils.norm_diff(%{a: 1, b: 2}, %{a: 3, b: 4}, :l2)
      assert_in_delta result, 2.828, 0.001
    end

    test "computes max norm" do
      assert Utils.norm_diff(%{a: 1.1, b: 2}, %{a: 3, b: 4}, :max) == 2.0
    end
  end
end
