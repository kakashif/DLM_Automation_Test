USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetMatchUpData_NHL_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetMatchUpData_NHL_XML]
	@teamKey   VARCHAR(100)
AS
-- =============================================
-- Author:      Prashant Kamat
-- Create date: 01/23/2015
-- Description: Get Matchup Module for NHL
-- Update:	  	01/28/2015 - pkamat: Use season_key instead of team_season_key from SMG_Default_Dates
-- 				01/29/2015 - pkamat: Added score in post event
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @leagueKey VARCHAR(100) = 'l.nhl.com', @leagueName VARCHAR(100) = 'nhl', @season_key INT, @sub_season_key VARCHAR(100), @event_key VARCHAR(100), @event_status VARCHAR(100), @home_team_key VARCHAR(100), @away_team_key VARCHAR(100);

    SELECT @season_key = season_key, @sub_season_key = sub_season_type
	  FROM dbo.SMG_Default_Dates
	 WHERE league_key = LOWER(@leagueName) AND page = 'statistics';
   
    SELECT @event_key = dbo.SMG_fnGetMatchupEventKey(@leagueKey, @teamKey);

/*
EVENTS
u'start_date_time': 'date_time': u'2015-01-27T19:00:00', u'time_zone': u'ET', 
'week_of_season_label': None, 
u'season_type': u'season-regular', 
u'game_status': None, 
u'event_status': u'pre-event', 
u'preview': None, 
u'event_key': u'l.nhl.com-2014-e.19870', 
u'site_information': [{u'weather': None, u'attendance': None, u'name': u'Nassau Veterans Memorial Coliseum'}]}

TEAMS
[{'last_name': u'Rangers', 'class_name': u'nhl3', 'team_front_url': u'/sports/nhl/rangers/', 'rank': None, 'ties': u'4', 'id': 'away', 'first_name': u'New York', 'display_name': u'Rangers', 'wins': u'27', 'losses': u'13', 'key_players': None, 'score': '0', 'league_key': u'l.nhl.com'}, 
{'last_name': u'Islanders', 'class_name': u'nhl2', 'team_front_url': u'/sports/nhl/islanders/', 'rank': None, 'ties': u'1', 'id': 'home', 'first_name': u'New York', 'display_name': u'Islanders', 'wins': u'31', 'losses': u'14', 'key_players': None, 'score': '0', 'league_key': u'l.nhl.com'}]

MATCHUPS
[{'stats': [{'max': 3.0, 'team_id': u'away', 'team_class_name': u'nhl3', 'percentage': '100%', 'value': 3.0}, {'max': 3.0, 'team_id': u'home', 'team_class_name': u'nhl2', 'percentage': '107%', 'value': 3.2}], 'name': u'GOALS PER GAME'}, 
'stats': [{'max': 2.3, 'team_id': u'away', 'team_class_name': u'nhl3', 'percentage': '100%', 'value': 2.3}, {'max': 2.3, 'team_id': u'home', 'team_class_name': u'nhl2', 'percentage': '122%', 'value': 2.8}], 'name': u'GOALS AGAINST PER GAME', 
'stats': [{'max': 102.0, 'team_id': u'away', 'team_class_name': u'nhl3', 'percentage': '100%', 'value': 102.0}, {'max': 102.0, 'team_id': u'home', 'team_class_name': u'nhl2', 'percentage': '125%', 'value': 128.0}], 'name': u'POWER PLAY %']

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
		league_key		VARCHAR(100) DEFAULT 'l.nhl.com'
	);

	DECLARE @team_stat TABLE (
		team_id 		VARCHAR(10),
		team_class_name	VARCHAR(100),
		team_key		VARCHAR(100),
		event_key		VARCHAR(100),
		stat			VARCHAR(100),
		value			VARCHAR(100),
		max_value		VARCHAR(100)
	);


	SELECT @home_team_key = home_team_key, @away_team_key = away_team_key, @event_status = event_status
	  FROM dbo.SMG_Schedules 
	 WHERE event_key = @event_key;

	DECLARE @events_played INT, @wins INT, @losses INT, @ties INT;

	SELECT TOP 1 @events_played = events_played, @wins = wins, @losses = losses, @ties = ties
	  FROM SportsEditDB.dbo.SMG_Team_Records
	 WHERE season_key = @season_key
	   AND league_key = @leagueKey
	   AND team_key = @home_team_key
	 ORDER BY date_time_EST DESC;

	SELECT @events_played = ISNULL(@events_played, 0), @wins = ISNULL(@wins, 0), @losses = ISNULL(@losses, 0), @ties = ISNULL(@ties, 0);

	INSERT INTO @team_info (id, team_key, events_played, wins, losses, ties)
	SELECT 'home', @home_team_key, @events_played, @wins, @losses, @ties;

	SELECT TOP 1 @events_played = events_played, @wins = wins, @losses = losses, @ties = ties
	  FROM SportsEditDB.dbo.SMG_Team_Records
	 WHERE season_key = @season_key
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

	DECLARE @home_value VARCHAR(100), @away_value VARCHAR(100), @max_value VARCHAR(100);
	DECLARE @home_event_key VARCHAR(100), @away_event_key VARCHAR(100); 

	IF (@event_status = 'post-event')
	BEGIN
		SELECT @home_event_key = @event_key, @away_event_key = @event_key;

		UPDATE temp
		   SET temp.score = scores.[value]
		  FROM @team_info temp
		 INNER JOIN dbo.SMG_Scores scores
			ON scores.team_key = temp.team_key
		   AND scores.event_key = @event_key
		   AND scores.[column] = 'total';
	END
	ELSE
	BEGIN
		SELECT TOP 1 @home_event_key = event_key 
		  FROM dbo.SMG_Schedules 
		 WHERE season_key = @season_key
		   AND (home_team_key = @home_team_key or away_team_key = @home_team_key)
		   AND event_status = 'post-event'
		 ORDER BY start_date_time_EST DESC;

		SELECT TOP 1 @away_event_key = event_key 
		  FROM dbo.SMG_Schedules 
		 WHERE season_key = @season_key
		   AND (home_team_key = @away_team_key or away_team_key = @away_team_key)
		   AND event_status = 'post-event'
		 ORDER BY start_date_time_EST DESC;
	END

	UPDATE @team_info
	   SET score = ISNULL(score, '0');

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
				(SELECT max_value as max, [value], team_key, event_key, team_id, team_class_name, CONVERT(VARCHAR, CONVERT(DECIMAL(5,1), CONVERT(DECIMAL, [value])*100.0/CONVERT(DECIMAL, max_value))) + '%' as percentage
				  FROM @team_stat 
				 WHERE stat = info.name
				 ORDER BY CASE team_id WHEN 'away' THEN 0 ELSE 1 END
				   FOR XML RAW('stats'), TYPE
				)
		  FROM (SELECT DISTINCT UPPER(stat) AS name
				  FROM @team_stat 
				) info 
           FOR XML RAW('matchups'), TYPE
	)
    FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF
END 

GO
