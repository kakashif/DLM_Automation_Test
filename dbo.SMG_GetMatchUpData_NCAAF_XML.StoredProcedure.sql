USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetMatchUpData_NCAAF_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetMatchUpData_NCAAF_XML]
	@teamKey   VARCHAR(100)
AS
-- =============================================
-- Author:      Prashant Kamat
-- Create date: 02/12/2015
-- Description: Get Matchup Module for NCAAF
-- Update:	    02/23/2015 - pkamat: Filled stats same as NFL stats
-- 				02/25/2015 - pkamat: Changed team class
-- 				03/03/2015 - pkamat: Get week description for bowls
-- 				03/17/2015 - pkamat: Get season key from SMG_Statistics
-- 				03/19/2015 - pkamat: Remove team front url for Div 1 aa teams
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @leagueKey VARCHAR(100) = 'l.ncaa.org.mfoot', @leagueName VARCHAR(100) = 'ncaaf', @season_key INT, @event_key VARCHAR(100), @home_team_key VARCHAR(100), @away_team_key VARCHAR(100), @event_season_key INT;
	DECLARE @event_sub_season_key VARCHAR(100), @event_status VARCHAR(100), @week VARCHAR(100);

    SELECT TOP 1 @season_key = season_key
	  FROM SportsEditDB.dbo.SMG_Statistics
	 WHERE league_key = @leagueKey AND sub_season_type = 'season-regular' AND team_key = @teamKey
	 ORDER BY season_key DESC;

    SELECT @event_key = dbo.SMG_fnGetMatchupEventKeyByLeagueAndTeam(@leagueName, @teamKey);

/*
EVENTS
u'updated_date': u'12/7/2014', 
u'start_date_time': 'date_time': u'2014-12-06T19:30:00', u'time_zone': u'ET', 
u'week_of_season_label': u'Week 15', 
u'season_type': u'season-regular', 
u'updated_time': u'2:01 AM', 
u'game_status': u'Final', 
u'event_status': u'post-event', 
u'preview': u'pre-event-coverage', 
u'event_key': u'l.ncaa.org.mfoot-2014-e.44054'

TEAMS
[{'last_name': u'Owls', 'class_name': u'TEM', 'team_front_url': u'/sports/ncaaf/temple/', 'rank': None, 'ties': u'0', 'id': 'away', 'first_name': u'Temple', 'display_name': u'Temple', 'wins': u'6', 'losses': u'6', 'key_players': None, 'score': u'10', 'league_key': u'l.ncaa.org.mfoot'}, 
{'last_name': u'Green Wave', 'class_name': u'TULN', 'team_front_url': u'/sports/ncaaf/tulane/', 'rank': None, 'ties': u'0', 'id': 'home', 'first_name': u'Tulane', 'display_name': u'Tulane', 'wins': u'3', 'losses': u'9', 'key_players': None, 'score': u'3', 'league_key': u'l.ncaa.org.mfoot'}]

MATCHUPS
[{'stats': [{'max': 0, 'team_id': u'away', 'team_class_name': u'TEM', 'percentage': 0, 'value': 0}, {'max': 0, 'team_id': u'home', 'team_class_name': u'TULN', 'percentage': 0, 'value': 0}], 'name': u'TOTAL YARDS'}, 
'stats': [{'max': 0, 'team_id': u'away', 'team_class_name': u'TEM', 'percentage': 0, 'value': 0}, {'max': 0, 'team_id': u'home', 'team_class_name': u'TULN', 'percentage': 0, 'value': 0}], 'name': u'PASSING YARDS', 
'stats': [{'max': 207.0, 'team_id': u'away', 'team_class_name': u'TEM', 'percentage': '44%', 'value': 92.0}, {'max': 207.0, 'team_id': u'home', 'team_class_name': u'TULN', 'percentage': '56%', 'value': 115.0}], 'name': u'RUSHING YARDS']
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
		league_key		VARCHAR(100) DEFAULT 'l.ncaa.org.mfoot'
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


	SELECT @home_team_key = home_team_key, @away_team_key = away_team_key, @event_status = event_status, @event_season_key = season_key, @event_sub_season_key = sub_season_type, @week = REPLACE([week], '-', ' ')
	  FROM dbo.SMG_Schedules 
	 WHERE event_key = @event_key;

	IF (@event_sub_season_key = 'season-regular')
	BEGIN
		SELECT @week = 'Week ' + @week;
		SELECT @week = 'Week ' + ups.score
          FROM dbo.USAT_Post_Seasons ups
         WHERE ups.event_key = @event_key;
	END

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
	   SET temp.display_name = teams.team_display,first_name = teams.team_first,last_name = teams.team_last,class_name = teams.team_abbreviation,
			team_front_url = CASE
                                  WHEN teams.conference_key IS NULL OR teams.division_key IS NULL THEN ''
                                  ELSE '/sports/' + @leagueName + '/' + teams.team_slug + '/'
                             END,
			abbr = teams.team_abbreviation
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

	--PASSING YARDS
	SELECT @stat_name = 'passing yards per game';
	SELECT @home_value = [value]
	  FROM SportsEditDB.dbo.SMG_Statistics 
	 WHERE league_key = @leagueKey
	   AND season_key = @season_key
	   AND sub_season_type = 'season-regular'
	   AND team_key = @home_team_key
	   AND player_key = 'team'
	   AND category = 'feed'
	   AND [column] = 'passes-average-yards-per-game';

	SELECT @away_value = [value]
	  FROM SportsEditDB.dbo.SMG_Statistics 
	 WHERE league_key = @leagueKey
	   AND season_key = @season_key
	   AND sub_season_type = 'season-regular'
	   AND team_key = @away_team_key
	   AND player_key = 'team'
	   AND category = 'feed'
	   AND [column] = 'passes-average-yards-per-game';

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

	--RUSHING YARDS
	SELECT @home_value = NULL, @away_value = NULL;
	SELECT @stat_name = 'rushing yards per game';
	SELECT @home_value = [value]
	  FROM SportsEditDB.dbo.SMG_Statistics 
	 WHERE league_key = @leagueKey
	   AND season_key = @season_key
	   AND sub_season_type = 'season-regular'
	   AND team_key = @home_team_key
	   AND player_key = 'team'
	   AND category = 'feed'
	   AND [column] = 'rushes-average-yards-per-game';

	SELECT @away_value = [value]
	  FROM SportsEditDB.dbo.SMG_Statistics 
	 WHERE league_key = @leagueKey
	   AND season_key = @season_key
	   AND sub_season_type = 'season-regular'
	   AND team_key = @away_team_key
	   AND player_key = 'team'
	   AND category = 'feed'
	   AND [column] = 'rushes-average-yards-per-game';

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

	--TOTAL YARDS
	SELECT @home_value = NULL, @away_value = NULL;
	SELECT @stat_name = 'total yards per game';
	SELECT @home_value = SUM(CONVERT(FLOAT, [value]))
	  FROM @team_stat 
	 WHERE team_key = @home_team_key;

	SELECT @away_value = SUM(CONVERT(FLOAT, [value]))
	  FROM @team_stat 
	 WHERE team_key = @away_team_key;

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
        SELECT event_key, sub_season_type, game_status, event_status, site_name, @week as week_of_season_label,
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
