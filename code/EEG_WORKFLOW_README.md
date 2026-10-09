# EEG workflow: extraction → feature selection → models

Complete guide for the updated code on this Mac. Updated: 2026-10-08.

## 1. What is ready now

The code is installed in three neighboring folders on the Elements drive:

```text
/Volumes/Elements/code/
├── feature_extraction_new/       MATLAB extraction and graph analysis
├── feature_selection_new/        MATLAB export bridge and Python selection
└── models_new/                   Python training, validation and prediction
```

Use these updated folders for this workflow. The original `feature_extraction`,
`feature_selection`, and `models` folders remain available.

Your Desktop test files have already completed extraction and graph export:

| File | EEG variables | Each variable |
| --- | --- | --- |
| `chenjiayizhinv.mat` | 10 | 13 channels × 150001 samples |
| `chenjingzhizi.mat` | 5 | 13 channels × 150001 samples |

Both files were processed using **500 Hz** and **300-second epochs**. The sample count
is consistent with approximately 300 seconds at 500 Hz, but these files did not establish
the actual sampling rate or amplitude units. Confirm both from the acquisition records.

| Existing result | Location on Desktop |
| --- | --- |
| Extracted feature MAT files | `feature_extraction_output/` |
| Combined feature Excel table | `feature_extraction_output/graph_output/EEG_Feature_Combined.xlsx` |
| Graph feature-name mapping | `feature_extraction_output/graph_output/EEG_Feature_Columns.csv` |
| Subject-wide modeling table | `feature_selection_test_data/dataset.csv` |
| Candidate feature manifest | `feature_selection_test_data/feature_manifest.json` |
| Blank clinical-label template | `feature_selection_test_data/clinical_template.csv` |
| `EEG_sleep`-only modeling table | `feature_selection_test_data_sleep/dataset.csv` |

The graph table has 15 rows and 811 columns. The subject-wide table has 2 subject rows
and 8060 candidate features. The sleep-only table has 2 subject rows and 806 candidate
features. These are candidate counts before training-only filtering.

**The real-data files contain no PMA labels.** Extraction and table conversion are verified;
supervised selection and model validation require real labels and a larger cohort.
The model/selection tests used synthetic labeled data, not invented labels for your subjects.

## 2. Workflow and requirements

```text
Raw signal MAT files
        ↓ MATLAB: main
Extracted EEG feature MAT files
        ↓ MATLAB: export_extracted
Combined feature table + column map
        ↓ Python: prepare_data + clinical table
Subject-level dataset + candidate feature manifest
        ↓ Python: split_subjects
Training subjects                    Independent test subjects
        ↓ selection and grouped CV          │
Choose a method/model using training CV      │
        ↓ fit the chosen final model        │
        └──────────── evaluate once ─────────┘
                         ↓
              Saved model → new-subject prediction
```

MATLAB requirements: R2026a, Signal Processing Toolbox, and Statistics and Machine
Learning Toolbox. Python on this Mac:

```text
/Users/lei/miniforge3/envs/jupyter/bin/python
```

This environment has numpy, pandas, scipy, scikit-learn, openpyxl, joblib, XGBoost,
and SHAP installed. On another machine, install the packages listed in
`feature_selection_new/requirements.txt` into your chosen Python environment.

MATLAB blocks below run in the **MATLAB Command Window**. Shell blocks run in
**macOS Terminal**. They cannot be pasted interchangeably.

Each new analysis should use a new run folder. The examples below use
`/Users/lei/Desktop/eeg_workflow_run1`. If that folder already contains results,
change `run1` to a new name in both MATLAB and Terminal commands.

## 3. Check the raw data

Each EEG signal variable must be a real numeric matrix with **channels in rows and
time samples in columns**. Examples of supported names are `EEG_sleep`, `EEG_wake`,
`EEG_alpha_sleep`, and `EEG_beta_wake`.

```matlab
whos('-file','/Users/lei/Desktop/chenjiayizhinv.mat')
whos('-file','/Users/lei/Desktop/chenjingzhizi.mat')
```

Keep the same sampling rate, amplitude units, channel order, referencing scheme,
and band/state definitions across a cohort and future prediction data. A matching
matrix size alone does not establish comparable EEG measurements.

For a larger cohort, put only the raw input MAT files in a dedicated input folder.
The extraction batch scans that folder's top-level `*.mat` files; it does not scan
subfolders. Numeric matrix metadata may be mistaken for signal variables, so keep
input files limited to signals and clearly identifiable metadata.

