{smcl}
{* *! version 0.1.0  10jun2026}{...}
{viewerjumpto "Syntax" "supershort_rho_bounds_proposal##syntax"}{...}
{viewerjumpto "Description" "supershort_rho_bounds_proposal##description"}{...}
{viewerjumpto "Options" "supershort_rho_bounds_proposal##options"}{...}
{viewerjumpto "Examples" "supershort_rho_bounds_proposal##examples"}{...}
{viewerjumpto "Stored results" "supershort_rho_bounds_proposal##results"}{...}
{title:Title}

{phang}
{bf:supershort_rho_bounds_proposal} {hline 2} Propose a set of rho bounds


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:supershort_rho_bounds_proposal}
{depvar} {indepvars}
{ifin}{cmd:,}
{opth set:ting(varname)}
{opth treat:ment(varname)}
[{it:options}]

{synoptset 26 tabbed}{...}
{synopthdr}
{synoptline}
{p2coldent:* {opth set:ting(varname)}}variable defining the estimation settings{p_end}
{p2coldent:* {opth treat:ment(varname)}}treatment variable; must appear among {it:indepvars}{p_end}
{synopt :{opth short:er(varlist)}}regressors of the super-short model; default is the treatment variable alone{p_end}
{synopt :{opt useneg:ative}}treat pairs whose bias changes have opposite signs as informative anyway{p_end}
{synopt :{opt minimum_bound(#)}}floor (> 1) applied to the proposed rho lower bounds{p_end}
{synopt :{opt maximum_bound(#)}}ceiling (> 1) applied to the proposed rho upper bounds{p_end}
{synopt :{opt or:der(namelist)}}setting names in the desired matrix order; default is sorted order{p_end}
{synopt :{opt v:erbose}}display per-setting estimates{p_end}
{synoptline}
{p2colreset}{...}
{pstd}* required.


{marker description}{...}
{title:Description}

{pstd}
{cmd:supershort_rho_bounds_proposal} suggests a plausible bound for rho, the
proportional parameter relating the omitted variable bias in setting A with
the omitted variable bias in setting B.

{pstd}
This bound is based on taking the estimation model (which is already missing
some predictors, since we have omitted variable bias) and omitting more
variables.  Within each setting, the full model {hline 2} a regression of
{depvar} on {it:indepvars} {hline 2} and a "super-short" model {hline 2} a
regression of {depvar} on the {opt shorter()} variables only {hline 2} are
both estimated.  The change in the treatment coefficient is the omitted
variable bias added by the further removal of predictors.  For each pair of
settings, the ratio of these changes (taken in both directions) gives the
proposed lower and upper bounds on rho.


{marker options}{...}
{title:Options}

{phang}
{opth setting(varname)} specifies the variable defining the estimation
settings.  Required.

{phang}
{opth treatment(varname)} specifies the treatment variable.  It must appear
among the regressors of both the full and the super-short model.  Required.

{phang}
{opth shorter(varlist)} specifies the regressors of the super-short model.
It must include the treatment variable, and it should omit the predictors
that are dropped to create the super-short comparison.  The default is the
treatment variable alone.

{phang}
{opt usenegative} treats pairs of settings whose bias changes have opposite
signs as informative anyway.  By default such pairs are considered
uninformative and their rho bounds are left unrestricted (missing).  This
corresponds to {cmd:negative_is_uninformative = FALSE} in the R package.

{phang}
{opt minimum_bound(#)} specifies a number greater than 1.  All proposed
(non-missing) rho lower bounds below {it:#} are raised to {it:#}.

{phang}
{opt maximum_bound(#)} specifies a number greater than 1.  All proposed
(non-missing) rho upper bounds above {it:#} are lowered to {it:#}.
Uninformative bounds are not adjusted.

{phang}
{opt order(namelist)} lists the setting names in the order to be used for
the rows and columns of the returned matrix.  Defaults to sorted order.
Names containing spaces must be enclosed in quotes.

{phang}
{opt verbose} displays the full and super-short estimates for each setting.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. use close_college, clear}{p_end}
{phang2}{cmd:. ovb_bounds_by_setting lwage educ smsa married exper, setting(blacksouth) treatment(educ) benchmark(smsa married exper) kd(.1)}{p_end}
{phang2}{cmd:. matrix bnds = r(bounds)}{p_end}

{pstd}Propose rho bounds by comparing the full model to a regression of
lwage on educ alone{p_end}
{phang2}{cmd:. supershort_rho_bounds_proposal lwage educ smsa married exper, setting(blacksouth) treatment(educ) order(Neither Black South "Black and South")}{p_end}
{phang2}{cmd:. matrix rb = r(rho_bounds)}{p_end}

{pstd}Get the partial identification bounds and the univariate bounds table{p_end}
{phang2}{cmd:. build_bounds, bounds(bnds) rho(rb) order(Neither Black South "Black and South")}{p_end}
{phang2}{cmd:. matrix uni = r(univariate)}{p_end}
{phang2}{cmd:. matrix prd = r(paired)}{p_end}
{phang2}{cmd:. univariate_bounds_table, univariate(uni) paired(prd)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:supershort_rho_bounds_proposal} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_settings)}}number of settings{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(settings)}}setting names, in matrix order{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(rho_bounds)}}square rho bounds matrix suitable for the
{opt rho()} option of {helpb build_bounds}; upper bounds above the
diagonal, lower bounds below; missing = unrestricted{p_end}
{synopt:{cmd:r(table)}}one row per setting pair with columns
{cmd:rho_low} and {cmd:rho_high}{p_end}
{p2colreset}{...}

{pstd}
Note: the R version represents uninformative pairs as plus/minus infinity;
in Stata they are represented as missing values, which
{helpb build_bounds} treats as unrestricted.


{title:Also see}

{psee}
Help:  {helpb hetset}, {helpb build_bounds}, {helpb ovb_bounds_by_setting}
{p_end}
