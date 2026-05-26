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

estimate_het_effects = function(data,
                                 setting,
                                 treatment,
                                 outcome = NULL,
                                 covariates = NULL,
                                 formula = NULL,
                                 estimation_function = hetset_feols,
                                 verbose = FALSE,
                                 ...) {
  if (is.null(formula) & is.null(outcome)) {
    stop("Either 'formula' or 'outcome' must be provided.")
  }

  data.table::setDT(data)

  results_list = list()
  if (verbose) {
    message("Estimating effects by setting...")
  }
  for (s in unique(data[[setting]])) {
    if (verbose) {
      message(paste0("  Running Setting: ", s, " at ", Sys.time()))
    }
    data_s = data[data[[setting]] == s]

    if (!is.null(formula)) {
      estimates_s = try(estimation_function(
        data = data_s,
        treatment = treatment,
        formula = formula,
        ...
      ))
    } else {
      estimates_s = try(estimation_function(
        data = data_s,
        treatment = treatment,
        outcome = outcome,
        covariates = covariates,
        ...
      ))
    }

    if (inherits(estimates_s, "try-error")) {
      warning(paste0("Estimation failed for setting: ", s, "."))
      estimates_s = data.table::data.table(
        failed = TRUE
      )
    }

    estimates_s[, setting := s]

    results_list[[as.character(s)]] = estimates_s
  }

  estimates = data.table::rbindlist(results_list)
  if (!"failed" %in% colnames(estimates)) {
    estimates[, failed := FALSE]
  }
  data.table::setcolorder(estimates,c('setting','failed'))

  return(estimates)
}

#' Build a hetset-compatible estimation wrapper for formula-using estimation functions
#'
#' Build a wrapper function around an estimation function to make it compatible with \code{estimate_het_effects}.
#'
#' This function takes an estimation function and returns a new function that conforms to the expected input and output.
#'
#' @param formula_string An string describing the command to run. All double quotes (\code{"}) will be changed to single quotes (\code{'}). Should accept a data set named \code{data} and a formula named \code{formula}. Can accept other arguments, and should probably include \code{...}. If this calls an external function it is recommended that you include the package, i.e. \code{fixest::feols} instead of just \code{feols}.
#' @param estimate_extract_string An optional string describing how to extract the causal effect estimate from the output of the estimation function, given an estimated model \code{m} and a treatment variable name string \code{treatment}. For example, for \code{estimation_function = lm}, this could be \code{coef(m)[treatment]}.
#' @param other_extract_strings A named list of additional strings describing how to extract other statistics from the output of the estimation function. All double quotes (\code{"}) will be changed to single quotes (\code{'}). Each string should be a function of the estimated model \code{m} and should assume arguments \code{treatment}, \code{formula}, \code{outcome}, and \code{covariates} are available if needed, as specified otherwise.
#'
#' @examples
#'
#' # This is the code used to create the fixest::feols estimation wrapper
#' hetset_feols = estimation_wrapper_formula(
#' formula_string = 'fixest::feols(fml = formula, data = data, ...)',
#' estimate_extract_string = 'coef(m)[treatment]',
#' other_extract_strings = list(
#'   std_error = 'm$se[treatment]',
#'   n_obs = 'm$nobs',
#'   t_stat = 'm$coeftable[treatment, "t value"]',
#'   p_value = "m$coeftable[treatment,'Pr(>|t|)']",
#'   rmse = 'as.numeric(fixest::fitstat(m, type = "rmse"))',
#'   r_squared = 'as.numeric(fixest::fitstat(m, type = "r2"))'
#' )
#' )
#'
# estimation_wrapper_formula = function(formula_string,
#                                       estimate_extract_string = 'coef(m)[treatment]',
#                                       other_extract_strings = list()
# ) {
#
#   # Change double quotes to singles
#   formula_string = gsub('"', "'", formula_string)
#   for (name in names(other_extract_strings)) {
#     other_extract_strings[[name]] = gsub('"', "'", other_extract_strings[[name]])
#   }
#
#   wrapper_code = 'function(data, treatment, formula = NULL, ...) {\n'
#
#   wrapper_code = paste0(wrapper_code,
#                         'if (is.null(formula)) { stop("The provided estimation function requires formula input.")}\n')
#
#   # Convert formula string to a formula in case it isn't already
#   wrapper_code = paste0(wrapper_code,
#                         'formula = as.formula(formula)\n')
#
#   wrapper_code = paste0(wrapper_code,
#                         'm = eval(parse(text = "',formula_string,'"))\n',
#                         'estimate = eval(parse(text = "', estimate_extract_string, '"))\n')
#
#   # Start the one-row data.table of output
#   wrapper_code = paste0(wrapper_code,
#                         'output = data.table::data.table(\n',
#                         '  estimate = estimate)\n')
#   # Add other extracts
#   if (length(other_extract_strings) > 0) {
#     for (name in names(other_extract_strings)) {
#       wrapper_code = paste0(wrapper_code,
#                             'est = eval(parse(text = "', other_extract_strings[[name]], '"))\n',
#                             'if (!is.null(unlist(est))) { output[, ', name, ' := est] } else { warning("NULL result produced for other_extract_string ',name,'")} \n')
#     }
#   }
#   wrapper_code = paste0(wrapper_code,
#                         'return(output)\n',
#                         '}')
#   #return(wrapper_code)
#   return(eval(parse(text = wrapper_code)))
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


