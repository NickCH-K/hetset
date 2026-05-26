"""
effect_sets.py
--------------
Construction and analysis of the partial identification bounds set.

Provides the main workflow functions for building the full set of
univariate and pairwise bounds (:func:`build_bounds`), checking whether
an identified set exists (:func:`identified_set_exists`), and summarising
the widest per-setting bounds consistent with all assumptions
(:func:`univariate_bounds_table`).
"""

import copy
import numpy as np
import pandas as pd

from .helpers import c_bounds, set_up_solver, _linprog_solve


def build_bounds(bounds_data, rho_bounds, settings_order=None, **kwargs):
    """
    Build the Full Set of Bounds for Effect Pairs.

    Combine per-setting OVB plausibility intervals (from e.g.
    :func:`~hetset.effect_estimate_sensemakr.ovb_bounds_by_setting`) with
    cross-setting rho constraints to produce the complete bounds structure
    consumed by :func:`identified_set_exists` and
    :func:`univariate_bounds_table`.

    Parameters
    ----------
    bounds_data : pandas.DataFrame
        Per-setting partial identification bounds.  Must contain columns
        ``setting``, ``original_estimate``, ``lower_plausible_bound``, and
        ``upper_plausible_bound``.  Typically the output of
        :func:`~hetset.effect_estimate_sensemakr.ovb_bounds_by_setting`.
    rho_bounds : numpy.ndarray or float
        * **Matrix** – square, with ``len(settings_order)`` rows and
          columns.  Element ``[i, j]`` is the *upper* bound on rho for the
          pair ``(settings_order[i], settings_order[j])``; element
          ``[j, i]`` is the corresponding *lower* bound.  If all
          lower-triangle values are 0 they are automatically set to
          ``1 / upper_triangle``.  Set an element to 0 to impose no
          restriction on that pair.
        * **Scalar** – a single positive float applied as the upper bound
          to every pair; the lower bound is then ``1 / scalar``.
    settings_order : list, optional
        Values of the setting variable in the order corresponding to the
        rows/columns of ``rho_bounds``.  Defaults to the order of settings
        as they appear in ``bounds_data``.
    **kwargs
        Currently unused; accepted for forward compatibility.

    Returns
    -------
    dict
        A dictionary with two keys:

        ``'univariate_bounds'``
            dict mapping each setting name to a sub-dict with keys
            ``estimate``, ``lower``, ``upper``, ``lower_nu``,
            ``upper_nu``.

        ``'paired_bounds'``
            :class:`pandas.DataFrame` with settings as both index and
            columns.  Element ``[s_i, s_j]`` stores the *upper* bound on
            the bias-difference ``(nu_i - nu_j)``; element ``[s_j, s_i]``
            stores the *lower* bound.

    Examples
    --------
    ::

        import numpy as np
        from hetset import ovb_bounds_by_setting, build_bounds, load_close_college

        df = load_close_college()
        bounds = ovb_bounds_by_setting(
            data=df, setting='blacksouth', treatment='educ',
            model='lwage ~ educ + smsa + married + exper',
            benchmark_covariates=['smsa', 'married', 'exper'], kd=0.1,
        )

        # 4x4 rho matrix (lower triangle 0 => auto-inverted)
        boundmat = np.array([
            [0,   2,   1.5, 0  ],
            [0,   0,   0,   1.5],
            [0,   0,   0,   2  ],
            [0,   0,   0,   0  ],
        ])
        pi_bounds = build_bounds(
            bounds, boundmat,
            settings_order=['Neither', 'Black', 'South', 'Black and South'],
        )
    """
    if settings_order is None:
        settings_order = list(bounds_data['setting'])

    # --- Validate settings match -----------------------------------------
    settings_in_data = set(bounds_data['setting'])
    settings_in_order = set(settings_order)

    missing_from_order = settings_in_data - settings_in_order
    missing_from_data = settings_in_order - settings_in_data

    if missing_from_order:
        raise ValueError(
            "The following settings are in bounds_data but not in "
            f"settings_order: {', '.join(str(s) for s in missing_from_order)}"
        )
    if missing_from_data:
        raise ValueError(
            "The following settings are in settings_order but not in "
            f"bounds_data: {', '.join(str(s) for s in missing_from_data)}"
        )

    # --- Normalise rho_bounds to a matrix --------------------------------
    if not isinstance(rho_bounds, np.ndarray):
        if not np.isscalar(rho_bounds):
            raise ValueError(
                "If rho_bounds is not a matrix it must be a single real value."
            )
        rb_val = float(rho_bounds)
        n = len(settings_order)
        rho_bounds = np.full((n, n), rb_val)
        rho_bounds[np.tril_indices(n)] = 1.0 / rb_val
        np.fill_diagonal(rho_bounds, 0.0)

    n = len(settings_order)
    if rho_bounds.shape != (n, n):
        raise ValueError(
            "rho_bounds must be a square matrix with dimensions equal to "
            "the length of settings_order."
        )

    # --- Build univariate bounds -----------------------------------------
    univariate_bounds_dict = {}
    for s in settings_order:
        row = bounds_data[bounds_data['setting'] == s].iloc[0]
        univariate_bounds_dict[s] = {
            'estimate': float(row['original_estimate']),
            'lower': float(row['lower_plausible_bound']),
            'upper': float(row['upper_plausible_bound']),
            'lower_nu': float(
                row['original_estimate'] - row['upper_plausible_bound']
            ),
            'upper_nu': float(
                row['original_estimate'] - row['lower_plausible_bound']
            ),
        }

    # --- Check whether all lower-triangle values are 0 ------------------
    lower_tri_vals = rho_bounds[np.tril_indices(n, k=-1)]
    all_subtrace_zero = np.all(lower_tri_vals == 0)

    # --- Build pairwise bounds -------------------------------------------
    paired_bounds = pd.DataFrame(
        data=np.full((n, n), np.nan),
        index=settings_order,
        columns=settings_order,
    )

    for i in range(n - 1):
        for j in range(i + 1, n):
            s_i = settings_order[i]
            s_j = settings_order[j]

            if rho_bounds[i, j] == 0:
                pair_bounds = [-np.inf, np.inf]
            else:
                rho_lower_ij = (
                    1.0 / rho_bounds[i, j]
                    if all_subtrace_zero
                    else rho_bounds[j, i]
                )
                pair_bounds = c_bounds(
                    b_lower=univariate_bounds_dict[s_j]['lower_nu'],
                    b_upper=univariate_bounds_dict[s_j]['upper_nu'],
                    rho_upper=rho_bounds[i, j],
                    rho_lower=rho_lower_ij,
                    return_full_set=False,
                )

            # [i, j] = upper bound; [j, i] = lower bound
            paired_bounds.loc[s_i, s_j] = pair_bounds[1]
            paired_bounds.loc[s_j, s_i] = pair_bounds[0]

    return {
        'univariate_bounds': univariate_bounds_dict,
        'paired_bounds': paired_bounds,
    }


