defmodule YogStableMarriageTest do
  use ExUnit.Case

  alias Yog.Bipartite

  # Classic stable marriage problem - 3 men, 3 women
  test "classic_three_couples_test" do
    # Men's preferences (1, 2, 3 are men; 101, 102, 103 are women)
    men_prefs = %{
      1 => [101, 102, 103],
      2 => [102, 101, 103],
      3 => [101, 102, 103]
    }

    # Women's preferences
    women_prefs = %{
      101 => [2, 1, 3],
      102 => [1, 2, 3],
      103 => [1, 2, 3]
    }

    matching = Bipartite.stable_marriage(left_prefs: men_prefs, right_prefs: women_prefs)

    # Verify everyone is matched
    assert Map.has_key?(matching, 1)
    assert Map.has_key?(matching, 2)
    assert Map.has_key?(matching, 3)

    # Verify symmetry (if A is matched to B, then B is matched to A)
    partner_1 = Map.get(matching, 1)
    assert Map.get(matching, partner_1) == 1
  end

  # Verify stability: no blocking pair exists
  test "stability_check_test" do
    men_prefs = %{
      1 => [101, 102],
      2 => [102, 101]
    }

    women_prefs = %{
      101 => [2, 1],
      102 => [1, 2]
    }

    matching = Bipartite.stable_marriage(left_prefs: men_prefs, right_prefs: women_prefs)

    # Check all matches
    p1 = Map.get(matching, 1)
    p2 = Map.get(matching, 2)

    # Verify it's a valid matching (one of two possible stable matchings)
    # Either (1->102, 2->101) or (1->101, 2->102)
    case p1 do
      102 -> assert p2 == 101
      101 -> assert p2 == 102
      _ -> flunk("Invalid matching")
    end
  end

  # Single pair
  test "single_pair_test" do
    left_prefs = %{1 => [101]}
    right_prefs = %{101 => [1]}

    matching = Bipartite.stable_marriage(left_prefs: left_prefs, right_prefs: right_prefs)

    assert Map.get(matching, 1) == 101
    assert Map.get(matching, 101) == 1
  end

  # Empty preferences
  test "empty_preferences_test" do
    left_prefs = %{}
    right_prefs = %{}

    matching = Bipartite.stable_marriage(left_prefs: left_prefs, right_prefs: right_prefs)

    assert Map.get(matching, 1) == nil
  end

  # Medical residency matching (realistic example)
  test "medical_residency_test" do
    # 4 residents, 4 hospitals
    residents = %{
      1 => [101, 102, 103, 104],  # Resident 1 ranks hospitals
      2 => [102, 104, 101, 103],
      3 => [103, 101, 104, 102],
      4 => [104, 103, 102, 101]
    }

    hospitals = %{
      101 => [2, 1, 3, 4],  # Hospital 101 ranks residents
      102 => [1, 3, 2, 4],
      103 => [3, 4, 1, 2],
      104 => [4, 2, 3, 1]
    }

    matching = Bipartite.stable_marriage(left_prefs: residents, right_prefs: hospitals)

    # Everyone should be matched
    assert Map.has_key?(matching, 1)
    assert Map.has_key?(matching, 2)
    assert Map.has_key?(matching, 3)
    assert Map.has_key?(matching, 4)

    # Check bidirectionality
    h1 = Map.get(matching, 1)
    assert Map.get(matching, h1) == 1
  end

  # Unbalanced groups (more proposers than receivers)
  test "unbalanced_groups_test" do
    # 3 men but only 2 women
    men_prefs = %{
      1 => [101, 102],
      2 => [102, 101],
      3 => [101, 102]
    }

    women_prefs = %{
      101 => [1, 2, 3],
      102 => [2, 1, 3]
    }

    matching = Bipartite.stable_marriage(left_prefs: men_prefs, right_prefs: women_prefs)

    # Two men should be matched, one should not
    matched_count =
      [1, 2, 3]
      |> Enum.count(fn man -> Map.has_key?(matching, man) end)

    assert matched_count == 2
  end

  # Proposer optimal: men proposing ensures stable matching
  test "proposer_optimal_test" do
    # Setup with conflicting preferences
    men_prefs = %{
      1 => [101, 102, 103],
      2 => [101, 102, 103],
      3 => [101, 102, 103]
    }

    # Women prefer in opposite order
    women_prefs = %{
      101 => [3, 2, 1],
      102 => [3, 2, 1],
      103 => [3, 2, 1]
    }

    matching = Bipartite.stable_marriage(left_prefs: men_prefs, right_prefs: women_prefs)

    # The unique stable matching has women getting their top choices
    # (Since they're "choosing" among proposers)
    assert Map.get(matching, 101) == 3
    assert Map.get(matching, 102) == 2
    assert Map.get(matching, 103) == 1

    # Everyone should be matched
    assert Map.has_key?(matching, 1)
    assert Map.has_key?(matching, 2)
    assert Map.has_key?(matching, 3)
  end

  # All prefer same person (contention)
  test "high_contention_test" do
    men_prefs = %{
      1 => [101, 102, 103],
      2 => [101, 102, 103],
      3 => [101, 102, 103]
    }

    women_prefs = %{
      101 => [1, 2, 3],
      102 => [1, 2, 3],
      103 => [1, 2, 3]
    }

    matching = Bipartite.stable_marriage(left_prefs: men_prefs, right_prefs: women_prefs)

    # Everyone should eventually be matched (even if not to first choice)
    assert Map.has_key?(matching, 1)
    assert Map.has_key?(matching, 2)
    assert Map.has_key?(matching, 3)

    # All three women should be matched
    assert Map.has_key?(matching, 101)
    assert Map.has_key?(matching, 102)
    assert Map.has_key?(matching, 103)
  end

  # Verify no duplicates in matching
  test "no_duplicate_matches_test" do
    men_prefs = %{
      1 => [101, 102],
      2 => [101, 102],
      3 => [102, 101]
    }

    women_prefs = %{
      101 => [1, 2, 3],
      102 => [2, 3, 1]
    }

    matching = Bipartite.stable_marriage(left_prefs: men_prefs, right_prefs: women_prefs)

    # Get all men's partners
    partners =
      [1, 2, 3]
      |> Enum.filter_map(
        fn man -> Map.has_key?(matching, man) end,
        fn man -> Map.get(matching, man) end
      )

    # Should have no duplicates
    unique_partners = MapSet.size(MapSet.new(partners))
    total_partners = length(partners)

    assert unique_partners == total_partners
  end

  # Incomplete preferences (not everyone ranks everyone)
  test "incomplete_preferences_test" do
    # Man 1 only wants woman 101, won't accept 102
    men_prefs = %{
      1 => [101],
      2 => [101, 102]
    }

    women_prefs = %{
      101 => [2, 1],
      102 => [2]
    }

    matching = Bipartite.stable_marriage(left_prefs: men_prefs, right_prefs: women_prefs)

    # Man 1 might not be matched if woman 101 prefers man 2
    # But man 2 should be matched
    assert Map.has_key?(matching, 2)
  end

  # Large instance (10 couples)
  test "large_instance_test" do
    men_prefs = %{
      1 => [101, 102, 103, 104, 105, 106, 107, 108, 109, 110],
      2 => [102, 101, 103, 104, 105, 106, 107, 108, 109, 110],
      3 => [103, 102, 101, 104, 105, 106, 107, 108, 109, 110],
      4 => [104, 103, 102, 101, 105, 106, 107, 108, 109, 110],
      5 => [105, 104, 103, 102, 101, 106, 107, 108, 109, 110],
      6 => [106, 105, 104, 103, 102, 101, 107, 108, 109, 110],
      7 => [107, 106, 105, 104, 103, 102, 101, 108, 109, 110],
      8 => [108, 107, 106, 105, 104, 103, 102, 101, 109, 110],
      9 => [109, 108, 107, 106, 105, 104, 103, 102, 101, 110],
      10 => [110, 109, 108, 107, 106, 105, 104, 103, 102, 101]
    }

    women_prefs = %{
      101 => [10, 9, 8, 7, 6, 5, 4, 3, 2, 1],
      102 => [9, 10, 8, 7, 6, 5, 4, 3, 2, 1],
      103 => [8, 9, 10, 7, 6, 5, 4, 3, 2, 1],
      104 => [7, 8, 9, 10, 6, 5, 4, 3, 2, 1],
      105 => [6, 7, 8, 9, 10, 5, 4, 3, 2, 1],
      106 => [5, 6, 7, 8, 9, 10, 4, 3, 2, 1],
      107 => [4, 5, 6, 7, 8, 9, 10, 3, 2, 1],
      108 => [3, 4, 5, 6, 7, 8, 9, 10, 2, 1],
      109 => [2, 3, 4, 5, 6, 7, 8, 9, 10, 1],
      110 => [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    }

    matching = Bipartite.stable_marriage(left_prefs: men_prefs, right_prefs: women_prefs)

    # All 10 men should be matched
    for man <- [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] do
      assert Map.has_key?(matching, man)
    end

    # All 10 women should be matched
    for woman <- [101, 102, 103, 104, 105, 106, 107, 108, 109, 110] do
      assert Map.has_key?(matching, woman)
    end
  end

  # Query non-existent person
  test "query_non_existent_test" do
    men_prefs = %{1 => [101]}
    women_prefs = %{101 => [1]}

    matching = Bipartite.stable_marriage(left_prefs: men_prefs, right_prefs: women_prefs)

    assert Map.get(matching, 999) == nil
  end
end
