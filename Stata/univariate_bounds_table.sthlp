{smcl}
{* *! version 0.1.0  10jun2026}{...}
{viewerjumpto "Syntax" "univariate_bounds_table##syntax"}{...}
{viewerjumpto "Description" "univariate_bounds_table##description"}{...}
{viewerjumpto "Options" "univariate_bounds_table##options"}{...}
{viewerjumpto "Examples" "univariate_bounds_table##examples"}{...}
{viewerjumpto "Stored results" "univariate_bounds_table##results"}{...}
{title:Title}

{phang}
{bf:univariate_bounds_table} {hline 2} Per-setting bounds consistent with all restrictions


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:univariate_bounds_table}{cmd:,}
{opt uni:variate(matname)}
{opt pair:ed(matname)}
[{it:options}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{p2coldent:* {opt uni:variate(matname)}}univariate bounds matrix from {helpb build_bounds} ({cmd:r(univariate)}){p_end}
{p2coldent:* {opt pair:ed(matname)}}paired bounds matrix from {helpb build_bounds} ({cmd:r(paired)}){p_end}
{synopt :{opt pin(speclist)}}pin estimates in some settings to fixed values; see below{p_end}
{synopt :{opt nodis:play}}suppress the displayed table{p_end}
{synoptline}
{p2colreset}{...}
{pstd}* required.  Requires Stata 16 or later.


{marker description}{...}
{title:Description}

{pstd}
{cmd:univariate_bounds_table} creates a table of bounds for the effect in
each setting.

{pstd}
The table shows the widest possible bounds consistent with the assumptions
for each setting one at a time, computed by linear programming over all
univariate and pairwise restrictions produced by {helpb build_bounds}.

{pstd}
Note that because this is a highly multidimensional problem, the actual
identified set of plausible estimates is somewhat narrower.  For example, if
in setting A the effect must be between 0 and 1, in setting B it must be
between 1 and 2, and the difference between them must be no greater than .5,
then the univariate set for A will be .5 to 1 and the set for B will be 1 to
1.5, ignoring that the joint combination (.5 for A, 1.5 for B) is not in the
identified set.

{pstd}
To check whether a specific combination of values is in the identified set,
pin those values with {opt pin()} and run {helpb identified_set_exists}, or
explore with the {opt pin()} option here.


{marker options}{...}
{title:Options}

{phang}
{opt univariate(matname)} and {opt paired(matname)} name the matrices
returned by {helpb build_bounds} in {cmd:r(univariate)} and {cmd:r(paired)}.
Both are required.

{phang}
{opt pin(speclist)} pins the estimates in some settings to fixed values
before computing the bounds for the remaining settings.  Each element of
{it:speclist} has the form {it:setting}{cmd:=}{it:value}, where {it:value}
is a number or one of {cmd:lower}, {cmd:upper}, or {cmd:original} (the
univariate lower bound, upper bound, or original point estimate for that
setting, respectively).  Elements whose setting name contains spaces or an
equals sign in the name must be enclosed in quotes, for example
{cmd:pin("Black and South=lower")}.  Useful for exploring the multivariate
nature of the bounds.

{phang}
{opt nodisplay} suppresses the displayed table.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. use close_college, clear}{p_end}
{phang2}{cmd:. ovb_bounds_by_setting lwage educ smsa married exper, setting(blacksouth) treatment(educ) benchmark(smsa married exper) kd(.1)}{p_end}
{phang2}{cmd:. matrix bnds = r(bounds)}{p_end}
{phang2}{cmd:. matrix boundmat = (0, 2, 1.5, 0 \ 0, 0, 0, 1.5 \ 0, 0, 0, 2 \ 0, 0, 0, 0)}{p_end}
{phang2}{cmd:. build_bounds, bounds(bnds) rho(boundmat) order(Neither Black South "Black and South")}{p_end}
{phang2}{cmd:. matrix uni = r(univariate)}{p_end}
{phang2}{cmd:. matrix prd = r(paired)}{p_end}

{pstd}Get the univariate bounds table.  Note in this example that the bounds
are only very slightly tighter than if we hadn't worried about cross-setting
relationships (for Black).{p_end}
{phang2}{cmd:. univariate_bounds_table, univariate(uni) paired(prd)}{p_end}

{pstd}Pin the estimate for Neither at its upper bound and see how the other
settings' bounds tighten{p_end}
{phang2}{cmd:. univariate_bounds_table, univariate(uni) paired(prd) pin(Neither=upper)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:univariate_bounds_table} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_settings)}}number of settings{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(settings)}}setting names, in row order of {cmd:r(table)}{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}one row per setting with columns {cmd:estimate},
{cmd:lower_bound}, {cmd:upper_bound}, {cmd:lower_nu_bound},
{cmd:upper_nu_bound}, {cmd:original_lower_bound},
{cmd:original_upper_bound}{p_end}
{p2colreset}{...}


{title:Also see}

{psee}
Help:  {helpb hetset}, {helpb build_bounds}, {helpb identified_set_exists}
{p_end}
