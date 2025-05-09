begin;

drop table if exists laliga.games;

set datestyle to 'SQL, YMD';

create table laliga.games (
	season			integer,
	week			text,
	day			text,
	date			date,
	time			text,
	home_team		text,
	home_xg			float,
	score			text,
	away_xg			float,
	away_team		text,
	attendance		integer,
	venue			text,
	referee			text,
	match_report		text,
	notes			text,
	home_score		integer,
	away_score		integer
);

copy laliga.games from '/tmp/games.csv' with delimiter as ',' csv;

alter table laliga.games add column game_id serial;

update laliga.games
set home_score = split_part(score,'–',1)::integer,
    away_score = split_part(score,'–',2)::integer;

commit;
