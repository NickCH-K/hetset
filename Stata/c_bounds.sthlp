{smcl}
{* *! version 0.1.0  10jun2026}{...}
{viewerjumpto "Syntax" "c_bounds##syntax"}{...}
{viewerjumpto "Description" "c_bounds##description"}{...}
{viewerjumpto "Options" "c_bounds##options"}{...}
{viewerjumpto "Examples" "c_bounds##examples"}{...}
{viewerjumpto "Stored results" "c_bounds##results"}{...}
{title:Title}

{phang}
{bf:c_bounds} {hline 2} Calculate C set of bounds


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:c_bounds}{cmd:,}
{opt b_lower(#)}
{opt b_upper(#)}
{opt rho_upper(#)}
[{opt rho_lower(#)}]


{marker description}{...}
{title:Description}

{pstd}
{cmd:c_bounds} calculates the set that bounds the difference between two
effects, from Huntington-Klein (2026).  The set is built from the four
corner values of the rectangle defined by the bounds on the bias nu in the
second setting (B in the paper) and the bounds on rho, the proportional
relationship between the biases in the two settings.

{pstd}
This is mainly an internal building block of {helpb build_bounds}, exposed
for users who want to compute pair bounds directly.


{marker options}{...}
{title:Options}

{phang}
{opt b_lower(#)} specifies the lower bound on nu in the second setting (B
in the paper).  Required.

{phang}
{opt b_upper(#)} specifies the upper bound on nu in the second setting (B
in the paper).  Required.

{phang}
{opt rho_upper(#)} specifies the upper bound on the proportional
relationship of biases between the two settings.  Required.

{phang}
{opt rho_lower(#)} specifies the lower bound on the proportional
relationship of biases between the two settings.  By default, this is set
to 1/{opt rho_upper()}, which is a common choice that ensures a symmetrical
bound on the ratio.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. c_bounds, b_lower(-0.05) b_upper(0.05) rho_upper(2)}{p_end}
{phang2}{cmd:. display r(lower) ", " r(upper)}{p_end}

{pstd}With an explicit lower rho bound{p_end}
{phang2}{cmd:. c_bounds, b_lower(-0.05) b_upper(0.05) rho_upper(2) rho_lower(0.25)}{p_end}
{phang2}{cmd:. matrix list r(cset)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:c_bounds} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(lower)}}minimum of the C set{p_end}
{synopt:{cmd:r(upper)}}maximum of the C set{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(cset)}}1 x 4 matrix of the four corner values of the C set{p_end}
{p2colreset}{...}


{title:Also see}

{psee}
Help:  {helpb hetset}, {helpb build_bounds}
{p_end}
