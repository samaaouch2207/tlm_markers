#!/usr/bin/env python3
"""
Compare x_Faster values between two tables.

* Medians for R10m / R20m / R60m (excluding *_TCI).
* Direct *_TCI values kept as‑is.
* Produces a bar plot similar to the reference image.
"""
import sys
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path 
from matplotlib.lines import Line2D

def print_usage():
    print(f"Usage: python {sys.argv[0]} <DS_NAME> [mode]")
    print("  DS_NAME: DS1, DS2, KAYRROS, DS2_KAYRROS, DS2_NTILE1")
    print("  mode (optional, default=online): local or online")
    sys.exit(1)

def get_csv_pattern(dataset_name):
    dataset_name = dataset_name.upper()
    if dataset_name == "DS1":
        return "DS_2CPS_20250527T092507_S20250527T074219"
    elif dataset_name == "DS2":
        return "DS_2CPS_20250527T093652_S20250527T075023"
    elif dataset_name == "KAYRROS":
        return "KAYRROS"
    elif dataset_name == "DS2_KAYRROS":
        return "DS_2CPS_20250527T093652_S20250527T075023_KAYRROS"
    elif dataset_name == "DS2_NTILE1":
        return "DS_2CPS_20250527T093652_S20250527T075023_IPF_NTILE1"
    else:
        raise ValueError(f"Invalid dataset name '{dataset_name}'. Expected one of: DS1, DS2, KAYRROS, DS2_KAYRROS")

# Check command-line arguments
if len(sys.argv) < 2 or not sys.argv[1]:
    print("ERROR: DS_NAME value must be entered!")
    print_usage()

DS_NAME = sys.argv[1]
CSV_PATTERN = get_csv_pattern(DS_NAME)

# Check mode
mode = sys.argv[2] if len(sys.argv) > 2 else "online"
if mode not in ["local", "online"]:
    print(f"ERROR: Invalid mode '{mode}'.")
    print_usage()

print(f"Using dataset: {DS_NAME}")
print(f"CSV_PATTERN: {CSV_PATTERN}")
print(f"Mode: {mode}")

# ----------------------------------------------------------------------
# 1. Read the two tables ------------------------------------------------
SMALL_CROP_PATH = Path(f"benchmark_results/{CSV_PATTERN}_{mode}_small_crop.csv")   # SMALL  crop   (rename if needed)
SMALL2T_CROP_PATH = Path(f"benchmark_results/{CSV_PATTERN}_{mode}_small2t_crop.csv")   # SMALL 2-tiles crop   (rename if needed)
MEDIUM_CROP_PATH = Path(f"benchmark_results/{CSV_PATTERN}_{mode}_medium_crop.csv")   # MEDIUM  crop   (rename if needed)
BIG_CROP_PATH = Path(f"benchmark_results/{CSV_PATTERN}_{mode}_big_crop.csv")   # BIG    crop   (rename if needed)
HUGE_CROP_PATH = Path(f"benchmark_results/{CSV_PATTERN}_{mode}_huge_crop.csv")   # HUGE    crop   (rename if needed)


# ----------------------------------------------------------------------
# 3. Prépare tableau groupé avec médianes et std ----------------------
def table_grouped_by_image_with_std(df: pd.DataFrame):
    grouped_median = (
        df
        .groupby(["Image", "Resolution_Band"], as_index=False)
        .agg(
            x_Faster_median         = ("x_Faster",              "median"),
            Time_without_TLM_median = ("Time_without_TLM(s)",   "median"),
            Time_with_TLM_median    = ("Time_with_TLM(s)",      "median"),
            Nb_requests_without_TLM_median = ("Nb_requests_without_TLM", "median"),
            Nb_requests_with_TLM_median    = ("Nb_requests_with_TLM",    "median"),
            Bandwidth_without_TLM_median = ("Bandwidth_without_TLM(MB)", "median"),
            Bandwidth_with_TLM_median    = ("Bandwidth_with_TLM(MB)",    "median")
        )
        .sort_values(["Image", "Resolution_Band"])
        .reset_index(drop=True)
    )
    
    return grouped_median

# ----------------------------------------------------------------------
# 4. Extraction des médianes et std pour x_Faster ----------------------
def extract_x_faster_median(tidy_df, category):
    if category.endswith("_TCI"):
        match = tidy_df["Resolution_Band"] == category
    else:
        match = (tidy_df["Resolution_Band"].str.startswith(category) &
                 ~tidy_df["Resolution_Band"].str.endswith("_TCI"))

    values = tidy_df.loc[match, "x_Faster_median"]
    return values.median() if not values.empty else None


