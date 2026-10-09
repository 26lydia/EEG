"""Subject-separated CV with selection, imputation and scaling inside each fold."""
import argparse
import json
from pathlib import Path
import sys

# Both *_new directories live beside each other under code/.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "feature_selection_new"))

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor, VotingRegressor
from sklearn.impute import SimpleImputer
from sklearn.linear_model import ElasticNet, Lasso, LinearRegression, Ridge
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.model_selection import GroupKFold
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.tree import DecisionTreeRegressor

from eeg_data import (group_values, load_dataset, numeric_features, output_folder,
                      read_table, validate_names, write_json)
from selection import FeatureSelector, SelectionConfig

MODEL_NAMES = ["ols", "ridge", "lasso", "elasticnet", "decisiontree", "randomforest", "ensemble"]


def make_model(kind, seed=42):
    bank = {
        "ols": LinearRegression(),
        "ridge": Ridge(alpha=30),
        "lasso": Lasso(alpha=0.04, max_iter=20000),
        "elasticnet": ElasticNet(alpha=0.05, l1_ratio=0.5, max_iter=20000),
        "decisiontree": DecisionTreeRegressor(max_depth=4, min_samples_leaf=2, random_state=seed),
        "randomforest": RandomForestRegressor(n_estimators=150, max_depth=7,
                                             min_samples_leaf=2, max_features="sqrt",
                                             random_state=seed, n_jobs=1),
        "ensemble": VotingRegressor([
            ("ols", LinearRegression()),
            ("rf", RandomForestRegressor(n_estimators=150, max_depth=7,
                                          min_samples_leaf=2, random_state=seed, n_jobs=1)),
        ]),
    }
    return make_pipeline(SimpleImputer(strategy="median"), StandardScaler(), bank[kind])


def metrics(y, prediction):
    return {"Rows": int(len(y)), "MAE": float(mean_absolute_error(y, prediction)),
            "RMSE": float(np.sqrt(mean_squared_error(y, prediction))),
            "R2": float(r2_score(y, prediction)) if len(y) > 1 and np.var(y) > 0 else None}


def fit_bundle(X, y, groups, config, kind, manifest, subjects, target):
    selector = FeatureSelector(config).fit(X, y, groups)
    model = make_model(kind, config.seed)
    model.fit(selector.transform(X), y)
    return {"selector": selector, "model": model, "kind": kind,
            "manifest": manifest, "training_subjects": sorted(set(subjects)), "target": target}


def infer(bundle, data):
    X = numeric_features(data, bundle["selector"].selected_)
    return bundle["model"].predict(X)


