USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetMatchUpData_NBA_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetMatchUpData_NBA_XML]
	@teamKey   VARCHAR(100)
AS
-- =============================================
-- Author:      Prashant Kamat
-- Create date: 01/22/2015
-- Description: Get Matchup Module for NBA
-- Update:	    01/28/2015 - pkamat: Use season_key instead of team_season_key from SMG_Default_Dates, use @stat_name for stat name
-- 				01/29/2015 - pkamat: Added score in post event
-- 				02/04/2015 - pkamat: Fix 0 value for max_stat in field goal % stat, 
--							 Call new function SMG_fnGetMatchupEventKeyByLeagueAndTeam to get event key
--							 Change current stats to Points Per Game, Points Allowed Per Game, Field Goal %
-- 				02/06/2015 - pkamat: Add sub season type join to get stats, get wins-loss record using event season key
-- 				02/12/2015 - pkamat: Calculate percentage in temp table
-- 				03/17/2015 - pkamat: Get season key from SMG_Statistics
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @leagueKey VARCHAR(100) = 'l.nba.com', @leagueName VARCHAR(100) = 'nba', @season_key INT, @event_key VARCHAR(100), @event_status VARCHAR(100), @home_team_key VARCHAR(100), @away_team_key VARCHAR(100), @event_season_key INT;

    SELECT TOP 1 @season_key = season_key
	  FROM SportsEditDB.dbo.SMG_Statistics
	 WHERE league_key = @leagueKey AND sub_season_type = 'season-regular' AND team_key = @teamKey
	 ORDER BY season_key DESC;

    SELECT @event_key = dbo.SMG_fnGetMatchupEventKeyByLeagueAndTeam(@leagueName, @teamKey);

