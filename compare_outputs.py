"""
compare_outputs.py
------------------
Run each documentation example from the hetset package in both R and Python
and print the outputs side-by-side for visual comparison.

Usage:
    python compare_outputs.py

Requirements:
    - R installed and on PATH (Rscript)
    - R packages: hetset, fixest, sensemakr, data.table
    - Python packages: hetset (this repo, pip install -e Python/[all])
"""

import subprocess
import sys
import textwrap
import tempfile
import os

# -- formatting helpers --------------------------------------------------------

COL_WIDTH = 56   # width of each language column
SEP = " | "

def _box(title, text, width=COL_WIDTH):
    """Wrap text into a fixed-width box with a title."""
    lines = []
    for raw in text.splitlines():
        # Hard-wrap long lines
        wrapped = textwrap.wrap(raw, width=width - 2) if len(raw) > width - 2 else [raw]
        lines.extend(wrapped or [''])
    return title.ljust(width), [l.ljust(width) for l in lines]


def print_comparison(title, r_output, py_output):
    """Print R and Python outputs for one example side by side."""
    hr = "-" * COL_WIDTH
    print(f"\n{'=' * (COL_WIDTH * 2 + len(SEP))}")
    heading = f"  EXAMPLE: {title}"
    print(heading)
    print(f"{'=' * (COL_WIDTH * 2 + len(SEP))}")
    print(f"{'R':^{COL_WIDTH}}{SEP}{'Python':^{COL_WIDTH}}")
    print(f"{hr}{SEP}{hr}")

    r_lines  = r_output.rstrip().splitlines()
    py_lines = py_output.rstrip().splitlines()

    n = max(len(r_lines), len(py_lines))
    r_lines  += [''] * (n - len(r_lines))
    py_lines += [''] * (n - len(py_lines))

    for r_l, py_l in zip(r_lines, py_lines):
        print(f"{r_l:<{COL_WIDTH}}{SEP}{py_l:<{COL_WIDTH}}")

    print(f"{hr}{SEP}{hr}")


# -- runner helpers ------------------------------------------------------------

def run_r(code: str) -> str:
    """Execute R code via Rscript and return stdout (stderr suppressed)."""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.R',
                                     delete=False, encoding='utf-8') as f:
        f.write(code)
        fname = f.name
    try:
        result = subprocess.run(
            ['Rscript', '--vanilla', fname],
            capture_output=True, text=True, timeout=120,
        )
        out = result.stdout
        if result.returncode != 0:
            out += '\n[R ERROR]\n' + result.stderr
        return out.strip()
    finally:
        os.unlink(fname)


def run_python(code: str) -> str:
    """Execute Python code in a subprocess and return stdout."""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.py',
                                     delete=False, encoding='utf-8') as f:
        f.write(code)
        fname = f.name
    try:
        result = subprocess.run(
            [sys.executable, fname],
            capture_output=True, text=True, timeout=120,
        )
        out = result.stdout
        if result.returncode != 0:
            out += '\n[PYTHON ERROR]\n' + result.stderr
        return out.strip()
    finally:
        os.unlink(fname)


# -----------------------------------------------------------------------------
# EXAMPLE DEFINITIONS
# Each example is a (title, r_code, py_code) tuple.
# -----------------------------------------------------------------------------

