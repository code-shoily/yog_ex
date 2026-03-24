defmodule JobMatching do
  @moduledoc """
  Job Matching Example

  Demonstrates max flow for bipartite matching and assignment problems
  """

  require Yog

  def run do
    IO.puts("=== Job Matching with Max Flow ===\n")

    IO.puts("Candidates and their qualifications:")
    IO.puts("  Alice (1): Qualified for Software Engineer (5), Data Analyst (6)")
    IO.puts("  Bob (2): Qualified for Software Engineer (5), Project Manager (7)")
    IO.puts("  Carol (3): Qualified for Data Analyst (6), Designer (8)")
    IO.puts("  Dave (4): Qualified for Project Manager (7), Designer (8)\n")

    network =
      Yog.directed()
      |> Yog.add_edge!(from: 0, to: 1, with: 1)
      |> Yog.add_edge!(from: 0, to: 2, with: 1)
      |> Yog.add_edge!(from: 0, to: 3, with: 1)
      |> Yog.add_edge!(from: 0, to: 4, with: 1)
      |> Yog.add_edge!(from: 1, to: 5, with: 1)
      |> Yog.add_edge!(from: 1, to: 6, with: 1)
      |> Yog.add_edge!(from: 2, to: 5, with: 1)
      |> Yog.add_edge!(from: 2, to: 7, with: 1)
      |> Yog.add_edge!(from: 3, to: 6, with: 1)
      |> Yog.add_edge!(from: 3, to: 8, with: 1)
      |> Yog.add_edge!(from: 4, to: 7, with: 1)
      |> Yog.add_edge!(from: 4, to: 8, with: 1)
      |> Yog.add_edge!(from: 5, to: 9, with: 1)
      |> Yog.add_edge!(from: 6, to: 9, with: 1)
      |> Yog.add_edge!(from: 7, to: 9, with: 1)
      |> Yog.add_edge!(from: 8, to: 9, with: 1)

    result =
      Yog.Flow.MaxFlow.edmonds_karp(
        network,
        0,
        9,
        0,
        &(&1 + &2),
        fn a, b -> a - b end,
        fn a, b -> a <= b end,
        &min/2
      )

    IO.puts("Maximum matching: #{result.max_flow} people can be assigned to jobs")

    if result.max_flow == 4 do
      IO.puts("Perfect matching! All jobs can be filled.")
    else
      IO.puts("Only #{result.max_flow} jobs can be filled with qualified candidates.")
    end

    # Extract assignments from the residual graph
    candidates = [
      {1, "Alice"},
      {2, "Bob"},
      {3, "Carol"},
      {4, "Dave"}
    ]

    jobs = [
      {5, "Software Engineer"},
      {6, "Data Analyst"},
      {7, "Project Manager"},
      {8, "Designer"}
    ]

    IO.puts("\nAssignments:")
    assignments = extract_assignments(result.residual_graph, network, candidates, jobs)
    print_assignments(assignments)
  end

  defp extract_assignments(_residual, _original, [], _jobs), do: []

  defp extract_assignments(residual, original, [{candidate_id, candidate_name} | rest_candidates], jobs) do
    case find_assignment(residual, original, candidate_id, candidate_name, jobs) do
      {:ok, match} -> [match | extract_assignments(residual, original, rest_candidates, jobs)]
      {:error, _} -> extract_assignments(residual, original, rest_candidates, jobs)
    end
  end

  defp find_assignment(_residual, _original, _candidate_id, _candidate_name, []), do: {:error, nil}

  defp find_assignment(residual, original, candidate_id, candidate_name, [{job_id, job_name} | rest_jobs]) do
    # Get original capacity from the original graph
    original_capacity = get_edge_capacity(original, candidate_id, job_id)

    # Get residual capacity from the residual graph (which is a map)
    residual_capacity = Map.get(residual, {candidate_id, job_id}, 0)

    case {original_capacity, residual_capacity} do
      {1, 0} -> {:ok, {candidate_name, job_name}}
      _ -> find_assignment(residual, original, candidate_id, candidate_name, rest_jobs)
    end
  end

  defp get_edge_capacity(graph, from, to) do
    case Yog.successors(graph, from) do
      successors when is_list(successors) ->
        case List.keyfind(successors, to, 0) do
          {^to, weight} -> weight
          nil -> 0
        end

      _ ->
        0
    end
  end

  defp print_assignments([]), do: nil

  defp print_assignments([{candidate, job} | rest]) do
    IO.puts("  #{candidate} -> #{job}")
    print_assignments(rest)
  end
end

JobMatching.run()
