#' @import data.table
#' @importFrom stats as.formula coef model.matrix na.omit
NULL

# linear effect estimation
#' Estimate Effects by Setting
#'
#' Estimate the effects of a treatment variable on an outcome variable within different settings defined by a set of covariates.
#'
#' This function works with a wide range of estimation functions. By default it is set up to work with linear regression via \code{fixest::feols}, specifically via the wrapper \code{hetset_feols}.
#'
#' See the function \code{estimation_wrapper} to create custom estimation functions compatible with this function.
#'
#' @param data A data frame containing the data.
#' @param setting A string or string vector specifying the name of a variable or variables that define the different estimation settings.
#' @param treatment A string specifying the name of the treatment variable.
#' @param outcome A string specifying the name of the outcome variable.
#' @param covariates A string vector specifying the names of covariate variables to include in the estimation.
#' @param formula An optional formula object specifying the model to be estimated. Should follow whatever formula syntax is allowed by \code{estimation_function}. If provided, this overrides the \code{outcome} and \code{covariates} arguments. The treatment variable should still be specified via the \code{treatment} argument.
#' @param estimation_function A function that takes the above-mentioned arguments and returns a data frame of estimates by setting, in the format outlined in \code{estimation_wrapper}.
#' @param verbose Logical indicating whether to print progress messages. Default is \code{FALSE}.
#' @param ... Additional arguments to pass to \code{estimation_function}.
#' @return A data frame containing the estimated effects by setting, along with estimation statistics like sample size, standard errors, and model fit.
#'
#' @export

# estimate_het_effects = function(data,
#                                  setting,
#                                  treatment,
#                                  outcome = NULL,
#                                  covariates = NULL,
#                                  formula = NULL,
#                                  estimation_function = hetset_feols,
#                                  verbose = FALSE,
#                                  ...) {
#   if (is.null(formula) & is.null(outcome)) {
#     stop("Either 'formula' or 'outcome' must be provided.")
#   }
#
#   data.table::setDT(data)
#
#   results_list = list()
#   if (verbose) {
#     message("Estimating effects by setting...")
#   }
#   for (s in unique(data[[setting]])) {
#     if (verbose) {
#       message(paste0("  Running Setting: ", s, " at ", Sys.time()))
#     }
#     data_s = data[data[[setting]] == s]
#
#     if (!is.null(formula)) {
#       estimates_s = try(estimation_function(
#         data = data_s,
#         treatment = treatment,
#         formula = formula,
#         ...
#       ))
#     } else {
#       estimates_s = try(estimation_function(
#         data = data_s,
#         treatment = treatment,
#         outcome = outcome,
#         covariates = covariates,
#         ...
#       ))
#     }
#
#     if (inherits(estimates_s, "try-error")) {
#       warning(paste0("Estimation failed for setting: ", s, "."))
#       estimates_s = data.table::data.table(
#         failed = TRUE
#       )
#     }
#
#     estimates_s[, setting := s]
#
#     results_list[[as.character(s)]] = estimates_s
#   }
#
#   estimates = data.table::rbindlist(results_list)
#   if (!"failed" %in% colnames(estimates)) {
#     estimates[, failed := FALSE]
#   }
#   data.table::setcolorder(estimates,c('setting','failed'))
#
#   return(estimates)
# }


#' A hetset-compatible estimation wrapper for fixest::feols
#'
#' A ready-to-use wrapper function for \code{fixest::feols} to be used with \code{estimate_het_effects}. This is the default function used throughout the package.
#'
#' @param data A data frame containing the data.
#' @param treatment A string specifying the name of the treatment variable.
#' @param formula A formula object specifying the model to be estimated.
#' @param ... Additional arguments to pass to \code{fixest::feols}.
#' @return A data frame containing the estimated effects by setting, along with estimation statistics like sample size, standard errors, and model fit.
#'
#' @examples
#' # Regress wt on mpg, am, and vs, extracting the mpg "effect"
#' hetset_feols(mtcars, 'mpg', 'wt~mpg+am+vs')[]
#'
# hetset_feols = estimation_wrapper_formula(
#   formula_string = 'fixest::feols(fml = formula, data = data, ...)',
#   estimate_extract_string = 'coef(m)[treatment]',
#   other_extract_strings = list(
#     std_error = 'm$se[treatment]',
#     n_obs = 'm$nobs',
#     t_stat = 'm$coeftable[treatment, "t value"]',
#     p_value = "m$coeftable[treatment,'Pr(>|t|)']",
#     rmse = 'as.numeric(fixest::fitstat(m, type = "rmse"))',
#     r_squared = 'as.numeric(fixest::fitstat(m, type = "r2"))'
#   )
# )
