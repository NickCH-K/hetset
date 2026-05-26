"""
setup.py — hetset Python package
"""

from setuptools import setup, find_packages

setup(
    name='hetset',
    version='0.1.0',
    author='Nick Huntington-Klein',
    author_email='nhuntington-klein@seattleu.edu',
    description=(
        'Partial Identification of Heterogeneous Treatment Effects '
        'across Settings'
    ),
    long_description=(
        'Python port of the hetset R package. Allows for the partial '
        'identification of causal effects that vary heterogeneously across '
        'settings, as in Huntington-Klein (2025). Uses statsmodels for '
        'regression and PySensemakr for sensitivity analysis.'
    ),
    license='MIT',
    packages=find_packages(),
    python_requires='>=3.8',
    install_requires=[
        'numpy',
        'pandas',
        'scipy',
        'statsmodels',
    ],
    extras_require={
        'sensemakr': ['PySensemakr'],
        'data': ['pyreadr'],
        'all': ['PySensemakr', 'pyreadr'],
    },
    package_data={
        'hetset': ['close_college.csv'],
    },
    classifiers=[
        'Development Status :: 3 - Alpha',
        'Intended Audience :: Science/Research',
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Python :: 3',
        'Topic :: Scientific/Engineering :: Mathematics',
    ],
)
