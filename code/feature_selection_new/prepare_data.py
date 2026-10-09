"""Convert the graph export to a named, manifest-controlled modeling table."""
import argparse

import numpy as np
import pandas as pd

from eeg_data import (RESERVED, numeric_features, output_folder, read_table,
                      validate_names, write_json)


def prepare(input_file, map_file, out, clinical_file=None, variable=None):
    data = validate_names(read_table(input_file))
    mapping = read_table(map_file)
    if not {"ColumnName", "FeatureLabel"}.issubset(mapping):
        raise ValueError("Column map must contain ColumnName and FeatureLabel.")
    features = mapping.ColumnName.astype(str).tolist()
    numeric_features(data, features)
    if mapping.ColumnName.duplicated().any():
        raise ValueError("Duplicate ColumnName in feature map.")
    if "EEGVariable" not in data or data.EEGVariable.isna().any():
        raise ValueError("Graph table must contain nonempty EEGVariable identifiers.")
    if data.duplicated(["name", "EEGVariable"]).any():
        raise ValueError("Duplicate subject/EEGVariable rows; resolve recording identities first.")
    original_subjects = set(data.name)
    metadata = [n for n in data if n not in features and n != "EEGVariable"]
    # Preserve clinical and QC columns separately from the feature manifest.
    clinical_columns = [n for n in metadata if n not in RESERVED or n in {"PMA", "group", "health"}]
    if variable:
        data = data.loc[data.EEGVariable.eq(variable)].copy()
        if data.empty:
            raise ValueError(f"No rows for EEG variable {variable}.")
        records = mapping.to_dict("records")
        prepared = data
    else:
        if any(data.groupby("name")[c].nunique(dropna=False).gt(1).any()
               for c in clinical_columns):
            raise ValueError("Clinical metadata differ between a subject's EEG variables.")
        prepared = data[["name"] + clinical_columns].drop_duplicates("name").set_index("name")
        records = []
        for var in sorted(data.EEGVariable.unique()):
            block = data.loc[data.EEGVariable.eq(var)].set_index("name")
            renamed = {c: f"{var}__{c}" for c in features}
            if set(renamed.values()).intersection(prepared.columns):
                raise ValueError("Feature names conflict with metadata.")
            prepared = prepared.join(block[features].rename(columns=renamed), how="left")
            records.extend({"ColumnName": renamed[r.ColumnName],
                            "FeatureLabel": r.FeatureLabel, "EEGVariable": var}
                           for r in mapping.itertuples(index=False))
        prepared = prepared.copy().reset_index()
    if clinical_file:
        clinical = validate_names(read_table(clinical_file))
        if clinical.name.duplicated().any():
            raise ValueError("Clinical table must have one row per unique name.")
        overlap = (set(clinical.columns) & set(prepared.columns)) - {"name"}
        if overlap:
            raise ValueError(f"Clinical columns already present: {sorted(overlap)}")
        prepared = prepared.merge(clinical, on="name", how="left", validate="many_to_one")
    prepared = prepared.replace([np.inf, -np.inf], np.nan)
    out = output_folder(out)
    prepared.to_csv(out / "dataset.csv", index=False)
    pd.DataFrame(records).to_csv(out / "feature_columns.csv", index=False)
    write_json(out / "feature_manifest.json", {
        "schema_version": 1, "features": [r["ColumnName"] for r in records],
        "layout": "single_variable" if variable else "subject_wide",
        "variable": variable, "source": str(input_file),
        "excluded_metadata": [c for c in prepared if c not in {r["ColumnName"] for r in records}],
    })
    template = pd.DataFrame({"name": sorted(original_subjects), "PMA": np.nan,
                             "group": "", "health": ""})
    template.to_csv(out / "clinical_template.csv", index=False)
    missing_subjects = sorted(original_subjects - set(prepared.name))
    write_json(out / "prepare_report.json", {
        "rows": len(prepared), "subjects": int(prepared.name.nunique()),
        "features": len(records), "subjects_without_requested_variable": missing_subjects,
        "target_present": "PMA" in prepared,
        "note": "Blank clinical template values are placeholders, never training labels.",
    })
    print(f"Prepared {len(prepared)} rows, {len(records)} features in {out}")
    return prepared


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True)
    parser.add_argument("--column-map", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--clinical", help="CSV/XLSX with unique name and real PMA labels")
    parser.add_argument("--variable", help="Only this EEGVariable; default pivots all into subject rows")
    args = parser.parse_args()
    try:
        prepare(args.input, args.column_map, args.output, args.clinical, args.variable)
    except ValueError as exc:
        parser.exit(2, f"Input error: {exc}\n")