# ----------------------------------------------------------------------
# 5. Generate table for median and std time with and without TLM ------
def summary_time_stats_all(original_df, categories):
    rows = []

    for category in categories:
        if category.endswith("_TCI"):
            match = original_df["Resolution_Band"] == category
        else:
            match = (
                original_df["Resolution_Band"].str.startswith(category)
                & ~original_df["Resolution_Band"].str.endswith("_TCI")
            )

        subset = original_df.loc[match]

        if subset.empty:
            row = {
                "Category": category,
                "Median_Time_without_TLM": None,
                "Std_Time_without_TLM": None,
                "Median_Time_with_TLM": None,
                "Std_Time_with_TLM": None
            }
        else:
            row = {
                "Category": category,
                "Median_Time_without_TLM": subset["Time_without_TLM(s)"].median(),
                "Std_Time_without_TLM": subset["Time_without_TLM(s)"].std(),
                "Median_Time_with_TLM": subset["Time_with_TLM(s)"].median(),
                "Std_Time_with_TLM": subset["Time_with_TLM(s)"].std()
            }

        rows.append(row)

    return pd.DataFrame(rows)

# ----------------------------------------------------------------------
# Chargement CSVs
df_small = pd.read_csv(SMALL_CROP_PATH)
df_small2t = pd.read_csv(SMALL2T_CROP_PATH)
df_medium = pd.read_csv(MEDIUM_CROP_PATH)
df_big   = pd.read_csv(BIG_CROP_PATH)
df_huge  = pd.read_csv(HUGE_CROP_PATH)

# ----------------------------------------------------------------------
# Calcul médianes et std
small_tidy = table_grouped_by_image_with_std(df_small)
small2t_tidy = table_grouped_by_image_with_std(df_small2t)
medium_tidy = table_grouped_by_image_with_std(df_medium)
big_tidy   = table_grouped_by_image_with_std(df_big)
huge_tidy  = table_grouped_by_image_with_std(df_huge)

# ----------------------------------------------------------------------
# Préparation des données pour le plot
categories = ["R10m", "R20m", "R60m", "R10m_TCI", "R20m_TCI", "R60m_TCI"]

values_small = [extract_x_faster_median(small_tidy, c) for c in categories]
print("Summary times for SMALL CROP:")
print(summary_time_stats_all(df_small, categories))

values_small2t = [extract_x_faster_median(small2t_tidy, c) for c in categories]
print("Summary times for SMALL 2-TILES CROP:")
print(summary_time_stats_all(df_small2t, categories))

values_medium  = [extract_x_faster_median(medium_tidy, c) for c in categories]
print("Summary times for MEDIUM CROP:")
print(summary_time_stats_all(df_medium, categories))

values_big   = [extract_x_faster_median(big_tidy, c) for c in categories]
print("Summary times for BIG CROP:")
print(summary_time_stats_all(df_big, categories))

values_huge  = [extract_x_faster_median(huge_tidy, c) for c in categories]
print("Summary times for HUGE CROP:")
print(summary_time_stats_all(df_huge, categories))


x = range(len(categories))
bar_width = 0.1

# ----------------------------------------------------------------------
# Plot avec barres d'erreur (écart-type)
fig, ax = plt.subplots(figsize=(11, 6))

crop_data = [
    ("SMALL CROP", values_small),
    ("SMALL 2-TILES CROP", values_small2t),
    ("MEDIUM CROP", values_medium),
    ("BIG CROP", values_big),
    ("HUGE CROP", values_huge),
    # Add more crops as needed
]

n = len(crop_data)
middle = (n - 1) / 2  # center-align bars

for i, (label, values) in enumerate(crop_data):
    offset = i - middle
    ax.bar(
        [xi + offset * bar_width for xi in x],
        values,
        width=bar_width,
        capsize=5,
        label=f"Time ratio gain median {label}"
    )

# Axis and styling
ax.set_xticks(x)
ax.set_xticklabels(categories)
ax.set_xlabel("Resolution")
ax.set_ylabel("Time ratio (time_no_tlm / time_tlm)")
ax.set_title(f"Faster time ratio comparison for {CSV_PATTERN}_{mode}")
ax.grid(axis="y", linestyle="--", alpha=0.6)

ax.legend()

plt.tight_layout()
fig.subplots_adjust(top=0.9)  # increase top margin
plt.savefig(f"{CSV_PATTERN}_{mode}_bars_plot.png", dpi=300)
