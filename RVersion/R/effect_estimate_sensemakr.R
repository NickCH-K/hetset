#' @import data.table
#' @importFrom stats as.formula coef model.matrix na.omit
NULL

# linear effect estimation

#' Estimate Partial Identification Effects by Setting with sensemakr
#'
#' Estimate the effects of a treatment variable on an outcome variable within different settings defined by a set of covariates, with partial identification bounds based on a set of baseline covariates with \code{sensemakr::ovb_bounds}.
#'
#' @param data A data frame containing the data.
#' @param setting A string or string vector specifying the name of a variable or variables that define the different estimation settings.
#' @param treatment A string specifying the name of the treatment variable.
#' @param model A string specifying the model to be estimated including the estimation function. Should refer to the name of the data set as \code{data}. For example, \code{'fixest::feols(formula = y ~ x + a + b, data = data)'}.
#' @param benchmark_covariates A string vector specifying the names of baseline covariates to be used for partial identification with \code{sensemakr::ovb_bounds}.
#' @param kd A numeric vector. Parameterizes how many times stronger the confounder is related to the treatment in comparison to the observed benchmark covariate. Default value is 1 (confounder is as strong as benchmark covariate).
#' @param ky A numeric vector. Parameterizes how many times stronger the confounder is related to the outcome in comparison to the observed benchmark covariate. Default value is the same as \code{kd}.
#' @param estimation_function The function that will be used to estimate the effect.
#' @param verbose Logical indicating whether to print progress messages. Default is \code{FALSE}.
#' @param ... Additional arguments to pass to \code{sensemakr::ovb_bounds}.
#' @return A data frame containing the estimated effects by setting, along with estimation statistics like sample size, standard errors, and model fit.
#'
#' @examples
#'
#' library(fixest)
#' library(hetset)
#' data("close_college")
#'
#' bounds = ovb_bounds_by_setting(close_college,
#'                                setting = 'blacksouth',
#'                                treatment = 'educ',
#'                                model = 'feols(lwage ~ educ + smsa + married + exper, data = data)',
#'                                benchmark_covariates = c('smsa','married','exper'),
#'                                kd = .1)
#'
#' @export

ovb_bounds_by_setting = function(data,
                                 setting,
                                 treatment,
                                 model,
                                 benchmark_covariates,
                                 kd = 1,
                                 ky = kd,
                                 estimation_function = fixest::feols,
                                 verbose = FALSE,
                                 ...) {
  data.table::setDT(data)
  data_full = data.table::copy(data)

  results_list = list()
  if (verbose) {
    message("Estimating effects by setting...")
  }
  for (s in unique(data[[setting]])) {
    if (verbose) {
      message(paste0("  Running Setting: ", s, " at ", Sys.time()))
    }
    data = data_full[data_full[[setting]] == s]

    m = eval(parse(text = model))
    bounds_s = try({
      b = data.table::as.data.table(sensemakr::ovb_bounds(model = m,
                                     treatment = treatment,
                                     benchmark_covariates = list('Total'=benchmark_covariates),
                                     kd = kd,
                                     ky = ky,
                                     ...))
      original_estimate = NULL
      b[, original_estimate := coef(m)[treatment]]
      b
    })

    if (inherits(bounds_s, "try-error")) {
      warning(paste0("Bounds estimation failed for setting: ", s, "."))
      bounds_s = data.table::data.table(
        failed = TRUE
      )
    }

    bounds_s[, setting := s]

    results_list[[as.character(s)]] = bounds_s
  }

  bounds = data.table::rbindlist(results_list, fill = TRUE)
  failed = NULL
  if (!"failed" %in% colnames(bounds)) {
    bounds[, failed := FALSE]
  }
  bounds[is.na(failed), failed := FALSE]
  data.table::setcolorder(bounds,c('setting','failed'))

  original_estimate = NULL
  lower_plausible_bound = NULL
  upper_plausible_bound = NULL
  adjusted_estimate = NULL
  lower_nu = NULL
  upper_nu = NULL
  bounds[, lower_plausible_bound := original_estimate-abs(original_estimate - adjusted_estimate)]
  bounds[, upper_plausible_bound := original_estimate+abs(original_estimate - adjusted_estimate)]
  bounds[, lower_nu := original_estimate - lower_plausible_bound]
  bounds[, upper_nu := original_estimate - upper_plausible_bound]

  return(bounds)
}


