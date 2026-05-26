#' @import data.table
#' @importFrom stats as.formula coef model.matrix na.omit
NULL

#' Build the full set of bounds for effect pairs
#'
#' Build the full set of bounds for effect pairs based on partial identification bounds.
#' @include helpers.R
#' @param bounds_data A data frame containing the partial identification bounds for each individual setting's effect, from a function like \code{ovb_bounds_by_setting}. Must be a \code{data.frame} with a column for \code{setting} and columns for \code{original_estimate}, \code{adjusted_estimate}, \code{lower_plausible_bound}, and \code{upper_plausible_bound}. Other columns are acceptable.
#' @param rho_bounds A matrix with the upper bound of rho_ij in the ith row and jth column, and the lower bound in the ith column and jth row. Trace values will be ignored. If all lower triangle values are 0, they will be set to the inverse of the corresponding upper bound. Alternately, provide a single real value to bound all pairs at that same value and its inverse. Set a bound to 0 to ignore it (set no restriction).
#' @param settings_order A vector with the values of the settings in the order they are used in \code{rho_bounds}. Defaults to the order of settings in \code{bounds_data}.
#' @param ... Additional arguments (not currently used).
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
#' # Put a 1.5 bound on Black vs Black & South and Neither vs South,
#' # 2 on Neither vs. black and South vs. Black & South
#' # and no restriction on Neither vs Black & South and on Black vs. South (setting to 0)
#' # Setting all the lower triangle values of 0
#' # will make them automatically the inverse of the upper triangle values
#' boundmat = matrix(c(0, 2, 1.5, 0,
#'                     0, 0, 0, 1.5,
#'                     0, 0, 0, 2,
#'                     0, 0, 0,0), nrow = 4, byrow = TRUE)
#' # Get the partial identification bounds
#' pi_bounds = build_bounds(bounds, boundmat,
#'                             settings_order = c('Neither','Black','South','Black and South'))
#'
#' @export

build_bounds = function(bounds_data,
                        rho_bounds,
                        settings_order = bounds_data$setting,
                        ...) {

  data.table::setDT(bounds_data)

  # ensure that settings_order contains all the settings and no more
  settings_not_in_order = setdiff(bounds_data$setting, settings_order)
  order_not_in_settings = setdiff(settings_order, bounds_data$setting)
  if (length(settings_not_in_order) > 0) {
    stop(paste0("The following settings are in bounds_data but not in settings_order: ", paste0(settings_not_in_order, collapse = ", ")))
  }
  if (length(order_not_in_settings) > 0) {
    stop(paste0("The following settings are in settings_order but not in bounds_data: ", paste0(order_not_in_settings, collapse = ", ")))
  }

  if (!is.matrix(rho_bounds)) {
    # Ensure it's just a single real value
    if (!is.numeric(rho_bounds) | length(rho_bounds) != 1) {
      stop('If rho_bounds is not a matrix it must be a single real value.')
    }
    rbvalue = rho_bounds
    rho_bounds = matrix(rep(rbvalue, length(settings_order)^2), ncol = length(settings_order))
    rho_bounds[lower.tri(rho_bounds)] = 1/rbvalue
  }

  # rho_bounds should be square with rows and cols equal to the length of settings_order
  if (nrow(rho_bounds) != ncol(rho_bounds) | nrow(rho_bounds) != length(settings_order)) {
    stop("rho_bounds must be a square matrix with dimensions equal to the length of settings_order.")
  }

  univariate_bounds_list = list()
  setting = NULL
  for (i in 1:length(settings_order)) {
    s = settings_order[i]
    bounds_s = bounds_data[setting == s]
    univariate_bounds_list[[s]] = list(
      estimate = bounds_s$original_estimate,
      lower = bounds_s$lower_plausible_bound,
      upper = bounds_s$upper_plausible_bound,
      lower_nu = bounds_s$original_estimate - bounds_s$upper_plausible_bound,
      upper_nu = bounds_s$original_estimate - bounds_s$lower_plausible_bound
    )
  }

  # Check if all sub-trace elements of rho_bounds are 0
  all_subtrace_zero = all(rho_bounds[lower.tri(rho_bounds)] == 0)

  paired_bounds_matrix = matrix(list(), nrow = length(settings_order), ncol = length(settings_order))
  for (i in 1:(length(settings_order)-1)) {
    for (j in (i+1):length(settings_order)) {
      s_i = settings_order[i]
      s_j = settings_order[j]
      if (rho_bounds[i,j] == 0) {
        pair_bounds = c(-Inf, Inf)
      } else {
        pair_bounds = c_bounds(
          b_lower = univariate_bounds_list[[s_j]]$lower_nu,
          b_upper = univariate_bounds_list[[s_j]]$upper_nu,
          rho_upper = rho_bounds[i,j],
          rho_lower = ifelse(all_subtrace_zero, 1/rho_bounds[i,j], rho_bounds[j,i]),
          return_full_set = FALSE
        )
      }
      paired_bounds_matrix[i, j] = pair_bounds[2]
      paired_bounds_matrix[j, i] = pair_bounds[1]
    }
  }
  colnames(paired_bounds_matrix) = settings_order
  rownames(paired_bounds_matrix) = settings_order
  return(list(
    univariate_bounds = univariate_bounds_list,
    paired_bounds = paired_bounds_matrix
  ))
}


