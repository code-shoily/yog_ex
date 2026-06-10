defmodule Yog.Community.QualityTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  alias Yog.Community.Metrics
  alias Yog.Generator.Random

  describe "Louvain quality floor" do
    # P-QUAL-COMM-001 — Lancichinetti & Fortunato, PRE 80, 056117 (2009)
    property "Louvain achieves NMI ≥ 0.85 on well-separated SBM" do
      check all(
              seed <- StreamData.integer(1..1_000_000),
              max_runs: 50
            ) do
        {graph, ground_truth} =
          Random.sbm_with_labels(180, 3, 0.30, 0.01, seed: seed)

        # Run with multiple random seeds and take the best NMI.
        # Louvain is sensitive to node ordering; a single bad seed can
        # trap the algorithm in a poor local optimum.
        nmi =
          for algo_seed <- 1..5 do
            detected = Yog.Community.Louvain.detect_with_options(graph, seed: algo_seed)
            Metrics.nmi(detected.assignments, ground_truth)
          end
          |> Enum.max()

        assert nmi >= 0.85,
               "Louvain NMI #{Float.round(nmi, 4)} below floor 0.85 (seed=#{seed}). " <>
                 "This regression is what the OTP-28 unmask exposed; " <>
                 "if seen, check whether phase 2+ ran."
      end
    end
  end

  describe "Leiden quality floor" do
    # P-QUAL-COMM-002 — Traag, Waltman, van Eck, Sci. Rep. 9, 5233 (2019)
    property "Leiden achieves NMI ≥ 0.85 on well-separated SBM" do
      check all(
              seed <- StreamData.integer(1..1_000_000),
              max_runs: 50
            ) do
        {graph, ground_truth} =
          Random.sbm_with_labels(180, 3, 0.30, 0.01, seed: seed)

        # Run with multiple random seeds and take the best NMI.
        nmi =
          for algo_seed <- 1..5 do
            detected = Yog.Community.Leiden.detect_with_options(graph, seed: algo_seed)
            Metrics.nmi(detected.assignments, ground_truth)
          end
          |> Enum.max()

        assert nmi >= 0.85,
               "Leiden NMI #{Float.round(nmi, 4)} below floor 0.85 (seed=#{seed})"
      end
    end
  end

  describe "Label Propagation quality floor" do
    # P-QUAL-COMM-003 — Cordasco & Gargano, IPCCC 2010
    property "Label Propagation achieves NMI ≥ 0.70 on well-separated SBM" do
      check all(
              seed <- StreamData.integer(1..1_000_000),
              max_runs: 50
            ) do
        {graph, ground_truth} =
          Random.sbm_with_labels(180, 3, 0.30, 0.01, seed: seed)

        # Run with multiple random seeds and take the best NMI.
        nmi =
          for algo_seed <- 1..5 do
            detected = Yog.Community.LabelPropagation.detect_with_options(graph, seed: algo_seed)
            Metrics.nmi(detected.assignments, ground_truth)
          end
          |> Enum.max()

        # LPA is inherently unstable; 0.70 is a pragmatic floor that catches
        # major regressions without false positives from random instability.
        assert nmi >= 0.70,
               "Label Propagation NMI #{Float.round(nmi, 4)} below floor 0.70 (seed=#{seed})"
      end
    end
  end
end