#' Create a Custom Bounds Table
#'
#' A convenience function for constructing a bounds table with the correct
#' column names and structure to use as input to \code{build_bounds}, when
#' partial identification bounds come from a source other than
#' \code{sensemakr::ovb_bounds} (e.g. manual calibration, a different
#' sensitivity framework, or a bootstrapped interval).
#'
#' The returned table has the same format as the output of
#' \code{ovb_bounds_by_setting} and can be passed directly to
#' \code{build_bounds}.
#'
#' @param setting A vector of setting values, one per row.  Each value must be
#'   unique.
#' @param original_estimate A numeric vector of point estimates for the
#'   treatment effect in each setting.
#' @param lower_plausible_bound A numeric vector of lower plausible bounds for
#'   the treatment effect in each setting.
#' @param upper_plausible_bound A numeric vector of upper plausible bounds for
#'   the treatment effect in each setting.
#' @param ... Additional named atomic vectors of length
#'   \code{length(setting)} to include as extra columns in the returned
#'   table.
#' @return A \code{data.table} with one row per setting and columns
#'   \code{setting}, \code{failed}, \code{original_estimate},
#'   \code{lower_plausible_bound}, \code{upper_plausible_bound},
#'   \code{lower_nu}, \code{upper_nu}, plus any extra columns supplied
#'   via \code{...}.
#'
#' @examples
#' library(hetset)
#'
#' # Manually specified bounds
#' bounds = custom_ovb_bounds_by_setting(
#'   setting               = c('Control', 'Treated'),
#'   original_estimate     = c(0.4, 0.6),
#'   lower_plausible_bound = c(0.2, 0.4),
#'   upper_plausible_bound = c(0.6, 0.8)
#' )
#'
#' # With extra informational columns
#' bounds = custom_ovb_bounds_by_setting(
#'   setting               = c('Control', 'Treated'),
#'   original_estimate     = c(0.4, 0.6),
#'   lower_plausible_bound = c(0.2, 0.4),
#'   upper_plausible_bound = c(0.6, 0.8),
#'   n_obs                 = c(500L, 450L),
#'   method                = c('bootstrap', 'bootstrap')
#' )
#'
#' @export
custom_ovb_bounds_by_setting = function(setting,
                                        original_estimate,
                                        lower_plausible_bound,
                                        upper_plausible_bound,
                                        ...) {
  n = length(setting)
  if (length(original_estimate)     != n ||
      length(lower_plausible_bound) != n ||
      length(upper_plausible_bound) != n) {
    stop("setting, original_estimate, lower_plausible_bound, and ",
         "upper_plausible_bound must all be the same length.")
  }
  if (anyDuplicated(setting)) {
    stop("Duplicate values in setting. Each setting must appear exactly once.")
  }

  result = data.table::data.table(
    setting               = setting,
    failed                = FALSE,
    original_estimate     = original_estimate,
    lower_plausible_bound = lower_plausible_bound,
    upper_plausible_bound = upper_plausible_bound,
    lower_nu              = original_estimate - lower_plausible_bound,
    upper_nu              = original_estimate - upper_plausible_bound
  )

  extra = list(...)
  for (nm in names(extra)) {
    col = extra[[nm]]
    if (!is.atomic(col)) {
      stop("Extra column '", nm, "' must be an atomic vector (not a list or other object).")
    }
    if (length(col) != n) {
      stop("Extra column '", nm, "' must have the same length as setting (", n, ").")
    }
    result[, (nm) := col]
  }

  return(result)
}


