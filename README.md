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

The Stata package can be installed once available with:

```stata
* Or for the dev version (currently identical)
net install causaldata, from("https://raw.githubusercontent.com/NickCH-K/hetset/master/Stata/")
```

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
