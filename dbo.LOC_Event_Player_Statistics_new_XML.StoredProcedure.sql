USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[LOC_Event_Player_Statistics_new_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[LOC_Event_Player_Statistics_new_XML] 
    @leagueName VARCHAR(100),
    @eventId INT,
    @teamSlug VARCHAR(100)
AS
-- =============================================
-- Author:      John Lin
-- Create date: 05/12/2015
-- Description: get event player statistics for USCP
-- Update: 06/23/2015 - John Lin - STATS migration
--         08/20/2015 - John Lin - SDI migration
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    IF (@leagueName NOT IN ('mlb', 'mls', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba'))
    BEGIN
        RETURN
    END


    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @season_key INT
    DECLARE @event_key VARCHAR(100)
    DECLARE @date_time VARCHAR(100)
    DECLARE @game_status VARCHAR(100)
    DECLARE @away_key VARCHAR(100)
    DECLARE @away_score INT
    DECLARE @home_key VARCHAR(100)
    DECLARE @home_score INT
    -- extra
    DECLARE @dt DATETIME
    DECLARE @team_key VARCHAR(100)

    SELECT TOP 1 @season_key = season_key, @event_key = event_key, @dt = start_date_time_EST, @game_status = game_status,
           @away_key = away_team_key, @home_key = home_team_key, @away_score = away_team_score, @home_score = home_team_score
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
     
    SET @date_time = CAST(DATEPART(MONTH, @dt) AS VARCHAR) + '/' +
                     CAST(DATEPART(DAY, @dt) AS VARCHAR) + '/' +
                     CAST(DATEPART(YEAR, @dt) AS VARCHAR) + ' ' +
                     CASE WHEN DATEPART(HOUR, @dt) > 12 THEN CAST(DATEPART(HOUR, @dt) - 12 AS VARCHAR) ELSE CAST(DATEPART(HOUR, @dt) AS VARCHAR) END + ':' +
                     CASE WHEN DATEPART(MINUTE, @dt) < 10 THEN  '0' ELSE '' END + CAST(DATEPART(MINUTE, @dt) AS VARCHAR) + ' ' +
                     CASE WHEN DATEPART(HOUR, @dt) < 12 THEN 'AM' ELSE 'PM' END

    SELECT @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @season_key AND team_slug = @teamSlug

    -- All-Stars
    IF (@leagueName = 'nfl')
    BEGIN
        IF (@teamSlug = 'al')
        BEGIN
            SET @team_key = '321'
        END
        
        IF (@teamSlug = 'nl')
        BEGIN
            SET @team_key = '322'
        END
    END
     
    DECLARE @stats TABLE
    (
        player_key VARCHAR(100),
        [column]   VARCHAR(100), 
        value      VARCHAR(100)
    )
    
    IF (@leagueName IN ('nfl', 'ncaaf'))
    BEGIN
        INSERT INTO @stats (player_key, [column], value)
        SELECT player_key, [column], value 
          FROM SportsEditDB.dbo.SMG_Events_football
         WHERE event_key = @event_key AND team_key = @team_key AND player_key <> 'team'

    	DECLARE @football TABLE
	    (
		    player_key VARCHAR(100),
            -- passing
            passing_plays_completed INT,
            passing_plays_attempted INT,
            passing_yards INT,
            passing_touchdowns INT,
            passing_plays_intercepted INT,
            -- rushing            
            rushing_plays INT,
            rushing_net_yards INT,
            [rushing-average-yards] VARCHAR(100),
            rushing_touchdowns INT,
            -- receiving
            receiving_receptions INT,
            receiving_yards INT,
            [receiving-average-yards] VARCHAR(100),
            receiving_touchdowns INT,
            -- extra
		    player_id VARCHAR(100)
    	)	
        INSERT INTO @football (player_key,
                               passing_plays_completed, passing_plays_attempted, passing_yards, passing_touchdowns, passing_plays_intercepted,
                               rushing_plays, rushing_net_yards, rushing_touchdowns,
                               receiving_receptions, receiving_yards, receiving_touchdowns)
        SELECT p.player_key,
               ISNULL(passing_plays_completed, 0), ISNULL(passing_plays_attempted, 0), ISNULL(passing_yards, 0), ISNULL(passing_touchdowns, 0), ISNULL(passing_plays_intercepted, 0),
               ISNULL(rushing_plays, 0), ISNULL(rushing_net_yards, 0), ISNULL(rushing_touchdowns, 0),
               ISNULL(receiving_receptions, 0), ISNULL(receiving_yards, 0), ISNULL(receiving_touchdowns, 0)
          FROM (SELECT player_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN (passing_plays_completed, passing_plays_attempted, passing_yards, passing_touchdowns, passing_plays_intercepted,
                                                rushing_plays, rushing_net_yards, rushing_touchdowns,
                                                receiving_receptions, receiving_yards, receiving_touchdowns)) AS p

        UPDATE @football
           SET [rushing-average-yards] = CAST((CAST(rushing_net_yards AS FLOAT) / rushing_plays) AS DECIMAL(4,1))
         WHERE rushing_plays > 0

        UPDATE @football
           SET [receiving-average-yards] = CAST((CAST(receiving_yards AS FLOAT) / receiving_receptions) AS DECIMAL(4,1))
         WHERE receiving_receptions > 0

        UPDATE @football
           SET player_id = dbo.SMG_fnEventId(player_key)



        ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
        SELECT
    	(
	    	SELECT @away_key AS away_key, @home_key AS home_key, @away_score AS away_score, @home_score AS home_score,
                   @date_time AS date_time, @game_status AS game_status,
		           (
                       SELECT 'true' AS 'json:Array',
                              player_id, passing_plays_completed AS completions, passing_plays_attempted AS attempts, passing_yards AS total_yards,
                              passing_touchdowns AS touchdowns, passing_plays_intercepted AS interceptions
                         FROM @football
                        WHERE passing_plays_attempted > 0
                        ORDER BY passing_yards DESC
                          FOR XML RAW('passing'), TYPE
                   ),
                   (
                       SELECT 'true' AS 'json:Array',
                              player_id, rushing_plays AS carries, rushing_net_yards AS total_yards, [rushing-average-yards] AS average,
                              rushing_touchdowns AS touchdowns
                         FROM @football
                        WHERE rushing_plays > 0
                        ORDER BY rushing_net_yards DESC
                          FOR XML RAW('rushing'), TYPE
                   ),
                   (
                       SELECT 'true' AS 'json:Array',
                              player_id, receiving_receptions AS receptions, receiving_yards AS total_yards, [receiving-average-yards] AS average,
                              receiving_touchdowns AS touchdowns
                         FROM @football
                        WHERE receiving_receptions > 0
                        ORDER BY receiving_yards DESC
                          FOR XML RAW('receiving'), TYPE
                   )
    		   FOR XML RAW('players'), TYPE
	    )
    	FOR XML PATH(''), ROOT('root')
    END
    ELSE IF (@leagueName IN ('nba', 'wnba', 'ncaab', 'ncaaw'))
    BEGIN
        INSERT INTO @stats (player_key, [column], value)
        SELECT player_key, [column], value 
          FROM SportsEditDB.dbo.SMG_Events_basketball
         WHERE event_key = @event_key AND team_key = @team_key AND player_key <> 'team'

    	DECLARE @basketball TABLE
	    (
		    player_key VARCHAR(100),
            seconds_played INT,
            [minutes] INT,
            field_goals_attempted INT,
            field_goals_made INT,
            three_point_field_goals_attempted INT,
            three_point_field_goals_made INT,
            rebounds_defensive INT,
            rebounds_offensive INT,
            rebounds INT,
            assists INT,
            blocks INT,
            turnovers INT,
            fouls_personal INT,
            points INT,
            -- extra
		    player_id VARCHAR(100)
    	)	
        INSERT INTO @basketball (player_key, seconds_played, field_goals_attempted, field_goals_made,
                                 three_point_field_goals_attempted, three_point_field_goals_made,
                                 rebounds_defensive, rebounds_offensive, assists, blocks, turnovers, fouls_personal, points)
        SELECT p.player_key,
               ISNULL(seconds_played, 0), ISNULL(field_goals_attempted, 0), ISNULL(field_goals_made, 0),
               ISNULL(three_point_field_goals_attempted, 0), ISNULL(three_point_field_goals_made, 0),
               ISNULL(rebounds_defensive, 0), ISNULL(rebounds_offensive, 0), ISNULL(assists, 0), ISNULL(blocks, 0), ISNULL(turnovers, 0), ISNULL(fouls_personal, 0), ISNULL(points, 0)
          FROM (SELECT player_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN (seconds_played, field_goals_attempted, field_goals_made,
                                                three_point_field_goals_attempted, three_point_field_goals_made,
                                                rebounds_defensive, rebounds_offensive, assists, blocks, turnovers, fouls_personal, points)) AS p

        UPDATE @basketball
           SET [minutes] = (seconds_played / 60),
               rebounds = (rebounds_offensive + rebounds_defensive),
               player_id = dbo.SMG_fnEventId(player_key)



        ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
        SELECT
    	(
	    	SELECT @team_key AS team_key, @away_score AS away_score, @home_score AS home_score,
                   @date_time AS date_time, @game_status AS game_status,
		           (
                       SELECT 'true' AS 'json:Array',
                              player_id, [minutes], field_goals_attempted AS field_goals_attempts, field_goals_made,
                                 three_point_field_goals_attempted AS three_points_attempts, three_point_field_goals_made AS three_points_made,
                                 rebounds, assists, blocks, turnovers, fouls_personal AS personal_fouls, points
                         FROM @basketball
                        ORDER BY points DESC
                          FOR XML RAW('stats'), TYPE
                   )
    		   FOR XML RAW('players'), TYPE
	    )
    	FOR XML PATH(''), ROOT('root')
    END
    
    SET NOCOUNT OFF;
END

GO
