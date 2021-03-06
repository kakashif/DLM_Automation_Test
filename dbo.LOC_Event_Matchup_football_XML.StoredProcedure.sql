USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[LOC_Event_Matchup_football_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[LOC_Event_Matchup_football_XML]
    @leagueName VARCHAR(100),
    @eventKey VARCHAR(100)
AS
-- =============================================
-- Author:      John Lin
-- Create date: 08/10/2015
-- Description: get football event details for USCP
-- Update: 09/28/2015 - John Lin - timeout count
--         10/03/2015 - John Lin - NCAAF use SMG_Transient
--         10/15/2015 - John Lin - tighter logic for leaders
--         10/18/2015 - John Lin - fix bug
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
    
    -- calculate
    DECLARE @away_timeouts INT
    DECLARE @home_timeouts INT
    -- drive
    DECLARE @team_key VARCHAR(100)
    DECLARE @total_yards INT
    DECLARE @number_of_plays INT
    DECLARE @time_of_possession VARCHAR(100)
    -- play
    DECLARE @period_value INT
    DECLARE @sequence_number INT
    DECLARE @down VARCHAR(100)
    DECLARE @yards_to_go VARCHAR(100)
    DECLARE @first_down_position INT
    DECLARE @initial_position INT
    DECLARE @initial_yard_line VARCHAR(100)
    DECLARE @initial_field_key VARCHAR(100)
    DECLARE @resulting_position INT
    DECLARE @resulting_yard_line INT
    DECLARE @resulting_field_key VARCHAR(100)
    DECLARE @play_type VARCHAR(100)
    DECLARE @scoring_type VARCHAR(100)
    DECLARE @narrative VARCHAR(MAX)
    -- extra
    DECLARE @drive_number INT


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
      FROM SportsEditDB.dbo.SMG_Events_football f
     INNER JOIN dbo.SMG_Events_Leaders l
        ON l.event_key = f.event_key AND l.team_key = f.team_key AND l.player_key = f.player_key AND l.category = 'PASSING'
     WHERE f.event_key = @eventKey AND f.[column] IN ('passing_yards', 'passing_plays_attempted', 'passing_plays_completed', 'passing_touchdowns', 'passing_plays_intercepted')

    INSERT INTO @columns (team_key, player_key, category, [column], value)
    SELECT f.team_key, f.player_key, l.category, f.[column], f.value 
      FROM SportsEditDB.dbo.SMG_Events_football f
     INNER JOIN dbo.SMG_Events_Leaders l
        ON l.event_key = f.event_key AND l.team_key = f.team_key AND l.player_key = f.player_key AND l.category = 'RUSHING'
     WHERE f.event_key = @eventKey AND f.[column] IN ('rushing_net_yards', 'rushing_plays', 'rushing_touchdowns')

    INSERT INTO @columns (team_key, player_key, category, [column], value)
    SELECT f.team_key, f.player_key, l.category, f.[column], f.value 
      FROM SportsEditDB.dbo.SMG_Events_football f
     INNER JOIN dbo.SMG_Events_Leaders l
        ON l.event_key = f.event_key AND l.team_key = f.team_key AND l.player_key = f.player_key AND l.category = 'RECEIVING'
     WHERE f.event_key = @eventKey AND f.[column] IN ('receiving_yards', 'receiving_receptions', 'receiving_touchdowns')

    DECLARE @leaders TABLE
    (
        team_key VARCHAR(100),
        player_key VARCHAR(100),
        player_id VARCHAR(100),
        category VARCHAR(100),
        passing_plays_attempted INT,
        passing_plays_completed INT,
        passing_yards INT,
        passing_touchdowns INT,
        rushing_plays INT,
        rushing_net_yards INT,
        rushing_average VARCHAR(100),
        rushing_touchdowns INT,
        receiving_receptions INT,
        receiving_yards INT,
        receiving_average VARCHAR(100),
        receiving_touchdowns INT
    )
    INSERT INTO @leaders (team_key, player_key, category,
                          passing_plays_attempted, passing_plays_completed, passing_yards, passing_touchdowns,
                          rushing_plays, rushing_net_yards, rushing_touchdowns,
                          receiving_receptions, receiving_yards, receiving_touchdowns)
    SELECT p.team_key, p.player_key, p.category,
           ISNULL(passing_plays_attempted, 0), ISNULL(passing_plays_completed, 0), ISNULL(passing_yards, 0), ISNULL(passing_touchdowns, 0),
           ISNULL(rushing_plays, 0), ISNULL(rushing_net_yards, 0), ISNULL(rushing_touchdowns, 0),
           ISNULL(receiving_receptions, 0), ISNULL(receiving_yards, 0), ISNULL(receiving_touchdowns, 0)
      FROM (SELECT team_key, player_key, category, [column], value FROM @columns) AS c
     PIVOT (MAX(c.value) FOR c.[column] IN (passing_plays_attempted, passing_plays_completed, passing_yards, passing_touchdowns,
                                            rushing_plays, rushing_net_yards, rushing_touchdowns,
                                            receiving_receptions, receiving_yards, receiving_touchdowns)) AS p

    UPDATE @leaders
       SET player_id = dbo.SMG_fnEventId(player_key)

    UPDATE @leaders
       SET rushing_average = CAST((CAST(rushing_net_yards AS FLOAT) / rushing_plays) AS DECIMAL(4,1))
     WHERE rushing_plays > 0

    UPDATE @leaders
       SET receiving_average = CAST((CAST(receiving_yards AS FLOAT) / receiving_receptions) AS DECIMAL(4,1))
     WHERE receiving_receptions > 0
     
    -- plays
    IF (@event_status = 'mid-event')
    BEGIN
        IF (@leagueName = 'ncaaf')
        BEGIN
            SELECT TOP 1 @team_key = team_key, @down = ISNULL(down, ''), @yards_to_go = ISNULL(distance_1st_down, ''), @initial_yard_line = ISNULL(field_line, ''),
                         @initial_field_key = CASE
                                                  WHEN field_side = 'away' THEN @away_key
                                                  WHEN field_side = 'home' THEN @home_key
                                                  ELSE ''
                                              END
              FROM dbo.SMG_Transient
             WHERE event_key = @eventKey
        END
        ELSE
        BEGIN
            SELECT TOP 1 @sequence_number = sequence_number, @drive_number = drive_number, @down = down, @yards_to_go = yards_to_go,
                         @initial_position = initial_position, @initial_yard_line = initial_yard_line, @initial_field_key = initial_field_key,
                         @resulting_position = resulting_position, @resulting_yard_line = resulting_yard_line, @resulting_field_key = resulting_field_key,
                         @play_type = play_type, @scoring_type = scoring_type, @narrative = narrative
              FROM dbo.USCP_football_plays
             WHERE event_key = @eventKey
             ORDER BY sequence_number DESC

            SELECT @team_key = team_key, @total_yards = total_yards, @number_of_plays = number_of_plays, @time_of_possession = time_of_possession
              FROM dbo.USCP_football_drives
             WHERE event_key = @eventKey AND drive_number = @drive_number

            SET @first_down_position = CASE
                                           WHEN @team_key = @away_key THEN (@initial_position + CAST(@yards_to_go AS INT))
                                           ELSE (@initial_position - CAST(@yards_to_go AS INT))
                                       END

            IF (@scoring_type IS NULL )
            BEGIN
                SET @scoring_type = ''
            END

            -- timeout
            DECLARE @timeout TABLE
            (
                sequence_number INT,
                team_key VARCHAR(100),
                period_value INT
            )

            INSERT INTO @timeout (sequence_number, team_key)
            SELECT sequence_number, value
              FROM dbo.SMG_Plays_Info
             WHERE event_key = @eventKey AND play_type = 'team_timeout' AND [column] = 'team_key'

            UPDATE t 
               SET t.period_value = CAST(i.value AS INT)
              FROM @timeout t
             INNER JOIN dbo.SMG_Plays_Info i
                ON i.event_key = @eventKey AND i.sequence_number = t.sequence_number AND i.[column] = 'period_value'

            SELECT TOP 1 @period_value = period_value
              FROM dbo.SMG_Plays_NFL
             WHERE event_key = @eventKey
             ORDER BY sequence_number DESC

            IF (@period_value IN (3, 4))
            BEGIN
                DELETE @timeout
                 WHERE period_value IN (1, 2)
            END

            SELECT @away_timeouts = COUNT(*)
              FROM @timeout
             WHERE team_key = @away_key

            SELECT @home_timeouts = COUNT(*)
              FROM @timeout
             WHERE team_key = @home_key
 
            SET @away_timeouts = (3 - @away_timeouts)
            SET @home_timeouts = (3 - @home_timeouts)
        END
    END
    ELSE
    BEGIN
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
    END  

 


    SELECT
	(
        SELECT @away_key AS away_key, @away_id AS away_id, @home_key AS home_key, @home_id AS home_id, @away_score AS away_score, @home_score AS home_score,
               @date_time AS date_time, @game_status AS game_status, @venue AS venue, ISNULL(@coverage, '') AS coverage, 
		       @away_timeouts AS away_timeouts, @home_timeouts AS home_timeouts,
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
                   SELECT @team_key AS team_key, @total_yards AS total_yards, @number_of_plays AS number_of_plays, @time_of_possession AS time_of_possession,
                          @sequence_number AS sequence_number, @down AS down, @yards_to_go AS yards_to_go, @first_down_position AS first_down_position,
                          @initial_position AS initial_position, @initial_yard_line AS initial_yard_line, @initial_field_key AS initial_field_key,                          
                          @resulting_position AS resulting_position, @resulting_yard_line AS resulting_yard_line, @resulting_field_key AS resulting_field_key,
                          @play_type AS play_type, @scoring_type AS scoring_type, @narrative AS narrative
                      FOR XML RAW('play'), TYPE
               ),
               (
                   SELECT
                   (
                       SELECT 
                       (
                           SELECT player_id, passing_plays_attempted AS attempts, passing_plays_completed AS completions, passing_yards AS total_yards, passing_touchdowns AS touchdowns
                             FROM @leaders
                            WHERE team_key = @away_key AND category = 'PASSING'
                              FOR XML RAW('passing'), TYPE                        
                       ),
                       (
                           SELECT player_id, rushing_plays AS carries, rushing_net_yards AS total_yards, rushing_average AS average, rushing_touchdowns AS touchdowns
                             FROM @leaders
                            WHERE team_key = @away_key AND category = 'RUSHING'
                              FOR XML RAW('rushing'), TYPE                        
                       ),
                       (
                           SELECT player_id, receiving_receptions AS receptions, receiving_yards AS total_yards, receiving_average AS average, receiving_touchdowns AS touchdowns
                             FROM @leaders
                            WHERE team_key = @away_key AND category = 'RECEIVING'
                              FOR XML RAW('receiving'), TYPE                        
                       )
                       FOR XML RAW('away'), TYPE
                   ),
                   (
                       SELECT 
                       (
                           SELECT player_id, passing_plays_attempted AS attempts, passing_plays_completed AS completions, passing_yards AS total_yards, passing_touchdowns AS touchdowns
                             FROM @leaders
                            WHERE team_key = @home_key AND category = 'PASSING'
                              FOR XML RAW('passing'), TYPE                        
                       ),
                       (
                           SELECT player_id, rushing_plays AS carries, rushing_net_yards AS total_yards, rushing_average AS average, rushing_touchdowns AS touchdowns
                             FROM @leaders
                            WHERE team_key = @home_key AND category = 'RUSHING'
                              FOR XML RAW('rushing'), TYPE                        
                       ),
                       (
                           SELECT player_id, receiving_receptions AS receptions, receiving_yards AS total_yards, receiving_average AS average, receiving_touchdowns AS touchdowns
                             FROM @leaders
                            WHERE team_key = @home_key AND category = 'RECEIVING'
                              FOR XML RAW('receiving'), TYPE                        
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
