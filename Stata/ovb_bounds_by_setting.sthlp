{smcl}
{* *! version 0.1.0  10jun2026}{...}
{viewerjumpto "Syntax" "ovb_bounds_by_setting##syntax"}{...}
{viewerjumpto "Description" "ovb_bounds_by_setting##description"}{...}
{viewerjumpto "Options" "ovb_bounds_by_setting##options"}{...}
{viewerjumpto "Remarks" "ovb_bounds_by_setting##remarks"}{...}
{viewerjumpto "Examples" "ovb_bounds_by_setting##examples"}{...}
{viewerjumpto "Stored results" "ovb_bounds_by_setting##results"}{...}
{title:Title}

{phang}
{bf:ovb_bounds_by_setting} {hline 2} Estimate partial identification effects by setting with sensemakr


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:ovb_bounds_by_setting}
{depvar} {indepvars}
{ifin}{cmd:,}
{opth set:ting(varname)}
{opth treat:ment(varname)}
{opth bench:mark(varlist)}
[{it:options}]

{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{p2coldent:* {opth set:ting(varname)}}variable defining the estimation settings (subgroups){p_end}
{p2coldent:* {opth treat:ment(varname)}}treatment variable; must appear among {it:indepvars}{p_end}
{p2coldent:* {opth bench:mark(varlist)}}benchmark covariates used to bound the strength of confounding{p_end}
{synopt :{opt kd(#)}}confounder strength relative to the benchmark covariates in explaining the treatment; default is {cmd:kd(1)}{p_end}
{synopt :{opt ky(#)}}confounder strength relative to the benchmark covariates in explaining the outcome; default is the value of {opt kd()}{p_end}
{synopt :{opt v:erbose}}display progress messages{p_end}
{synoptline}
{p2colreset}{...}
{pstd}* required.  {it:indepvars} and {opt benchmark()} may contain factor and
time-series operators.  Requires the {bf:sensemakr} package from SSC.


{marker description}{...}
{title:Description}

{pstd}
{cmd:ovb_bounds_by_setting} estimates the effect of the treatment variable on
{depvar} separately within each level of the {opt setting()} variable, using
linear regression of {depvar} on {it:indepvars}.  For each setting it then
computes a partial identification (plausibility) interval for the true effect
using {helpb sensemakr}, based on a hypothetical confounder {opt kd()} times
as strong as the {opt benchmark()} covariates in explaining residual
treatment variation, and {opt ky()} times as strong in explaining residual
outcome variation.

{pstd}
When more than one benchmark covariate is supplied, the covariates are
benchmarked jointly as a single group (named {it:Total}), matching the
behavior of the R package, which calls {cmd:sensemakr::ovb_bounds()} with a
grouped benchmark.

{pstd}
The resulting plausible interval for each setting is symmetric around the
original estimate:  {it:original} +/- |{it:original} - {it:adjusted}|, where
{it:adjusted} is the sensemakr bias-adjusted estimate.  The output is
returned in {cmd:r(bounds)} in the format expected by the {opt bounds()}
option of {helpb build_bounds}.


{marker options}{...}
{title:Options}

{phang}
{opth setting(varname)} specifies a numeric or string variable whose values
define the estimation settings.  The model is estimated separately within
each level.  If the variable is numeric and has value labels, the labels are
used as the setting names.  Required.

{phang}
{opth treatment(varname)} specifies the treatment variable whose effect is
of interest.  It must appear among the regressors.  Required.

{phang}
{opth benchmark(varlist)} specifies the observed covariates used to bound
the plausible strength of unobserved confounding, as in
{cmd:sensemakr}'s {opt benchmark()} and {opt gbenchmark()} options.
Required.

{phang}
{opt kd(#)} parameterizes how many times stronger the hypothetical
confounder is related to the treatment in comparison to the benchmark
covariates.  Default is {cmd:kd(1)}.

{phang}
{opt ky(#)} parameterizes how many times stronger the hypothetical
confounder is related to the outcome in comparison to the benchmark
covariates.  Default is the value of {opt kd()}.

{phang}
{opt verbose} displays a progress message for each setting.


{marker remarks}{...}
{title:Remarks}

{pstd}
Settings are processed in sorted order of the {opt setting()} variable's
values (the order reported by {helpb levelsof}); this is the row order of
{cmd:r(bounds)}.

{pstd}
If estimation fails in a setting (for example, too few observations), a
warning is displayed, the {cmd:failed} column of {cmd:r(bounds)} is set to 1
for that setting, and the remaining values are missing.
{helpb build_bounds} will refuse to use settings with missing bounds.

{pstd}
A common cause of failure is the {cmd:sensemakr} error
{bf:"Impossible value. Try a lower kd and/or ky"} (or a message about an
implied R-squared greater than 1).  This occurs when the {opt benchmark()}
covariates are too strong relative to the chosen {opt kd()}/{opt ky()}: the
implied strength of a confounder {opt kd()} times as strong as the benchmark
would exceed 1, which is impossible for an R-squared.  When this happens,
{cmd:ovb_bounds_by_setting} re-runs {cmd:sensemakr} for the offending setting
and echoes its message, then advises re-running with a smaller {opt kd()}
and/or {opt ky()}.  The documentation examples use {cmd:kd(.1)} for exactly
this reason.

{pstd}
Setting names are sanitized to legal matrix row names in {cmd:r(bounds)}
(for example, {it:Black and South} becomes {it:Black_and_South}).
Downstream {cmd:hetset} commands accept either form.

{pstd}
{cmd:ovb_bounds_by_setting} calls {cmd:sensemakr}, which replaces any
current {cmd:e()} estimation results; your previous {cmd:e()} results are
held and restored, but estimates stored by {cmd:sensemakr} itself under the
names {cmd:main_model} and {cmd:treat_model} will remain in the estimates
store.


{marker examples}{...}
{title:Examples}

{pstd}Setup, using the example data shipped with the package
({stata "ssc install hetset, all":ssc install hetset, all} downloads it){p_end}
{phang2}{cmd:. use close_college, clear}{p_end}

{pstd}Bounds based on a confounder one-tenth as strong as smsa, married,
and exper combined{p_end}
{phang2}{cmd:. ovb_bounds_by_setting lwage educ smsa married exper, setting(blacksouth) treatment(educ) benchmark(smsa married exper) kd(.1)}{p_end}
{phang2}{cmd:. matrix bnds = r(bounds)}{p_end}
{phang2}{cmd:. matlist bnds}{p_end}

{pstd}Alternatively, the data can be obtained through the {bf:causaldata}
package (SSC), constructing the setting variable by hand{p_end}
{phang2}{cmd:. causaldata close_college.dta, use clear download}{p_end}
{phang2}{cmd:. generate blacksouth = "Neither"}{p_end}
{phang2}{cmd:. replace blacksouth = "Black" if black & !south}{p_end}
{phang2}{cmd:. replace blacksouth = "South" if !black & south}{p_end}
{phang2}{cmd:. replace blacksouth = "Black and South" if black & south}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:ovb_bounds_by_setting} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_settings)}}number of settings{p_end}
{synopt:{cmd:r(kd)}}value of kd used{p_end}
{synopt:{cmd:r(ky)}}value of ky used{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(treatment)}}name of the treatment variable{p_end}
{synopt:{cmd:r(setting)}}name of the setting variable{p_end}
{synopt:{cmd:r(settings)}}setting names, in row order of {cmd:r(bounds)}{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(bounds)}}one row per setting with columns {cmd:failed},
{cmd:kd}, {cmd:ky}, {cmd:r2dz_x}, {cmd:r2yz_dx}, {cmd:adjusted_estimate},
{cmd:adjusted_se}, {cmd:adjusted_t}, {cmd:adjusted_lower_CI},
{cmd:adjusted_upper_CI}, {cmd:original_estimate},
{cmd:lower_plausible_bound}, {cmd:upper_plausible_bound}, {cmd:lower_nu},
{cmd:upper_nu}{p_end}
{p2colreset}{...}


{title:Also see}

{psee}
Help:  {helpb hetset}, {helpb build_bounds}, {helpb custom_ovb_bounds_by_setting},
{helpb supershort_rho_bounds_proposal}, {helpb sensemakr} (if installed)
{p_end}
