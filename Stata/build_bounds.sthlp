{smcl}
{* *! version 0.1.0  10jun2026}{...}
{viewerjumpto "Syntax" "build_bounds##syntax"}{...}
{viewerjumpto "Description" "build_bounds##description"}{...}
{viewerjumpto "Options" "build_bounds##options"}{...}
{viewerjumpto "Remarks" "build_bounds##remarks"}{...}
{viewerjumpto "Examples" "build_bounds##examples"}{...}
{viewerjumpto "Stored results" "build_bounds##results"}{...}
{title:Title}

{phang}
{bf:build_bounds} {hline 2} Build the full set of bounds for effect pairs


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:build_bounds}{cmd:,}
{opt bo:unds(matname)}
{opt rho(matname|#)}
[{it:options}]

{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{p2coldent:* {opt bo:unds(matname)}}per-setting bounds matrix, from {helpb ovb_bounds_by_setting} or {helpb custom_ovb_bounds_by_setting}{p_end}
{p2coldent:* {opt rho(matname|#)}}matrix of rho bounds, or a single positive value applied to all pairs{p_end}
{synopt :{opt or:der(namelist)}}setting names in the order used by the rows/columns of {opt rho()}; default is the row order of {opt bounds()}{p_end}
{synopt :{opt nodis:play}}suppress the displayed tables{p_end}
{synoptline}
{p2colreset}{...}
{pstd}* required.  Setting names containing spaces must be enclosed in
quotes within {opt order()}.


{marker description}{...}
{title:Description}

{pstd}
{cmd:build_bounds} combines per-setting plausibility intervals with
cross-setting rho constraints to produce the complete bounds structure used
by {helpb identified_set_exists} and {helpb univariate_bounds_table}.

{pstd}
The {opt bounds()} matrix must contain columns named
{cmd:original_estimate}, {cmd:lower_plausible_bound}, and
{cmd:upper_plausible_bound}, with one row per setting (row names identify
the settings).  Other columns are acceptable and ignored.

{pstd}
If {opt rho()} is a matrix, element [{it:i},{it:j}] with {it:i} < {it:j}
holds the {it:upper} bound on rho for the pair of settings
({it:i},{it:j}), and element [{it:j},{it:i}] holds the corresponding
{it:lower} bound, where settings are numbered according to {opt order()}.
Diagonal values are ignored.  Set an element to 0 (or missing) to impose no
restriction on that pair.  If {it:all} lower-triangle values are 0 or
missing, the lower bounds are automatically set to the inverse of the
corresponding upper bounds.

{pstd}
If {opt rho()} is a single real value, that value is used as the upper
bound for every pair and its inverse as the lower bound.


{marker options}{...}
{title:Options}

{phang}
{opt bounds(matname)} names a matrix containing the partial identification
bounds for each individual setting's effect, such as {cmd:r(bounds)} from
{helpb ovb_bounds_by_setting}.  Required.

{phang}
{opt rho(matname|#)} provides the bounds on rho, the proportional
relationship of omitted variable bias between pairs of settings.  Required.

{phang}
{opt order(namelist)} lists the setting names in the order in which they
appear in the rows and columns of the {opt rho()} matrix.  Defaults to the
row order of {opt bounds()}.  Names may be given in their original form
(quoted if they contain spaces) or in the sanitized form used for matrix
row names (spaces replaced by underscores).

{phang}
{opt nodisplay} suppresses the displayed tables.


{marker remarks}{...}
{title:Remarks}

{pstd}
The R version of this function represents unrestricted pairs as
plus/minus infinity in the paired bounds.  Stata matrices cannot store
infinity, so unrestricted pair bounds are stored as missing ({cmd:.})
instead; downstream commands treat missing pair bounds as unrestricted.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. use close_college, clear}{p_end}
{phang2}{cmd:. ovb_bounds_by_setting lwage educ smsa married exper, setting(blacksouth) treatment(educ) benchmark(smsa married exper) kd(.1)}{p_end}
{phang2}{cmd:. matrix bnds = r(bounds)}{p_end}

{pstd}Put a 1.5 bound on Black vs Black & South and Neither vs South,
2 on Neither vs Black and South vs Black & South, and no restriction on
Neither vs Black & South and on Black vs South (setting those to 0).
Leaving all lower-triangle values at 0 makes them automatically the inverse
of the upper-triangle values.{p_end}
{phang2}{cmd:. matrix boundmat = (0, 2, 1.5, 0 \ 0, 0, 0, 1.5 \ 0, 0, 0, 2 \ 0, 0, 0, 0)}{p_end}
{phang2}{cmd:. build_bounds, bounds(bnds) rho(boundmat) order(Neither Black South "Black and South")}{p_end}
{phang2}{cmd:. matrix uni = r(univariate)}{p_end}
{phang2}{cmd:. matrix prd = r(paired)}{p_end}

{pstd}A single bound of 2 on every pair{p_end}
{phang2}{cmd:. build_bounds, bounds(bnds) rho(2)}{p_end}

{pstd}Using a data-driven rho proposal{p_end}
{phang2}{cmd:. supershort_rho_bounds_proposal lwage educ smsa married exper, setting(blacksouth) treatment(educ) order(Neither Black South "Black and South")}{p_end}
{phang2}{cmd:. matrix rb = r(rho_bounds)}{p_end}
{phang2}{cmd:. build_bounds, bounds(bnds) rho(rb) order(Neither Black South "Black and South")}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:build_bounds} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_settings)}}number of settings{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(settings)}}setting names, in the order used{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(univariate)}}one row per setting with columns {cmd:estimate},
{cmd:lower}, {cmd:upper}, {cmd:lower_nu}, {cmd:upper_nu}{p_end}
{synopt:{cmd:r(paired)}}square matrix of paired bounds on bias differences;
element [{it:i},{it:j}] with {it:i} < {it:j} is the upper bound on
nu_{it:i} - nu_{it:j} and [{it:j},{it:i}] is the lower bound; missing means
unrestricted{p_end}
{p2colreset}{...}


{title:Also see}

{psee}
Help:  {helpb hetset}, {helpb ovb_bounds_by_setting},
{helpb identified_set_exists}, {helpb univariate_bounds_table},
{helpb supershort_rho_bounds_proposal}
{p_end}
