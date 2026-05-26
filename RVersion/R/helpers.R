#' Calculate C set of bounds
#'
#' Calculate the set that bounds the difference between two effects, from Huntington-Klein (2025).
#'
#' @param b_lower The lower bound on \eqn{\nu} in the second setting (B in the paper).
#' @param b_upper The upper bound on \eqn{\nu} in the second setting (B in the paper).
#' @param rho_upper The upper bound on the difference of biases between the two settings.
#' @param rho_lower The lower bound on the difference of biases between the two settings. By default, this is set to \code{1/rho_upper}, which is a common choice that ensures a symmetrical bound on the ratio.
#' @param return_full_set A boolean indicating whether to return the full set of bounds (the four values corresponding to the corners of the rectangle defined by the bounds) or just the range (the minimum and maximum of those values). By default, this is set to \code{FALSE}, which returns just the range.
#'
#' @export
c_bounds = function(b_lower, b_upper, rho_upper, rho_lower = 1/rho_upper, return_full_set = FALSE) {
  # here a and b refer to \nu_a and \nu_b from the paper
  C_set = c((rho_lower-1)*b_lower,
            (rho_upper-1)*b_lower,
            (rho_lower-1)*b_upper,
            (rho_upper-1)*b_upper)
  if (return_full_set) {
    return(C_set)
  }
  return(range(C_set))
}

# Shorthand for evaluating text code
pp = function(...) {
  parse(text = paste0(...))
}



# Check whether bounds are jointly satisfiable
are_bounds_satisfiable = function(a_lower, a_upper, b_lower, b_upper, rho_upper, rho_lower = 1/rho_upper) {
  C_set = c_bounds(b_lower, b_upper, rho_upper, rho_lower, return_full_set = FALSE)

  # Check if there is an a that satisfies all criteria
  # The bound on the difference is
  # th_a - th_b \in [(th_a_s-th_b_s)+min(C), (th_a_s-th_b_s)+max(C)]
  # => (th_a - th_a_s) \in [(th_b - th_b_s)+min(C), (th_b - th_b_s)+max(C)]
  # and we have th_a - th_a_s \in [a_lower, a_upper]
  # and th_b - th_b_s \in [b_lower, b_upper]
  # so we need overlap between [a_lower, a_upper] and [b_lower + min(C), b_upper + max(C)]
  a_is_possible = !( (a_upper < b_lower + C_set[1]) | (a_lower > b_upper + C_set[2]) )
  b_is_possible = !( (b_upper < a_lower - C_set[2]) | (b_lower > a_upper - C_set[1]) )

  return(list(jointly_satisfiable = a_is_possible & b_is_possible,
              a_is_possible = a_is_possible,
              b_is_possible = b_is_possible))
}

# set up the solver
set_up_solver = function(full_bounds_set, check_only = NULL) {
  numsets = length(full_bounds_set[[1]])
  setting_names = names(full_bounds_set[[1]])

  if (is.null(check_only)) {
    check_only = 1:numsets
  } else {
    if (length(check_only) < 2) {
      stop("check_only must contain at least two settings to check joint satisfiability.")
    }
    check_only = which(setting_names %in% check_only)
    numsets = length(check_only)
    setting_names = setting_names[check_only]
  }

  rst = c()
  direc = c()
  rhs = c()

  # Add the univariate restrictions
  for (i in check_only) {
    a_lower = full_bounds_set[[1]][[i]]$lower
    a_upper = full_bounds_set[[1]][[i]]$upper
    coefvec = rep(0, numsets)
    coefvec[which(check_only == i)] = 1
    rst = c(rst, coefvec, coefvec)
    direc = c(direc, "<=", ">=")
    rhs = c(rhs, a_upper, a_lower)
  }

  # Add the pair restrictions
  for (i in check_only[1:(length(check_only)-1)]) {
    for (j in check_only[check_only > i]) {
      d_upper = full_bounds_set[[2]][[setting_names[which(check_only == i)],setting_names[which(check_only == j)]]]
      d_lower = full_bounds_set[[2]][[setting_names[which(check_only == j)],setting_names[which(check_only == i)]]]
      a_est = full_bounds_set[[1]][[i]]$estimate
      b_est = full_bounds_set[[1]][[j]]$estimate
      coefvec = rep(0, numsets)
      coefvec[which(check_only == i)] = 1
      coefvec[which(check_only == j)] = -1
      if (!is.infinite(d_upper)) {
        rst = c(rst, coefvec)
        direc = c(direc, "<=")
        rhs = c(rhs, a_est-b_est+d_upper)
      }
      if (!is.infinite(d_lower)) {
        rst = c(rst, coefvec)
        direc = c(direc, ">=")
        rhs = c(rhs, a_est-b_est+d_lower)
      }
    }
  }

  return(list(rst = matrix(rst, ncol = numsets, byrow = TRUE),
              direc = direc,
              rhs = rhs))
}
