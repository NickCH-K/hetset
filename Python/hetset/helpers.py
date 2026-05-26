"""
helpers.py
----------
Core mathematical utilities for the hetset package.

Provides the C-set bounds calculation and LP solver setup used throughout
the partial identification framework of Huntington-Klein (2025).
"""

import numpy as np
from scipy.optimize import linprog


def c_bounds(b_lower, b_upper, rho_upper, rho_lower=None, return_full_set=False):
    """
    Calculate C set of bounds.

    Calculate the set that bounds the difference between two effects,
    from Huntington-Klein (2025).

    Parameters
    ----------
    b_lower : float
        Lower bound of the bias (nu) in setting B.
    b_upper : float
        Upper bound of the bias (nu) in setting B.
    rho_upper : float
        Upper bound on rho (the proportional relationship between biases
        across settings). Must be >= 1.
    rho_lower : float, optional
        Lower bound on rho. Defaults to ``1 / rho_upper``.
    return_full_set : bool, optional
        If True, return all four corner values of the C set rather than
        just the [min, max] range. Default is False.

    Returns
    -------
    list
        If ``return_full_set=False`` (default): a two-element list
        ``[min_C, max_C]``.
        If ``return_full_set=True``: a four-element list of all corner values.
    """
    if rho_lower is None:
        rho_lower = 1.0 / rho_upper

    # Here a and b refer to nu_a and nu_b from the paper
    C_set = [
        (rho_lower - 1) * b_lower,
        (rho_upper - 1) * b_lower,
        (rho_lower - 1) * b_upper,
        (rho_upper - 1) * b_upper,
    ]

    if return_full_set:
        return C_set
    return [min(C_set), max(C_set)]


def are_bounds_satisfiable(a_lower, a_upper, b_lower, b_upper, rho_upper,
                           rho_lower=None):
    """
    Check whether bounds are jointly satisfiable for a pair of settings.

    Parameters
    ----------
    a_lower : float
        Lower bound of nu (bias) in setting A.
    a_upper : float
        Upper bound of nu (bias) in setting A.
    b_lower : float
        Lower bound of nu (bias) in setting B.
    b_upper : float
        Upper bound of nu (bias) in setting B.
    rho_upper : float
        Upper bound on rho.
    rho_lower : float, optional
        Lower bound on rho. Defaults to ``1 / rho_upper``.

    Returns
    -------
    dict
        Dictionary with keys ``jointly_satisfiable``, ``a_is_possible``,
        and ``b_is_possible`` (all bool).
    """
    C_set = c_bounds(b_lower, b_upper, rho_upper, rho_lower,
                     return_full_set=False)

    # Check if there is an a that satisfies all criteria.
    # The bound on the difference is:
    #   th_a - th_b in [(th_a_s - th_b_s) + min(C),
    #                   (th_a_s - th_b_s) + max(C)]
    # => (th_a - th_a_s) in [(th_b - th_b_s) + min(C),
    #                         (th_b - th_b_s) + max(C)]
    # and we have th_a - th_a_s in [a_lower, a_upper]
    # and th_b - th_b_s in [b_lower, b_upper]
    # so we need overlap between [a_lower, a_upper] and
    # [b_lower + min(C), b_upper + max(C)]
    a_is_possible = not ((a_upper < b_lower + C_set[0]) or
                         (a_lower > b_upper + C_set[1]))
    b_is_possible = not ((b_upper < a_lower - C_set[1]) or
                         (b_lower > a_upper - C_set[0]))

    return {
        'jointly_satisfiable': a_is_possible and b_is_possible,
        'a_is_possible': a_is_possible,
        'b_is_possible': b_is_possible,
    }