#' Check for the existence of an identified set satisfying all bounds
#'
#' @param full_bounds_set A full set of univariate and paired bounds produced by \code{build_bounds}
#' @param check_only A vector of setting names to check only those settings. If \code{NULL} (default) checks all settings. This option is used to try to figure out which setting combinations might be leading to no identified set existing.
#' @param return_one_solution Set to \code{TRUE} to return a set of parameters that satisfy all bounds. \emph{IT IS EXTREMELY IMPORTANT TO NOTE} that this is not a "best" solution or anything like that. It is simply one possible solution.
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
#'
#' # Put a 1.5 bound on Black vs Black & South and Neither vs South,
#' # 2 on Neither vs. black and South vs. Black & South
#' # and no restriction on Neither vs Black & South and on Black vs. South (setting to 0)
#' # Setting all the lower triangle values of 0
#' # will make them automatically the inverse of the upper triangle values
#' boundmat = matrix(c(0, 2, 1.5, 0,
#'                     0, 0, 0, 1.5,
#'                     0, 0, 0, 2,
#'                     0, 0, 0,0), nrow = 4, byrow = TRUE)
#' # Get the partial identification bounds
#' boundset = build_bounds(bounds, boundmat,
#'                         settings_order = c('Neither','Black','South','Black and South'))
#'
#'
#' # Check if there exists a set of effect parameters that satisfy all bounds.
#' identified_set_exists(boundset)
#' # Get one example of a set of parameters in the identified set.
#' identified_set_exists(boundset, return_one_solution = TRUE)
#'
#' @export
identified_set_exists = function(full_bounds_set, check_only = NULL, return_one_solution = FALSE) {
  get_setup = set_up_solver(full_bounds_set, check_only)
  rst = get_setup$rst
  direc = get_setup$direc
  rhs = get_setup$rhs

  numsets = ncol(rst)

  slv = Rglpk::Rglpk_solve_LP(
    obj = rep(0, numsets),
    mat = rst,
    dir = direc,
    rhs = rhs
  )

  if (slv$status == 0) {
    if (return_one_solution) {
      solution = slv$solution
      settingnames = names(full_bounds_set[[1]])
      if (!is.null(check_only)) {
        settingnames = check_only
      }
      names(solution) = settingnames
      return(solution)
    } else {
      return(TRUE)
    }
  } else {
    return(FALSE)
  }
}


