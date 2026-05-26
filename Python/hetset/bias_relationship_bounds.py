"""
bias_relationship_bounds.py
---------------------------
Data-driven proposal for rho bounds via model comparison.

Provides :func:`supershort_rho_bounds_proposal`, which estimates plausible
rho values — the proportional relationship between omitted-variable bias
across settings — by comparing coefficient estimates from a full model
and a shorter (less-controlled) model within each setting.
"""

import warnings
import numpy as np
import pandas as pd
import statsmodels.formula.api as smf


def supershort_rho_bounds_proposal(data, setting, treatment,
                                   model, model_shorter,
                                   negative_is_uninformative=True,
                                   minimum_bound=None,
                                   maximum_bound=None,
                                   settings_order=None,
                                   return_type='matrix'):
    """
    Propose a Set of rho Bounds.

    Suggests plausible bounds for rho — the proportional parameter
    relating the omitted variable bias in setting A to the bias in setting
    B — by examining how much a coefficient changes when additional
    covariates are removed.

    The intuition: we already have an imperfect model (some predictors are
    missing, so there is OVB).  By further dropping predictors we can
    observe how the bias *changes*, and compare this change across
    settings to bound their ratio.

    Parameters
    ----------
    data : pandas.DataFrame
        Data containing all variables.
    setting : str
        Name of the column defining the estimation settings.
    treatment : str
        Name of the treatment variable.
    model : str
        Patsy formula for the *full* model (all covariates included),
        e.g. ``'lwage ~ educ + smsa + married + exper'``.

        .. note::
            In the R package this was a complete model-call string such as
            ``'fixest::feols(y ~ x, data = data)'``.  In this Python port
            it is a plain patsy formula; OLS is always used.
    model_shorter : str
        Patsy formula for the *shorter* model (the predictors to be
        omitted from ``model`` are absent here), e.g. ``'lwage ~ educ'``.
    negative_is_uninformative : bool, optional
        If the bias-change in setting A and setting B have *opposite*
        signs, treat the analysis as uninformative for that pair (set rho
        bounds to ``(-inf, inf)``).  Default ``True``.
    minimum_bound : float, optional
        A value > 1.  All finite rho upper-bounds below ``minimum_bound``
        are raised to ``minimum_bound``; all finite rho lower-bounds above
        ``1 / minimum_bound`` are lowered to ``1 / minimum_bound``.
    maximum_bound : float, optional
        A value > 1.  All finite rho bounds are clamped to
        ``[1 / maximum_bound, maximum_bound]``.
    settings_order : list, optional
        Values of the setting variable in the desired order.  Determines
        the row/column order of the returned matrix.  Defaults to
        ``sorted(unique(data[setting]))``.
    return_type : {'matrix', 'table', 'both'}, optional
        * ``'matrix'`` (default) – return a ``numpy.ndarray`` suitable for
          use as ``rho_bounds`` in :func:`~hetset.effect_sets.build_bounds`.
        * ``'table'`` – return a :class:`pandas.DataFrame` of pairwise
          rho estimates.
        * ``'both'`` – return a dict ``{'Table': df, 'Matrix': arr}``.

    Returns
    -------
    numpy.ndarray or pandas.DataFrame or dict
        See ``return_type``.

    Examples
    --------
    ::

        from hetset import (
            ovb_bounds_by_setting, supershort_rho_bounds_proposal,
            build_bounds, univariate_bounds_table, load_close_college,
        )

        df = load_close_college()

        bounds = ovb_bounds_by_setting(
            data=df, setting='blacksouth', treatment='educ',
            model='lwage ~ educ + smsa + married + exper',
            benchmark_covariates=['smsa', 'married', 'exper'], kd=0.1,
        )
        boundmat = supershort_rho_bounds_proposal(
            data=df,
            setting='blacksouth',
            treatment='educ',
            model='lwage ~ educ + smsa + married + exper',
            model_shorter='lwage ~ educ',
            settings_order=['Neither', 'Black', 'South', 'Black and South'],
        )

        pi_bounds = build_bounds(
            bounds, boundmat,
            settings_order=['Neither', 'Black', 'South', 'Black and South'],
        )
        univariate_bounds_table(pi_bounds)
    """
    # --- Validate arguments -----------------------------------------------
    if minimum_bound is not None and minimum_bound <= 1:
        raise ValueError("minimum_bound must be above 1.")
    if maximum_bound is not None and maximum_bound <= 1:
        raise ValueError("maximum_bound must be above 1.")
    if return_type not in ('table', 'matrix', 'both'):
        raise ValueError(
            "return_type must be one of 'table', 'matrix', or 'both'."
        )

    if settings_order is not None:
        settings_in_data = set(data[setting].unique())
        settings_in_order = set(settings_order)
        if settings_in_data != settings_in_order:
            raise ValueError(
                "settings_order must contain all of the values in the "
                "setting column and no more."
            )
    else:
        settings_order = sorted(data[setting].unique())

    # --- Estimate coefficients in each setting for both models ------------
    coefs_list = []
    for s in settings_order:
        data_s = data[data[setting] == s].copy()

        m_full = smf.ols(formula=model, data=data_s).fit()
        eff_s = m_full.params[treatment]

        m_short = smf.ols(formula=model_shorter, data=data_s).fit()
        eff_ss = m_short.params[treatment]

        coefs_list.append({
            'setting': s,
            'eff_s': eff_s,
            'eff_ss': eff_ss,
            'diff': eff_s - eff_ss,
        })

    coefs_df = pd.DataFrame(coefs_list)

    # --- Build pairwise rho table ----------------------------------------
    rho_rows = []
    n = len(settings_order)

    for idx_a in range(n - 1):
        sa = settings_order[idx_a]
        diff_a = coefs_df.loc[coefs_df['setting'] == sa, 'diff'].iloc[0]

        for idx_b in range(idx_a + 1, n):
            sb = settings_order[idx_b]
            diff_b = coefs_df.loc[coefs_df['setting'] == sb, 'diff'].iloc[0]

            if (negative_is_uninformative
                    and np.sign(diff_a) != np.sign(diff_b)):
                rho_low = -np.inf
                rho_high = np.inf
            else:
                ratio = diff_a / diff_b if diff_b != 0 else np.inf
                inv_ratio = diff_b / diff_a if diff_a != 0 else np.inf
                rho_low = min(ratio, inv_ratio)
                rho_high = max(ratio, inv_ratio)

            rho_rows.append({
                'setting_a': sa,
                'setting_b': sb,
                'rho_low': rho_low,
                'rho_high': rho_high,
            })

    rhotab = pd.DataFrame(rho_rows)

    # --- Apply floor / ceiling -------------------------------------------
    if minimum_bound is not None:
        mask = ~rhotab['rho_low'].isin([np.inf, -np.inf])
        rhotab.loc[mask & (rhotab['rho_low'] < minimum_bound),
                   'rho_low'] = minimum_bound

    if maximum_bound is not None:
        mask = ~rhotab['rho_high'].isin([np.inf, -np.inf])
        rhotab.loc[mask & (rhotab['rho_high'] > maximum_bound),
                   'rho_high'] = maximum_bound

    if return_type == 'table':
        return rhotab

    # --- Convert to matrix -----------------------------------------------
    rhomat = np.zeros((n, n))

    for _, row in rhotab.iterrows():
        i = settings_order.index(row['setting_a'])
        j = settings_order.index(row['setting_b'])
        rhomat[i, j] = row['rho_high']   # upper bound in [i, j]
        rhomat[j, i] = row['rho_low']    # lower bound in [j, i]

    # Build as a DataFrame with labels so build_bounds can read it easily,
    # but return as ndarray to match the R interface
    rhomat_df = pd.DataFrame(rhomat, index=settings_order,
                             columns=settings_order)

    if return_type == 'matrix':
        return rhomat
    else:  # 'both'
        return {'Table': rhotab, 'Matrix': rhomat}