Optional artifact sidecars must have the same shape as the signal:
`<signal_variable>_art`, for example `EEG_sleep_art`. Use `1` for artifact/excluded
and `0` for valid. A matching common `art` matrix is also supported.

## 4. Extract EEG features — MATLAB

For a fresh run using the two Desktop files:

```matlab
codeRoot = '/Volumes/Elements/code';
runRoot = '/Users/lei/Desktop/eeg_workflow_run1';
inputDir = '/Users/lei/Desktop';
extractDir = fullfile(runRoot,'extracted');

addpath(fullfile(codeRoot,'feature_extraction_new'),'-begin');
which main -all
which features_all -all

fs = 500;       % Replace with the confirmed acquisition sampling rate.
epoch = 300;    % Epoch duration in seconds, not samples.

extractionReport = main(inputDir,extractDir,fs,epoch);
disp(struct2table(extractionReport));
writetable(struct2table(extractionReport), ...
    fullfile(runRoot,'extraction_report.csv'));
```

The first `which` result should point to the updated folder. Change `inputDir` when
you add more subjects. Input and output folders must differ.

| Extraction status | Meaning |
| --- | --- |
| `saved` | Features were saved successfully. |
| `partial` | Some variables failed; inspect `message`. |
| `failed` | The file failed; inspect `message`. |
| `skipped` | An output already exists, or no eligible signal was extracted; inspect `message`. |

Inspect an output:

```matlab
R = load(fullfile(extractDir,'chenjiayizhinv.mat'));
fieldnames(R.EEG)
block = R.EEG.EEG_sleep;
size(block.feats{1})     % 20 × 13: single-channel feature rows × channels
numel(block.flist)       % 32 feature labels
size(block.feats{2})     % 13 × 13: first connectivity matrix
mean(block.art(:))      % Artifact fraction, 0–1
block.fs                % Sampling rate supplied to extraction
```

`feats{1}` has 20 single-channel feature rows; `feats{2:13}` contain 12 connectivity
matrices. Read the saved `flist` instead of assuming an old label order. NaN indicates
missing or inapplicable results. Names such as `EEG_alpha_sleep` are recognized as
band-specific: burst/suppression descriptors are left inapplicable, while the relevant
other features remain available.

### Optional preprocessing

The default batch performs artifact detection and ART-aware extraction without enabling
the extra `preprocess_eeg` filtering step. The two test files appear to be organized by
frequency band/state, so the verified run did not apply another bandpass to all variables.

For a folder containing suitable **raw broadband EEG**, you can enable preprocessing:

```matlab
opts = struct('HighpassHz',0.5,'LowpassHz',45, ...
              'LineHz',[],'MaxGapSeconds',0.5);
extractionReport = main(inputDir, ...
    fullfile(runRoot,'extracted_preprocessed'),fs,epoch,opts);
```

This applies a zero-phase 0.5–45 Hz filter and admits short internal gaps after
interpolation. Interpolated samples participate in feature calculations; long/edge
gaps remain excluded, with a filter guard around them. `LineHz` can specify the
confirmed line frequency, subject to the filter's frequency limits. Do not apply
this batch option indiscriminately to previously band-filtered signals.

Default artifact detection uses per-second maximum absolute amplitude: >500 or
<0.01 is excluded. Without optional preprocessing it pads detection by 5 seconds.
Those thresholds depend on signal units. Review them or supply a verified ART mask.
See `feature_extraction_new/README.md` for detailed artifact/statistical rules.

## 5. Export the feature table and graph features — MATLAB

Run this after successful extraction:

```matlab
addpath(fullfile(codeRoot,'feature_selection_new'),'-begin');
graphDir = fullfile(runRoot,'graph');

[T,graphReport,columnMap] = export_extracted(extractDir,graphDir);
disp(struct2table(graphReport));
size(T)
writetable(struct2table(graphReport), ...
    fullfile(runRoot,'graph_report.csv'));
```

The bridge reads extracted feature MAT files and calls the existing graph module.
It saves `EEG_Feature_Combined.xlsx`, `EEG_Feature_Combined.csv`, and
`EEG_Feature_Columns.csv`. Each table row represents one file and EEG variable.

The graph module defaults to edge proportion 0.4. For 13 channels, its regional
mapping follows the original project channel indices. Confirm the electrode order
before interpreting left/right or regional summaries. For other mappings, pass
an explicit region structure:

```matlab
% Example indices only: replace them with your actual channel assignments.
options = struct('Proportion',0.4, ...
    'Regions',struct('Left',[1 3],'Right',[2 4]));
[T,graphReport,columnMap] = export_extracted( ...
    extractDir,fullfile(runRoot,'graph_custom'),'',options);
```