#
# estimation_wrapper = function(estimation_function,
#                               estimate_extract_string = 'coef(m)[treatment]',
#                               allow_formula = TRUE,
#                               allow_vector = TRUE,
#                               convert_to_formula = FALSE,
#                               formula_string = NULL,
#                               vector_string = NULL,
#                               other_extract_strings = list()
#                               ) {
#
#   if (!allow_formula & !is.null(formula_string)) {
#     warning("formula_string is provided but allow_formula is FALSE. The string will be ignored.")
#   }
#   if (!allow_vector & !is.null(vector_string)) {
#     warning("vector_string is provided but allow_vector is FALSE. The string will be ignored.")
#   }
#   if (!allow_vector & !allow_formula) {
#     stop("At least one of allow_formula or allow_vector must be TRUE.")
#   }
#   if (is.null(formula_string) & is.null(vector_string)) {
#     warning("No version strings provided. Make sure the estimation_function is compatible with hetset.")
#   }
#   if (is.null(formula_string) & convert_to_formula) {
#     stop("convert_to_formula is TRUE but no formula_string is provided.")
#   }
#
#   wrapper_code = 'function(data, treatment, outcome = NULL, covariates = NULL, formula = NULL, ...) {\n'
#
#   if (!allow_vector) {
#     wrapper_code = paste0(wrapper_code,
#                           'if (!is.null(outcome) | !is.null(covariates)) { stop("The provided estimation function does not support vector input for outcome and covariates.")}\n')
#   }
#   if (!allow_formula) {
#     wrapper_code = paste0(wrapper_code,
#                           'if (!is.null(formula)) { stop("The provided estimation function does not support formula input.")}\n')
#   }
#
#   if (allow_vector) {
#     wrapper_code = paste0(wrapper_code,
#                           'if (is.null(formula)) {\n')
#     if (convert_to_formula) {
#       wrapper_code = paste0(wrapper_code,
#                             '  if (is.null(covariates)) {\n',
#                             '    formula = paste0("`",outcome, "`` ~ `", treatment,"`")\n',
#                             '  } else {\n',
#                             '    formula = paste0("`",outcome, "`` ~ `", treatment, "` + ", paste(paste0("`",covariates,"`"), collapse = " + "))\n',
#                             '  }\n
#                             estimation_code = "', formula_string, '"\n}\n')
#     } else {
#       wrapper_code = paste0(wrapper_code,'    estimation_code = "', vector_string,'"\n')
#     }
#   }
#   if (allow_formula) {
#     wrapper_code = paste0(wrapper_code,
#                           'if (!is.null(formula)) {\n',
#                           '  estimation_code = "', formula_string, '"\n}\n')
#   }
#   wrapper_code = paste0(wrapper_code,
#                         'cat(estimation_code)\n',
#                         'm = eval(parse(text = estimation_code))\n',
#                         'estimate = eval(parse(text = "', estimate_extract_string, '"))\n')
#
#   # Start the one-row data.table of output
#   wrapper_code = paste0(wrapper_code,
#                         'output = data.table::data.table(\n',
#                         '  estimate = estimate)\n')
#   # Add other extracts
#   if (length(other_extract_strings) > 0) {
#     for (name in names(other_extract_strings)) {
#       wrapper_code = paste0(wrapper_code,
#                             'output[, ', name, ' := eval(parse(text = "', other_extract_strings[[name]], '"))]\n')
#     }
#   }
#   wrapper_code = paste0(wrapper_code,
#                         'return(output)\n',
#                         '}')
#
#   return(eval(parse(text = wrapper_code)))
# }
