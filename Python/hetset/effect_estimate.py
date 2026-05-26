"""
effect_estimate.py
------------------
Generic heterogeneous effect estimation by setting.

Provides :func:`estimate_het_effects` for estimating treatment effects
separately within each level of a *setting* variable, along with the
default OLS estimation wrapper :func:`hetset_ols`.
"""

import warnings
import numpy as np
import pandas as pd
import statsmodels.formula.api as smf


def hetset_ols(data, treatment, formula=None, outcome=None, covariates=None,
               **kwargs):
    """
    A hetset-compatible estimation wrapper for statsmodels OLS.

    A ready-to-use wrapper for ``statsmodels.formula.api.ols`` to be used
    with :func:`estimate_het_effects`.  This is the default estimation
    function throughout the package, and serves as the Python analogue of
    ``hetset_feols`` in the R package.

    Parameters
    ----------
    data : pandas.DataFrame
        Data for a single setting.
    treatment : str
        Name of the treatment variable whose coefficient is extracted.
    formula : str, optional
        A patsy formula string such as ``'y ~ x1 + x2'``.  If provided,
        ``outcome`` and ``covariates`` are ignored.
    outcome : str, optional
        Name of the outcome variable.  Used to build a formula when
        ``formula`` is not provided.
    covariates : list of str, optional
        Names of control variables.  Included additively in the formula when
        ``formula`` is not provided.
    **kwargs
        Additional keyword arguments forwarded to
        ``statsmodels.formula.api.ols``.

    Returns
    -------
    pandas.DataFrame
        A one-row DataFrame with columns:

        * ``estimate`` – OLS coefficient for ``treatment``.
        * ``std_error`` – standard error of the estimate.
        * ``n_obs`` – number of observations.
        * ``t_stat`` – t-statistic for ``treatment``.
        * ``p_value`` – two-sided p-value for ``treatment``.
        * ``rmse`` – root mean squared error of the regression.
        * ``r_squared`` – R² of the regression.

    Examples
    --------
    Regress ``wt`` on ``mpg``, ``am``, and ``vs`` in a toy DataFrame,
    extracting the ``mpg`` coefficient::

        hetset_ols(mtcars, treatment='mpg', formula='wt ~ mpg + am + vs')
    """
    if formula is None:
        if outcome is None:
            raise ValueError(
                "Either 'formula' or 'outcome' must be provided."
            )
        if covariates:
            covariate_str = ' + '.join(covariates)
            formula = f'{outcome} ~ {treatment} + {covariate_str}'
        else:
            formula = f'{outcome} ~ {treatment}'

    m = smf.ols(formula=formula, data=data, **kwargs).fit()

    rmse = np.sqrt(m.mse_resid)

    return pd.DataFrame({
        'estimate': [m.params[treatment]],
        'std_error': [m.bse[treatment]],
        'n_obs': [int(m.nobs)],
        't_stat': [m.tvalues[treatment]],
        'p_value': [m.pvalues[treatment]],
        'rmse': [rmse],
        'r_squared': [m.rsquared],
    })


def estimate_het_effects(data, setting, treatment, outcome=None,
                         covariates=None, formula=None,
                         estimation_function=None,
                         verbose=False, **kwargs):
    """
    Estimate Effects by Setting.

    Estimate the effects of a treatment variable on an outcome variable
    within different settings defined by a set of covariates.

    This function works with a wide range of estimation functions.  By
    default it uses :func:`hetset_ols`, which fits OLS via
    ``statsmodels``.

    Parameters
    ----------
    data : pandas.DataFrame
        Data containing all variables.
    setting : str
        Name of the variable (column) that defines the estimation settings.
    treatment : str
        Name of the treatment variable.
    outcome : str, optional
        Name of the outcome variable.  Required when ``formula`` is not
        provided.
    covariates : list of str, optional
        Names of covariate variables to include as controls.
    formula : str, optional
        A patsy formula string.  If provided, overrides ``outcome`` and
        ``covariates``.  The treatment variable should still be specified
        via ``treatment``.
    estimation_function : callable, optional
        A function compatible with :func:`hetset_ols`'s call signature::

            f(data, treatment, formula=..., outcome=..., covariates=...,
              **kwargs) -> pd.DataFrame

        Defaults to :func:`hetset_ols`.
    verbose : bool, optional
        Print progress messages.  Default is ``False``.
    **kwargs
        Additional arguments forwarded to ``estimation_function``.

    Returns
    -------
    pandas.DataFrame
        Estimated effects by setting.  Always contains columns ``setting``
        and ``failed``; additional columns depend on the estimation
        function.

    Examples
    --------
    ::

        from hetset import estimate_het_effects, load_close_college

        df = load_close_college()
        effects = estimate_het_effects(
            data=df,
            setting='blacksouth',
            treatment='educ',
            outcome='lwage',
            covariates=['smsa', 'married', 'exper'],
        )
    """
    if formula is None and outcome is None:
        raise ValueError("Either 'formula' or 'outcome' must be provided.")

    if estimation_function is None:
        estimation_function = hetset_ols

    results_list = []

    if verbose:
        print("Estimating effects by setting...")

    for s in data[setting].unique():
        if verbose:
            import datetime
            print(f"  Running Setting: {s} at {datetime.datetime.now()}")

        data_s = data[data[setting] == s].copy()

        try:
            if formula is not None:
                estimates_s = estimation_function(
                    data=data_s,
                    treatment=treatment,
                    formula=formula,
                    **kwargs,
                )
            else:
                estimates_s = estimation_function(
                    data=data_s,
                    treatment=treatment,
                    outcome=outcome,
                    covariates=covariates,
                    **kwargs,
                )
        except Exception as exc:
            warnings.warn(f"Estimation failed for setting: {s}.  ({exc})")
            estimates_s = pd.DataFrame({'failed': [True]})

        estimates_s = estimates_s.copy()
        estimates_s['setting'] = s
        results_list.append(estimates_s)

    estimates = pd.concat(results_list, ignore_index=True)

    if 'failed' not in estimates.columns:
        estimates['failed'] = False

    # Reorder columns: setting and failed first
    cols = ['setting', 'failed'] + [
        c for c in estimates.columns if c not in ('setting', 'failed')
    ]
    estimates = estimates[cols]

    return estimates
