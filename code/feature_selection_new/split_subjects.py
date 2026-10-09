"""Split a prepared dataset before any supervised feature selection."""
import argparse

import numpy as np

from eeg_data import group_values, output_folder, read_table, validate_names, write_json


def split_subjects(data_file, out, test_fraction=0.2, group_column="name", seed=42):
    if not 0 < test_fraction < 1:
        raise ValueError("test_fraction must be between zero and one.")
    data = validate_names(read_table(data_file))
    groups = group_values(data, group_column)
    unique = np.unique(groups)
    count = max(1, int(np.ceil(len(unique) * test_fraction)))
    if len(unique) - count < 4:
        raise ValueError("Need enough subjects to leave at least four training groups after the test split.")
    rng = np.random.default_rng(seed)
    test_groups = rng.choice(unique, count, replace=False)
    mask = np.isin(groups, test_groups)
    out = output_folder(out)
    data.loc[~mask].to_csv(out / "train.csv", index=False)
    data.loc[mask].to_csv(out / "test.csv", index=False)
    write_json(out / "split_subjects.json", {"seed": seed, "group_column": group_column,
        "training_groups": sorted(set(groups[~mask])), "test_groups": sorted(set(groups[mask]))})
    print(f"Split {len(unique)-count} training groups and {count} independent test groups.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--test-fraction", type=float, default=0.2)
    parser.add_argument("--group-column", default="name")
    args = parser.parse_args()
    try:
        split_subjects(args.data, args.output, args.test_fraction, args.group_column)
    except ValueError as exc:
        parser.exit(2, f"Input error: {exc}\n")
