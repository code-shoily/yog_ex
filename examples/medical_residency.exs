defmodule MedicalResidency do
  @moduledoc """
  Medical Residency Matching Example

  Demonstrates stable marriage matching using Gale-Shapley algorithm
  """

  require Yog

  def run do
    IO.puts("--- Medical Residency Matching (NRMP Style) ---")
    IO.puts("")

    residents = %{
      1 => [101, 102, 103, 104, 105],
      2 => [102, 105, 101, 103, 104],
      3 => [103, 101, 104, 102, 105],
      4 => [104, 103, 105, 102, 101],
      5 => [105, 104, 103, 102, 101]
    }

    hospitals = %{
      101 => [3, 1, 2, 4, 5],
      102 => [1, 2, 5, 3, 4],
      103 => [3, 4, 1, 2, 5],
      104 => [4, 5, 3, 2, 1],
      105 => [5, 2, 4, 3, 1]
    }

    IO.puts("Resident Preferences:")
    IO.puts("  Dr. Anderson (1): City General, Metro, University, Regional, Coastal")
    IO.puts("  Dr. Brown (2):    Metro, Coastal, City General, University, Regional")
    IO.puts("  Dr. Chen (3):     University, City General, Regional, Metro, Coastal")
    IO.puts("  Dr. Davis (4):    Regional, University, Coastal, Metro, City General")
    IO.puts("  Dr. Evans (5):    Coastal, Regional, University, Metro, City General")
    IO.puts("")

    IO.puts("Hospital Preferences:")
    IO.puts("  City General (101):  Chen, Anderson, Brown, Davis, Evans")
    IO.puts("  Metro Hospital (102): Anderson, Brown, Evans, Chen, Davis")
    IO.puts("  University Med (103): Chen, Davis, Anderson, Brown, Evans")
    IO.puts("  Regional Care (104):  Davis, Evans, Chen, Brown, Anderson")
    IO.puts("  Coastal Medical (105): Evans, Brown, Davis, Chen, Anderson")
    IO.puts("")

    matching = Yog.Bipartite.stable_marriage(left_prefs: residents, right_prefs: hospitals)

    IO.puts("=== Stable Matching Results ===")
    IO.puts("")

    resident_names = ["Anderson", "Brown", "Chen", "Davis", "Evans"]
    hospital_names = [
      "City General", "Metro Hospital", "University Med", "Regional Care",
      "Coastal Medical"
    ]

    Enum.each(1..5, fn resident_id ->
      case Map.get(matching, resident_id) do
        nil ->
          resident_name = Enum.at(resident_names, resident_id - 1)
          IO.puts("Dr. #{resident_name} was not matched")

        hospital_id ->
          resident_name = Enum.at(resident_names, resident_id - 1)
          hospital_name = Enum.at(hospital_names, hospital_id - 101)
          resident_rank = get_rank(residents, resident_id, hospital_id)
          hospital_rank = get_rank(hospitals, hospital_id, resident_id)

          IO.puts("Dr. #{resident_name} (##{resident_id}) matched to #{hospital_name} (##{hospital_id})")
          IO.puts("  - Resident's rank for this hospital: #{resident_rank} of 5")
          IO.puts("  - Hospital's rank for this resident: #{hospital_rank} of 5")
      end
    end)

    IO.puts("")
    IO.puts("--- Properties of This Matching ---")
    IO.puts("✓ Stable: No resident-hospital pair would both prefer each other")
    IO.puts("✓ Complete: All participants are matched (groups are equal size)")
    IO.puts("✓ Resident-optimal: Residents get best stable outcome possible")
    IO.puts("✓ Hospital-pessimal: Hospitals get worst stable outcome possible")
  end

  defp get_rank(prefs, person, target) do
    case Map.get(prefs, person) do
      nil -> 999
      pref_list ->
        case Enum.find_index(pref_list, &(&1 == target)) do
          nil -> 999
          idx -> idx + 1
        end
    end
  end
end

MedicalResidency.run()
