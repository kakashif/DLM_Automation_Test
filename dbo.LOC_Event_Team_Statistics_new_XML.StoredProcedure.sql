USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[LOC_Event_Team_Statistics_new_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[LOC_Event_Team_Statistics_new_XML] 
    @leagueName VARCHAR(100),
    @eventId INT
AS
-- =============================================
-- Author:      John Lin
-- Create date: 05/12/2015
-- Description: get event team statistics for USCP
-- Update: 06/23/2015 - John Lin - STATS migration
--         10/15/2015 - John Lin - SDI migration
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
     
    DECLARE @stats TABLE
    (
        team_key VARCHAR(100),
        [column] VARCHAR(100), 
        value    VARCHAR(100)
    )
    
    IF (@leagueName = 'mlb')
    BEGIN
        INSERT INTO @stats (team_key, [column], value)
        SELECT team_key, [column], value 
          FROM SportsEditDB.dbo.SMG_Events_baseball
         WHERE event_key = @event_key AND player_key = 'team'

    	DECLARE @baseball TABLE
	    (
            team_key VARCHAR(100),
            [home-runs] INT,
            [doubles] INT,
            [triples] INT,
            [rbi] INT,
            [bases-on-balls] INT,
            [stolen-bases] INT,
            [stolen-bases-caught] INT,
            [slugging-percentage] VARCHAR(100),
            [batting-average] VARCHAR(100),
            [outs-pitched] INT,
            [strikeouts] INT,
            [errors-wild-pitch] INT,
            [errors-hit-with-pitch] INT,
            [earned-runs] INT
        )
        INSERT INTO @baseball (team_key, [home-runs], [doubles], [triples], [rbi], [bases-on-balls], [stolen-bases],
                               [stolen-bases-caught], [slugging-percentage], [batting-average], [outs-pitched], [strikeouts],
                               [errors-wild-pitch], [errors-hit-with-pitch], [earned-runs])
        SELECT p.team_key, ISNULL([home-runs], 0), ISNULL([doubles], 0), ISNULL([triples], 0), ISNULL([rbi], 0), ISNULL([bases-on-balls], 0),
               ISNULL([stolen-bases], 0), ISNULL([stolen-bases-caught], 0), [slugging-percentage], [batting-average], ISNULL([outs-pitched], 0),
               ISNULL([strikeouts], 0), ISNULL([errors-wild-pitch], 0), ISNULL([errors-hit-with-pitch], 0), ISNULL([earned-runs], 0)
          FROM (SELECT team_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([home-runs], [doubles], [triples], [rbi], [bases-on-balls], [stolen-bases],
                                                [stolen-bases-caught], [slugging-percentage], [batting-average], [outs-pitched], [strikeouts],
                                                [errors-wild-pitch], [errors-hit-with-pitch], [earned-runs])) AS p
 


        SELECT
	    (
		    SELECT @away_key AS away_key, @home_key AS home_key, @away_score AS away_score, @home_score AS home_score,
                   @date_time AS date_time, @game_status AS game_status,
    		       (
                       SELECT [home-runs], [doubles], [triples], [rbi], [bases-on-balls], [stolen-bases],
                              [stolen-bases-caught], [slugging-percentage], [batting-average], [outs-pitched], [strikeouts],
                              [errors-wild-pitch], [errors-hit-with-pitch], [earned-runs]
                         FROM @baseball
                        WHERE team_key = @away_key
                          FOR XML PATH('away'), TYPE
                   ),
                   (
                       SELECT [home-runs], [doubles], [triples], [rbi], [bases-on-balls], [stolen-bases],
                              [stolen-bases-caught], [slugging-percentage], [batting-average], [outs-pitched], [strikeouts],
                              [errors-wild-pitch], [errors-hit-with-pitch], [earned-runs]
                         FROM @baseball
                        WHERE team_key = @home_key
                          FOR XML PATH('home'), TYPE
                   )
    		   FOR XML PATH('stats'), TYPE
	    )
    	FOR XML PATH(''), ROOT('root')
    END
    ELSE IF (@leagueName IN ('nba', 'wnba', 'ncaab', 'ncaaw'))
    BEGIN
        INSERT INTO @stats (team_key, [column], value)
        SELECT team_key, [column], value 
          FROM SportsEditDB.dbo.SMG_Events_basketball
         WHERE event_key = @event_key AND player_key = 'team'

    	DECLARE @basketball TABLE
	    (
            team_key VARCHAR(100),
            field_goals_attempted INT,
            field_goals_made INT,
            three_point_field_goals_attempted INT,
            three_point_field_goals_made INT,
            free_throws_attempted INT,
            free_throws_made INT,
            rebounds_defensive INT,
            rebounds_offensive INT,
            rebounds_team INT,
            rebounds INT,
            assists INT,
            steals INT,
            blocks INT,
            turnovers INT,
            points_fast_break INT,
            fouls_personal INT,
            fouls_technical INT,
            fouls INT
        )
        INSERT INTO @basketball (team_key, field_goals_attempted, field_goals_made, three_point_field_goals_attempted, three_point_field_goals_made, 
                                 free_throws_attempted, free_throws_made, rebounds_defensive, rebounds_offensive, rebounds_team,
                                 assists, steals, blocks, turnovers, points_fast_break, fouls_personal, fouls_technical)
        SELECT p.team_key, ISNULL(field_goals_attempted, 0), ISNULL(field_goals_made, 0), ISNULL(three_point_field_goals_attempted, 0), ISNULL(three_point_field_goals_made, 0), 
               ISNULL(free_throws_attempted, 0), ISNULL(free_throws_made, 0), ISNULL(rebounds_defensive, 0), ISNULL(rebounds_offensive, 0), ISNULL(rebounds_team, 0),
               ISNULL(assists, 0), ISNULL(steals, 0), ISNULL(blocks, 0), ISNULL(turnovers, 0), ISNULL(points_fast_break, 0), ISNULL(fouls_personal, 0), ISNULL(fouls_technical, 0)
          FROM (SELECT team_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN (field_goals_attempted, field_goals_made, three_point_field_goals_attempted, three_point_field_goals_made, 
                                                free_throws_attempted, free_throws_made, rebounds_defensive, rebounds_offensive, rebounds_team,
                                                assists, steals, blocks, turnovers, points_fast_break, fouls_personal, fouls_technical)) AS p
 
        UPDATE @basketball
           SET rebounds = (rebounds_defensive + rebounds_offensive + rebounds_team),
               fouls = (fouls_personal + fouls_technical)


        SELECT
	    (
		    SELECT @away_key AS away_key, @home_key AS home_key, @away_score AS away_score, @home_score AS home_score,
                   @date_time AS date_time, @game_status AS game_status,
    		       (
                       SELECT field_goals_attempted AS shooting_attempts, field_goals_made AS shooting_made,
                              three_point_field_goals_attempted AS threept_shooting_attempts, three_point_field_goals_made AS threept_shooting_made, 
                              free_throws_attempted AS free_throws_attempts, free_throws_made, rebounds,
                              assists, steals, blocks, turnovers, points_fast_break AS fast_break_pts, fouls
                         FROM @basketball
                        WHERE team_key = @away_key
                          FOR XML PATH('away'), TYPE
                   ),
                   (
                       SELECT field_goals_attempted AS shooting_attempts, field_goals_made AS shooting_made,
                              three_point_field_goals_attempted AS threept_shooting_attempts, three_point_field_goals_made AS threept_shooting_made, 
                              free_throws_attempted AS free_throws_attempts, free_throws_made, rebounds,
                              assists, steals, blocks, turnovers, points_fast_break AS fast_break_pts, fouls
                         FROM @basketball
                        WHERE team_key = @home_key
                          FOR XML PATH('home'), TYPE
                   )
    		   FOR XML PATH('stats'), TYPE
	    )
    	FOR XML PATH(''), ROOT('root')
    END
    
    SET NOCOUNT OFF;
END

GO