#' Estimate Partial Identification Effects by Setting with dml.sensemakr
#'
#' Estimates a separate DML model for each level of \code{setting}, then
#' calibrates a per-setting plausibility interval for the bias using either
#' \code{dml.sensemakr}'s built-in benchmarking (one benchmark covariate,
#' evaluated separately within each setting) or direct confounding-strength
#' parameters (\code{cf.y} / \code{cf.d}).
#'
#' Because DML is fit independently within each setting, both the point
#' estimates and the bias bounds can vary across settings which is the
#' purpose of this function.
#'
#' \strong{Benchmark mode} (\code{benchmark_covariates} supplied): calls
#' \code{dml.sensemakr::sensemakr()} on each setting's DML fit to obtain
#' \code{$bench.bounds}, extracting \code{gain.Y} (\code{cf.y}) and
#' \code{gain.D} (\code{cf.d}) for that setting.  These are passed to
#' \code{dml.sensemakr::dml_bounds()} to derive setting-specific
#' \code{theta.m} and \code{bias.bound}.
#'
#' \strong{Current limitation:} \code{dml.sensemakr} benchmarks one covariate
#' at a time.  When multiple \code{benchmark_covariates} are supplied only the
#' first is used and a warning is issued.
#'
#' \strong{Direct mode} (\code{benchmark_covariates = NULL}): \code{cf.y} and
#' \code{cf.d} can be either a single value (recycled to all settings) or a
#' vector with one value per setting in the order returned by
#' \code{unique(data[[setting]])}.
#'
#' Listwise deletion is applied within each setting.
#'
#' @param data A data frame containing the data.
#' @param setting A string name of the variable defining estimation settings.
#' @param y A string name of the outcome variable.
#' @param d A string name of the treatment variable.
#' @param x A character vector names of covariates (conditioning set).
#'   No intercept column should be included; one is excluded via \code{-1} in
#'   the \code{model.matrix} call.
#' @param benchmark_covariates A character vector of covariate names drawn from
#'   \code{x}.  Only the first element is used (see limitation above).  Set to
#'   \code{NULL} to supply \code{cf.y} / \code{cf.d} directly instead.
#' @param cf.y Numeric scalar or vector.  R2-type confounding strength in the
#'   outcome residual.  A scalar is recycled to all settings; a vector must
#'   have one entry per setting (in the order of
#'   \code{unique(data[[setting]])}).  Only used when
#'   \code{benchmark_covariates} is \code{NULL}.
#' @param cf.d Numeric scalar or vector.  R2-type confounding strength for the
#'   Riesz representer.  Same recycling rules as \code{cf.y}.  Defaults to
#'   \code{cf.y}.  Only used when \code{benchmark_covariates} is \code{NULL}.
#' @param rho2 Numeric in [0, 1].  Degree of adversity.  In benchmark mode,
#'   defaults to the squared \code{rho} from \code{$bench.bounds} per setting.
#'   In direct mode, defaults to \code{1}.  Can be overridden in either mode.
#' @param model_type Either \code{'plm'} or \code{'npm'}.  Passed to
#'   \code{dml.sensemakr::dml()}.  Defaults to \code{'plm'}.
#' @param verbose Logical.  Print per-setting progress and forward to
#'   \code{dml.sensemakr::dml()}.  Default \code{FALSE}.
#' @param ... Additional arguments forwarded to \code{dml.sensemakr::dml()}
#'   (e.g. \code{cf.folds}, \code{reg}).
#' @return A \code{data.table} with one row per setting containing:
#'   \describe{
#'     \item{setting}{Setting value.}
#'     \item{failed}{Logical whether estimation failed for this setting.}
#'     \item{bound_label}{Benchmark covariate name, or \code{cf.y}/\code{cf.d}
#'       values in direct mode.}
#'     \item{treatment}{Name of the treatment variable.}
#'     \item{original_estimate}{DML point estimate (\code{theta.s}).}
#'     \item{adjusted_estimate}{\code{theta.m = theta.s - bias_bound}.}
#'     \item{bias_bound}{Setting-specific plausible bias magnitude.}
#'     \item{bench_cf_y}{\code{gain.Y} from benchmark (benchmark mode only).}
#'     \item{bench_cf_d}{\code{gain.D} from benchmark (benchmark mode only).}
#'     \item{bench_rho2}{Squared benchmark \code{rho} (benchmark mode only).}
#'     \item{lower_plausible_bound}{\code{original_estimate - bias_bound}.}
#'     \item{upper_plausible_bound}{\code{original_estimate + bias_bound}.}
#'     \item{lower_nu}{Signed bias to the lower bound (positive).}
#'     \item{upper_nu}{Signed bias to the upper bound (negative).}
#'   }
#'
#' @examples
#' \dontrun{
#' library(hetset)
#' data("close_college")
#'
#' # Benchmark-based (setting-specific bias bounds)
#' bounds <- ovb_bounds_by_setting_dml_proposed(
#'   close_college,
#'   setting              = "blacksouth",
#'   y                    = "lwage",
#'   d                    = "educ",
#'   x                    = c("smsa", "married", "exper"),
#'   benchmark_covariates = "exper",
#'   model_type           = "plm"
#' )
#'
#' # Direct mode same cf.y/cf.d for all settings
#' bounds_direct <- ovb_bounds_by_setting_dml_proposed(
#'   close_college,
#'   setting              = "blacksouth",
#'   y                    = "lwage",
#'   d                    = "educ",
#'   x                    = c("smsa", "married", "exper"),
#'   benchmark_covariates = NULL,
#'   cf.y                 = 0.02,
#'   cf.d                 = 0.02,
#'   model_type           = "plm"
#' )
#'
#' # Direct mode different cf.y per setting (order matches unique(data$blacksouth))
#' bounds_varying <- ovb_bounds_by_setting_dml_proposed(
#'   close_college,
#'   setting              = "blacksouth",
#'   y                    = "lwage",
#'   d                    = "educ",
#'   x                    = c("smsa", "married", "exper"),
#'   benchmark_covariates = NULL,
#'   cf.y                 = c(0.01, 0.02, 0.03, 0.04),
#'   model_type           = "plm"
#' )
#' }
#'
#' @export
ovb_bounds_by_setting_dml <- function(
    data,
    setting,
    y,
    d,
    x,
    benchmark_covariates = NULL,
    cf.y                 = NULL,
    cf.d                 = cf.y,
    rho2                 = NULL,
    model_type           = c("plm", "npm"),
    verbose              = FALSE,
    ...
) {
  # ---- guards ----------------------------------------------------------
  if (!requireNamespace("dml.sensemakr", quietly = TRUE)) {
    stop(paste0(
      "The 'dml.sensemakr' package is required. ",
      "Install it from GitHub: devtools::install_github('carloscinelli/dml.sensemakr')"
    ))
  }

  # Do not allow the groups variable to be set
  if ("groups" %in% names(list(...))) {
    stop("The 'groups' argument is not allowed in this function. ",
         "DML is fit separately within each setting, so no additional grouping is needed.")
  }

  model_type <- match.arg(model_type)

  use_benchmarks <- !is.null(benchmark_covariates)
  use_direct     <- !is.null(cf.y)

  if (!use_benchmarks && !use_direct) {
    stop("Provide either benchmark_covariates or cf.y (and optionally cf.d).")
  }
  if (use_benchmarks && !all(benchmark_covariates %in% x)) {
    bad <- benchmark_covariates[!benchmark_covariates %in% x]
    stop("benchmark_covariates not found in x: ", paste(bad, collapse = ", "))
  }
  if (use_benchmarks && length(benchmark_covariates) > 1) {
    warning(
      "dml.sensemakr currently benchmarks one covariate at a time and does not ",
      "support joint group benchmarks. Only the first benchmark covariate ('",
      benchmark_covariates[1], "') will be used. This will be updated when ",
      "dml.sensemakr adds group-benchmark support."
    )
    benchmark_covariates <- benchmark_covariates[1]
  }

  # ---- data prep -------------------------------------------------------
  data.table::setDT(data)
  data_full  <- data.table::copy(data)
  settings   <- unique(data_full[[setting]])
  n_settings <- length(settings)

  # ---- validate / recycle cf.y and cf.d (direct mode only) -------------
  if (use_direct) {
    if (length(cf.y) == 1L) cf.y <- rep(cf.y, n_settings)
    if (length(cf.d) == 1L) cf.d <- rep(cf.d, n_settings)
    if (length(cf.y) != n_settings)
      stop("cf.y must be length 1 or length equal to the number of settings (",
           n_settings, "); got length ", length(cf.y), ".")
    if (length(cf.d) != n_settings)
      stop("cf.d must be length 1 or length equal to the number of settings (",
           n_settings, "); got length ", length(cf.d), ".")
  }

  # ---- main loop -------------------------------------------------------
  if (verbose) message("Estimating DML effects by setting...")

  results_list <- list()

  for (i in seq_along(settings)) {
    s <- settings[i]
    if (verbose) message("  Setting: ", s, " ", Sys.time())

    data_s <- data_full[data_full[[setting]] == s, .SD, .SDcols = c(y, d, x)]
    data_s <- na.omit(data_s)

    bounds_s <- try({
      ydat     <- as.numeric(data_s[[y]])
      ddat     <- as.numeric(data_s[[d]])
      xdat     <- model.matrix(
        as.formula(paste("~ -1 +", paste(x, collapse = "+"))),
        data = data_s
      )

      # ---- fit DML for this setting ----------------------------------
      dml_fit <- dml.sensemakr::dml(
        ydat, ddat, xdat,
        model   = model_type,
        verbose = verbose,
        ...
      )

      # ---- patch model$call for bench_fun compatibility --------------
      # bench_fun() replays model$call via eval(model.call) in its own
      # scope.  match.call() inside dml() captured our local variable
      # *names* (ydat, ddat, xdat, model_type, verbose) as unevaluated
      # symbols, which don't exist in bench_fun's frame.
      #
      # Fix: replace data-vector slots with quoted references into
      # model$data (bench_fun has `model` in scope so model$data$y etc.
      # resolve correctly), and inline scalar values directly.
      dml_fit$call[["y"]]       <- quote(model$data$y)
      dml_fit$call[["d"]]       <- quote(model$data$d)
      dml_fit$call[["x"]]       <- quote(model$data$x)
      dml_fit$call[["model"]]   <- model_type   # stores "plm"/"npm" by value
      dml_fit$call[["verbose"]] <- FALSE

      # ---- derive setting-specific cf.y, cf.d, rho2 ------------------
      if (use_benchmarks) {
        smk_result <- dml.sensemakr::sensemakr(
          dml_fit,
          benchmark_covariates = benchmark_covariates
        )

        bench     <- smk_result$bench.bounds
        bench_row <- bench$benchmarks[[benchmark_covariates]]

        cf_y_used  <- bench_row[["gain.Y"]]
        cf_d_used  <- bench_row[["gain.D"]]
        rho2_used  <- if (!is.null(rho2)) rho2 else bench_row[["rho"]]^2
        bound_label_used <- benchmark_covariates
        bench_cf_y <- cf_y_used
        bench_cf_d <- cf_d_used
        bench_rho2 <- rho2_used

      } else {
        cf_y_used        <- cf.y[i]
        cf_d_used        <- cf.d[i]
        rho2_used        <- if (!is.null(rho2)) rho2 else 1
        bound_label_used <- paste0("cf.y=", cf_y_used, ", cf.d=", cf_d_used)
        bench_cf_y       <- NA_real_
        bench_cf_d       <- NA_real_
        bench_rho2       <- NA_real_
      }

      # ---- compute bounds and extract estimates ----------------------
      bounds_obj <- dml.sensemakr::dml_bounds(
        dml_fit,
        cf.y = cf_y_used,
        cf.d = cf_d_used,
        rho2 = rho2_used
      )

      # Extract from $results$main (pooled within this setting).
      # [[1]] indexes the first cross-fitting result for the "all" target.
      ests <- bounds_obj$results$main$all[[1]]$estimates

      data.table::data.table(
        bound_label       = bound_label_used,
        treatment         = d,
        original_estimate = ests$theta.s,
        adjusted_estimate = ests$theta.m,
        bias_bound        = ests$bias.bound,
        bench_cf_y        = bench_cf_y,
        bench_cf_d        = bench_cf_d,
        bench_rho2        = bench_rho2,
        failed            = FALSE
      )
    })

    if (inherits(bounds_s, "try-error")) {
      warning("Bounds estimation failed for setting: ", s)
      bounds_s <- data.table::data.table(failed = TRUE)
    }

    bounds_s[, setting := s]
    results_list[[as.character(s)]] <- bounds_s
  }

  # ---- assemble and compute plausibility intervals ---------------------
  bounds <- data.table::rbindlist(results_list, fill = TRUE)

  failed = NULL
  if (!"failed" %in% colnames(bounds)) bounds[, failed := FALSE]
  bounds[is.na(failed), failed := FALSE]

  data.table::setcolorder(bounds, c("setting", "failed"))

  # Symmetric interval around original_estimate with half-width = bias_bound.
  # Formula mirrors ovb_bounds_by_setting exactly.
  original_estimate = NULL
  lower_plausible_bound = NULL
  upper_plausible_bound = NULL
  adjusted_estimate = NULL
  lower_nu = NULL
  upper_nu = NULL
  bounds[, lower_plausible_bound := original_estimate - abs(original_estimate - adjusted_estimate)]
  bounds[, upper_plausible_bound := original_estimate + abs(original_estimate - adjusted_estimate)]
  bounds[, lower_nu              := original_estimate - lower_plausible_bound]
  bounds[, upper_nu              := original_estimate - upper_plausible_bound]

  return(bounds)
}