R_PREAMBLE = """\
suppressPackageStartupMessages({
  library(hetset)
  library(fixest)
  library(data.table)
})
data("close_college")
ORDER <- c('Neither','Black','South','Black and South')
options(digits = 6)

# ---- Patches for installed-package bugs ------------------------------------
# The installed hetset (v0.1.0) pre-dates two source fixes:
#   (1) identified_set_exists: missing 'numsets = ncol(rst)' line.
#   (2) univariate_bounds_table pin_values: installed version also sets
#       $estimate = pinned value, shifting pairwise constraints.
#       The source (and Python port) do NOT update $estimate.
# These patched versions match the current source / Python behaviour.

identified_set_exists <- function(full_bounds_set, check_only = NULL,
                                   return_one_solution = FALSE) {
  get_setup <- hetset:::set_up_solver(full_bounds_set, check_only)
  rst   <- get_setup$rst
  direc <- get_setup$direc
  rhs   <- get_setup$rhs
  numsets <- ncol(rst)        # fix: was missing in installed pkg
  slv <- Rglpk::Rglpk_solve_LP(obj = rep(0, numsets), mat = rst,
                                 dir = direc, rhs = rhs)
  if (slv$status == 0) {
    if (return_one_solution) {
      solution <- slv$solution
      settingnames <- names(full_bounds_set[[1]])
      if (!is.null(check_only)) settingnames <- check_only
      names(solution) <- settingnames
      return(solution)
    } else return(TRUE)
  } else return(FALSE)
}

univariate_bounds_table <- function(full_bounds_set, pin_values = NULL, ...) {
  setting_names      <- names(full_bounds_set[[1]])
  original_bounds_set <- copy(full_bounds_set)
  if (!is.null(pin_values)) {
    for (s in names(pin_values)) {
      set_value <- pin_values[[s]]
      if (!is.numeric(set_value)) {
        if      (set_value == 'lower')    set_value <- full_bounds_set[[1]][[s]]$lower
        else if (set_value == 'upper')    set_value <- full_bounds_set[[1]][[s]]$upper
        else if (set_value == 'original') set_value <- full_bounds_set[[1]][[s]]$estimate
        else stop(paste0("pin_values for '", s, "' must be numeric, 'lower', 'upper', or 'original'."))
      }
      # fix: installed pkg also sets $estimate = set_value (shifts pairwise
      # constraints). Source and Python do NOT do this.
      full_bounds_set[[1]][[s]]$lower <- set_value
      full_bounds_set[[1]][[s]]$upper <- set_value
    }
  }
  get_setup <- hetset:::set_up_solver(full_bounds_set, check_only = NULL)
  rst <- get_setup$rst; direc <- get_setup$direc; rhs <- get_setup$rhs
  numsets <- length(setting_names)
  full_bounds_table <- data.table::data.table()
  for (s in 1:numsets) {
    mincol <- maxcol <- rep(0, numsets)
    mincol[s] <-  1; maxcol[s] <- -1
    slv_low <- Rglpk::Rglpk_solve_LP(obj = mincol, mat = rst, dir = direc, rhs = rhs)$solution[s]
    slv_up  <- Rglpk::Rglpk_solve_LP(obj = maxcol, mat = rst, dir = direc, rhs = rhs)$solution[s]
    est <- full_bounds_set[[1]][[s]]$estimate
    full_bounds_table <- rbind(full_bounds_table, data.table::data.table(
      setting = setting_names[s], estimate = est,
      lower_bound = slv_low, upper_bound = slv_up,
      lower_nu_bound = est - slv_up, upper_nu_bound = est - slv_low,
      original_lower_bound = original_bounds_set[[1]][[s]]$lower,
      original_upper_bound = original_bounds_set[[1]][[s]]$upper))
  }
  full_bounds_table[, lower_bound := estimate - upper_nu_bound]
  full_bounds_table[, upper_bound := estimate - lower_nu_bound]
  return(full_bounds_table)
}
# ---- End patches -----------------------------------------------------------
"""

PY_PREAMBLE = """\
import warnings
warnings.filterwarnings('ignore')
import numpy as np
import pandas as pd
pd.set_option('display.precision', 6)
pd.set_option('display.float_format', '{:.6f}'.format)
pd.set_option('display.width', 200)
from hetset import (
    load_close_college, c_bounds, ovb_bounds_by_setting,
    supershort_rho_bounds_proposal, build_bounds,
    identified_set_exists, univariate_bounds_table,
)
df = load_close_college()
ORDER = ['Neither', 'Black', 'South', 'Black and South']
"""

EXAMPLES = []

# -- 1. c_bounds --------------------------------------------------------------

