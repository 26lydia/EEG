"""Named-column contract shared by preparation, selection and models."""
import json
from pathlib import Path

import numpy as np
import pandas as pd

RESERVED = {"name", "EEGVariable", "ARTFraction", "ValidChannelCount",
            "IncompleteGraphCount", "PMA", "group", "health"}


def read_table(path):
    path = Path(path)
    if path.suffix.lower() == ".csv":
        return pd.read_csv(path, dtype={"name": "string"})
    if path.suffix.lower() in {".xlsx", ".xlsm"}:
        return pd.read_excel(path, dtype={"name": "string"})
    raise ValueError("Use CSV or XLSX; first export extracted MAT files using graph theory.")


def output_folder(path):
    path = Path(path)
    if path.exists() and any(path.iterdir()):
        raise ValueError(f"Output folder is not empty: {path}. Choose a new folder.")
    path.mkdir(parents=True, exist_ok=True)
    return path


def write_json(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2,
                                    allow_nan=False) + "\n", encoding="utf-8")


def validate_names(data):
    if "name" not in data:
        raise ValueError("Missing subject identifier column: name")
    if data.name.isna().any() or data.name.astype(str).str.strip().eq("").any():
        raise ValueError("Subject names must be nonempty.")
    data = data.copy()
    data["name"] = data.name.astype(str)
    return data


def numeric_features(data, names):
    absent = set(names) - set(data.columns)
    if absent:
        raise ValueError(f"Missing required feature columns: {sorted(absent)[:10]}")
    if not names or len(names) != len(set(names)):
        raise ValueError("Feature names must be nonempty and unique.")
    if RESERVED.intersection(names):
        raise ValueError("Clinical/identifier/quality columns cannot be features.")
    bad = [n for n in names if not pd.api.types.is_numeric_dtype(data[n])]
    if bad:
        raise ValueError(f"Nonnumeric feature columns: {bad[:10]}")
    return data[names].astype(float).replace([np.inf, -np.inf], np.nan)


def load_dataset(data_file, manifest_file, target="PMA", require_target=True):
    data = validate_names(read_table(data_file))
    manifest = json.loads(Path(manifest_file).read_text(encoding="utf-8"))
    if manifest.get("schema_version") != 1:
        raise ValueError("Unsupported feature manifest schema.")
    if target in manifest["features"]:
        raise ValueError(f"Target {target} cannot also be a predictor.")
    X = numeric_features(data, manifest["features"])
    if require_target:
        if target not in data:
            raise ValueError(f"Missing target {target}. Join a clinical table by name first.")
        y = pd.to_numeric(data[target], errors="coerce").to_numpy(dtype=float)
        if not np.isfinite(y).all():
            raise ValueError(f"{target} contains missing/nonfinite/nonnumeric values; supply real labels.")
        if np.unique(y).size < 2:
            raise ValueError(f"{target} must vary for regression/selection.")
    else:
        y = None
    return data, X, y, manifest


def group_values(data, column="name"):
    if column not in data or data[column].isna().any():
        raise ValueError(f"Missing or incomplete subject grouping column: {column}")
    values = data[column].astype(str).to_numpy()
    if any(not g.strip() for g in values):
        raise ValueError("Grouping values must be nonempty.")
    # A cohort/age-bin column named group is NOT automatically a subject ID.
    # All repeated rows from a subject must remain in the same CV group.
    if data.assign(_cv_group=values).groupby("name")._cv_group.nunique().gt(1).any():
        raise ValueError("A subject maps to multiple CV groups.")
    return values
