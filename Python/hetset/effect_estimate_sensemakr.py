"""
effect_estimate_sensemakr.py
----------------------------
Partial identification bounds via sensemakr, estimated by setting.

Provides :func:`ovb_bounds_by_setting`, which fits a separate regression
within each level of a *setting* variable and calls
``sensemakr.ovb_bounds`` to obtain omitted-variable-bias plausibility
intervals for the treatment coefficient in each setting.

Also provides :func:`custom_ovb_bounds_by_setting` for constructing a
properly formatted bounds table from non-sensemakr methods.

The ``dml.sensemakr``-based function
(``ovb_bounds_by_setting_dml`` in the R package) is **not** ported here
because there is no Python equivalent of ``dml.sensemakr``.
"""

import warnings
import numpy as np
import pandas as pd
import statsmodels.formula.api as smf


def ovb_bounds_by_setting(data, setting, treatment, model,
                          benchmark_covariates, kd=1, ky=None,
                          verbose=False, **kwargs):
    """
    Estimate Partial Identification Bounds by Setting with sensemakr.

    Fits a separate OLS regression within each level of ``setting``, then
    calls ``sensemakr.ovb_bounds`` to obtain per-setting omitted-variable-
    bias bounds for the treatment coefficient.

    Parameters
    ----------
    data : pandas.DataFrame
        Data containing all variables.
    setting : str
        Name of the column that defines the estimation settings.
    treatment : str
        Name of the treatment variable.
    model : str
        A patsy formula string for the regression, e.g.
        ``'lwage ~ educ + smsa + married + exper'``.  OLS is fit via
        ``statsmodels.formula.api.ols``.

        .. note::
            In the R package, ``model`` was a complete model-call string
            such as ``'feols(y ~ x, data = data)'``.  In this Python port
            ``model`` is a plain formula string; the estimation function is
            always ``statsmodels`` OLS.
    benchmark_covariates : list of str
        Names of observed covariates used to calibrate the unobserved
        confounder strength via ``sensemakr.ovb_bounds``.  These variables
        must appear in ``model``.  All covariates are grouped together
        under the label ``'Total'``, mirroring the R package default.
    kd : float or list of float, optional
        How many times stronger the confounder's relationship with the
        *treatment* is compared to the benchmark covariate.  Default 1.
    ky : float or list of float, optional
        How many times stronger the confounder's relationship with the
        *outcome* is compared to the benchmark covariate.  Defaults to
        ``kd``.
    verbose : bool, optional
        Print progress messages.  Default is ``False``.
    **kwargs
        Additional keyword arguments forwarded to ``sensemakr.ovb_bounds``.

    Returns
    -------
    pandas.DataFrame
        One row per setting.  Always contains ``setting`` and ``failed``
        as the first two columns, followed by all columns returned by
        ``sensemakr.ovb_bounds`` plus:

        * ``original_estimate`` – OLS coefficient for ``treatment``.
        * ``lower_plausible_bound`` – ``original_estimate`` minus the
          absolute bias implied by the OVB bound.
        * ``upper_plausible_bound`` – ``original_estimate`` plus the
          absolute bias.
        * ``lower_nu`` – signed bias to the lower bound (positive).
        * ``upper_nu`` – signed bias to the upper bound (negative).

    Examples
    --------
    ::

        from hetset import ovb_bounds_by_setting, load_close_college

        df = load_close_college()
        bounds = ovb_bounds_by_setting(
            data=df,
            setting='blacksouth',
            treatment='educ',
            model='lwage ~ educ + smsa + married + exper',
            benchmark_covariates=['smsa', 'married', 'exper'],
            kd=0.1,
        )
    """
    try:
        from sensemakr import ovb_bounds as _ovb_bounds
    except ImportError:
        raise ImportError(
            "The 'PySensemakr' package is required. "
            "Install it with: pip install PySensemakr"
        )

    if ky is None:
        ky = kd

    results_list = []

    if verbose:
        print("Estimating effects by setting...")

    for s in data[setting].unique():
        if verbose:
            import datetime
            print(f"  Running Setting: {s} at {datetime.datetime.now()}")

        data_s = data[data[setting] == s].copy()

        try:
            m = smf.ols(formula=model, data=data_s).fit()

            b = _ovb_bounds(
                model=m,
                treatment=treatment,
                benchmark_covariates={'Total': benchmark_covariates},
                kd=kd,
                ky=ky,
                **kwargs,
            )

            b = b.copy()
            original_estimate = m.params[treatment]
            b['original_estimate'] = original_estimate
            bounds_s = b

        except Exception as exc:
            warnings.warn(
                f"Bounds estimation failed for setting: {s}.  ({exc})"
            )
            bounds_s = pd.DataFrame({'failed': [True]})

        bounds_s = bounds_s.copy()
        bounds_s['setting'] = s
        results_list.append(bounds_s)

    bounds = pd.concat(results_list, ignore_index=True)

    if 'failed' not in bounds.columns:
        bounds['failed'] = False
    bounds['failed'] = bounds['failed'].fillna(False)

    # Reorder: setting and failed first
    cols = ['setting', 'failed'] + [
        c for c in bounds.columns if c not in ('setting', 'failed')
    ]
    bounds = bounds[cols]

    # Compute symmetric plausibility interval:
    #   half-width = |original_estimate - adjusted_estimate|
    bounds['lower_plausible_bound'] = (
        bounds['original_estimate']
        - (bounds['original_estimate'] - bounds['adjusted_estimate']).abs()
    )
    bounds['upper_plausible_bound'] = (
        bounds['original_estimate']
        + (bounds['original_estimate'] - bounds['adjusted_estimate']).abs()
    )
    bounds['lower_nu'] = (
        bounds['original_estimate'] - bounds['lower_plausible_bound']
    )
    bounds['upper_nu'] = (
        bounds['original_estimate'] - bounds['upper_plausible_bound']
    )

    return bounds