EXAMPLES.append((
    "c_bounds(b_lower=-0.2, b_upper=0.2, rho_upper=2)",

    R_PREAMBLE + """\
cat("c_bounds(-0.2, 0.2, rho_upper=2):\\n")
print(c_bounds(-0.2, 0.2, 2))

cat("\\nc_bounds(-0.2, 0.2, rho_upper=2, return_full_set=TRUE):\\n")
print(c_bounds(-0.2, 0.2, 2, return_full_set = TRUE))

cat("\\nc_bounds(-0.2, 0.2, rho_upper=3, rho_lower=1.5):\\n")
print(c_bounds(-0.2, 0.2, rho_upper=3, rho_lower=1.5))
""",

    PY_PREAMBLE + """\
print("c_bounds(-0.2, 0.2, rho_upper=2):")
print(c_bounds(-0.2, 0.2, rho_upper=2))

print()
print("c_bounds(-0.2, 0.2, rho_upper=2, return_full_set=True):")
print(c_bounds(-0.2, 0.2, rho_upper=2, return_full_set=True))

print()
print("c_bounds(-0.2, 0.2, rho_upper=3, rho_lower=1.5):")
print(c_bounds(-0.2, 0.2, rho_upper=3, rho_lower=1.5))
""",
))

# -- 2. ovb_bounds_by_setting -------------------------------------------------

EXAMPLES.append((
    "ovb_bounds_by_setting",

    R_PREAMBLE + """\
bounds <- ovb_bounds_by_setting(
  close_college,
  setting              = 'blacksouth',
  treatment            = 'educ',
  model                = 'feols(lwage ~ educ + smsa + married + exper, data = data)',
  benchmark_covariates = c('smsa','married','exper'),
  kd                   = 0.1
)
cols <- c('setting','original_estimate','adjusted_estimate',
          'lower_plausible_bound','upper_plausible_bound')
print(bounds[match(ORDER, setting), ..cols])
""",

    PY_PREAMBLE + """\
bounds = ovb_bounds_by_setting(
    data=df,
    setting='blacksouth',
    treatment='educ',
    model='lwage ~ educ + smsa + married + exper',
    benchmark_covariates=['smsa', 'married', 'exper'],
    kd=0.1,
)
cols = ['setting','original_estimate','adjusted_estimate',
        'lower_plausible_bound','upper_plausible_bound']
out = bounds.set_index('setting').loc[ORDER, cols[1:]].reset_index()
print(out.to_string(index=False))
""",
))

# -- 3. supershort_rho_bounds_proposal (table) ---------------------------------

EXAMPLES.append((
    "supershort_rho_bounds_proposal (return table)",

    R_PREAMBLE + """\
tab <- supershort_rho_bounds_proposal(
  data          = close_college,
  setting       = 'blacksouth',
  treatment     = 'educ',
  model         = 'fixest::feols(lwage ~ educ + smsa + married + exper, data = data)',
  model_shorter = 'fixest::feols(lwage ~ educ, data = data)',
  settings_order = ORDER,
  return        = 'table'
)
print(tab)
""",

    PY_PREAMBLE + """\
tab = supershort_rho_bounds_proposal(
    data=df,
    setting='blacksouth',
    treatment='educ',
    model='lwage ~ educ + smsa + married + exper',
    model_shorter='lwage ~ educ',
    settings_order=ORDER,
    return_type='table',
)
print(tab.to_string(index=False))
""",
))

# -- 4. supershort_rho_bounds_proposal (matrix) --------------------------------

EXAMPLES.append((
    "supershort_rho_bounds_proposal (return matrix)",

    R_PREAMBLE + """\
mat <- supershort_rho_bounds_proposal(
  data          = close_college,
  setting       = 'blacksouth',
  treatment     = 'educ',
  model         = 'fixest::feols(lwage ~ educ + smsa + married + exper, data = data)',
  model_shorter = 'fixest::feols(lwage ~ educ, data = data)',
  settings_order = ORDER,
  return        = 'matrix'
)
print(mat)
""",

    PY_PREAMBLE + """\
mat = supershort_rho_bounds_proposal(
    data=df,
    setting='blacksouth',
    treatment='educ',
    model='lwage ~ educ + smsa + married + exper',
    model_shorter='lwage ~ educ',
    settings_order=ORDER,
    return_type='matrix',
)
import pandas as pd
mat_df = pd.DataFrame(mat, index=ORDER, columns=ORDER)
print(mat_df.to_string())
""",
))

# -- 5. build_bounds -----------------------------------------------------------
# Uses a fixed rho matrix (not from supershort), matching the docstring example.