#' Univariate Bounds Table
#'
#' Creates a table of bounds for the effect in each setting.
#'
#' The table shows the widest possible bounds consistent with the assumptions for each setting one at a time.
#'
#' Note that because this is a highly multidimensional problem, the actual identified set of plausible estimates is somewhat narrower.
#'
#' For example, if in setting A the effect must be between 0 and 1, in setting B it must be between 1 and 2, and the difference between them must be no greater than .5, then the univariate set for A will be .5 to 1 and the set for B will be 1 to 1.5, ignoring that the joint set (.5 for A, 1.5 for B) is not in the identified set.
#'
#' To check whether a specific combination of values is in the identified set, use the function \code{valid_solution_check}.
#'
#' @param full_bounds_set A full set of univariate and paired bounds produced by \code{build_bounds}.
#' @param pin_values A named list of settings and values to pin estimates in those settings to. Values can be numeric, or can be \code{'lower'}, \code{'upper'}, or \code{'original'} for the univariate lower-bound, upper bound, or original estimate, respectively. Useful for exploring the multivariate nature of the bounds.
#' @param ... Additional arguments (not currently used).
#'
#' @examples
#' library(fixest)
#' library(hetset)
#' data("close_college")
#' bounds = ovb_bounds_by_setting(close_college,
#'                                setting = 'blacksouth',
#'                                treatment = 'educ',
#'                                model = 'feols(lwage ~ educ + smsa + married + exper, data = data)',
#'                                benchmark_covariates = c('smsa','married','exper'),
#'                                kd = .1)
#'
#' # Put a 1.5 bound on Black vs Black & South and Neither vs South,
#' # 2 on Neither vs. black and South vs. Black & South
#' # and no restriction on Neither vs Black & South and on Black vs. South (setting to 0)
#' # Setting all the lower triangle values of 0
#' # will make them automatically the inverse of the upper triangle values
#' boundmat = matrix(c(0, 2, 1.5, 0,
#'                     0, 0, 0, 1.5,
#'                     0, 0, 0, 2,
#'                     0, 0, 0,0), nrow = 4, byrow = TRUE)
#' # Get the partial identification bounds
#' boundset = build_bounds(bounds, boundmat,
#'                         settings_order = c('Neither','Black','South','Black and South'))
#'
#' # Get the univariate bounds table
#' univariate_bounds_table(boundset)
#' # Note in this example that the bounds are only very
#' # slightly tighter than if we hadn't worried about cross-setting
#' # relationships (for Black).
#'
#' @export
univariate_bounds_table = function(full_bounds_set, pin_values = NULL, ...) {
  setting_names = names(full_bounds_set[[1]])

  original_bounds_set = copy(full_bounds_set)

  if (!is.null(pin_values)) {
    for (s in names(pin_values)) {
      set_value = pin_values[[s]]
      if (!is.numeric(set_value)) {
        if (set_value == 'lower') {
          set_value = full_bounds_set[[1]][[s]]$lower
        } else if (set_value == 'upper') {
          set_value = full_bounds_set[[1]][[s]]$upper
        } else if (set_value == 'original') {
          set_value = full_bounds_set[[1]][[s]]$estimate
        } else {
          stop(paste0("pin_values for setting ", s, " must be numeric, 'lower', 'upper', or 'original'."))
        }
      }
      # Modify the full_bounds_set to pin this value
      full_bounds_set[[1]][[s]]$lower = set_value
      full_bounds_set[[1]][[s]]$upper = set_value
    }
  }

  get_setup = set_up_solver(full_bounds_set, check_only = NULL)
  rst = get_setup$rst
  direc = get_setup$direc
  rhs = get_setup$rhs

  numsets = length(setting_names)

  full_bounds_table = data.table::data.table()

  for (s in 1:numsets) {
    mincol = rep(0, numsets)
    mincol[s] = 1
    slv_low = Rglpk::Rglpk_solve_LP(
      obj = mincol,
      mat = rst,
      dir = direc,
      rhs = rhs
    )$solution[s]
    maxcol = rep(0, numsets)
    maxcol[s] = -1
    slv_up = Rglpk::Rglpk_solve_LP(
      obj = maxcol,
      mat = rst,
      dir = direc,
      rhs = rhs
    )$solution[s]
    full_bounds_table = rbind(
      full_bounds_table,
      data.table::data.table(
        setting = setting_names[s],
        estimate = full_bounds_set[[1]][[s]]$estimate,
        lower_bound = slv_low,
        upper_bound = slv_up,
        lower_nu_bound = full_bounds_set[[1]][[s]]$estimate - slv_up,
        upper_nu_bound = full_bounds_set[[1]][[s]]$estimate - slv_low,
        original_lower_bound = original_bounds_set[[1]][[s]]$lower,
        original_upper_bound = original_bounds_set[[1]][[s]]$upper
      )
    )
  }

  estimate = NULL
  upper_nu_bound = NULL
  lower_nu_bound = NULL
  lower_bound = NULL
  upper_bound = NULL
  full_bounds_table[, lower_bound := estimate - upper_nu_bound]
  full_bounds_table[, upper_bound := estimate - lower_nu_bound]

  rst_dt = data.table::data.table(
    setting = setting_names,
    lower_bound = sapply(setting_names, function(s) full_bounds_set[[1]][[s]]$lower),
    upper_bound = sapply(setting_names, function(s) full_bounds_set[[1]][[s]]$upper)
  )
  return(full_bounds_table)
}