The empty clinical filename `''` skips the clinical join here. Clinical labels
can be joined later in Python as described below.

Check `ARTFraction`, `ValidChannelCount`, and `IncompleteGraphCount`. An incomplete
connectivity network can produce missing graph metrics. Observed zero weights,
missing connections, and disconnected graphs have different meanings; do not
replace all missing values with zero.

Graph outputs already exist for your two test files. To reuse them, skip Sections
4–5 and use the existing graph folder in the Terminal setup below.

## 6. Set Terminal paths and choose a table layout

Open Terminal and run:

```sh
PY=/Users/lei/miniforge3/envs/jupyter/bin/python
CODE=/Volumes/Elements/code
RUN=/Users/lei/Desktop/eeg_workflow_run1
GRAPH="$RUN/graph"
GROUP=name
mkdir -p "$RUN"
```

If reusing the already-generated test export, change only `GRAPH`:

```sh
GRAPH=/Users/lei/Desktop/feature_extraction_output/graph_output
```

Choose one layout before preparing your cohort:

| Layout | How to request it | Result |
| --- | --- | --- |
| Subject-wide | Default | One subject row; each band/state gets prefixed feature columns. |
| One EEG variable | `--variable EEG_sleep` | One row per subject that has that variable. |

Missing variables in subject-wide data become NaN. A single-variable layout is useful
when all subjects have the same recording type, such as `EEG_sleep`. Subjects lacking
the requested variable are listed in the preparation report. Do not treat a subject's
multiple bands as independent subjects to increase the sample count.

The examples below use subject-wide layout. If you choose single-variable layout,
add the same `--variable EEG_sleep` option to every preparation command, including
future prediction-data preparation.

## 7. Create the clinical template, then supply real labels

First prepare without clinical labels:

```sh
"$PY" "$CODE/feature_selection_new/prepare_data.py" \
  --input "$GRAPH/EEG_Feature_Combined.xlsx" \
  --column-map "$GRAPH/EEG_Feature_Columns.csv" \
  --output "$RUN/prepared_unlabeled"
```

Open `prepared_unlabeled/clinical_template.csv` in Excel and save a filled copy as
`eeg_workflow_run1/clinical.csv`. Keep the original blank template as a template.

| Column | Required content |
| --- | --- |
| `name` | Exact MAT basename without `.mat`; one unique row per name. |
| `PMA` | Real numeric target; use the same units throughout the cohort. |
| `group` | Optional cohort/category information. |
| `health` | Optional clinical information. |
| `subject_id` | Add if several file basenames belong to the same person. |

For these test files the names are `chenjiayizhinv` and `chenjingzhizi`. Do not fill
example numbers or zeros in place of unknown PMA. CSV UTF-8 or XLSX is supported;
if saving XLSX, change the clinical filename in the next command accordingly.

If adding `subject_id`, set `GROUP=subject_id` in Terminal. Use that grouping choice
consistently for splitting, selection, and training. `group` is often a clinical
cohort/age category and is not automatically a person identifier.

Prepare the labeled dataset into a new folder:

```sh
"$PY" "$CODE/feature_selection_new/prepare_data.py" \
  --input "$GRAPH/EEG_Feature_Combined.xlsx" \
  --column-map "$GRAPH/EEG_Feature_Columns.csv" \
  --clinical "$RUN/clinical.csv" \
  --output "$RUN/prepared_labeled"
```

Preparation produces:

| Output | Purpose |
| --- | --- |
| `dataset.csv` | Numeric candidates, subject identifiers, and joined clinical labels. |
| `feature_manifest.json` | Exact list of eligible candidate feature columns. |
| `feature_columns.csv` | Output columns mapped to original feature labels/EEG variables. |
| `prepare_report.json` | Row/subject/feature counts and omitted-variable subjects. |
| `clinical_template.csv` | Blank template, not a labeled training table. |

Identifiers, PMA, clinical columns, and ART quality fields are excluded from the
manifest's predictors. Constant and all-missing candidates may still appear here;
their removal is learned from training data rather than the whole cohort.

**With only the current two subjects, stop here.** The automated split must leave
at least four training groups, and each model training fold needs at least three
groups and varying labels. At a 20% holdout, five total groups are the arithmetic
minimum, not a scientifically adequate sample size for thousands of predictors.

## 8. Split subjects before supervised selection

After adding a sufficiently large labeled cohort:

```sh
"$PY" "$CODE/feature_selection_new/split_subjects.py" \
  --data "$RUN/prepared_labeled/dataset.csv" \
  --group-column "$GROUP" \
  --test-fraction 0.2 \
  --output "$RUN/split"
```