EXAMPLES.append((
    "build_bounds (univariate_bounds component)",

    R_PREAMBLE + """\
bounds <- ovb_bounds_by_setting(
  close_college,
  setting              = 'blacksouth',
  treatment            = 'educ',
  model                = 'feols(lwage ~ educ + smsa + married + exper, data = data)',
  benchmark_covariates = c('smsa','married','exper'),
  kd                   = 0.1
)
boundmat <- matrix(
  c(0, 2, 1.5, 0,
    0, 0, 0,   1.5,
    0, 0, 0,   2,
    0, 0, 0,   0),
  nrow = 4, byrow = TRUE
)
pi_bounds <- build_bounds(bounds, boundmat, settings_order = ORDER)

cat("--- univariate_bounds ---\\n")
for (s in ORDER) {
  ub <- pi_bounds$univariate_bounds[[s]]
  cat(sprintf("  %s: estimate=%.6f  lower=%.6f  upper=%.6f\\n",
              s, ub$estimate, ub$lower, ub$upper))
}

cat("\\n--- paired_bounds matrix ---\\n")
pb <- pi_bounds$paired_bounds
pb_num <- matrix(NA_real_, 4, 4, dimnames = list(ORDER, ORDER))
for (i in seq_along(ORDER))
  for (j in seq_along(ORDER))
    if (i != j) pb_num[i, j] <- as.numeric(pb[[i, j]])
print(round(pb_num, 6))
""",

    PY_PREAMBLE + """\
import numpy as np

bounds = ovb_bounds_by_setting(
    data=df,
    setting='blacksouth',
    treatment='educ',
    model='lwage ~ educ + smsa + married + exper',
    benchmark_covariates=['smsa', 'married', 'exper'],
    kd=0.1,
)
boundmat = np.array([
    [0,   2,   1.5, 0  ],
    [0,   0,   0,   1.5],
    [0,   0,   0,   2  ],
    [0,   0,   0,   0  ],
])
pi_bounds = build_bounds(bounds, boundmat, settings_order=ORDER)

print("--- univariate_bounds ---")
for s in ORDER:
    ub = pi_bounds['univariate_bounds'][s]
    print(f"  {s}: estimate={ub['estimate']:.6f}  lower={ub['lower']:.6f}  upper={ub['upper']:.6f}")

print()
print("--- paired_bounds matrix ---")
print(pi_bounds['paired_bounds'].loc[ORDER, ORDER].round(6).to_string())
""",
))

# -- 6. identified_set_exists -------------------------------------------------

EXAMPLES.append((
    "identified_set_exists",

    R_PREAMBLE + """\
bounds <- ovb_bounds_by_setting(
  close_college,
  setting              = 'blacksouth',
  treatment            = 'educ',
  model                = 'feols(lwage ~ educ + smsa + married + exper, data = data)',
  benchmark_covariates = c('smsa','married','exper'),
  kd                   = 0.1
)
boundmat <- matrix(
  c(0, 2, 1.5, 0,
    0, 0, 0,   1.5,
    0, 0, 0,   2,
    0, 0, 0,   0),
  nrow = 4, byrow = TRUE
)
pi_bounds <- build_bounds(bounds, boundmat, settings_order = ORDER)

cat("identified_set_exists:\\n")
print(identified_set_exists(pi_bounds))

cat("\\none feasible solution:\\n")
print(round(identified_set_exists(pi_bounds, return_one_solution = TRUE), 6))
""",

    PY_PREAMBLE + """\
import numpy as np

bounds = ovb_bounds_by_setting(
    data=df, setting='blacksouth', treatment='educ',
    model='lwage ~ educ + smsa + married + exper',
    benchmark_covariates=['smsa','married','exper'], kd=0.1,
)
boundmat = np.array([
    [0,   2,   1.5, 0  ],
    [0,   0,   0,   1.5],
    [0,   0,   0,   2  ],
    [0,   0,   0,   0  ],
])
pi_bounds = build_bounds(bounds, boundmat, settings_order=ORDER)

print("identified_set_exists:")
print(identified_set_exists(pi_bounds))

print()
print("one feasible solution:")
sol = identified_set_exists(pi_bounds, return_one_solution=True)
for k, v in sol.items():
    print(f"  {k}: {v:.6f}")
""",
))

# -- 7. univariate_bounds_table -----------------------------------------------