def train(data_file, manifest_file, out, kind="ridge", config=None, folds=5,
          target="PMA", group_column="name", test_file=None):
    config = config or SelectionConfig()
    config.validate()
    if kind not in MODEL_NAMES + ["all"]:
        raise ValueError("Unknown model type.")
    data, X, y, manifest = load_dataset(data_file, manifest_file, target)
    if manifest.get("supervised_selection"):
        raise ValueError("Use the original feature_manifest.json for CV, not a globally selected manifest.")
    groups = group_values(data, group_column)
    unique_groups = np.unique(groups)
    if len(unique_groups) < 4:
        raise ValueError("Training/CV needs at least four labeled subject groups; the two test subjects are only a format check.")
    if folds < 2:
        raise ValueError("CV folds must be at least two.")
    nfolds = min(folds, len(unique_groups))
    split = list(GroupKFold(n_splits=nfolds).split(X, y, groups))
    if any(len(np.unique(groups[tr])) < 3 for tr, _ in split):
        raise ValueError("Each training fold needs at least three subject groups; increase folds or subjects.")
    test = None
    if test_file:
        test = validate_names(read_table(test_file))
        overlap = set(data.name) & set(test.name)
        if overlap:
            raise ValueError(f"Independent test contains training subjects: {sorted(overlap)}")
        if group_column in test:
            if set(group_values(test, group_column)) & set(groups):
                raise ValueError("Independent test groups overlap training groups.")
        if target in test:
            labels = pd.to_numeric(test[target], errors="coerce").to_numpy(dtype=float)
            if not np.isfinite(labels).all():
                raise ValueError("Test labels must be finite when present; omit target for unlabeled prediction.")
        # All candidate columns checked before writing any output.
        numeric_features(test, manifest["features"])
    out = output_folder(out)
    kinds = MODEL_NAMES if kind == "all" else [kind]
    summaries = []
    for model_name in kinds:
        folder = out / model_name
        folder.mkdir()
        predictions = np.full(len(data), np.nan)
        fold_ids = np.zeros(len(data), dtype=int)
        rows, audit, features_by_fold = [], [], []
        for number, (tr, va) in enumerate(split, 1):
            assert not set(groups[tr]) & set(groups[va])
            assert not set(data.name.iloc[tr]) & set(data.name.iloc[va])
            bundle = fit_bundle(X.iloc[tr], y[tr], groups[tr], config, model_name,
                                manifest, data.name.iloc[tr], target)
            predictions[va] = infer(bundle, data.iloc[va])
            fold_ids[va] = number
            rows.append({"Fold": number, **metrics(y[va], predictions[va]),
                         "TrainingSubjects": int(len(set(groups[tr]))),
                         "ValidationSubjects": int(len(set(groups[va]))),
                         "SelectedFeatures": len(bundle["selector"].selected_)})
            features_by_fold.extend({"Fold": number, "Feature": name}
                                    for name in bundle["selector"].selected_)
            audit.append({"fold": number, "training_groups": sorted(set(groups[tr])),
                          "validation_groups": sorted(set(groups[va])),
                          "training_subjects": sorted(set(data.name.iloc[tr])),
                          "validation_subjects": sorted(set(data.name.iloc[va]))})
        assert np.isfinite(predictions).all() and np.all(fold_ids > 0)
        identity = [c for c in ["name", "EEGVariable"] if c in data]
        pred_table = data[identity].copy()
        pred_table["Fold"] = fold_ids
        pred_table["True"] = y
        pred_table["Predicted"] = predictions
        pred_table["Residual"] = y - predictions
        pred_table.to_csv(folder / "cv_predictions.csv", index=False)
        pd.DataFrame(rows).to_csv(folder / "fold_metrics.csv", index=False)
        pd.DataFrame(features_by_fold).to_csv(folder / "fold_selected_features.csv", index=False)
        write_json(folder / "fold_subjects.json", audit)
        overall = metrics(y, predictions)
        subject_errors = pd.DataFrame({"subject": data.name, "abs_error": abs(y - predictions)})
        overall["SubjectBalancedMAE"] = float(subject_errors.groupby("subject").abs_error.mean().mean())
        summaries.append({"Model": model_name, **overall})
        write_json(folder / "cv_metrics.json", overall)
        # Final fitting may use all training subjects, but never the independent test.
        final = fit_bundle(X, y, groups, config, model_name, manifest, data.name, target)
        joblib.dump(final, folder / "model.joblib")
        final["selector"].ranking_.to_csv(folder / "final_feature_ranking.csv", index=False)
        pd.DataFrame({"Feature": final["selector"].selected_}).to_csv(folder / "used_features.csv", index=False)
        estimator = final["model"].steps[-1][1]
        weight = getattr(estimator, "coef_", getattr(estimator, "feature_importances_", None))
        if weight is not None:
            pd.DataFrame({"Feature": final["selector"].selected_, "Weight": weight}).to_csv(
                folder / "final_weights.csv", index=False)
        if test is not None:
            prediction = infer(final, test)
            result = test[[c for c in identity if c in test]].copy()
            result["Predicted"] = prediction
            if target in test:
                result["True"] = test[target].astype(float)
                result["Residual"] = result["True"] - prediction
                write_json(folder / "test_metrics.json", metrics(result["True"].to_numpy(), prediction))
            result.to_csv(folder / "test_predictions.csv", index=False)
        write_json(folder / "run_config.json", {
            "model": model_name, "selection": final["selector"].config_dict(),
            "target": target, "group_column": group_column, "folds": nfolds,
            "training_file": str(data_file), "feature_manifest": str(manifest_file),
            "parameters": {k: v for k, v in estimator.get_params(deep=False).items()
                           if isinstance(v, (str, int, float, bool)) or v is None},
            "note": "Fixed model parameters, no test-driven tuning or true-PMA residual correction.",
        })
        print(f"{model_name}: CV MAE={overall['MAE']:.4f}, features={len(final['selector'].selected_)}")
    pd.DataFrame(summaries).to_csv(out / "model_comparison.csv", index=False)
    return summaries


def predict(model_file, data_file, output_file):
    output_file = Path(output_file)
    if output_file.exists():
        raise ValueError(f"Prediction output already exists: {output_file}")
    bundle = joblib.load(model_file)
    data = validate_names(read_table(data_file))
    result = data[[c for c in ["name", "EEGVariable"] if c in data]].copy()
    result["Predicted"] = infer(bundle, data)
    output_file.parent.mkdir(parents=True, exist_ok=True)
    result.to_csv(output_file, index=False)
    print(f"Saved {len(result)} predictions to {output_file}")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    tr = sub.add_parser("train")
    tr.add_argument("--data", required=True)
    tr.add_argument("--manifest", required=True)
    tr.add_argument("--output", required=True)
    tr.add_argument("--model", choices=MODEL_NAMES + ["all"], default="ridge")
    tr.add_argument("--selection-config", help="selection_config.json from training-only selection")
    tr.add_argument("--method", choices=["pearson", "mi", "elasticnet", "xgboost", "none"], default="pearson")
    tr.add_argument("--top-k", type=int, default=15)
    tr.add_argument("--folds", type=int, default=5)
    tr.add_argument("--target", default="PMA")
    tr.add_argument("--group-column", default="name")
    tr.add_argument("--test", help="Independent subjects only; target optional for prediction")
    pr = sub.add_parser("predict")
    pr.add_argument("--model-file", required=True)
    pr.add_argument("--data", required=True)
    pr.add_argument("--output", required=True)
    args = parser.parse_args()
    try:
        if args.command == "train":
            config = (SelectionConfig(**json.loads(Path(args.selection_config).read_text()))
                      if args.selection_config else SelectionConfig(method=args.method, top_k=args.top_k))
            train(args.data, args.manifest, args.output, args.model, config,
                  args.folds, args.target, args.group_column, args.test)
        else:
            predict(args.model_file, args.data, args.output)
    except ValueError as exc:
        parser.exit(2, f"Input error: {exc}\n")
