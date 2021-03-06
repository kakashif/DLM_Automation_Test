USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetMatchUpData_MLB_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetMatchUpData_MLB_XML]
	@teamKey   VARCHAR(100)
AS
-- =============================================
-- Author:      Prashant Kamat
-- Create date: 01/27/2015
-- Description: Get Matchup Module for MLB
-- Update:	    02/04/2015 - pkamat: Call new function SMG_fnGetMatchupEventKeyByLeagueAndTeam to get event key
--							 Change current stats to Batting Average, Runs Scored, ERA
-- 				02/06/2015 - pkamat: Add sub season type join to get stats, get wins-loss record using event season key
-- 				02/12/2015 - pkamat: Calculate percentage in temp table
-- 				02/13/2015 - pkamat: Change run scored stat to run scored per game stat
-- 				02/17/2015 - pkamat: Handle nulls for max_value
-- 				02/18/2015 - pkamat: Use run-scored-per-game stat instead of calculating it
-- 				03/17/2015 - pkamat: Get season key from SMG_Statistics
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @leagueKey VARCHAR(100) = 'l.mlb.com', @leagueName VARCHAR(100) = 'mlb', @season_key INT, @event_key VARCHAR(100), @event_status VARCHAR(100), @home_team_key VARCHAR(100), @away_team_key VARCHAR(100), @event_season_key INT;

    SELECT TOP 1 @season_key = season_key
	  FROM SportsEditDB.dbo.SMG_Statistics
	 WHERE league_key = @leagueKey AND sub_season_type = 'season-regular' AND team_key = @teamKey
	 ORDER BY season_key DESC;

    SELECT @event_key = dbo.SMG_fnGetMatchupEventKeyByLeagueAndTeam(@leagueName, @teamKey);