This writes `train.csv`, `test.csv`, and `split_subjects.json`. All records from a
subject/group stay on one side of the split. The default seed is 42. The split is
random by subject group; it does not guarantee balanced PMA/health distributions.

Keep the independent test subjects out of feature selection and model choices.
If you already have a separate external test cohort, use its separately prepared
table instead; training and external-test people/groups must not overlap.

## 9. Explore and configure feature selection using training subjects

Start with Pearson screening:

```sh
"$PY" "$CODE/feature_selection_new/select_features.py" \
  --data "$RUN/split/train.csv" \
  --manifest "$RUN/prepared_labeled/feature_manifest.json" \
  --group-column "$GROUP" \
  --method pearson --top-k 15 \
  --output "$RUN/selection_pearson"
```

| `--method` | What it does |
| --- | --- |
| `pearson` | Ranks absolute Pearson correlation with PMA; exports p-values and BH FDR q-values. |
| `mi` | Continuous-target mutual information after training-median imputation. |
| `elasticnet` | Subject-cluster bootstrap; standardized-feature nonzero-coefficient stability. |
| `xgboost` | Subject-cluster bootstrap; training-only SHAP top-k appearance stability. |
| `none` | Removes unusable candidates but retains all remaining features. |

To try another method, change `--method` and use a different output folder. For
ElasticNet/XGBoost you can also set `--bootstrap-runs 30 --stability 0.6`.

The default observed fraction is 0.5, with at least three observations and variation
required. Redundancy filtering rejects absolute correlation >=0.8 with a retained
feature, including negative correlation. `top-k` is an upper limit; fewer features
may survive. Pearson p/q-values are exploratory and do not gate top-k selection.

Review `feature_ranking.csv`, `dropped_features.csv`, and `selected_features.csv`.
`selection_config.json` records the method/thresholds for the model stage.

`selected_dataset.csv` and `selected_manifest.json` are exploratory/training-only
exports. **For cross-validation use the original candidate dataset/manifest**, as
in the next section. Selection must be refitted inside each CV training fold. The
model code explicitly rejects the globally supervised-selected manifest.

## 10. Compare models using training-set cross-validation

This command intentionally evaluates only training subjects:

```sh
"$PY" "$CODE/models_new/model_workflow.py" train \
  --data "$RUN/split/train.csv" \
  --manifest "$RUN/prepared_labeled/feature_manifest.json" \
  --selection-config "$RUN/selection_pearson/selection_config.json" \
  --group-column "$GROUP" \
  --model all --folds 5 \
  --output "$RUN/models_cv"
```

Models: `ols`, `ridge`, `lasso`, `elasticnet`, `decisiontree`, `randomforest`,
`ensemble`, or `all`. The ensemble is equal-weight OLS/Random Forest voting.
Hyperparameters are fixed defaults recorded in `run_config.json`; the new workflow
does not automatically perform a grid search.

GroupKFold keeps people/groups separated. Within each fold, the code fits feature
usability checks, selection, redundancy filtering, imputation, scaling, and the
regression model using only the training portion. The effective number of folds
is reduced when fewer groups are available. More bootstrap runs can increase runtime.

Open `models_cv/model_comparison.csv`:

| Metric | Interpretation |
| --- | --- |
| `MAE` | Mean absolute prediction error; lower is better. |
| `RMSE` | Error metric that penalizes large errors more; lower is better. |
| `R2` | Explained variance relative to the mean baseline; may be negative. |
| `SubjectBalancedMAE` | Gives equal weight to subjects with different row counts. |

MAE/RMSE use the same units as PMA. Overall CV metrics use held-out predictions.
A one-row or constant-target validation fold has no reported R².

Per-model folders contain:

```text
cv_predictions.csv          Names, fold IDs, true/predicted targets, residuals
fold_metrics.csv            Metrics for each validation fold
cv_metrics.json             Aggregate held-out metrics
fold_subjects.json          Training/validation group and person audit
fold_selected_features.csv  Features selected separately in each fold
final_feature_ranking.csv   Ranking from all training subjects
used_features.csv           Final feature names
final_weights.csv           Coefficients/importances, when available
run_config.json             Model and selection settings
model.joblib                Selector + imputer + scaler + fitted regressor
```

Choose the model/method using training evidence and your study design. Comparing
many methods or tuning thresholds can make training CV optimistic; the untouched
test cohort is needed to assess the final chosen workflow.

## 11. Evaluate the chosen model on independent test subjects

