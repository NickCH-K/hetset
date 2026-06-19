{smcl}
{* *! version 0.1.0  10jun2026}{...}
{title:Title}

{phang}
{bf:close_college} {hline 2} Data from Card (1995) to estimate the effect of college education on earnings


{title:Description}

{pstd}
{cmd:close_college.dta} contains data from the National Longitudinal Survey
Young Men Cohort.  This data is used to estimate the effect of college
education on earnings, using the presence of a nearby (in-county) college as
an instrument for college attendance.

{pstd}
This data is used in the {it:Instrumental Variables} chapter of
{it:Causal Inference: The Mixtape} by Cunningham.

{pstd}
This is a copy of the data stored in the {bf:causaldata} package, but with a
variable {cmd:blacksouth} added, which shows the four possible combinations
of the variables {cmd:black} and {cmd:south}.

{pstd}
The dataset is shipped with the {helpb hetset} package as an ancillary file.
Download it to the current directory with
{cmd:ssc install hetset, all} or {cmd:net get hetset}, then load it with:

{phang2}{cmd:. use close_college, clear}{p_end}


{title:Variables}

{pstd}A dataset with 3,010 observations and 9 variables:{p_end}

{synoptset 14 tabbed}{...}
{synopt:{cmd:lwage}}Log wages{p_end}
{synopt:{cmd:educ}}Years of education{p_end}
{synopt:{cmd:exper}}Years of work experience{p_end}
{synopt:{cmd:black}}Race: Black{p_end}
{synopt:{cmd:south}}In the southern United States{p_end}
{synopt:{cmd:blacksouth}}A string variable showing the four possible combinations of {cmd:black} and {cmd:south} ("Neither", "Black", "South", "Black and South"){p_end}
{synopt:{cmd:married}}Is married{p_end}
{synopt:{cmd:smsa}}In a Standard Metropolitan Statistical Area (urban){p_end}
{synopt:{cmd:nearc4}}There is a four-year college in the county{p_end}
{p2colreset}{...}


{title:Source}

{pstd}
Card, David.  1995.  "Aspects of Labour Economics: Essays in Honour of John
Vanderkamp."  In.  University of Toronto Press.


{title:References}

{pstd}
Cunningham, S.  2021.  {it:Causal Inference: The Mixtape}.  Yale Press.
{browse "https://mixtape.scunning.com/index.html"}


{title:Also see}

{psee}
Help:  {helpb hetset}, {helpb ovb_bounds_by_setting}
{p_end}