def identified_set_exists(full_bounds_set, check_only=None,
                          return_one_solution=False):
    """
    Check for the Existence of an Identified Set Satisfying All Bounds.

    Uses linear programming to determine whether there exists a vector of
    true treatment effects — one per setting — that simultaneously
    satisfies all univariate and pairwise bounds.

    Parameters
    ----------
    full_bounds_set : dict
        Output of :func:`build_bounds`.
    check_only : list of str, optional
        Setting names to restrict the check to.  If ``None`` (default),
        all settings are checked.  Must contain at least two settings when
        provided; useful for diagnosing which pair(s) of settings drive
        infeasibility.
    return_one_solution : bool, optional
        If ``True`` and the identified set exists, return a dict mapping
        each (checked) setting name to a feasible effect value rather than
        returning ``True``.

        .. important::
            This is **not** a "best" or "representative" solution.  It is
            simply *one* feasible point in the identified set, determined
            by the LP solver's internal path.

    Returns
    -------
    bool or dict
        ``True`` / ``False`` indicating whether the identified set is
        non-empty, or — when ``return_one_solution=True`` and the set
        exists — a dict ``{setting: feasible_value}``.

    Examples
    --------
    ::

        from hetset import (
            ovb_bounds_by_setting, build_bounds,
            identified_set_exists, load_close_college,
        )
        import numpy as np

        df = load_close_college()
        bounds = ovb_bounds_by_setting(
            data=df, setting='blacksouth', treatment='educ',
            model='lwage ~ educ + smsa + married + exper',
            benchmark_covariates=['smsa', 'married', 'exper'], kd=0.1,
        )
        boundmat = np.array([
            [0, 2, 1.5, 0],
            [0, 0, 0, 1.5],
            [0, 0, 0, 2],
            [0, 0, 0, 0],
        ])
        boundset = build_bounds(
            bounds, boundmat,
            settings_order=['Neither', 'Black', 'South', 'Black and South'],
        )

        # Check feasibility
        identified_set_exists(boundset)

        # Get one feasible solution
        identified_set_exists(boundset, return_one_solution=True)
    """
    solver_setup = set_up_solver(full_bounds_set, check_only)
    rst = solver_setup['rst']
    direc = solver_setup['direc']
    rhs = solver_setup['rhs']

    numsets = rst.shape[1]

    result = _linprog_solve(
        obj=np.zeros(numsets),
        rst=rst,
        direc=direc,
        rhs=rhs,
    )

    if result.status == 0:  # Feasible / optimal
        if return_one_solution:
            setting_names = list(full_bounds_set['univariate_bounds'].keys())
            if check_only is not None:
                setting_names = [
                    s for s in setting_names if s in check_only
                ]
            return dict(zip(setting_names, result.x))
        return True
    else:
        return False