/*
EVENTS
u'start_date_time': 'date_time': u'2015-01-19T14:30:00', u'time_zone': u'ET', 
u'week_of_season_label': None, 
u'season_type': u'season-regular', 
u'game_status': None, u'event_status': u'pre-event',
u'preview': u'pre-event-coverage', 
u'event_key': u'l.nba.com-2014-e.20579'
}

TEAMS
[{'last_name': u'Pistons', 'class_name': u'nba12', 'team_front_url': u'/sports/nba/pistons/', 'rank': None, 'ties': u'0', 'id': 'away', 'first_name': u'Detroit', 'display_name': u'Pistons', 'wins': u'16', 'losses': u'25', 'key_players': None, 'score': '0', 'league_key': u'l.nba.com'}, 
{'last_name': u'Hawks', 'class_name': u'nba8', 'team_front_url': u'/sports/nba/hawks/', 'rank': None, 'ties': u'0', 'id': 'home', 'first_name': u'Atlanta', 'display_name': u'Hawks', 'wins': u'33', 'losses': u'8', 'key_players': None, 'score': '0', 'league_key': u'l.nba.com'}]


MATCHUPS
[{'stats': [{'max': 193.0, 'team_id': u'away', 'team_class_name': u'nba12', 'percentage': '51%', 'value': 98.1}, {'max': 193.0, 'team_id': u'home', 'team_class_name': u'nba13', 'percentage': '49%', 'value': 94.9}], 'name': u'POINTS PER GAME'}, 
'stats': [{'max': 179.5, 'team_id': u'away', 'team_class_name': u'nba12', 'percentage': '51%', 'value': 90.8}, {'max': 179.5, 'team_id': u'home', 'team_class_name': u'nba13', 'percentage': '49%', 'value': 88.7}], 'name': u'POINTS ALLOWED PER GAME', 
'stats': [{'max': 85.43, 'team_id': u'away', 'team_class_name': u'nba12', 'percentage': '50%', 'value': 42.56}, {'max': 85.43, 'team_id': u'home', 'team_class_name': u'nba13', 'percentage': '50%', 'value': 42.87}], 'name': u'FIELD GOAL %']

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
		league_key		VARCHAR(100) DEFAULT 'l.nba.com'
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
	   SET temp.display_name = teams.team_display,first_name = teams.team_first,last_name = teams.team_last,class_name = @leagueName + REVERSE(LEFT(REVERSE(temp.team_key), CHARINDEX('.', REVERSE(temp.team_key))-1)),
			team_front_url = '/sports/' + @leagueName + '/' + teams.team_slug,abbr = teams.team_abbreviation
	  FROM @team_info temp
	 INNER JOIN dbo.SMG_Teams teams
		ON teams.season_key = @season_key
	   AND teams.league_key = @leagueKey
	   AND teams.team_key = temp.team_key;

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
		   AND scores.[column] = 'total';
	END

	UPDATE @team_info
	   SET score = ISNULL(score, '0');

	--POINTS PER GAME
	SELECT @stat_name = 'points per game';
	SELECT @home_value = [value]
	  FROM SportsEditDB.dbo.SMG_Statistics 
	 WHERE league_key = @leagueKey
	   AND season_key = @season_key
	   AND sub_season_type = 'season-regular'
	   AND team_key = @home_team_key
	   AND player_key = 'team'
	   AND category = 'feed'
	   AND [column] = 'points-scored-total-per-game';

	SELECT @away_value = [value]
	  FROM SportsEditDB.dbo.SMG_Statistics 
	 WHERE league_key = @leagueKey
	   AND season_key = @season_key
	   AND sub_season_type = 'season-regular'
	   AND team_key = @away_team_key
	   AND player_key = 'team'
	   AND category = 'feed'
	   AND [column] = 'points-scored-total-per-game';

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

	--POINTS ALLOWED PER GAME
	SELECT @home_value = NULL, @away_value = NULL;
	SELECT @stat_name = 'points allowed per game';
	SELECT @home_value = [value]
	  FROM SportsEditDB.dbo.SMG_Statistics 
	 WHERE league_key = @leagueKey
	   AND season_key = @season_key
	   AND sub_season_type = 'season-regular'
	   AND team_key = @home_team_key
	   AND player_key = 'team'
	   AND category = 'feed'
	   AND [column] = 'points-scored-against-per-game';

	SELECT @away_value = [value]
	  FROM SportsEditDB.dbo.SMG_Statistics 
	 WHERE league_key = @leagueKey
	   AND season_key = @season_key
	   AND sub_season_type = 'season-regular'
	   AND team_key = @away_team_key
	   AND player_key = 'team'
	   AND category = 'feed'
	   AND [column] = 'points-scored-against-per-game';

	SELECT @home_value = ISNULL(@home_value, 0), @away_value = ISNULL(@away_value, 0);
	SET @max_value = CONVERT(FLOAT, @home_value) + CONVERT(FLOAT, @away_value);

	IF (@max_value = '0')
	BEGIN
		SET @max_value = '1';
	END

	SELECT @home_percentage = CONVERT(VARCHAR, CONVERT(DECIMAL(5,1), CONVERT(FLOAT, @home_value)*100.0/@max_value)) + '%',
			@away_percentage = CONVERT(VARCHAR, CONVERT(DECIMAL(5,1), CONVERT(FLOAT, @away_value)*100.0/@max_value)) + '%';

	INSERT INTO @team_stat (team_key,stat,[value],max_value,percentage,[order])
	VALUES(@home_team_key, @stat_name, @home_value, @max_value, @home_percentage, 2),(@away_team_key, @stat_name, @away_value, @max_value, @away_percentage, 2);

	--FIELD GOAL %
	SELECT @home_value = NULL, @away_value = NULL;
	SELECT @stat_name = 'field goal %';
	SELECT @home_value = CONVERT(FLOAT, [value])*100
	  FROM SportsEditDB.dbo.SMG_Statistics 
	 WHERE league_key = @leagueKey
	   AND season_key = @season_key
	   AND sub_season_type = 'season-regular'
	   AND team_key = @home_team_key
	   AND player_key = 'team'
	   AND category = 'feed'
	   AND [column] = 'field-goals-percentage';

	SELECT @away_value = CONVERT(FLOAT, [value])*100
	  FROM SportsEditDB.dbo.SMG_Statistics 
	 WHERE league_key = @leagueKey
	   AND season_key = @season_key
	   AND sub_season_type = 'season-regular'
	   AND team_key = @away_team_key
	   AND player_key = 'team'
	   AND category = 'feed'
	   AND [column] = 'field-goals-percentage';

	SELECT @home_value = ISNULL(@home_value, 0), @away_value = ISNULL(@away_value, 0);
	SET @max_value = CONVERT(FLOAT, @home_value) + CONVERT(FLOAT, @away_value);

	IF (@max_value = '0')
	BEGIN
		SET @max_value = '1';
	END

	SELECT @home_percentage = CONVERT(VARCHAR, CONVERT(DECIMAL(5,1), CONVERT(FLOAT, @home_value)*100.0/@max_value)) + '%',
			@away_percentage = CONVERT(VARCHAR, CONVERT(DECIMAL(5,1), CONVERT(FLOAT, @away_value)*100.0/@max_value)) + '%';

	INSERT INTO @team_stat (team_key,stat,[value],max_value,percentage,[order])
	VALUES(@home_team_key, @stat_name, @home_value, @max_value, @home_percentage, 3),(@away_team_key, @stat_name, @away_value, @max_value, @away_percentage, 3);

	--Update team class and id in stats
	UPDATE stat
	   SET stat.team_id = info.id, stat.team_class_name = info.class_name
	  FROM @team_stat stat
	 INNER JOIN @team_info info
		ON stat.team_key = info.team_key;

	SELECT
	(
        SELECT id,display_name,first_name,last_name,class_name,team_front_url,abbr,events_played,ties,wins,losses,team_key,league_key,score
		  FROM @team_info team
           FOR XML RAW('teams'), TYPE
    ),
	(
        SELECT event_key, sub_season_type, game_status, event_status, site_name,
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
