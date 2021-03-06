USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[LOC_Event_Matchup_basketball_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[LOC_Event_Matchup_basketball_XML]
    @leagueName VARCHAR(100),
    @eventKey VARCHAR(100)
AS
-- =============================================
-- Author:      John Lin
-- Create date: 10/15/2015
-- Description: get basketball event details for USCP
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 
    
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @season_key INT
    DECLARE @sub_season_type VARCHAR(100)
    DECLARE @date_time VARCHAR(100)
    DECLARE @event_status VARCHAR(100)
    DECLARE @game_status VARCHAR(100)
    DECLARE @away_key VARCHAR(100)
    DECLARE @away_id VARCHAR(100)
    DECLARE @away_score INT
    DECLARE @home_key VARCHAR(100)
    DECLARE @home_id VARCHAR(100)
    DECLARE @home_score INT
    DECLARE @coverage VARCHAR(MAX)
    DECLARE @venue VARCHAR(100)
    -- extra
    DECLARE @dt DATETIME
    

    SELECT @season_key = season_key, @sub_season_type = sub_season_type, @dt = start_date_time_EST, @event_status = event_status, @game_status = game_status,
           @venue = site_name, @away_key = away_team_key, @home_key = home_team_key, @away_score = away_team_score, @home_score = home_team_score
      FROM dbo.SMG_Schedules
     WHERE event_key = @eventKey

    SET @away_id = dbo.SMG_fnEventId(@away_key)
    SET @home_id = dbo.SMG_fnEventId(@home_key)

    SET @date_time = CAST(DATEPART(MONTH, @dt) AS VARCHAR) + '/' +
                     CAST(DATEPART(DAY, @dt) AS VARCHAR) + '/' +
                     CAST(DATEPART(YEAR, @dt) AS VARCHAR) + ' ' +
                     CASE WHEN DATEPART(HOUR, @dt) > 12 THEN CAST(DATEPART(HOUR, @dt) - 12 AS VARCHAR) ELSE CAST(DATEPART(HOUR, @dt) AS VARCHAR) END + ':' +
                     CASE WHEN DATEPART(MINUTE, @dt) < 10 THEN  '0' ELSE '' END + CAST(DATEPART(MINUTE, @dt) AS VARCHAR) + ' ' +
                     CASE WHEN DATEPART(HOUR, @dt) < 12 THEN 'AM' ELSE 'PM' END
    
    DECLARE @info TABLE
    (
        team_key VARCHAR(100),
        column_type VARCHAR(100),
        [column] VARCHAR(100),
        value VARCHAR(MAX)
    )
    INSERT INTO @info (team_key, column_type, [column], value)
    SELECT team_key, column_type, [column], value
      FROM dbo.SMG_Scores
     WHERE event_key = @eventKey

    DECLARE @linescore TABLE
    (
        period INT,
        period_value VARCHAR(100),
        away_value VARCHAR(100),
        home_value VARCHAR(100)
    )
    INSERT INTO @linescore (period, period_value, away_value, home_value)
    SELECT period, period_value, away_value, home_value
      FROM dbo.SMG_Periods
     WHERE event_key = @eventKey AND period_value <> 'Score'

    IF NOT EXISTS (SELECT 1 FROM @linescore)
    BEGIN
        INSERT INTO @linescore (period, period_value)
        VALUES (1, '1'), (2, '2'), (3, '3'), (4, '4')
    END
    ELSE
    BEGIN
      -- extra quarters
      IF EXISTS (SELECT 1 FROM @linescore WHERE period_value = 'OT')
      BEGIN
          UPDATE l
             SET l.away_value = i.value
            FROM @linescore l
           INNER JOIN @info i
              ON i.column_type = 'period' AND i.[column] = '5' AND i.team_key = @away_key
           WHERE l.period_value = 'OT'

          UPDATE l
             SET l.home_value = i.value
            FROM @linescore l
           INNER JOIN @info i
              ON i.column_type = 'period' AND i.[column] = '5' AND i.team_key = @home_key           
           WHERE l.period_value = 'OT'
        END
    END

    -- leaders
    DECLARE @columns TABLE
    (
        team_key VARCHAR(100),
        player_key VARCHAR(100),
        category VARCHAR(100),
        [column] VARCHAR(100),
        value VARCHAR(100)
    )
    INSERT INTO @columns (team_key, player_key, category, [column], value)
    SELECT f.team_key, f.player_key, l.category, f.[column], f.value 
      FROM SportsEditDB.dbo.SMG_Events_basketball f
     INNER JOIN dbo.SMG_Events_Leaders l
        ON l.event_key = f.event_key AND l.team_key = f.team_key AND l.player_key = f.player_key AND l.category = 'POINTS'
     WHERE f.event_key = @eventKey AND f.[column] IN ('points')

    INSERT INTO @columns (team_key, player_key, category, [column], value)
    SELECT f.team_key, f.player_key, l.category, f.[column], f.value 
      FROM SportsEditDB.dbo.SMG_Events_basketball f
     INNER JOIN dbo.SMG_Events_Leaders l
        ON l.event_key = f.event_key AND l.team_key = f.team_key AND l.player_key = f.player_key AND l.category = 'ASSISTS'
     WHERE f.event_key = @eventKey AND f.[column] IN ('assists')

    INSERT INTO @columns (team_key, player_key, category, [column], value)
    SELECT f.team_key, f.player_key, l.category, f.[column], f.value 
      FROM SportsEditDB.dbo.SMG_Events_basketball f
     INNER JOIN dbo.SMG_Events_Leaders l
        ON l.event_key = f.event_key AND l.team_key = f.team_key AND l.player_key = f.player_key AND l.category = 'REBOUNDS'
     WHERE f.event_key = @eventKey AND f.[column] IN ('rebounds_offensive', 'rebounds_defensive')

    DECLARE @leaders TABLE
    (
        team_key VARCHAR(100),
        player_key VARCHAR(100),
        player_id VARCHAR(100),
        category VARCHAR(100),
        points INT,
        assists INT,
        rebounds_offensive INT,
        rebounds_defensive INT,
        [rebounds-total] INT
    )
    INSERT INTO @leaders (team_key, player_key, category, points, assists, rebounds_offensive, rebounds_defensive)
    SELECT p.team_key, p.player_key, p.category, ISNULL(points, 0), ISNULL(assists, 0), ISNULL(rebounds_offensive, 0), ISNULL(rebounds_defensive , 0)
      FROM (SELECT team_key, player_key, category, [column], value FROM @columns) AS c
     PIVOT (MAX(c.value) FOR c.[column] IN (points, assists, rebounds_offensive, rebounds_defensive)) AS p

    UPDATE @leaders
       SET player_id = dbo.SMG_fnEventId(player_key),
           [rebounds-total] = (rebounds_offensive + rebounds_defensive)

    -- plays
    IF (@event_status = 'pre-event')
    BEGIN
        SELECT @coverage = value
          FROM @info
         WHERE column_type = 'pre-event-coverage'
    END
    ELSE
    BEGIN
        SELECT @coverage = value
          FROM @info
         WHERE column_type = 'post-event-coverage'
    END

 

    SELECT
	(
        SELECT @away_key AS away_key, @away_id AS away_id, @home_key AS home_key, @home_id AS home_id, @away_score AS away_score, @home_score AS home_score,
               @date_time AS date_time, @game_status AS game_status, @venue AS venue, ISNULL(@coverage, '') AS coverage, '' AS sequence_number,
		       (
                   SELECT period_value AS headings
                     FROM @linescore
                    ORDER BY period ASC
                      FOR XML PATH(''), TYPE
               ),
               (
                   SELECT away_value AS away_scores
                     FROM @linescore
                    ORDER BY period ASC
                      FOR XML PATH(''), TYPE
               ),
               (
                   SELECT home_value AS home_scores
                     FROM @linescore
                    ORDER BY period ASC
                      FOR XML PATH(''), TYPE
               ),
               (
                   SELECT
                   (
                       SELECT 
                       (
                           SELECT player_id, points
                             FROM @leaders
                            WHERE team_key = @away_key AND category = 'POINTS'
                              FOR XML RAW('points'), TYPE                        
                       ),
                       (
                           SELECT player_id, assists
                             FROM @leaders
                            WHERE team_key = @away_key AND category = 'ASSISTS'
                              FOR XML RAW('assists'), TYPE                        
                       ),
                       (
                           SELECT player_id, [rebounds-total] AS rebounds
                             FROM @leaders
                            WHERE team_key = @away_key AND category = 'REBOUNDS'
                              FOR XML RAW('rebounds'), TYPE                        
                       )
                       FOR XML RAW('away'), TYPE
                   ),
                   (
                       SELECT 
                       (
                           SELECT player_id, points
                             FROM @leaders
                            WHERE team_key = @home_key AND category = 'POINTS'
                              FOR XML RAW('points'), TYPE                        
                       ),
                       (
                           SELECT player_id, assists
                             FROM @leaders
                            WHERE team_key = @home_key AND category = 'ASSISTS'
                              FOR XML RAW('assists'), TYPE                        
                       ),
                       (
                           SELECT player_id, [rebounds-total] AS rebounds
                             FROM @leaders
                            WHERE team_key = @home_key AND category = 'REBOUNDS'
                              FOR XML RAW('rebounds'), TYPE                        
                       )
                       FOR XML RAW('home'), TYPE
                   )
                   FOR XML RAW('leaders'), TYPE
               )
           FOR XML RAW('gamecast'), TYPE
	)
    FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF;
END

GO