def univariate_bounds_table(full_bounds_set, pin_values=None, **kwargs):
    """
    Univariate Bounds Table.

    For each setting, compute the widest range of effect values consistent
    with *all* univariate and pairwise constraints simultaneously, using
    linear programming.

    This is a univariate summary: it reports the marginal bounds for each
    setting in isolation, ignoring that certain *combinations* across
    settings may be infeasible.  Use :func:`identified_set_exists` with
    ``return_one_solution=True`` or enumerate the joint identified set for
    a fully multivariate picture.

    Parameters
    ----------
    full_bounds_set : dict
        Output of :func:`build_bounds`.
    pin_values : dict, optional
        Mapping of setting names to fixed values.  Pins the effect in
        those settings to the given value before computing bounds for the
        remaining settings.  Values can be:

        * a numeric float — pin to that exact value;
        * ``'lower'`` — pin to the univariate lower bound;
        * ``'upper'`` — pin to the univariate upper bound;
        * ``'original'`` — pin to the point estimate.

        Useful for exploring how fixing one setting's effect constrains
        the rest.
    **kwargs
        Currently unused; accepted for forward compatibility.

    Returns
    -------
    pandas.DataFrame
        One row per setting with columns:

        * ``setting``
        * ``estimate`` — original point estimate.
        * ``lower_bound`` — LP-derived lower bound for the effect.
        * ``upper_bound`` — LP-derived upper bound for the effect.
        * ``lower_nu_bound`` — lower bound on the bias
          ``= estimate - upper_bound``.
        * ``upper_nu_bound`` — upper bound on the bias
          ``= estimate - lower_bound``.
        * ``original_lower_bound`` — input lower plausibility bound
          (before cross-setting tightening).
        * ``original_upper_bound`` — input upper plausibility bound.

    Examples
    --------
    ::

        from hetset import (
            ovb_bounds_by_setting, build_bounds,
            univariate_bounds_table, load_close_college,
        )
        import numpy as np

        df = load_close_college()
        bounds = ovb_bounds_by_setting(
            data=df, setting='blacksouth', treatment='educ',
            model='lwage ~ educ + smsa + married + exper',
            benchmark_covariates=['smsa', 'married', 'exper'], kd=0.1,
        )
        boundmat = np.array([
            [0, 2, 1.5, 0],
            [0, 0, 0, 1.5],
            [0, 0, 0, 2],
            [0, 0, 0, 0],
        ])
        boundset = build_bounds(
            bounds, boundmat,
            settings_order=['Neither', 'Black', 'South', 'Black and South'],
        )
        univariate_bounds_table(boundset)
    """
    setting_names = list(full_bounds_set['univariate_bounds'].keys())

    # Deep copy so we can pin values without mutating the caller's object
    original_bounds_set = copy.deepcopy(full_bounds_set)

    if pin_values is not None:
        for s, val in pin_values.items():
            if isinstance(val, str):
                if val == 'lower':
                    val = full_bounds_set['univariate_bounds'][s]['lower']
                elif val == 'upper':
                    val = full_bounds_set['univariate_bounds'][s]['upper']
                elif val == 'original':
                    val = full_bounds_set['univariate_bounds'][s]['estimate']
                else:
                    raise ValueError(
                        f"pin_values for setting '{s}' must be numeric, "
                        "'lower', 'upper', or 'original'."
                    )
            full_bounds_set['univariate_bounds'][s]['lower'] = float(val)
            full_bounds_set['univariate_bounds'][s]['upper'] = float(val)

    solver_setup = set_up_solver(full_bounds_set, check_only=None)
    rst = solver_setup['rst']
    direc = solver_setup['direc']
    rhs = solver_setup['rhs']

    numsets = len(setting_names)
    rows = []

    for s_idx, s in enumerate(setting_names):
        # ---- Minimise variable s_idx -----------------------------------
        min_obj = np.zeros(numsets)
        min_obj[s_idx] = 1.0
        min_result = _linprog_solve(min_obj, rst, direc, rhs)
        slv_low = min_result.x[s_idx]

        # ---- Maximise variable s_idx (= minimise its negative) ---------
        max_obj = np.zeros(numsets)
        max_obj[s_idx] = -1.0
        max_result = _linprog_solve(max_obj, rst, direc, rhs)
        slv_up = max_result.x[s_idx]

        est = full_bounds_set['univariate_bounds'][s]['estimate']

        rows.append({
            'setting': s,
            'estimate': est,
            'lower_bound': slv_low,
            'upper_bound': slv_up,
            'lower_nu_bound': est - slv_up,
            'upper_nu_bound': est - slv_low,
            'original_lower_bound': (
                original_bounds_set['univariate_bounds'][s]['lower']
            ),
            'original_upper_bound': (
                original_bounds_set['univariate_bounds'][s]['upper']
            ),
        })

    result_df = pd.DataFrame(rows)
    # Recompute to match R's final assignment order exactly
    result_df['lower_bound'] = (
        result_df['estimate'] - result_df['upper_nu_bound']
    )
    result_df['upper_bound'] = (
        result_df['estimate'] - result_df['lower_nu_bound']
    )

    return result_df
