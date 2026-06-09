defmodule Yog.Oracle.CommunityQualityTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  alias Yog.Community.{Louvain, Metrics}
  alias Yog.Generator.Random

  describe "Louvain quality floor" do
    property "Louvain achieves NMI ≥ 0.85 on well-separated SBM" do
      check all(
              seed <- StreamData.integer(1..1_000_000),
              max_runs: 50
            ) do
        {graph, ground_truth} =
          Random.sbm_with_labels(180, 3, 0.30, 0.01, seed: seed)

        detected = Louvain.detect(graph)
        nmi = Metrics.nmi(detected.assignments, ground_truth)

        assert nmi >= 0.85,
               "Louvain NMI #{Float.round(nmi, 4)} below floor 0.85 (seed=#{seed}). " <>
                 "This regression is what the OTP-28 unmask exposed; " <>
                 "if seen, check whether phase 2+ ran."
      end
    end
  end
end