After choosing a model, evaluate it using a fresh output directory. `ridge` below
is an example; replace it with your chosen model and selection configuration:

```sh
"$PY" "$CODE/models_new/model_workflow.py" train \
  --data "$RUN/split/train.csv" \
  --manifest "$RUN/prepared_labeled/feature_manifest.json" \
  --selection-config "$RUN/selection_pearson/selection_config.json" \
  --group-column "$GROUP" \
  --model ridge --folds 5 \
  --test "$RUN/split/test.csv" \
  --output "$RUN/models_final"
```

This refits on all training subjects and writes `test_predictions.csv` and
`test_metrics.json` in `models_final/ridge/`. Test labels are used only to calculate
errors, never for feature selection, fitting, or prediction corrections. Without
target labels, the independent-test command can write predictions without metrics.

Report test performance for the workflow selected before inspecting test results.
Repeatedly choosing features/parameters/models from test errors makes that dataset
a development set rather than an independent final test.

## 12. Predict a new subject without PMA

Process new raw data with the same extraction settings, graph mapping, and table
layout. Example Terminal setup after new extraction/graph export:

```sh
NEW_GRAPH=/path/to/new_subject_graph
NEW_PREPARED=/Users/lei/Desktop/eeg_new_subject_prepared

"$PY" "$CODE/feature_selection_new/prepare_data.py" \
  --input "$NEW_GRAPH/EEG_Feature_Combined.xlsx" \
  --column-map "$NEW_GRAPH/EEG_Feature_Columns.csv" \
  --output "$NEW_PREPARED"

"$PY" "$CODE/models_new/model_workflow.py" predict \
  --model-file "$RUN/models_final/ridge/model.joblib" \
  --data "$NEW_PREPARED/dataset.csv" \
  --output "$RUN/new_subject_predictions.csv"
```

Replace `/path/to/new_subject_graph` with the actual export folder. If you trained
with `--variable EEG_sleep`, add that option to this preparation command too.

Prediction needs the final selected feature columns with exactly the same names
and meanings. NaN observations are filled using saved training values. An absent
required column is an error. In subject-wide mode, a new export with fewer EEG
variable types may omit entire prefixed columns; standardize the variable schema
upstream or use a consistent single-variable workflow. Do not invent missing columns
or rename unrelated features merely to make the code run.

Use a model file created by this workflow and keep `feature_selection_new` available
beside `models_new`, since the saved selector refers to that Python module.

## 13. Validation and troubleshooting

Run synthetic checks when changing code or moving the installation:

```matlab
addpath('/Volumes/Elements/code/feature_extraction_new','-begin');
test_feature_extraction;
test_preprocess_eeg;
addpath('/Volumes/Elements/code/feature_extraction_new/graph theory','-begin');
test_graph_theory;
```

```sh
"$PY" "$CODE/models_new/test_pipeline.py"
```

The extraction/preprocessing tests passed previously. The real export and MATLAB
bridge were verified. The Python tests passed all five selection methods and seven
model modes, grouped validation, independent-test separation, missing/constant
features, negative redundancy, clinical joining, and saved-model unlabeled prediction.

| Message/problem | Action |
| --- | --- |
| Extraction says `skipped` | Read its message; an existing output is skipped. Use a fresh extraction folder to recompute. |
| Graph output already exists / Python output is not empty | Choose a new output folder; the workflow protects previous results. |
| Missing target PMA | Join a real clinical table by name; raw EEG MAT files do not supply PMA. |
| PMA is missing/nonfinite/nonnumeric | Correct the clinical labels and rebuild the labeled table. |
| Too few subject groups / no varying training target | Add adequate real labeled subjects; do not replicate rows or invent labels. |
| No usable/selected features | Inspect missingness, units, artifacts, and training-only thresholds. |
| Globally selected manifest rejected | Use `prepared_labeled/feature_manifest.json` and pass `selection_config.json`. |
| Independent test overlaps training | Correct subject identities and split whole subjects/groups. |
| Missing feature column during prediction | Check EEG variable layout, extraction version, channel mapping, and the original feature manifest. |
| Missing Python package | Use the stated Jupyter Python executable; another `python` may use a different environment. |
| MATLAB function points to the original folder | Put the updated folder first in the MATLAB path and inspect `which ... -all`. |

Preserve the raw files, clinical table, original candidate manifest, feature-label
mapping, subject split, extraction settings/reports, selection configuration, run
configuration, and saved model together for reproducibility. The updated scripts
are consolidated workflows; historical plotting/VIF/grid-search experiments are
not all reproduced. Further algorithm details are in each code folder's README.
