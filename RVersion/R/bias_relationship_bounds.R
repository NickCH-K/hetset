#' Propose a set of rho bounds
#'
#' This function suggests a plausible bound for rho, the proportional parameter relating the omitted variable bias in setting A with the omitted variable bias in setting B.
#'
#' This bound is based on taking the estimation model (which is already missing some predictors, since we have omitted variable bias) and omitting more variables. The change in the estimated coefficient is the omitted variable bias added by the further removal of predictors. The ratio of the change in biases in the two settings is given as their proportional relationship.
#'
#' @param data A data frame containing the data.
#' @param setting A string or string vector specifying the name of a variable or variables that define the different estimation settings.
#' @param treatment A string specifying the name of the treatment variable.
#' @param model A string specifying the model to be estimated including the estimation function. Should refer to the name of the data set as \code{data}. For example, \code{'fixest::feols(formula = y ~ x + a + b, data = data)'}. This model should include all covariates, including those that are to be dropped.
#' @param model_shorter A string specifying the model to be estimated including the estimation function. Should refer to the name of the data set as \code{data}. For example, \code{'fixest::feols(formula = y ~ x + a, data = data)'}. This model should not include the predictors further removed to create a super-short model.
#' @param treatment_code A string specifying how to extract the treatment effect from a model named \code{m}.
#' @param negative_is_uninformative If the change in bias in setting A and setting B are of opposite signs, consider this analysis to be uninformative.
#' @param minimum_bound A number greater than 1. All rho bounds between 1 and \code{minimum_bound} will be set to \code{minimum_bound}, and all rho bounds between 1 and \code{1/minimum_bound} will be set to \code{1/minimum_bound}.
#' @param maximum_bound A number greater than 1. All rho bounds will be constrained to \code{[1/maximum_bound,maximum_bound]}. Uninformative bounds given by \code{negative_is_uninformative = TRUE} will not be adjusted.
#' @param settings_order A vector with the values of the settings in the order they are used in \code{rho_bounds}. Defaults to \code{sort()} order.
#' @param return Set to \code{'table'} to return a table of rho bounds, \code{'matrix'} to return a bounds matrix suitable for use with \code{build_bounds}, or \code{'both'} to get a list with both.
#'
#' @examples
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
#' boundmat = supershort_rho_bounds_proposal(
#'   data = close_college,
#'   setting = 'blacksouth',
#'   treatment = 'educ',
#'   model = 'fixest::feols(lwage ~ educ + smsa + married + exper, data = data)',
#'   model_shorter = 'fixest::feols(lwage ~ educ, data = data)',
#'   settings_order = c('Neither','Black','South','Black and South'))
#'
#' # Get the partial identification bounds
#' pi_bounds = build_bounds(bounds, boundmat,
#'                             settings_order = c('Neither','Black','South','Black and South'))
#'
#' # Get the univariate bounds table
#' univariate_bounds_table(pi_bounds)
#'
#' @export
supershort_rho_bounds_proposal = function(data, setting,
                                          treatment, model, model_shorter,
                                          treatment_code = 'coef(m)[treatment]',
                                          negative_is_uninformative = TRUE,
                                          minimum_bound = NULL,
                                          maximum_bound = NULL,
                                          settings_order = NULL,
                                          return = 'matrix') {

  if (!is.null(minimum_bound)) {
    if (minimum_bound <= 1) {
      stop('minimum_bound must be above 1.')
    }
  }
  if (!is.null(maximum_bound)) {
    if (maximum_bound <= 1) {
      stop('maximum_bound must be above 1.')
    }
  }
  if (!is.null(settings_order)) {
    settings_in_data = unique(data[[setting]])
    if (!(all(settings_in_data %in% settings_order) & all(settings_order %in% settings_in_data))) {
      stop('settings_order must contain all of the values in settings and no more.')
    }
  } else {
    settings_order = sort(unique(data[[setting]]))
  }
  if (!(return %in% c('table','matrix','both'))) {
    stop('return must be one of "table", "matrix", or "both".')
  }

  data_full = data.table::data.table(data)
  coefs_by_setting = lapply(unique(data_full[[setting]]), function(x) {
    data = data_full[data_full[[setting]] == x]
    m = eval(parse(text = model))
    eff_s = eval(parse(text = treatment_code))
    m = eval(parse(text = model_shorter))
    eff_ss = eval(parse(text = treatment_code))

    data.table(setting = x, eff_s = eff_s, eff_ss = eff_ss)
  })
  coefs_by_setting = data.table::rbindlist(coefs_by_setting)
  coefs_by_setting[, diff := eff_s - eff_ss]

  rhotab = data.table::CJ(setting_a = settings_order,
                          setting_b = settings_order)
  rhotab = rhotab[sapply(setting_a, function(x) which(settings_order == x)) < sapply(setting_b, function(x) which(settings_order == x))]

  for (sa in settings_order[1:(length(settings_order) - 1)]) {
    diff_a = coefs_by_setting[setting == sa, diff]
    remaining_settings = settings_order[(which(settings_order == sa)+1):length(settings_order)]
    for (sb in remaining_settings) {
      if (sa != sb) {
        diff_b = coefs_by_setting[setting == sb, diff]
        if (negative_is_uninformative & sign(diff_a) != sign(diff_b)) {
          rhotab[setting_a == sa & setting_b == sb, rho_low := -Inf]
          rhotab[setting_a == sa & setting_b == sb, rho_high := Inf]
        } else {
          rhotab[setting_a == sa & setting_b == sb, rho_low := min(diff_a/diff_b, diff_b/diff_a)]
          rhotab[setting_a == sa & setting_b == sb, rho_high := max(diff_a/diff_b, diff_b/diff_a)]
        }
      }
    }
  }

  if (!is.null(minimum_bound)) {
    rhotab[!is.infinite(rho_low) & rho_low < minimum_bound, rho_low := minimum_bound]
  }
  if (!is.null(maximum_bound)) {
    rhotab[!is.infinite(rho_high) & rho_high > maximum_bound, rho_high := maximum_bound]
  }

  if (return %in% c('matrix','both')) {
    rhomat = matrix(nrow = length(settings_order),
                    ncol = length(settings_order))
    for (i in 1:(length(settings_order)-1)) {
      for (j in (i+1):length(settings_order)) {
        rhomat[i, j] = rhotab[setting_a == settings_order[i] &
                                setting_b == settings_order[j],
                              rho_high]
        rhomat[j,i] = rhotab[setting_a == settings_order[i] &
                                setting_b == settings_order[j],
                              rho_low]
      }
    }
    colnames(rhomat) = settings_order
    rownames(rhomat) = settings_order
  } else {
    return(rhotab)
  }

  if (return == 'matrix') {
    return(rhomat)
  } else {
    return(list('Table' = rhotab, 'Matrix' = rhomat))
  }
}
