# models_new

Compatible consolidated replacement for the old Linear/Non-Linear experimental notebooks.
Original notebooks remain unchanged. Requires sibling `feature_selection_new` for the shared
data contract and selection code; use the requirements file there.

`model_workflow.py train` supports `ols`, `ridge`, `lasso`, `elasticnet`, `decisiontree`,
`randomforest`, `ensemble` (equal OLS/RF voting), or `all`. It reads prepared CSV/XLSX using a
feature manifest, never positional slices, old feature numbers or fuzzy feature-name matching.
This replaces the main fitting/validation/prediction paths, not every historical plotting,
VIF, grid-search or residual-correction experiment. Hyperparameters are fixed defaults in
`make_model`, recorded in `run_config.json`; change them using training-only evidence. No
automated hyperparameter search is claimed. CV comparison is exploratory model selection;
use an untouched independent cohort for final performance reporting.

```sh
PY=/Users/lei/miniforge3/envs/jupyter/bin/python
CODE=/Volumes/Elements/code
"$PY" "$CODE/models_new/model_workflow.py" train \
  --data /path/split/train.csv --manifest /path/labeled/feature_manifest.json \
  --selection-config /path/selection/selection_config.json \
  --model all --folds 5 --test /path/split/test.csv --output /path/models
```

Training requires real finite PMA labels and at least four distinct subject groups; every
training fold must have at least three groups and varying labels. More subjects are needed
for scientific validation. The CV splitter is GroupKFold, grouping by `name` by default.
If several filenames belong to one person, join a clinical `subject_id` column and pass
`--group-column subject_id` to both splitting, selection and training. An old cohort/age-bin
column named `group` is not automatically a subject identifier. All rows for a given name
must have a consistent CV group. Independent-test subjects/groups cannot overlap training.

Each fold refits feature usability checks, selection, redundancy filtering, median imputation,
scaling and model fitting on its training subjects. Validation rows are transformed only.
Final model fitting uses all training subjects; the optional independent test is never used
to select features or tune parameters. There is no true-test-PMA residual adjustment.
Prediction requires no clinical labels or age bins.

Outputs per model: CV predictions with names/folds, fold and aggregate MAE/RMSE/R2, selected
features per fold, fold subject audit, final ranking and selected feature list, `model.joblib`
including selector/imputer/scaler/model, and optional independent-test predictions/metrics.
R2 is null for constant-target or one-row validation folds; aggregate R2 uses all held-out
predictions. `SubjectBalancedMAE` gives equal weight to subjects with different row counts.
`model_comparison.csv` summarizes CV. Use new/empty output folders to protect previous runs.

```sh
"$PY" "$CODE/models_new/model_workflow.py" predict \
  --model-file /path/models/ridge/model.joblib \
  --data /path/unlabeled/dataset.csv --output /path/predictions.csv
"$PY" "$CODE/models_new/test_pipeline.py"
```

Prediction tables need the final selected columns with the exact same names and meanings;
no filename-based reordering or fuzzy renaming is used. Missing observations may be NaN,
but absent required columns cause an explicit error. Only load model files you trust.

Validation on this Mac: all seven model modes, all five selection methods (including SHAP),
negative redundancy, train-only missing-column exclusion, grouped CV with repeated subject
rows, saved-model reload and unlabeled prediction passed on synthetic labeled data.
Real exports passed preparation (2 subjects, 8060 wide candidate features), but these files
have no PMA labels and cannot validate a supervised regression model.