def custom_ovb_bounds_by_setting(setting, original_estimate,
                                 lower_plausible_bound, upper_plausible_bound,
                                 **kwargs):
    """
    Create a Custom Bounds Table.

    A convenience function for constructing a bounds table with the correct
    column names and structure to use as input to
    :func:`~hetset.effect_sets.build_bounds`, when partial identification
    bounds come from a source other than ``sensemakr.ovb_bounds`` (e.g.
    manual calibration, a different sensitivity framework, or a bootstrapped
    interval).

    The returned DataFrame has the same format as the output of
    :func:`ovb_bounds_by_setting` and can be passed directly to
    :func:`~hetset.effect_sets.build_bounds`.

    Parameters
    ----------
    setting : array-like
        Setting values, one per row.  Each value must be unique.
    original_estimate : array-like of float
        Point estimates for the treatment effect in each setting.
    lower_plausible_bound : array-like of float
        Lower plausible bounds for the treatment effect in each setting.
    upper_plausible_bound : array-like of float
        Upper plausible bounds for the treatment effect in each setting.
    **kwargs
        Additional named array-likes of the same length as ``setting`` to
        include as extra columns.  Each must be a one-dimensional sequence
        of scalars (str, int, float, bool), not a nested structure.

    Returns
    -------
    pandas.DataFrame
        One row per setting with columns ``setting``, ``failed``,
        ``original_estimate``, ``lower_plausible_bound``,
        ``upper_plausible_bound``, ``lower_nu``, ``upper_nu``, plus any
        extra columns supplied via ``**kwargs``.

    Raises
    ------
    ValueError
        If any input vectors differ in length, if ``setting`` contains
        duplicate values, or if an extra column is not a one-dimensional
        sequence of scalars.

    Examples
    --------
    Manually specified bounds::

        from hetset import custom_ovb_bounds_by_setting

        bounds = custom_ovb_bounds_by_setting(
            setting               = ['Control', 'Treated'],
            original_estimate     = [0.4, 0.6],
            lower_plausible_bound = [0.2, 0.4],
            upper_plausible_bound = [0.6, 0.8],
        )

    With extra informational columns::

        bounds = custom_ovb_bounds_by_setting(
            setting               = ['Control', 'Treated'],
            original_estimate     = [0.4, 0.6],
            lower_plausible_bound = [0.2, 0.4],
            upper_plausible_bound = [0.6, 0.8],
            n_obs                 = [500, 450],
            method                = ['bootstrap', 'bootstrap'],
        )
    """
    import numpy as np

    setting = list(setting)
    original_estimate = list(original_estimate)
    lower_plausible_bound = list(lower_plausible_bound)
    upper_plausible_bound = list(upper_plausible_bound)

    n = len(setting)
    if len(original_estimate) != n or \
       len(lower_plausible_bound) != n or \
       len(upper_plausible_bound) != n:
        raise ValueError(
            "setting, original_estimate, lower_plausible_bound, and "
            "upper_plausible_bound must all be the same length."
        )
    if len(set(setting)) != n:
        raise ValueError(
            "Duplicate values in setting. Each setting must appear exactly once."
        )

    for col_name, col_val in kwargs.items():
        try:
            col_val = list(col_val)
        except TypeError:
            raise ValueError(
                f"Extra column '{col_name}' must be iterable."
            )
        if len(col_val) != n:
            raise ValueError(
                f"Extra column '{col_name}' must have the same length as "
                f"setting ({n})."
            )
        # Check each element is a scalar (not a list/dict/array)
        for i, v in enumerate(col_val):
            if not isinstance(v, (str, bytes, bool, int, float,
                                  np.integer, np.floating, np.bool_,
                                  type(None))):
                raise ValueError(
                    f"Extra column '{col_name}' must contain only scalar "
                    f"values (str, int, float, bool, or None). "
                    f"Element at index {i} is {type(v).__name__}."
                )
        kwargs[col_name] = col_val

    oe = [float(v) for v in original_estimate]
    lb = [float(v) for v in lower_plausible_bound]
    ub = [float(v) for v in upper_plausible_bound]

    result = pd.DataFrame({
        'setting':               setting,
        'failed':                [False] * n,
        'original_estimate':     oe,
        'lower_plausible_bound': lb,
        'upper_plausible_bound': ub,
        'lower_nu':              [o - l for o, l in zip(oe, lb)],
        'upper_nu':              [o - u for o, u in zip(oe, ub)],
        **kwargs,
    })

    return result