EXAMPLES.append((
    "univariate_bounds_table",

    R_PREAMBLE + """\
bounds <- ovb_bounds_by_setting(
  close_college,
  setting              = 'blacksouth',
  treatment            = 'educ',
  model                = 'feols(lwage ~ educ + smsa + married + exper, data = data)',
  benchmark_covariates = c('smsa','married','exper'),
  kd                   = 0.1
)
boundmat <- matrix(
  c(0, 2, 1.5, 0,
    0, 0, 0,   1.5,
    0, 0, 0,   2,
    0, 0, 0,   0),
  nrow = 4, byrow = TRUE
)
pi_bounds <- build_bounds(bounds, boundmat, settings_order = ORDER)
tbl <- univariate_bounds_table(pi_bounds)
tbl_ordered <- tbl[match(ORDER, tbl$setting), ]
print(tbl_ordered[, c('setting','estimate','lower_bound','upper_bound',
                       'lower_nu_bound','upper_nu_bound')])
""",

    PY_PREAMBLE + """\
import numpy as np

bounds = ovb_bounds_by_setting(
    data=df, setting='blacksouth', treatment='educ',
    model='lwage ~ educ + smsa + married + exper',
    benchmark_covariates=['smsa','married','exper'], kd=0.1,
)
boundmat = np.array([
    [0,   2,   1.5, 0  ],
    [0,   0,   0,   1.5],
    [0,   0,   0,   2  ],
    [0,   0,   0,   0  ],
])
pi_bounds = build_bounds(bounds, boundmat, settings_order=ORDER)
tbl = univariate_bounds_table(pi_bounds)
cols = ['setting','estimate','lower_bound','upper_bound',
        'lower_nu_bound','upper_nu_bound']
out = tbl.set_index('setting').loc[ORDER, cols[1:]].reset_index()
print(out.to_string(index=False))
""",
))

# -- 8. univariate_bounds_table with pin_values -------------------------------

EXAMPLES.append((
    "univariate_bounds_table (pin_values)",

    R_PREAMBLE + """\
bounds <- ovb_bounds_by_setting(
  close_college,
  setting              = 'blacksouth',
  treatment            = 'educ',
  model                = 'feols(lwage ~ educ + smsa + married + exper, data = data)',
  benchmark_covariates = c('smsa','married','exper'),
  kd                   = 0.1
)
boundmat <- matrix(
  c(0, 2, 1.5, 0,
    0, 0, 0,   1.5,
    0, 0, 0,   2,
    0, 0, 0,   0),
  nrow = 4, byrow = TRUE
)
pi_bounds <- build_bounds(bounds, boundmat, settings_order = ORDER)
tbl <- univariate_bounds_table(pi_bounds,
         pin_values = list('Neither' = 'lower'))
tbl_ordered <- tbl[match(ORDER, tbl$setting), ]
print(tbl_ordered[, c('setting','estimate','lower_bound','upper_bound')])
""",

    PY_PREAMBLE + """\
import numpy as np

bounds = ovb_bounds_by_setting(
    data=df, setting='blacksouth', treatment='educ',
    model='lwage ~ educ + smsa + married + exper',
    benchmark_covariates=['smsa','married','exper'], kd=0.1,
)
boundmat = np.array([
    [0,   2,   1.5, 0  ],
    [0,   0,   0,   1.5],
    [0,   0,   0,   2  ],
    [0,   0,   0,   0  ],
])
pi_bounds = build_bounds(bounds, boundmat, settings_order=ORDER)
tbl = univariate_bounds_table(pi_bounds,
        pin_values={'Neither': 'lower'})
cols = ['setting','estimate','lower_bound','upper_bound']
out = tbl.set_index('setting').loc[ORDER, cols[1:]].reset_index()
print(out.to_string(index=False))
""",
))

# -- 9. build_bounds with scalar rho ------------------------------------------

