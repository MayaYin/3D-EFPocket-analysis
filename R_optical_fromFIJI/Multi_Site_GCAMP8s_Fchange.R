#Multi Site Stimulation Analysis

# ============================================================
# Section 1: Setup — libraries and parameters
# ============================================================
library(ggplot2)
library(dplyr)
library(tidyr)
library(stringr)

# Set working directory to the folder containing this script and the CSV files
# If running interactively in RStudio: setwd(dirname(rstudioapi::getSourceEditorContext()$path))
# If running from command line, set your working directory first
dir_path <- "."

# stim_windows: time window (in seconds) to shade as the stimulation period on each plot
stim_windows <- data.frame(xmin = 22, xmax = 32)

files <- list.files(dir_path, pattern = "Results_.*\\.csv", full.names = TRUE)

gcamp_files <- files[grepl("^Results_g.*camp", basename(files))]
glut_files  <- files[grepl("^Results_glutamate", basename(files))]

get_suffix <- function(x) {
  sub("^Results_(g.*camp|glutamate)_Mesh_", "", basename(x))
}

gcamp_map <- setNames(gcamp_files, get_suffix(gcamp_files))
glut_map  <- setNames(glut_files,  get_suffix(glut_files))

common_keys <- intersect(names(gcamp_map), names(glut_map))

# ============================================================
# Section 2: Reference scaling from glutamate condition (0086)
# ============================================================
# Compute the peak dF/F from the glutamate condition to use as a
# common y-axis scale across all stimulus conditions (normalization anchor).
ref_key <- common_keys[grepl("0086", common_keys)]

REF_G_MAX <- NULL
REF_L_MAX <- NULL

if (length(ref_key) == 1) {

  df_gcamp <- read.csv(gcamp_map[[ref_key]], check.names = FALSE)
  df_glut  <- read.csv(glut_map[[ref_key]],  check.names = FALSE)

  gcamp_cols <- grep("^Mean", colnames(df_gcamp), value = TRUE)
  glut_cols  <- grep("^Mean", colnames(df_glut),  value = TRUE)

  df_ref <- data.frame()

  for (i in seq_len(min(length(gcamp_cols), length(glut_cols)))) {

    gcamp <- df_gcamp[[gcamp_cols[i]]]
    glut  <- df_glut[[glut_cols[i]]]

    # baseline_idx: frame indices used to compute F0 (baseline fluorescence)
    # 50 frames before frame 360 (adjust if your baseline period differs)
    baseline_idx <- (360-50):(360-1)
    baseline_idx <- baseline_idx[baseline_idx > 0]

    F0_gcamp <- mean(gcamp[baseline_idx], na.rm = TRUE)
    F0_glut  <- mean(glut[baseline_idx],  na.rm = TRUE)

    df_ref <- rbind(df_ref, data.frame(
      G = ((gcamp - F0_gcamp)/F0_gcamp)*100,
      L = ((glut  - F0_glut)/F0_glut)*100
    ))
  }

  REF_G_MAX <- max(abs(df_ref$G), na.rm = TRUE)
  REF_L_MAX <- max(abs(df_ref$L), na.rm = TRUE)
}

# ============================================================
# Section 3: Main loop — compute dF/F and plot per condition
# ============================================================
for (key in common_keys) {

  cat("Processing:", key, "\n")

  file_gcamp <- gcamp_map[[key]]
  file_glut  <- glut_map[[key]]

  clean_title <- gsub("^Results_|\\.csv", "", basename(file_gcamp))

  df_gcamp <- read.csv(file_gcamp, check.names = FALSE)
  df_glut  <- read.csv(file_glut,  check.names = FALSE)

  # fps: camera frame rate in frames per second — used to convert frame index to time (seconds)
  fps <- 15.2
  time <- seq_len(nrow(df_gcamp)) / fps

  gcamp_cols <- grep("^Mean", colnames(df_gcamp), value = TRUE)
  glut_cols  <- grep("^Mean", colnames(df_glut),  value = TRUE)

  df_all <- data.frame()

  for (i in seq_len(min(length(gcamp_cols), length(glut_cols)))) {

    gcamp <- df_gcamp[[gcamp_cols[i]]]
    glut  <- df_glut[[glut_cols[i]]]

    # baseline_idx: frames used for F0 calculation (50 frames before frame 360)
    baseline_idx <- (360-50):(360-1)
    baseline_idx <- baseline_idx[baseline_idx > 0]

    F0_gcamp <- mean(gcamp[baseline_idx], na.rm = TRUE)
    F0_glut  <- mean(glut[baseline_idx],  na.rm = TRUE)

    df_all <- rbind(df_all, data.frame(
      time = time,
      ROI = paste0("ROI ", i),
      GCaMP = ((gcamp - F0_gcamp)/F0_gcamp)*100,
      Glutamate = ((glut - F0_glut)/F0_glut)*100
    ))
  }

  ##########################################################
  # CONDITIONAL SCALING
  ##########################################################
  if (grepl("0085", key) & !is.null(REF_G_MAX)) {
    G_MAX <- REF_G_MAX
    L_MAX <- REF_L_MAX
  } else {
    G_MAX <- max(abs(df_all$GCaMP), na.rm = TRUE)
    L_MAX <- max(abs(df_all$Glutamate), na.rm = TRUE)
  }

  # SCALE: ratio used to align the glutamate y-axis to the GCaMP y-axis on the dual-axis plot
  SCALE <- G_MAX / L_MAX
  df_all$Glut_scaled <- df_all$Glutamate * SCALE

  ##########################################################
  # PLOT
  ##########################################################
  p <- ggplot(df_all, aes(x = time)) +

    geom_rect(
      data = stim_windows,
      aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf),
      inherit.aes = FALSE,
      fill = "grey",
      alpha = 0.6
    ) +

    geom_line(aes(y = GCaMP, color = "GCaMP"), linewidth = 1) +
    geom_line(aes(y = Glut_scaled, color = "Glutamate"), linewidth = 1) +

    geom_text(
      data = stim_windows,
      aes(x = xmin, y = G_MAX * 1, label = "ON"),
      inherit.aes = FALSE
    ) +

    geom_text(
      data = stim_windows,
      aes(x = xmax, y = G_MAX * 1, label = "OFF"),
      inherit.aes = FALSE,
      hjust = 1
    ) +

    facet_wrap(~ ROI, nrow = 1) +

    scale_color_manual(values = c(
      "GCaMP" = "#00A65A",
      "Glutamate" = "#00BFC4"
    )) +

    scale_y_continuous(
      limits = c(-G_MAX, G_MAX),
      name = "GCaMP (ΔF/F₀ %)",
      sec.axis = sec_axis(~ ./SCALE,
                          name = "Glutamate (ΔF/F₀ %)")
    ) +

    theme_classic() +
    labs(title = key)

  print(p)

  ##########################################################
  # SAVE
  ##########################################################
  safe_name <- gsub("[^A-Za-z0-9]", "_", clean_title)

  ggsave(
    filename = file.path(dir_path, paste0("FINAL_", key, "_", safe_name, ".pdf")),
    plot = p,
    width = 12,
    height = 4,
    units = "in",
    device = cairo_pdf
  )

}
