"""
hetset
======
Partial Identification of Heterogeneous Treatment Effects across Settings.

Python port of the R ``hetset`` package (Huntington-Klein, 2025).

This package allows for the partial identification of causal effects that
vary heterogeneously across settings.  The core workflow is:

1. **Estimate per-setting OVB bounds** using
   :func:`ovb_bounds_by_setting`, which wraps
   ``PySensemakr``'s ``ovb_bounds`` function.

2. **Propose rho bounds** using
   :func:`supershort_rho_bounds_proposal`, which suggests bounds on the
   proportional relationship between omitted-variable biases across
   settings by comparing a full model to a shorter one.

3. **Build the full bounds set** using :func:`build_bounds`, combining
   the univariate OVB intervals with the cross-setting rho constraints.

4. **Analyse the identified set** using
   :func:`identified_set_exists` (feasibility check) and
   :func:`univariate_bounds_table` (per-setting LP bounds).

Key differences from the R package
-----------------------------------
* OLS is performed via ``statsmodels`` (``smf.ols``) rather than
  ``fixest::feols``.  Formula syntax follows ``patsy`` conventions.
* ``PySensemakr`` is used in place of the R ``sensemakr`` package.
* The ``ovb_bounds_by_setting_dml`` function (which requires the R-only
  ``dml.sensemakr`` package) is **not** included in this port.
* Formula arguments that were full model-call strings in R (e.g.
  ``'fixest::feols(y ~ x, data = data)'``) are now plain patsy formula
  strings (e.g. ``'y ~ x'``).
* The LP solver is ``scipy.optimize.linprog`` (HiGHS backend) rather than
  ``Rglpk``.

Dependencies
------------
Required:
    pandas, numpy, scipy, statsmodels

Optional (needed for :func:`ovb_bounds_by_setting`):
    PySensemakr (``pip install PySensemakr``)

Optional (needed for :func:`load_close_college` from .rda):
    pyreadr (``pip install pyreadr``)

References
----------
Huntington-Klein, N. (2025). *Partial Identification of Heterogeneous
Treatment Effects across Settings*.
"""

from .helpers import c_bounds
from .effect_estimate import estimate_het_effects, hetset_ols
from .effect_estimate_sensemakr import ovb_bounds_by_setting, custom_ovb_bounds_by_setting
from .effect_sets import (
    build_bounds,
    identified_set_exists,
    univariate_bounds_table,
)
from .bias_relationship_bounds import supershort_rho_bounds_proposal
from .data import load_close_college

__all__ = [
    # Core workflow
    'ovb_bounds_by_setting',
    'custom_ovb_bounds_by_setting',
    'supershort_rho_bounds_proposal',
    'build_bounds',
    'identified_set_exists',
    'univariate_bounds_table',
    # Generic effect estimation
    'estimate_het_effects',
    'hetset_ols',
    # Utility
    'c_bounds',
    # Data
    'load_close_college',
]

__version__ = '0.1.0'
__author__ = 'Nick Huntington-Klein'