EXAMPLES.append((
    "build_bounds with scalar rho_bounds",

    R_PREAMBLE + """\
bounds <- ovb_bounds_by_setting(
  close_college,
  setting              = 'blacksouth',
  treatment            = 'educ',
  model                = 'feols(lwage ~ educ + smsa + married + exper, data = data)',
  benchmark_covariates = c('smsa','married','exper'),
  kd                   = 0.1
)
pi_bounds <- build_bounds(bounds, rho_bounds = 2,
                          settings_order = ORDER)
tbl <- univariate_bounds_table(pi_bounds)
tbl_ordered <- tbl[match(ORDER, tbl$setting), ]
print(tbl_ordered[, c('setting','estimate','lower_bound','upper_bound')])
""",

    PY_PREAMBLE + """\
bounds = ovb_bounds_by_setting(
    data=df, setting='blacksouth', treatment='educ',
    model='lwage ~ educ + smsa + married + exper',
    benchmark_covariates=['smsa','married','exper'], kd=0.1,
)
pi_bounds = build_bounds(bounds, rho_bounds=2, settings_order=ORDER)
tbl = univariate_bounds_table(pi_bounds)
cols = ['setting','estimate','lower_bound','upper_bound']
out = tbl.set_index('setting').loc[ORDER, cols[1:]].reset_index()
print(out.to_string(index=False))
""",
))

# -- 10. identified_set_exists with check_only ---------------------------------

EXAMPLES.append((
    "identified_set_exists (check_only subset)",

    R_PREAMBLE + """\
bounds <- ovb_bounds_by_setting(
  close_college,
  setting              = 'blacksouth',
  treatment            = 'educ',
  model                = 'feols(lwage ~ educ + smsa + married + exper, data = data)',
  benchmark_covariates = c('smsa','married','exper'),
  kd                   = 0.1
)
boundmat <- matrix(
  c(0, 2, 1.5, 0,
    0, 0, 0,   1.5,
    0, 0, 0,   2,
    0, 0, 0,   0),
  nrow = 4, byrow = TRUE
)
pi_bounds <- build_bounds(bounds, boundmat, settings_order = ORDER)

cat("check_only = Neither + Black:\\n")
print(identified_set_exists(pi_bounds,
        check_only = c('Neither','Black')))

cat("check_only = Neither + Black, one solution:\\n")
print(round(identified_set_exists(pi_bounds,
        check_only = c('Neither','Black'),
        return_one_solution = TRUE), 6))
""",

    PY_PREAMBLE + """\
import numpy as np

bounds = ovb_bounds_by_setting(
    data=df, setting='blacksouth', treatment='educ',
    model='lwage ~ educ + smsa + married + exper',
    benchmark_covariates=['smsa','married','exper'], kd=0.1,
)
boundmat = np.array([
    [0,   2,   1.5, 0  ],
    [0,   0,   0,   1.5],
    [0,   0,   0,   2  ],
    [0,   0,   0,   0  ],
])
pi_bounds = build_bounds(bounds, boundmat, settings_order=ORDER)

print("check_only = Neither + Black:")
print(identified_set_exists(pi_bounds,
        check_only=['Neither','Black']))

print()
print("check_only = Neither + Black, one solution:")
sol = identified_set_exists(pi_bounds,
        check_only=['Neither','Black'],
        return_one_solution=True)
for k, v in sol.items():
    print(f"  {k}: {v:.6f}")
""",
))


# -----------------------------------------------------------------------------
# MAIN
# -----------------------------------------------------------------------------

if __name__ == '__main__':
    import io

    # Write to both stdout and a log file
    log_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            'compare_outputs.txt')
    log_lines = []

    def tee(text=''):
        print(text)
        log_lines.append(text)

    tee("hetset R vs Python - output comparison")
    tee(f"{'=' * (COL_WIDTH * 2 + len(SEP))}")
    tee(f"{'R':^{COL_WIDTH}}{SEP}{'Python':^{COL_WIDTH}}")

    for i, (title, r_code, py_code) in enumerate(EXAMPLES, 1):
        print(f"\nRunning example {i}/{len(EXAMPLES)}: {title} ...",
              end='', flush=True)
        r_out  = run_r(r_code)
        py_out = run_python(py_code)
        print(" done")

        # Capture print_comparison output
        buf = io.StringIO()
        orig_stdout = sys.stdout
        sys.stdout = buf
        print_comparison(title, r_out, py_out)
        sys.stdout = orig_stdout
        chunk = buf.getvalue()
        print(chunk, end='')
        log_lines.append(chunk)

    tee(f"\n{'=' * (COL_WIDTH * 2 + len(SEP))}")
    tee("All examples complete.")

    with open(log_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(log_lines))
    print(f"\nOutput also saved to: {log_path}")
