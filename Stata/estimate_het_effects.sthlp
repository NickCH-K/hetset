{smcl}
{* *! version 0.1.0  10jun2026}{...}
{viewerjumpto "Syntax" "estimate_het_effects##syntax"}{...}
{viewerjumpto "Description" "estimate_het_effects##description"}{...}
{viewerjumpto "Options" "estimate_het_effects##options"}{...}
{viewerjumpto "Examples" "estimate_het_effects##examples"}{...}
{viewerjumpto "Stored results" "estimate_het_effects##results"}{...}
{title:Title}

{phang}
{bf:estimate_het_effects} {hline 2} Estimate effects by setting


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:estimate_het_effects}
{depvar} {indepvars}
{ifin}{cmd:,}
{opth set:ting(varname)}
{opth treat:ment(varname)}
[{it:options}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{p2coldent:* {opth set:ting(varname)}}variable defining the estimation settings{p_end}
{p2coldent:* {opth treat:ment(varname)}}treatment variable; must appear among {it:indepvars}{p_end}
{synopt :{opt cmd(command)}}estimation command to use; default is {cmd:regress}{p_end}
{synopt :{opt cmdopt:ions(string)}}options passed to the estimation command{p_end}
{synopt :{opt v:erbose}}display progress messages{p_end}
{synoptline}
{p2colreset}{...}
{pstd}* required.  {it:indepvars} may contain factor and time-series
operators if the estimation command supports them.


{marker description}{...}
{title:Description}

{pstd}
{cmd:estimate_het_effects} estimates the effect of the treatment variable
on {depvar} within different settings defined by the {opt setting()}
variable, running the estimation command separately for each setting and
collecting the treatment coefficient along with estimation statistics like
sample size, standard errors, and model fit.

{pstd}
This command works with a wide range of estimation commands.  By default it
uses {helpb regress} (the R package's default is linear regression via
{cmd:fixest::feols}).  Any e-class command with
{cmd:{it:command} {it:depvar} {it:indepvars} [if]{cmd:,} {it:options}}
syntax that leaves {cmd:_b[{it:treatment}]} and {cmd:_se[{it:treatment}]}
defined can be used via the {opt cmd()} option (e.g. {cmd:rreg},
{cmd:poisson}, {cmd:areg}).


{marker options}{...}
{title:Options}

{phang}
{opth setting(varname)} specifies the variable defining the estimation
settings.  Required.

{phang}
{opth treatment(varname)} specifies the treatment variable whose
coefficient is extracted.  Required.

{phang}
{opt cmd(command)} specifies the estimation command run within each
setting.  Default is {cmd:regress}.

{phang}
{opt cmdoptions(string)} provides options appended to the estimation
command, for example {cmd:cmdoptions(vce(robust))}.

{phang}
{opt verbose} displays a progress message for each setting.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. use close_college, clear}{p_end}

{pstd}Effects of education on log wage by setting{p_end}
{phang2}{cmd:. estimate_het_effects lwage educ smsa married exper, setting(blacksouth) treatment(educ)}{p_end}
{phang2}{cmd:. matrix est = r(estimates)}{p_end}

{pstd}With robust standard errors{p_end}
{phang2}{cmd:. estimate_het_effects lwage educ smsa married exper, setting(blacksouth) treatment(educ) cmdoptions(vce(robust))}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:estimate_het_effects} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_settings)}}number of settings{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(treatment)}}name of the treatment variable{p_end}
{synopt:{cmd:r(setting)}}name of the setting variable{p_end}
{synopt:{cmd:r(cmd)}}estimation command used{p_end}
{synopt:{cmd:r(settings)}}setting names, in row order of {cmd:r(estimates)}{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(estimates)}}one row per setting with columns {cmd:failed},
{cmd:estimate}, {cmd:std_error}, {cmd:n_obs}, {cmd:t_stat}, {cmd:p_value},
{cmd:r_squared}, {cmd:rmse} (missing where unavailable){p_end}
{p2colreset}{...}


{title:Also see}

{psee}
Help:  {helpb hetset}, {helpb ovb_bounds_by_setting}
{p_end}
