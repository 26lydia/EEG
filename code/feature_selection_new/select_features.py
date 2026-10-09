"""Export exploratory/training-only rankings; models refit selection in each CV fold."""
import argparse

import pandas as pd

from eeg_data import group_values, load_dataset, output_folder, write_json
from selection import FeatureSelector, SelectionConfig


def select(data_file, manifest_file, out, config, target="PMA", group_column="name"):
    data, X, y, manifest = load_dataset(data_file, manifest_file, target)
    groups = group_values(data, group_column)
    if len(set(groups)) < 3:
        raise ValueError("At least three labeled subjects are needed for selection; two test files are insufficient.")
    selector = FeatureSelector(config).fit(X, y, groups)
    out = output_folder(out)
    selector.ranking_.to_csv(out / "feature_ranking.csv", index=False)
    selector.dropped_.to_csv(out / "dropped_features.csv", index=False)
    pd.DataFrame({"Feature": selector.selected_}).to_csv(out / "selected_features.csv", index=False)
    metadata = [n for n in data if n not in manifest["features"]]
    data[metadata + selector.selected_].to_csv(out / "selected_dataset.csv", index=False)
    write_json(out / "selected_manifest.json", {**manifest, "features": selector.selected_,
                                               "supervised_selection": True})
    write_json(out / "selection_config.json", selector.config_dict())
    write_json(out / "selection_report.json", {
        "subjects": len(set(groups)), "rows": len(data), "selected": len(selector.selected_),
        "target": target, "group_column": group_column,
        "note": "Rankings are exploratory. For CV, use the original candidate manifest and refit selection in every fold.",
    })
    print(f"Selected {len(selector.selected_)} features in {out}")
    return selector


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--target", default="PMA")
    parser.add_argument("--group-column", default="name")
    parser.add_argument("--method", choices=["pearson", "mi", "elasticnet", "xgboost", "none"], default="pearson")
    parser.add_argument("--top-k", type=int, default=15)
    parser.add_argument("--correlation-limit", type=float, default=0.8)
    parser.add_argument("--min-observed-fraction", type=float, default=0.5)
    parser.add_argument("--bootstrap-runs", type=int, default=30)
    parser.add_argument("--stability", type=float, default=0.6)
    parser.add_argument("--alpha", type=float, default=0.05)
    parser.add_argument("--l1-ratio", type=float, default=0.5)
    args = parser.parse_args()
    config = SelectionConfig(**{k: getattr(args, k) for k in SelectionConfig.__dataclass_fields__ if hasattr(args, k)})
    try:
        select(args.data, args.manifest, args.output, config, args.target, args.group_column)
    except ValueError as exc:
        parser.exit(2, f"Input error: {exc}\n")
