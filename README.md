# 3D µEFPocket for Multimodal Communications with Brain Organoids Analysis 

Analysis code accompanying the manuscript. Three independent pipelines cover electrical recording analysis, calcium imaging analysis from Suite2p, and calcium imaging analysis from FIJI ROI measurements.

---

## Repository Structure

```
mesh_submission/
├── Python_electrical_optical/
│   ├── electrical_analysis_mesh.ipynb                 # Electrophysiology pipeline (Intan RHS)
│   ├── mesh_suite2p_output.ipynb                      # Calcium imaging pipeline (Suite2p output)
|   ├── Latency plot by fluorescence intensity.ipynb   # Latency plot of electrical stimulation
│   ├── load_intan_rhs.py                              # Intan RHS file reader
│   ├── importrhdutilities.py                          # Intan RHD file utilities
│   ├── intanutil/                                     # Intan parser helpers (header, data, filter, report)
│   ├── Intan_output_example/                          # Example RHS recording (3 consecutive files)
│   └── Suite2p_output_example/                        # Example Suite2p output (plane0 .npy files)
│
└── R_optical_fromFIJI/
    ├── Multi_Site_GCAMP8s_Fchange.R                   # GCaMP + Glutamate dF/F analysis
    ├── Results_gcamp_*.csv                            # FIJI ROI measurements — GCaMP channel
    └── Results_glutamate_*.csv                        # FIJI ROI measurements — Glutamate sensor channel
```

---

## Pipelines

### 1. Electrophysiology — `electrical_analysis_mesh.ipynb`

Processes raw Intan RHS recordings from mesh MEA electrodes. Runs end-to-end on the included example data without any path changes.

**Steps:**
1. Load `.rhs` file(s) and build electrode channel map
2. Detect stimulation windows from recorded stim channel or amplitude threshold
3. Interpolate over stimulation artifacts
4. Bandpass filter (300–6000 Hz) via SpikeInterface
5. Detect spikes using sliding-window local standard deviation threshold
6. Cluster spike waveforms with PCA + K-Means; optionally with UMAP + DBSCAN
7. Export spike cutouts and timestamps to `.npy`

---

### 2. Calcium Imaging (Suite2p) — `mesh_suite2p_output.ipynb`

Processes Suite2p output from GCaMP recordings. Runs end-to-end on the included example data.

**Steps:**
1. Load Suite2p output (F, Fneu, spks, stat, ops, iscell)
2. Select cell-classified ROIs
3. Define stimulation timing from known timestamps 
4. Plot fluorescence traces and ΔF/F heatmaps
5. Compute spike timing latencies relative to stimulation onset
6. Plot ROI positions on mean image; color by latency
7. Pairwise fluorescence correlation matrix

---

### 3. Calcium Imaging (FIJI) — `Multi_Site_GCAMP8s_Fchange.R`

Computes ΔF/F₀ from FIJI multi-measurement ROI exports and plots paired GCaMP and Glutamate sensor traces per ROI per condition. Scales the Glutamate axis to match the GCaMP axis using the glutamate bath condition (0086) as a reference.

**Steps:**
1. Load matched GCaMP and Glutamate CSV pairs for each condition
2. Compute ΔF/F₀ (%) using a 50-frame pre-stimulus baseline
3. Scale Glutamate signal to GCaMP dynamic range using the 0086 glutamate reference
4. Plot dual-axis ΔF/F traces with stimulation window shading per ROI
5. Save one PDF per condition

**Conditions (filename suffixes):**

| File suffix | Condition |
|---|---|
| `1_stim200faprox_0077` | Stimulation trial 1 |
| `2_stim200faprox_0078` | Stimulation trial 2 |
| `3_stim200faprox_0082` | Stimulation trial 3 |
| `4_stim200faprox_0084` | Stimulation trial 4 |
| `baselinefaprox_0085` | Baseline (no stimulation; scaled to 0086 reference) |
| `glutamate_40ulfaprox_0086` | 40 µL glutamate bath (reference for axis scaling) |

**CSV format:** FIJI multi-measure output with columns `Mean1`, `Mean2`, … for each ROI per frame. One row per frame at 15.2 Hz.
