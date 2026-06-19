{smcl}
{* *! version 0.1.0  10jun2026}{...}
{viewerjumpto "Description" "hetset##description"}{...}
{viewerjumpto "Workflow" "hetset##workflow"}{...}
{viewerjumpto "Commands" "hetset##commands"}{...}
{viewerjumpto "Requirements" "hetset##requirements"}{...}
{viewerjumpto "Example" "hetset##examples"}{...}
{viewerjumpto "References" "hetset##references"}{...}
{viewerjumpto "Author" "hetset##author"}{...}
{title:Title}

{phang}
{bf:hetset} {hline 2} Partial identification of heterogeneous treatment effects across settings


{marker description}{...}
{title:Description}

{pstd}
The {bf:hetset} package implements the partial identification framework of
Huntington-Klein (2026) for causal effects that vary heterogeneously across
settings (subgroups), while accounting for omitted variable bias using
sensitivity analysis.

{pstd}
The key idea: the treatment effect is estimated separately in each setting
defined by a categorical variable.  Each setting's estimate is subject to
omitted variable bias, and {help sensemakr} (Cinelli, Ferwerda, and Hazlett
2020) is used to produce a plausible interval for each setting's true effect.
On top of these univariate intervals, the researcher places bounds on
{it:rho}, the proportional relationship between the omitted variable bias in
one setting and the bias in another.  Together these restrictions define an
identified set for the vector of true effects, which can be checked for
feasibility and summarized using linear programming.

{pstd}
This is a Stata port of the R package {bf:hetset}; commands carry the same
names as the corresponding R functions.


{marker workflow}{...}
{title:Workflow}

{phang2}1.  Estimate per-setting effects with plausibility intervals using
{helpb ovb_bounds_by_setting} (or supply your own intervals with
{helpb custom_ovb_bounds_by_setting}).{p_end}

{phang2}2.  Choose bounds on rho for each pair of settings, either by hand
(as a matrix) or data-driven via {helpb supershort_rho_bounds_proposal}.{p_end}

{phang2}3.  Combine the univariate intervals and the rho bounds into a full
bounds set with {helpb build_bounds}.{p_end}

{phang2}4.  Check whether any vector of effects satisfies all bounds with
{helpb identified_set_exists}, and summarize the per-setting bounds implied
by all restrictions jointly with {helpb univariate_bounds_table}.{p_end}


{marker commands}{...}
{title:Commands}

{p2colset 5 36 38 2}{...}
{p2col :{helpb ovb_bounds_by_setting}}per-setting effects with omitted variable bias bounds via {cmd:sensemakr}{p_end}
{p2col :{helpb custom_ovb_bounds_by_setting}}build a bounds table from user-supplied numbers{p_end}
{p2col :{helpb supershort_rho_bounds_proposal}}data-driven proposal for rho bounds via model comparison{p_end}
{p2col :{helpb build_bounds}}combine univariate and cross-setting bounds into a full bounds set{p_end}
{p2col :{helpb identified_set_exists}}check whether the identified set is non-empty{p_end}
{p2col :{helpb univariate_bounds_table}}per-setting bounds consistent with all restrictions{p_end}
{p2col :{helpb estimate_het_effects}}simple per-setting treatment effect estimation{p_end}
{p2col :{helpb c_bounds}}the C set bounding the difference between two effects{p_end}
{p2col :{helpb close_college}}description of the included example dataset{p_end}
{p2colreset}{...}

{pstd}
The R package's {cmd:ovb_bounds_by_setting_dml()} function relies on the
R-only {cmd:dml.sensemakr} package and is not included in this port.


{marker requirements}{...}
{title:Requirements}

{phang2}- The {bf:sensemakr} package from SSC is required by
{cmd:ovb_bounds_by_setting}:  {stata "ssc install sensemakr":ssc install sensemakr}{p_end}

{phang2}- {cmd:identified_set_exists} and {cmd:univariate_bounds_table}
require Stata 16 or later (they use the Mata {helpb mf_LinearProgram:LinearProgram()}
class).  All other commands require Stata 14 or later.{p_end}

{phang2}- The example dataset {cmd:close_college.dta} is an ancillary
file.  Install it to the current directory with
{cmd:ssc install hetset, all} or {cmd:net get hetset}.{p_end}


{marker examples}{...}
{title:Example}

{phang2}{cmd:. use close_college, clear}{p_end}

{phang2}{cmd:. ovb_bounds_by_setting lwage educ smsa married exper, setting(blacksouth) treatment(educ) benchmark(smsa married exper) kd(.1)}{p_end}
{phang2}{cmd:. matrix bnds = r(bounds)}{p_end}

{phang2}{cmd:. * 1.5 bound on Black vs Black & South and Neither vs South,}{p_end}
{phang2}{cmd:. * 2 on Neither vs Black and South vs Black & South,}{p_end}
{phang2}{cmd:. * no restriction (0) on Neither vs Black & South and Black vs South}{p_end}
{phang2}{cmd:. matrix boundmat = (0, 2, 1.5, 0 \ 0, 0, 0, 1.5 \ 0, 0, 0, 2 \ 0, 0, 0, 0)}{p_end}

{phang2}{cmd:. build_bounds, bounds(bnds) rho(boundmat) order(Neither Black South "Black and South")}{p_end}
{phang2}{cmd:. matrix uni = r(univariate)}{p_end}
{phang2}{cmd:. matrix prd = r(paired)}{p_end}

{phang2}{cmd:. identified_set_exists, univariate(uni) paired(prd)}{p_end}
{phang2}{cmd:. identified_set_exists, univariate(uni) paired(prd) solution}{p_end}

{phang2}{cmd:. univariate_bounds_table, univariate(uni) paired(prd)}{p_end}


{marker references}{...}
{title:References}

{phang}
Huntington-Klein, N.  2026.
{it:Partial Identification of Heterogeneous Treatment Effects across Settings}.
arXiv:2605.25483.  {browse "https://arxiv.org/abs/2605.25483"}

{phang}
Cinelli, C., and C. Hazlett.  2020.  Making sense of sensitivity: Extending
omitted variable bias.  {it:Journal of the Royal Statistical Society, Series B}
82(1): 39-67.

{phang}
Cinelli, C., J. Ferwerda, and C. Hazlett.  2020.  sensemakr: Sensitivity
analysis tools for OLS in R and Stata.
{browse "https://econpapers.repec.org/software/bocbocode/s458773.htm"}


{marker author}{...}
{title:Author}

{pstd}
Nick Huntington-Klein{break}
Seattle University{break}
nhuntington-klein@seattleu.edu


{title:Also see}

{psee}
SSC:  {helpb sensemakr} (if installed)
{p_end}