/*
EVENTS
u'start_date_time': [{'date_time': u'2014-09-28T13:35:00', u'time_zone': u'ET'}], 
u'week_of_season_label': None, 
u'season_type': u'season-regular', 
u'updated_time': u'11:42 PM', 
u'game_status': u'Final', 
u'event_status': u'post-event', 
u'preview': None, 
u'event_key': u'l.mlb.com-2014-e.41561', 
u'site_information': [{u'weather': None, u'attendance': u'36,879', u'name': u'Fenway Park'}]

TEAMS
[{'last_name': u'Yankees', 'class_name': u'mlb3', 'team_front_url': u'/sports/mlb/yankees/', 'rank': None, 'ties': u'0', 'id': 'away', 'first_name': u'New York', 'display_name': u'Yankees', 'wins': u'84', 'losses': u'78', 'key_players': [{'first_name': u'Michael', 'last_name': u'Pineda', 'title_abbr': 'WP', 'title': 'Winning Pitcher'}], 'score': u'9', 'league_key': u'l.mlb.com'}, 
'last_name': u'Red Sox', 'class_name': u'mlb2', 'team_front_url': u'/sports/mlb/red-sox/', 'rank': None, 'ties': u'0', 'id': 'home', 'first_name': u'Boston', 'display_name': u'Red Sox', 'wins': u'71', 'losses': u'91', 'key_players': [{'first_name': u'Clay', 'last_name': u'Buchholz', 'title_abbr': 'LP', 'title': 'Losing Pitcher'}], 'score': u'5', 'league_key': u'l.mlb.com']

MATCHUPS
[{'stats': [{'max': 0.472, 'team_id': u'away', 'team_class_name': u'mlb3', 'percentage': '67%', 'value': 0.316}, {'max': 0.472, 'team_id': u'home', 'team_class_name': u'mlb2', 'percentage': '33%', 'value': 0.156}], 'name': u'BATTING AVERAGE'}, 
'stats': [{'max': 17.0, 'team_id': u'away', 'team_class_name': u'mlb3', 'percentage': '71%', 'value': 12.0}, {'max': 17.0, 'team_id': u'home', 'team_class_name': u'mlb2', 'percentage': '29%', 'value': 5.0}], 'name': u'RUNS SCORED', 
'stats': [{'max': 22.0, 'team_id': u'away', 'team_class_name': u'mlb3', 'percentage': '32%', 'value': 7.0}, {'max': 22.0, 'team_id': u'home', 'team_class_name': u'mlb2', 'percentage': '68%', 'value': 15.0}], 'name': u'EARNED RUN AVERAGE']

*/

	DECLARE @team_info TABLE (
		id 				VARCHAR(10),
		display_name	VARCHAR(100),
		first_name		VARCHAR(100),
		last_name		VARCHAR(100),
		class_name		VARCHAR(100),
		team_front_url	VARCHAR(100),
		score			VARCHAR(100),
		abbr			VARCHAR(10),
		events_played	INT,
		wins			INT,
		losses			INT,
		ties			INT,
		team_key		VARCHAR(100) PRIMARY KEY,
		league_key		VARCHAR(100) DEFAULT 'l.mlb.com'
	);

	DECLARE @team_stat TABLE (
		[order]			INT,
		team_id 		VARCHAR(10),
		team_class_name	VARCHAR(100),
		team_key		VARCHAR(100),
		stat			VARCHAR(100),
		value			VARCHAR(100),
		max_value		VARCHAR(100),
		percentage		VARCHAR(100)
	);

	DECLARE @player_info TABLE (
		first_name		VARCHAR(100),
		last_name		VARCHAR(100),
		title_abbr		VARCHAR(100),
		title			VARCHAR(100),
		player_key		VARCHAR(100) PRIMARY KEY,
		team_key		VARCHAR(100)
	);

	SELECT @home_team_key = home_team_key, @away_team_key = away_team_key, @event_status = event_status, @event_season_key = season_key
	  FROM dbo.SMG_Schedules 
	 WHERE event_key = @event_key;

	DECLARE @events_played INT, @wins INT, @losses INT, @ties INT;

	SELECT TOP 1 @events_played = events_played, @wins = wins, @losses = losses, @ties = ties
	  FROM SportsEditDB.dbo.SMG_Team_Records
	 WHERE season_key = @event_season_key
	   AND league_key = @leagueKey
	   AND team_key = @home_team_key
	 ORDER BY date_time_EST DESC;

	SELECT @events_played = ISNULL(@events_played, 0), @wins = ISNULL(@wins, 0), @losses = ISNULL(@losses, 0), @ties = ISNULL(@ties, 0);

	INSERT INTO @team_info (id, team_key, events_played, wins, losses, ties)
	SELECT 'home', @home_team_key, @events_played, @wins, @losses, @ties;

	SELECT TOP 1 @events_played = events_played, @wins = wins, @losses = losses, @ties = ties
	  FROM SportsEditDB.dbo.SMG_Team_Records
	 WHERE season_key = @event_season_key
	   AND league_key = @leagueKey
	   AND team_key = @away_team_key
	 ORDER BY date_time_EST DESC;

	SELECT @events_played = ISNULL(@events_played, 0), @wins = ISNULL(@wins, 0), @losses = ISNULL(@losses, 0), @ties = ISNULL(@ties, 0);

	INSERT INTO @team_info (id, team_key, events_played, wins, losses, ties)
	SELECT 'away', @away_team_key, @events_played, @wins, @losses, @ties;

	UPDATE temp
	   SET display_name = teams.team_display,first_name = teams.team_first,last_name = teams.team_last,class_name = @leagueName + REVERSE(LEFT(REVERSE(temp.team_key), CHARINDEX('.', REVERSE(temp.team_key))-1)),
			team_front_url = '/sports/' + @leagueName + '/' + teams.team_slug,abbr = teams.team_abbreviation
	  FROM @team_info temp
	 INNER JOIN dbo.SMG_Teams teams
		ON teams.season_key = @season_key
	   AND teams.league_key = @leagueKey
	   AND teams.team_key = temp.team_key;

	INSERT INTO @player_info (team_key, player_key, title_abbr, title)
	SELECT team_key, player_key, CASE [value] WHEN 'win' THEN 'WP' WHEN 'loss' THEN 'LP' WHEN 'save' THEN 'SP' END, CASE [value] WHEN 'win' THEN 'Winning Pitcher' WHEN 'loss' THEN 'Losing Pitcher' WHEN 'save' THEN 'Saving Pitcher' END
	  FROM SportsEditDB.dbo.SMG_Events_baseball stats
	 WHERE stats.event_key = @event_key --'l.mlb.com-2014-e.44565'
	   AND stats.[column] = 'event-credit'
	   AND stats.[value] in ('win','loss','save');

	UPDATE temp
	   SET first_name = players.first_name,last_name = players.last_name
	  FROM @player_info temp
	 INNER JOIN dbo.SMG_Players players
		ON temp.player_key = players.player_key;

	DECLARE @home_value VARCHAR(100), @away_value VARCHAR(100), @max_value VARCHAR(100), @stat_name VARCHAR(100); 
	DECLARE @home_percentage VARCHAR(100), @away_percentage VARCHAR(100);

	IF (@event_status = 'post-event')
	BEGIN
		UPDATE temp
		   SET temp.score = scores.[value]
		  FROM @team_info temp
		 INNER JOIN dbo.SMG_Scores scores
			ON scores.team_key = temp.team_key
		   AND scores.event_key = @event_key
		   AND scores.[column] = 'runs-scored';
	END

	UPDATE @team_info
	   SET score = ISNULL(score, '0');

	--BATTING AVERAGE
	SELECT @stat_name = 'batting average';
	SELECT @home_value = [value]
	  FROM SportsEditDB.dbo.SMG_Statistics 
	 WHERE league_key = @leagueKey
	   AND season_key = @season_key
	   AND sub_season_type = 'season-regular'
	   AND team_key = @home_team_key
	   AND player_key = 'team'
	   AND category = 'feed'
	   AND [column] = 'average';

	SELECT @away_value = [value]
	  FROM SportsEditDB.dbo.SMG_Statistics 
	 WHERE league_key = @leagueKey
	   AND season_key = @season_key
	   AND sub_season_type = 'season-regular'
	   AND team_key = @away_team_key
	   AND player_key = 'team'
	   AND category = 'feed'
	   AND [column] = 'average';

	SELECT @home_value = ISNULL(@home_value, 0), @away_value = ISNULL(@away_value, 0);
	SET @max_value = CONVERT(FLOAT, @home_value) + CONVERT(FLOAT, @away_value);

	IF (@max_value = '0')
	BEGIN
		SET @max_value = '1';
	END

	SELECT @home_percentage = CONVERT(VARCHAR, CONVERT(DECIMAL(5,1), CONVERT(FLOAT, @home_value)*100.0/@max_value)) + '%',
			@away_percentage = CONVERT(VARCHAR, CONVERT(DECIMAL(5,1), CONVERT(FLOAT, @away_value)*100.0/@max_value)) + '%';

	INSERT INTO @team_stat (team_key,stat,[value],max_value,percentage,[order])
	VALUES(@home_team_key, @stat_name, @home_value, @max_value, @home_percentage, 1),(@away_team_key, @stat_name, @away_value, @max_value, @away_percentage, 1);

	--RUNS SCORED
	SELECT @home_value = NULL, @away_value = NULL;
	SELECT @stat_name = 'runs scored per game';
	SELECT @home_value = [value]
	  FROM SportsEditDB.dbo.SMG_Statistics 
	 WHERE league_key = @leagueKey
	   AND season_key = @season_key
	   AND sub_season_type = 'season-regular'
	   AND team_key = @home_team_key
	   AND player_key = 'team'
	   AND category = 'feed'
	   AND [column] = 'runs-scored-per-game';

	SELECT @away_value = [value]
	  FROM SportsEditDB.dbo.SMG_Statistics 
	 WHERE league_key = @leagueKey
	   AND season_key = @season_key
	   AND sub_season_type = 'season-regular'
	   AND team_key = @away_team_key
	   AND player_key = 'team'
	   AND category = 'feed'
	   AND [column] = 'runs-scored-per-game';

	SELECT @home_value = ISNULL(@home_value, 0), @away_value = ISNULL(@away_value, 0);
	SET @max_value = CONVERT(DECIMAL(5,1), @home_value) + CONVERT(DECIMAL(5,1), @away_value);

	IF (@max_value = '0.0')
	BEGIN
		SET @max_value = '1.0';
	END

	SELECT @home_percentage = CONVERT(VARCHAR, CONVERT(DECIMAL(5,1), CONVERT(FLOAT, @home_value)*100.0/@max_value)) + '%',
			@away_percentage = CONVERT(VARCHAR, CONVERT(DECIMAL(5,1), CONVERT(FLOAT, @away_value)*100.0/@max_value)) + '%';

	INSERT INTO @team_stat (team_key,stat,[value],max_value,percentage,[order])
	VALUES(@home_team_key, @stat_name, @home_value, @max_value, @home_percentage, 2),(@away_team_key, @stat_name, @away_value, @max_value, @away_percentage, 2);

	--EARNED RUN AVERAGE
	SELECT @home_value = NULL, @away_value = NULL;
	SELECT @stat_name = 'earned run average';
	SELECT @home_value = [value]
	  FROM SportsEditDB.dbo.SMG_Statistics 
	 WHERE league_key = @leagueKey
	   AND season_key = @season_key
	   AND sub_season_type = 'season-regular'
	   AND team_key = @home_team_key
	   AND player_key = 'team'
	   AND category = 'feed'
	   AND [column] = 'era';

	SELECT @away_value = [value]
	  FROM SportsEditDB.dbo.SMG_Statistics 
	 WHERE league_key = @leagueKey
	   AND season_key = @season_key
	   AND sub_season_type = 'season-regular'
	   AND team_key = @away_team_key
	   AND player_key = 'team'
	   AND category = 'feed'
	   AND [column] = 'era';

	SELECT @home_value = ISNULL(@home_value, 0.0), @away_value = ISNULL(@away_value, 0.0);
	SET @max_value = CONVERT(FLOAT, @home_value) + CONVERT(FLOAT, @away_value);

	IF (@max_value = '0')
	BEGIN
		SET @max_value = '1';
	END

	SELECT @home_percentage = CONVERT(VARCHAR, CONVERT(DECIMAL(5,1), CONVERT(FLOAT, @home_value)*100.0/@max_value)) + '%',
			@away_percentage = CONVERT(VARCHAR, CONVERT(DECIMAL(5,1), CONVERT(FLOAT, @away_value)*100.0/@max_value)) + '%';

	INSERT INTO @team_stat (team_key,stat,[value],max_value,percentage,[order])
	VALUES(@home_team_key, @stat_name, @home_value, @max_value, @home_percentage, 3),(@away_team_key, @stat_name, @away_value, @max_value, @away_percentage, 3);

	UPDATE stat
	   SET stat.team_id = info.id, stat.team_class_name = info.class_name
	  FROM @team_stat stat
	 INNER JOIN @team_info info
		ON stat.team_key = info.team_key;

	SELECT
	(
        SELECT id,display_name,first_name,last_name,class_name,team_front_url,abbr,events_played,ties,wins,losses,team_key,league_key,score,
				(SELECT first_name,last_name,player_key,title_abbr,title
				   FROM @player_info player
				  WHERE player.team_key = team.team_key
					FOR XML RAW('key_players'), TYPE
				)
		  FROM @team_info team
           FOR XML RAW('teams'), TYPE
    ),
	(
        SELECT event_key, season_key, sub_season_type, game_status, event_status, site_name,
				(SELECT start_date_time_EST as date_time, 'ET' as time_zone
					FOR XML RAW('start_date_time'), TYPE
				)
		  FROM dbo.SMG_Schedules 
		 WHERE event_key = @event_key
           FOR XML RAW('events'), TYPE
	),
	(
		SELECT info.name, 
				(SELECT max_value as max, [value], team_key, team_id, team_class_name, percentage
				  FROM @team_stat 
				 WHERE stat = info.name
				 ORDER BY CASE team_id WHEN 'away' THEN 0 ELSE 1 END
				   FOR XML RAW('stats'), TYPE
				)
		  FROM (SELECT DISTINCT UPPER(stat) AS name, [order]
				  FROM @team_stat 
				) info 
		 ORDER BY info.[order]
           FOR XML RAW('matchups'), TYPE
	)
    FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF
END 

GO