def set_up_solver(full_bounds_set, check_only=None):
    """
    Set up the LP constraint system for the identified-set solver.

    Builds the constraint matrix, direction vector, and right-hand-side
    vector used by :func:`~hetset.effect_sets.identified_set_exists` and
    :func:`~hetset.effect_sets.univariate_bounds_table`.

    Parameters
    ----------
    full_bounds_set : dict
        A full set of univariate and paired bounds produced by
        :func:`~hetset.effect_sets.build_bounds`.
    check_only : list of str, optional
        Setting names to include. If ``None`` (default) all settings are
        included. Must contain at least two settings when provided.

    Returns
    -------
    dict
        Dictionary with keys:

        * ``'rst'`` – constraint matrix as a ``numpy.ndarray`` of shape
          ``(n_constraints, n_settings)``.
        * ``'direc'`` – list of ``'<='`` or ``'>='`` strings, one per row.
        * ``'rhs'`` – right-hand-side values as a ``numpy.ndarray``.
    """
    setting_names = list(full_bounds_set['univariate_bounds'].keys())

    if check_only is None:
        check_only = setting_names
    else:
        if len(check_only) < 2:
            raise ValueError(
                "check_only must contain at least two settings to check "
                "joint satisfiability."
            )
        check_only = [s for s in setting_names if s in check_only]

    numsets = len(check_only)
    rows = []
    direc = []
    rhs_vals = []

    # --- Univariate restrictions -----------------------------------------
    for i, s in enumerate(check_only):
        bounds_s = full_bounds_set['univariate_bounds'][s]
        coefvec = np.zeros(numsets)
        coefvec[i] = 1.0

        # x_s <= a_upper
        rows.append(coefvec.copy())
        direc.append('<=')
        rhs_vals.append(bounds_s['upper'])

        # x_s >= a_lower
        rows.append(coefvec.copy())
        direc.append('>=')
        rhs_vals.append(bounds_s['lower'])

    # --- Pairwise restrictions -------------------------------------------
    paired_bounds = full_bounds_set['paired_bounds']

    for idx_i in range(len(check_only) - 1):
        s_i = check_only[idx_i]
        for idx_j in range(idx_i + 1, len(check_only)):
            s_j = check_only[idx_j]

            # d_upper: upper bound on (theta_i - theta_j) deviation
            d_upper = paired_bounds.loc[s_i, s_j]
            # d_lower: lower bound on (theta_i - theta_j) deviation
            d_lower = paired_bounds.loc[s_j, s_i]

            a_est = full_bounds_set['univariate_bounds'][s_i]['estimate']
            b_est = full_bounds_set['univariate_bounds'][s_j]['estimate']

            coefvec = np.zeros(numsets)
            coefvec[idx_i] = 1.0
            coefvec[idx_j] = -1.0

            if not np.isinf(d_upper):
                rows.append(coefvec.copy())
                direc.append('<=')
                rhs_vals.append(a_est - b_est + d_upper)

            if not np.isinf(d_lower):
                rows.append(coefvec.copy())
                direc.append('>=')
                rhs_vals.append(a_est - b_est + d_lower)

    return {
        'rst': np.array(rows, dtype=float),
        'direc': direc,
        'rhs': np.array(rhs_vals, dtype=float),
    }


def _linprog_solve(obj, rst, direc, rhs):
    """
    Thin wrapper around ``scipy.optimize.linprog`` that accepts the same
    constraint format as :func:`set_up_solver`.

    Parameters
    ----------
    obj : array-like
        Objective coefficient vector (minimization).
    rst : numpy.ndarray
        Constraint matrix, shape ``(n_constraints, n_vars)``.
    direc : list of str
        Direction for each constraint row: ``'<='`` or ``'>='``.
    rhs : array-like
        Right-hand-side values.

    Returns
    -------
    scipy.optimize.OptimizeResult
        Result object from ``linprog``. Check ``.status`` (0 = success,
        2 = infeasible) and ``.x`` for the solution vector.
    """
    n = len(obj)
    c = np.array(obj, dtype=float)

    A_ub_rows = []
    b_ub_vals = []

    for i, d in enumerate(direc):
        row = np.array(rst[i], dtype=float)
        r = float(rhs[i])
        if d == '<=':
            A_ub_rows.append(row)
            b_ub_vals.append(r)
        elif d == '>=':
            A_ub_rows.append(-row)
            b_ub_vals.append(-r)
        else:
            raise ValueError(f"Unsupported direction '{d}'. Use '<=' or '>='.")

    A_ub = np.array(A_ub_rows, dtype=float) if A_ub_rows else None
    b_ub = np.array(b_ub_vals, dtype=float) if b_ub_vals else None

    result = linprog(
        c,
        A_ub=A_ub,
        b_ub=b_ub,
        bounds=[(None, None)] * n,
        method='highs',
    )
    return result
