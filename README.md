# hetset
R, Python, and Stata packages to implement Partial Identification of Causal Effects that Vary by Setting

## R

The R package can be installed with:

```r
# dev version 
# If necessary: install.packages('remotes')
remotes::install_github('NickCH-K/hetset/RVersion/')
```

## Stata

The Stata package can be installed with:

```stata
net install causaldata, from("https://raw.githubusercontent.com/NickCH-K/hetset/master/Stata/")
```

**Note that the Stata version is an almost purely AI-translated version of the R package. It has been tested to ensure it matches the output of other packages but is not human-written.**

## Python

To install the Python package, do

```python
pip install hetset
```

For the dev version (currently identical), use the green Code button on this page to [download this repository](https://github.com/NickCH-K/hetset/archive/refs/heads/main.zip), unzip it, change the directory to the `causaldata/Python` folder, and install with:

```python
python setup.py install
```

Or, if you're using something with IPython like Spyder, you might use

```python
runfile('the/full/path/to/hetset/Python/setup.py', wdir='your/working/directory',args='install')
```

**Note that the Python version is an largely (but not entirely) AI-translated version of the R package. It has been tested to ensure it matches the output of other packages but is mostly not human-written.**