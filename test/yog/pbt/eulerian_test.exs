defmodule Yog.PBT.EulerianTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Yog.Generators

  describe "Property Properties: Eulerian" do
    property "Eulerian properties act consistently" do
      check all(graph <- undirected_graph_gen()) do
        case Yog.Property.Eulerian.eulerian_circuit(graph) do
          {:ok, circuit} ->
            assert Yog.Property.Eulerian.has_eulerian_circuit?(graph)
            assert length(circuit) >= 1
            assert List.first(circuit) == List.last(circuit)

          {:error, :no_eulerian_circuit} ->
            refute Yog.Property.Eulerian.has_eulerian_circuit?(graph)
        end

        case Yog.Property.Eulerian.eulerian_path(graph) do
          {:ok, path} ->
            assert Yog.Property.Eulerian.has_eulerian_path?(graph)
            assert length(path) >= 1

          {:error, :no_eulerian_path} ->
            refute Yog.Property.Eulerian.has_eulerian_path?(graph)
        end
      end
    end
  end
end
