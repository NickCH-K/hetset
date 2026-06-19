{smcl}
{* *! version 0.1.0  10jun2026}{...}
{viewerjumpto "Syntax" "identified_set_exists##syntax"}{...}
{viewerjumpto "Description" "identified_set_exists##description"}{...}
{viewerjumpto "Options" "identified_set_exists##options"}{...}
{viewerjumpto "Examples" "identified_set_exists##examples"}{...}
{viewerjumpto "Stored results" "identified_set_exists##results"}{...}
{title:Title}

{phang}
{bf:identified_set_exists} {hline 2} Check for the existence of an identified set satisfying all bounds


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:identified_set_exists}{cmd:,}
{opt uni:variate(matname)}
{opt pair:ed(matname)}
[{it:options}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{p2coldent:* {opt uni:variate(matname)}}univariate bounds matrix from {helpb build_bounds} ({cmd:r(univariate)}){p_end}
{p2coldent:* {opt pair:ed(matname)}}paired bounds matrix from {helpb build_bounds} ({cmd:r(paired)}){p_end}
{synopt :{opt check:only(namelist)}}check only the listed settings (at least two){p_end}
{synopt :{opt sol:ution}}also return one set of effect parameters that satisfies all bounds{p_end}
{synoptline}
{p2colreset}{...}
{pstd}* required.  Requires Stata 16 or later.  Setting names containing
spaces must be enclosed in quotes within {opt checkonly()}.


{marker description}{...}
{title:Description}

{pstd}
{cmd:identified_set_exists} uses linear programming (the Mata
{helpb mf_LinearProgram:LinearProgram()} class) to determine whether there
exists a vector of true treatment effects {hline 2} one per setting
{hline 2} that simultaneously satisfies all univariate and pairwise bounds
produced by {helpb build_bounds}.


{marker options}{...}
{title:Options}

{phang}
{opt univariate(matname)} and {opt paired(matname)} name the matrices
returned by {helpb build_bounds} in {cmd:r(univariate)} and {cmd:r(paired)}.
Both are required.

{phang}
{opt checkonly(namelist)} restricts the check to the listed settings.  Must
contain at least two settings.  This option is useful for diagnosing which
combinations of settings lead to no identified set existing.

{phang}
{opt solution} returns one set of effect parameters that satisfies all
bounds in {cmd:r(solution)}.  {it:IT IS EXTREMELY IMPORTANT TO NOTE} that
this is not a "best" solution or anything like that.  It is simply one
possible solution, determined by the solver's internal path.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. use close_college, clear}{p_end}
{phang2}{cmd:. ovb_bounds_by_setting lwage educ smsa married exper, setting(blacksouth) treatment(educ) benchmark(smsa married exper) kd(.1)}{p_end}
{phang2}{cmd:. matrix bnds = r(bounds)}{p_end}
{phang2}{cmd:. matrix boundmat = (0, 2, 1.5, 0 \ 0, 0, 0, 1.5 \ 0, 0, 0, 2 \ 0, 0, 0, 0)}{p_end}
{phang2}{cmd:. build_bounds, bounds(bnds) rho(boundmat) order(Neither Black South "Black and South")}{p_end}
{phang2}{cmd:. matrix uni = r(univariate)}{p_end}
{phang2}{cmd:. matrix prd = r(paired)}{p_end}

{pstd}Check whether a set of effect parameters satisfying all bounds exists{p_end}
{phang2}{cmd:. identified_set_exists, univariate(uni) paired(prd)}{p_end}

{pstd}Get one example of a set of parameters in the identified set{p_end}
{phang2}{cmd:. identified_set_exists, univariate(uni) paired(prd) solution}{p_end}

{pstd}Check a subset of settings only{p_end}
{phang2}{cmd:. identified_set_exists, univariate(uni) paired(prd) checkonly(Neither "Black and South")}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:identified_set_exists} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(exists)}}1 if an identified set exists, 0 otherwise{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(solution)}}one feasible vector of effects (only with
{opt solution}, and only if the set exists){p_end}
{p2colreset}{...}


{title:Also see}

{psee}
Help:  {helpb hetset}, {helpb build_bounds}, {helpb univariate_bounds_table}
{p_end}
