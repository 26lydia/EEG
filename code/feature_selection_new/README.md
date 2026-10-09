# feature_selection_new

Compatible replacement for the original experimental selection scripts. Originals remain untouched.
Run Python using `/Users/lei/miniforge3/envs/jupyter/bin/python` on this Mac. Keep this folder
beside `models_new` and `feature_extraction_new` under `/Volumes/Elements/code`.

The input contract is the current graph export `EEG_Feature_Combined.xlsx` plus
`EEG_Feature_Columns.csv`. Raw/extracted MAT files must first pass through graph export.
`export_extracted.m` provides a MATLAB bridge. The column map is authoritative: only its
feature columns become predictors; identifiers, ART quality, PMA and clinical metadata do not.

## Files and replacement scope

| Original workflow | New entry point |
| --- | --- |
| Older positional Excel handling | `prepare_data.py` + feature manifest |
| `pic_PearsonR.m`, `pearson_all.m`, `delete_collinearity.m` | `select_features.py --method pearson` |
| `pic_MI.m` | `select_features.py --method mi` |
| `ElasticNet.ipynb` stability selection | `select_features.py --method elasticnet` |
| `XGBoost.ipynb` SHAP stability selection | `select_features.py --method xgboost` |
| `splitgroup.ipynb` | `split_subjects.py` |
| `deletezero.m` | Training-only constant/missing-column exclusion in `selection.py` |

Historical plotting cells, hand-selected feature numbers, test-error weighting, and every
experimental notebook variant are not copied. CSV rankings include actual column names and
scores for plotting in Excel/Python. These are consolidated executable replacements, not
numerical reproductions of the old analyses. No arbitrary PLI/PLV deletion is performed.

## Preparation

```sh
PY=/Users/lei/miniforge3/envs/jupyter/bin/python
CODE=/Volumes/Elements/code
"$PY" "$CODE/feature_selection_new/prepare_data.py" \
  --input /Users/lei/Desktop/feature_extraction_output/graph_output/EEG_Feature_Combined.xlsx \
  --column-map /Users/lei/Desktop/feature_extraction_output/graph_output/EEG_Feature_Columns.csv \
  --output /Users/lei/Desktop/prepared_eeg
```

Default: one row per MAT-file subject, with `EEGVariable__feature` columns; missing bands/states
remain NaN. Add `--variable EEG_sleep` for a single signal type (subjects without it are reported).
Preparation retains constant/all-missing candidates; removal is learned from training data later.

The output includes `dataset.csv`, `feature_manifest.json`, `feature_columns.csv`,
`prepare_report.json`, and a blank `clinical_template.csv`. Fill real PMA labels and optionally
group/health in a **copy** of the template, then rerun preparation in a new folder with
`--clinical /path/clinical.csv`. `name` must exactly match the MAT filename without `.mat`.
Do not combine different EEG variables as interchangeable independent subjects.

## Selection after splitting subjects

```sh
"$PY" "$CODE/feature_selection_new/split_subjects.py" \
  --data /path/labeled/dataset.csv --output /path/split
"$PY" "$CODE/feature_selection_new/select_features.py" \
  --data /path/split/train.csv --manifest /path/labeled/feature_manifest.json \
  --output /path/selection --method pearson --top-k 15
```

All output folders must be empty/new. `--method` accepts pearson, mi, elasticnet, xgboost, none.
The default redundancy limit is absolute correlation >=0.8, checked only against retained
features. Both positive and negative redundancy are handled. The default observed fraction is
0.5; at least three finite observations and variation are required. Inf is treated as missing.

Pearson uses pairwise finite observations and records p-values and BH FDR q-values for
exploration. These do not gate top-k selection. MI is sklearn continuous-target mutual
information after training-median imputation, not the old histogram estimator. ElasticNet
uses subject-cluster bootstrap, standardized features, alpha=0.05, l1_ratio=0.5, and nonzero
coefficients. XGBoost uses cluster bootstrap and training-only mean absolute SHAP, counting
top-k appearances. Both default to 30 bootstrap runs and appearance threshold 0.6. There is
no validation-error weighting. These choices can change selected features from the old code.
P-values assume independent rows: prefer subject-wide or single-variable tables for inference.

`selected_dataset.csv`/`selected_manifest.json` are training-only exploratory/final-fit exports.
For unbiased CV, models must receive the **original candidate dataset and manifest** plus
`selection_config.json`, so selection is refitted inside each fold. The model code rejects
globally supervised-selected manifests. Do not manually edit one to bypass that check.

Dependencies are in `requirements.txt`; optional XGBoost/SHAP are already installed in the
Jupyter environment on this Mac. Reproducibility uses seed 42. Minimum checks are computational
requirements, not evidence that a small cohort can support thousands of candidate predictors.

Tests: run `../models_new/test_pipeline.py`. See the Desktop full-process guide for model commands.
