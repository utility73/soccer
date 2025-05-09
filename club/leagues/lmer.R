sink("diagnostics/lmer.txt")

library("lme4")
library("RPostgreSQL")

drv <- dbDriver("PostgreSQL")

con <- dbConnect(drv, dbname="soccer")

query <- dbSendQuery(con, "
select
r.game_id,
r.year,
r.field as field,
r.team_id as team,
r.team_league_key as team_league,
r.opponent_id as opponent,
r.opponent_league_key as opponent_league,
team_score as gs
--(case
--when r.competition in ('','Friendly') then 0.5
--else 1.0
--end) as w
from club.results r

where
    r.year between 2000 and 2020

and r.team_score is not null
and r.opponent_score is not null

and r.team_league_key not like '%women%'
and r.opponent_league_key not like '%women%'

and (year,r.team_league_key) not in 
(
select year,team_league_key
from club.results group by year,team_league_key
having count(*) < 200
)

and (year,r.opponent_league_key) not in 
(
select year,team_league_key
from club.results group by year,team_league_key
having count(*) < 200
)

and r.team_league_key not in ('north+american+soccer+league')
and r.opponent_league_key not in ('north+american+soccer+league')

/*
and r.team_league_key in
(select distinct league_key
 from club.teams
 where year=2018)
and r.team_league_key in
(select distinct league_key
 from club.teams
 where year=2020)
and r.opponent_league_key in
(select distinct league_key
 from club.teams
 where year=2018)
and r.opponent_league_key in
(select distinct league_key
 from club.teams
 where year=2020)
*/

-- Ignore leagues with no outside connectivity
-- To do algorithmically

-- Multiple years

/*
and r.team_league_key in
(
select league_key from
(select distinct year,league_key from club.games) l
group by league_key
having count(*)>4
)

and r.opponent_league_key in

(
select league_key from
(select distinct year,league_key from club.games) l
group by league_key
having count(*)>4
)
*/

;")

games <- fetch(query,n=-1)

dim(games)

attach(games)

pll <- list()

# Fixed parameters

year <- as.factor(year)

field <- as.factor(field)

offense_league <- as.factor(team_league)

defense_league <- as.factor(opponent_league)

fp <- data.frame(year,field,offense_league,defense_league)
fpn <- names(fp)

# Random parameters

game_id <- as.factor(game_id)

offense <- as.factor(paste(year,"/",team,sep=""))

defense <- as.factor(paste(year,"/",opponent,sep=""))

rp <- data.frame(offense,defense)
rpn <- names(rp)

for (n in fpn) {
  df <- fp[[n]]
  level <- as.matrix(attributes(df)$levels)
  parameter <- rep(n,nrow(level))
  type <- rep("fixed",nrow(level))
  pll <- c(pll,list(data.frame(parameter,type,level)))
}

for (n in rpn) {
  df <- rp[[n]]
  level <- as.matrix(attributes(df)$levels)
  parameter <- rep(n,nrow(level))
  type <- rep("random",nrow(level))
  pll <- c(pll,list(data.frame(parameter,type,level)))
}

# Model parameters

parameter_levels <- as.data.frame(do.call("rbind",pll))
dbWriteTable(con,c("club","_parameter_levels"),parameter_levels,row.names=TRUE)

g <- cbind(fp,rp) #,w)

dim(g)

model <- gs ~ year+offense_league+defense_league+field+(1|offense)+(1|defense)+(1|game_id)

fit <- glmer(model,
             data=g,
             #weights=w,
             verbose=TRUE,
             family=poisson(link=log),
             nAGQ=0,
             control=glmerControl(optimizer = "nloptwrap"))

fit
summary(fit)

# List of data frames

# Fixed factors

f <- fixef(fit)
fn <- names(f)

# Random factors

r <- ranef(fit)
rn <- names(r) 

results <- list()

for (n in fn) {

  df <- f[[n]]

  factor <- n
  level <- n
  type <- "fixed"
  estimate <- df

  results <- c(results,list(data.frame(factor,type,level,estimate)))

 }

for (n in rn) {

  df <- r[[n]]

  factor <- rep(n,nrow(df))
  type <- rep("random",nrow(df))
  level <- row.names(df)
  estimate <- df[,1]

  results <- c(results,list(data.frame(factor,type,level,estimate)))

 }

combined <- as.data.frame(do.call("rbind",results))

dbWriteTable(con,c("club","_basic_factors"),as.data.frame(combined),row.names=TRUE)

quit("no")
