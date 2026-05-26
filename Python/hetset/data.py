"""
data.py
-------
Dataset loading utilities for the hetset package.

Provides :func:`load_close_college`, which loads the Card (1995) dataset
used in the package examples.
"""

import os
import warnings


def load_close_college():
    """
    Load the close_college dataset.

    Data from Card (1995) via the National Longitudinal Survey Young Men
    Cohort, used to estimate the effect of college education on earnings
    using nearby-college presence as an instrument.

    This dataset is drawn from the ``causaldata`` R package (as used in
    *Causal Inference: The Mixtape* by Cunningham), augmented with a
    ``blacksouth`` column that cross-tabulates ``black`` and ``south``
    into four categories.

    The function attempts, in order:

    1. Load ``close_college.csv`` from the same directory as this file
       (present if you obtained hetset as a Python package with bundled
       data).
    2. Load ``close_college.rda`` from the sibling ``RVersion/data/``
       folder (present if you are working from the hetset source tree)
       using the ``pyreadr`` package.
    3. Raise an informative ``FileNotFoundError`` with instructions.

    Returns
    -------
    pandas.DataFrame
        3010 rows × 9 columns:

        * ``lwage`` – log wages.
        * ``educ`` – years of education.
        * ``exper`` – years of work experience.
        * ``black`` – race indicator (Black).
        * ``south`` – southern United States indicator.
        * ``blacksouth`` – factor with four levels combining ``black`` and
          ``south`` (``'Neither'``, ``'Black'``, ``'South'``,
          ``'Black and South'``).
        * ``married`` – is married indicator.
        * ``smsa`` – in a Standard Metropolitan Statistical Area.
        * ``nearc4`` – four-year college in the county indicator.

    References
    ----------
    Card, David. 1995. "Aspects of Labour Economics: Essays in Honour of
    John Vanderkamp." University of Toronto Press.

    Cunningham. 2021. *Causal Inference: The Mixtape*. Yale Press.
    https://mixtape.scunning.com/

    Examples
    --------
    ::

        from hetset import load_close_college
        df = load_close_college()
        print(df.shape)   # (3010, 9)
    """
    import pandas as pd

    # --- Attempt 1: bundled CSV ------------------------------------------
    _here = os.path.dirname(os.path.abspath(__file__))
    csv_path = os.path.join(_here, 'close_college.csv')
    if os.path.isfile(csv_path):
        return pd.read_csv(csv_path)

    # --- Attempt 2: RVersion .rda via pyreadr ----------------------------
    rda_path = os.path.join(_here, '..', '..', 'RVersion', 'data',
                            'close_college.rda')
    rda_path = os.path.normpath(rda_path)
    if os.path.isfile(rda_path):
        try:
            import pyreadr
            result = pyreadr.read_r(rda_path)
            df = result['close_college']
            return df
        except ImportError:
            warnings.warn(
                "Found close_college.rda but pyreadr is not installed. "
                "Install pyreadr (`pip install pyreadr`) to load it, or "
                "provide a close_college.csv in the hetset package folder."
            )

    # --- Attempt 3: informative error ------------------------------------
    raise FileNotFoundError(
        "Could not locate the close_college dataset.  Options:\n"
        "  1. Install pyreadr (`pip install pyreadr`) — the RVersion .rda\n"
        "     file will be loaded automatically if you are in the hetset\n"
        "     source tree.\n"
        "  2. Place a close_college.csv file in the hetset package folder\n"
        "     (same directory as this data.py file).\n"
        "  3. Load the data manually from the R causaldata package.\n"
        "     The 'blacksouth' column combines 'black' and 'south' into:\n"
        "     'Neither', 'Black', 'South', 'Black and South'."
    )
