"""Meaningful schema, leakage, missing-data and saved-model checks; synthetic labels only."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "feature_selection_new"))

import joblib
import numpy as np
import pandas as pd

from eeg_data import load_dataset, numeric_features, write_json
from prepare_data import prepare
from selection import FeatureSelector, SelectionConfig
from split_subjects import split_subjects
from model_workflow import infer, predict, train


class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="eeg-model-test-")
        self.root = Path(self.temp.name)
        rng = np.random.default_rng(4)
        n = 24
        subject = np.repeat([f"subject{i:02d}" for i in range(12)], 2)
        base = np.repeat(np.linspace(-2, 2, 12), 2)
        self.data = pd.DataFrame({
            "name": subject, "EEGVariable": np.tile(["EEG_sleep", "EEG_wake"], 12),
            "signal": base + rng.normal(0, 0.04, n), "negative_duplicate": -base,
            "noise": rng.normal(size=n), "sparse": rng.normal(size=n),
            "empty": np.nan, "constant": 0.0,
            "PMA": 34 + 2 * base, "health": np.tile([0, 1], 12), "group": "cohort",
            "ARTFraction": 0.1,
        })
        self.data.loc[:15, "sparse"] = np.nan
        self.features = ["signal", "negative_duplicate", "noise", "sparse", "empty", "constant"]
        self.file = self.root / "data.csv"
        self.data.to_csv(self.file, index=False)
        self.manifest = self.root / "manifest.json"
        write_json(self.manifest, {"schema_version": 1, "features": self.features})

    def tearDown(self):
        self.temp.cleanup()

    def test_preparation_and_clinical_join(self):
        long = self.data.drop(columns=["PMA", "group", "health"])
        long.to_excel(self.root / "graph.xlsx", index=False)
        pd.DataFrame({"ColumnName": self.features, "FeatureLabel": self.features}).to_csv(
            self.root / "map.csv", index=False)
        self.data[["name", "PMA"]].drop_duplicates().to_csv(self.root / "clinical.csv", index=False)
        prepared = prepare(self.root / "graph.xlsx", self.root / "map.csv", self.root / "wide",
                           self.root / "clinical.csv")
        self.assertEqual(prepared.name.nunique(), 12)
        self.assertEqual(len(prepared), 12)
        _, X, y, manifest = load_dataset(self.root / "wide/dataset.csv", self.root / "wide/feature_manifest.json")
        self.assertEqual(X.shape, (12, 12))
        self.assertNotIn("PMA", manifest["features"])
        self.assertTrue(np.isfinite(y).all())
        single = prepare(self.root / "graph.xlsx", self.root / "map.csv", self.root / "single",
                         variable="EEG_sleep")
        self.assertEqual(len(single), 12)
        self.assertRaises(ValueError, load_dataset, self.root / "single/dataset.csv",
                          self.root / "single/feature_manifest.json")
        self.assertRaises(ValueError, numeric_features, self.data, ["PMA"])

    def test_methods_missing_and_negative_redundancy(self):
        X = self.data[self.features]
        for method in ["pearson", "mi", "elasticnet", "xgboost", "none"]:
            selector = FeatureSelector(SelectionConfig(method=method, top_k=3,
                bootstrap_runs=5, stability=0.2)).fit(X, self.data.PMA, self.data.name)
            self.assertTrue(selector.selected_)
            self.assertFalse(set(selector.selected_) & {"constant", "empty", "sparse"})
            if method != "none":
                self.assertFalse({"signal", "negative_duplicate"}.issubset(selector.selected_))
        # A candidate observed only outside the training fold is excluded.
        X = X.copy()
        X["heldout_only"] = np.nan
        X.loc[20:, "heldout_only"] = np.arange(4)
        selector = FeatureSelector().fit(X.iloc[:20], self.data.PMA.iloc[:20], self.data.name.iloc[:20])
        self.assertNotIn("heldout_only", selector.selected_)

    def test_all_models_group_cv_reload_and_unlabeled_prediction(self):
        train(self.file, self.manifest, self.root / "models", kind="all",
              config=SelectionConfig(top_k=2), folds=3)
        bundle = joblib.load(self.root / "models/ridge/model.joblib")
        for kind in ["ols", "ridge", "lasso", "elasticnet", "decisiontree", "randomforest", "ensemble"]:
            audit = json.loads((self.root / f"models/{kind}/fold_subjects.json").read_text())
            for fold in audit:
                self.assertFalse(set(fold["training_subjects"]) & set(fold["validation_subjects"]))
            cv = pd.read_csv(self.root / f"models/{kind}/cv_predictions.csv")
            self.assertTrue(np.isfinite(cv.Predicted).all())
            self.assertTrue(cv.groupby("name").Fold.nunique().eq(1).all())
        unlabeled = self.data.drop(columns=["PMA", "health", "group"])
        unlabeled.to_csv(self.root / "unlabeled.csv", index=False)
        prediction = predict(self.root / "models/ridge/model.joblib", self.root / "unlabeled.csv",
                             self.root / "predictions.csv")
        np.testing.assert_allclose(prediction.Predicted, infer(bundle, self.data))
        changed_labels = self.data.copy()
        changed_labels["PMA"] += 999
        np.testing.assert_allclose(infer(bundle, changed_labels), infer(bundle, self.data))
        self.assertRaises(ValueError, train, self.file, self.manifest, self.root / "overlap",
                          test_file=self.file)
        write_json(self.root / "selected.json", {"schema_version": 1, "features": self.features,
                                                "supervised_selection": True})
        self.assertRaises(ValueError, train, self.file, self.root / "selected.json", self.root / "leaked")

    def test_subject_split_and_independent_test(self):
        split_subjects(self.file, self.root / "split", test_fraction=0.25)
        tr = pd.read_csv(self.root / "split/train.csv")
        te = pd.read_csv(self.root / "split/test.csv")
        self.assertFalse(set(tr.name) & set(te.name))
        train(self.root / "split/train.csv", self.manifest, self.root / "independent",
              config=SelectionConfig(top_k=2), folds=3, test_file=self.root / "split/test.csv")
        results = pd.read_csv(self.root / "independent/ridge/test_predictions.csv")
        self.assertEqual(len(results), len(te))
        self.assertTrue(np.isfinite(results.Predicted).all())

    def test_stability_selection_inside_model_folds(self):
        for method in ["mi", "elasticnet", "xgboost", "none"]:
            train(self.file, self.manifest, self.root / f"cv_{method}", folds=3,
                  config=SelectionConfig(method=method, top_k=2, bootstrap_runs=3, stability=0.2))
            cv = pd.read_csv(self.root / f"cv_{method}/ridge/cv_predictions.csv")
            self.assertTrue(np.isfinite(cv.Predicted).all())


if __name__ == "__main__":
    unittest.main(verbosity=2)
