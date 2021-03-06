USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[LOC_Event_Matchup_baseball_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[LOC_Event_Matchup_baseball_XML]
    @eventKey VARCHAR(100)
AS
-- =============================================
-- Author:      John Lin
-- Create date: 06/04/2015
-- Description: get baseball event details for USCP
-- Update: 06/09/2015 - John Lin - add on deck list
--         06/10/2015 - John Lin - expand head shot to 200 chars
--         06/23/2015 - John Lin - STATS migration
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 
    
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('mlb')
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
    
    -- pre
    DECLARE @pitcher_away VARCHAR(100)
    DECLARE @pitcher_home VARCHAR(100)
    -- mid
    DECLARE @inning_half VARCHAR(100)
    DECLARE @outs INT
    DECLARE @strikes INT
    DECLARE @balls INT
    DECLARE @umpire_call VARCHAR(100)
    DECLARE @runner_on_first VARCHAR(100)
    DECLARE @runner_on_second VARCHAR(100)
    DECLARE @runner_on_third VARCHAR(100)
    DECLARE @last_play VARCHAR(MAX)

    DECLARE @pitcher_key VARCHAR(100)
    DECLARE @pitcher_name VARCHAR(100)
    DECLARE @pitcher_head_shot VARCHAR(200)
    DECLARE @earned_runs INT
    DECLARE @strikeouts INT
    DECLARE @bases_on_balls INT
    DECLARE @innings_pitched VARCHAR(100)
    DECLARE @pitch_count INT
    
    DECLARE @batter_key VARCHAR(100)
    DECLARE @batter_name VARCHAR(100)
    DECLARE @batter_head_shot VARCHAR(200)
    DECLARE @batter_position VARCHAR(100)
    DECLARE @average VARCHAR(100)
    DECLARE @rbi INT
    DECLARE @home_runs INT
    DECLARE @season_average VARCHAR(100)
    DECLARE @season_rbi INT
    DECLARE @season_home_runs INT
    -- post
    DECLARE @pitcher_win  VARCHAR(100)
    DECLARE @pitcher_loss VARCHAR(100)
    DECLARE @pitcher_save VARCHAR(100)
    DECLARE @team_win     VARCHAR(100)
    DECLARE @team_loss    VARCHAR(100)
    DECLARE @team_save    VARCHAR(100)
    DECLARE @logo_win     VARCHAR(100)
    DECLARE @logo_loss    VARCHAR(100)
    DECLARE @logo_save    VARCHAR(100)

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
    
    DECLARE @scores TABLE
    (
        team_key VARCHAR(100),
        column_type VARCHAR(100),
        [column] VARCHAR(100),
        value VARCHAR(MAX)
    )
    INSERT INTO @scores (team_key, column_type, [column], value)
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
     WHERE event_key = @eventKey

    IF NOT EXISTS (SELECT 1 FROM @linescore)
    BEGIN
        INSERT INTO @linescore (period, period_value)
        VALUES (1, '1'), (2, '2'), (3, '3'), (4, '4'), (5, '5'), (6, '6'), (7, '7'), (8, '8'), (9, '9'), (10, 'R'), (11, 'H'), (12, 'E')
    END
    ELSE
    BEGIN 
        DECLARE @min_inning INT
        
        SELECT TOP 1 @min_inning = period
          FROM @linescore
         ORDER BY period ASC

        IF (@min_inning > 1 )
        BEGIN
            INSERT INTO @linescore (period, period_value, away_value)
	        SELECT CAST([column] AS INT), [column], value
              FROM @scores
             WHERE team_key = @away_key AND column_type = 'period' AND CAST([column] AS INT) < @min_inning           

            UPDATE l
               SET l.home_value = s.value
              FROM @linescore l
             INNER JOIN @scores s
                ON s.team_key = @home_key AND s.[column] = l.period_value
        END
    END

    IF (@event_status = 'mid-event')
    BEGIN
        SELECT TOP 1 @inning_half = inning_half, @outs = outs, @strikes = strikes, @balls = balls, 
                     @runner_on_first = ISNULL(NULLIF(runner_on_first, ''), '0'),
                     @runner_on_second = ISNULL(NULLIF(runner_on_second, ''), '0'),
                     @runner_on_third = ISNULL(NULLIF(runner_on_third, ''), '0'),
                     @pitcher_key = pitcher_key, @batter_key = batter_key, @umpire_call = umpire_call, @pitch_count = pitch_count, @last_play = last_play
          FROM dbo.SMG_Transient
         WHERE event_key = @eventKey
         ORDER BY date_time DESC

        IF (@runner_on_first <> '0')
        BEGIN
            SET @runner_on_first = REPLACE(@runner_on_first, @league_key + '-p.', '')
        END
        
        IF (@runner_on_second <> '0')
        BEGIN
            SET @runner_on_second = REPLACE(@runner_on_second, @league_key + '-p.', '')
        END
        
        IF (@runner_on_third <> '0')
        BEGIN
            SET @runner_on_third = REPLACE(@runner_on_third, @league_key + '-p.', '')
        END

        -- assume bottom of the inning
        DECLARE @pitcher_team_key VARCHAR(100) = @away_key
        DECLARE @batter_team_key VARCHAR(100) = @home_key
        DECLARE @linup_slot INT
        
        IF (@inning_half = 'top')
        BEGIN
            SET @pitcher_team_key = @home_key
            SET @batter_team_key = @away_key
        END

        -- pitcher, batter
        SELECT @pitcher_head_shot = CASE
                                        WHEN head_shot IS NULL OR [filename] IS NULL THEN ''
                                        ELSE 'http://www.gannett-cdn.com/media/SMG/' + head_shot + '120x120/' + [filename]
                                    END
          FROM dbo.SMG_Rosters
         WHERE season_key = @season_key AND team_key = @pitcher_team_key AND player_key = @pitcher_key

        SELECT @batter_head_shot = CASE
                                       WHEN head_shot IS NULL OR [filename] IS NULL THEN ''
                                       ELSE 'http://www.gannett-cdn.com/media/SMG/' + head_shot + '120x120/' + [filename]
                                   END
          FROM dbo.SMG_Rosters
         WHERE season_key = @season_key AND team_key = @batter_team_key AND player_key = @batter_key

        -- stats for event
        DECLARE @stats TABLE
        (
            team_key   VARCHAR(100),
            player_key VARCHAR(100),
            [column]   VARCHAR(100), 
            value      VARCHAR(100),
            [level]    VARCHAR(100)
        )
        INSERT INTO @stats (team_key, player_key, [column], value, [level])
        SELECT team_key, player_key, [column], value, 'event'
          FROM SportsEditDB.dbo.SMG_Events_baseball
         WHERE event_key = @eventKey

        -- on deck
    	DECLARE @lineup TABLE
        (
            team_key VARCHAR(100),
            player_key VARCHAR(100),           
		    -- extra
            [lineup-slot-sequence] INT,
            [lineup-slot] INT
        )
    	DECLARE @on_deck TABLE
        (
            id  INT IDENTITY(1, 1) PRIMARY KEY,
            player_key VARCHAR(100),
    	    first_name VARCHAR(100),
    	    last_name VARCHAR(100),
    	    uniform_number INT,
    	    head_shot VARCHAR(200)
        )
        INSERT INTO @lineup (team_key, player_key, [lineup-slot], [lineup-slot-sequence])
        SELECT p.team_key, p.player_key, [lineup-slot], [lineup-slot-sequence]
          FROM (SELECT player_key, team_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([lineup-slot], [lineup-slot-sequence])) AS p

        -- on deck
        INSERT INTO @on_deck (player_key)
        SELECT player_key
          FROM @lineup
         WHERE team_key = @batter_team_key AND [lineup-slot] IS NOT NULL AND [lineup-slot-sequence] IS NOT NULL
         ORDER BY [lineup-slot] ASC, [lineup-slot-sequence] ASC

        -- second time for lineup loop
        INSERT INTO @on_deck (player_key)
        SELECT player_key
          FROM @lineup
         WHERE team_key = @batter_team_key AND [lineup-slot] IS NOT NULL AND [lineup-slot-sequence] IS NOT NULL
         ORDER BY [lineup-slot] ASC, [lineup-slot-sequence] ASC

        SELECT TOP 1 @linup_slot = id
          FROM @on_deck
         WHERE player_key = @batter_key
         ORDER BY id ASC

        DELETE @on_deck
         WHERE id <= @linup_slot

        DELETE @on_deck
         WHERE id > @linup_slot + 3

        UPDATE od
           SET od.first_name = sp.first_name, od.last_name = sp.last_name
          FROM @on_deck od
         INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = od.player_key

        UPDATE od
           SET od.uniform_number = sr.uniform_number,
               od.head_shot = CASE
                                  WHEN sr.head_shot IS NULL OR sr.[filename] IS NULL THEN ''
                                  ELSE 'http://www.gannett-cdn.com/media/SMG/' + sr.head_shot + '120x120/' + sr.[filename]
                              END
          FROM @on_deck od
         INNER JOIN dbo.SMG_Rosters sr
            ON sr.season_key = @season_key AND sr.team_key = @batter_team_key AND sr.player_key = od.player_key

        -- pitcher
        SELECT @pitcher_name = first_name + ' ' + last_name
          FROM dbo.SMG_Players
         WHERE player_key = @pitcher_key
              
        SELECT @earned_runs = ISNULL(p.[earned-runs], 0), @strikeouts = ISNULL(p.[strikeouts], 0), @bases_on_balls = ISNULL(p.[bases-on-balls], 0), @innings_pitched = [innings-pitched]
          FROM (SELECT [column], value
                  FROM @stats
                 WHERE player_key = @pitcher_key AND [level] = 'event') AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([earned-runs], [strikeouts], [bases-on-balls], [innings-pitched])) AS p

        -- batter
        SELECT @batter_name = first_name + ' ' + last_name
          FROM dbo.SMG_Players
         WHERE player_key = @batter_key

        SELECT @average = REPLACE(ROUND(ISNULL(p.[average], '0'), 3), '0.', '.'), @rbi = ISNULL(p.[rbi], 0), @home_runs = ISNULL(p.[home-runs], 0), @batter_position = ISNULL([position-event], '')
          FROM (SELECT [column], value
                  FROM @stats
                 WHERE player_key = @batter_key AND [level] = 'event') AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([average], [rbi], [home-runs], [position-event])) AS p

        -- stats for season
        INSERT INTO @stats (team_key, player_key, [column], value, [level])
        SELECT team_key, player_key, [column], value, 'season'
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = @sub_season_type AND
               team_key = @batter_team_key AND player_key = @batter_key AND category = 'feed'

        SELECT @season_average = REPLACE(ROUND(ISNULL(p.[average], '0'), 3), '0.', '.'), @season_rbi = ISNULL(p.[rbi], 0), @season_home_runs = ISNULL(p.[home-runs], 0)
          FROM (SELECT [column], value
                  FROM @stats
                 WHERE [level] = 'season') AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([average], [rbi], [home-runs])) AS p

        SET @batter_position = CASE
	                               WHEN @batter_position = '1' THEN 'P'
	                               WHEN @batter_position = '2' THEN 'C'
  	                               WHEN @batter_position = '3' THEN '1B'
	                               WHEN @batter_position = '4' THEN '2B'
	                               WHEN @batter_position = '5' THEN '3B'
	                               WHEN @batter_position = '6' THEN 'SS'
	                               WHEN @batter_position = '7' THEN 'LF'
	                               WHEN @batter_position = '8' THEN 'CF'
	                               WHEN @batter_position = '9' THEN 'RF'
	                               WHEN @batter_position = 'D' THEN 'DH'
	                               WHEN @batter_position = 'P' THEN 'PH'
	                               ELSE @batter_position
	                           END
    END
    ELSE
    BEGIN
        IF (@event_status = 'pre-event')
        BEGIN
            SELECT @coverage = value
              FROM @scores
             WHERE column_type = 'pre-event-coverage'

            DECLARE @transient TABLE
            (
                team_key VARCHAR(100),
                player_key VARCHAR(100)
            )
            INSERT INTO @transient (team_key, player_key)
            SELECT team_key, player_key
              FROM dbo.SMG_Transient
             WHERE event_key = @eventKey
            
            SELECT @pitcher_away = sp.first_name + ' ' + sp.last_name
              FROM dbo.SMG_Players sp
             INNER JOIN @transient t
                ON team_key = @away_key AND t.player_key = sp.player_key

            SELECT @pitcher_home = sp.first_name + ' ' + sp.last_name
              FROM dbo.SMG_Players sp
             INNER JOIN @transient t
                ON team_key = @home_key AND t.player_key = sp.player_key            
        END
        ELSE
        BEGIN
            SELECT @coverage = value
              FROM @scores
             WHERE column_type = 'post-event-coverage'

            DECLARE @event_stats TABLE
            (
                team_key VARCHAR(100),
                player_key VARCHAR(100),                
                value VARCHAR(100)                
            )
            INSERT INTO @event_stats (team_key, player_key, value)
            SELECT team_key, player_key, value
              FROM SportsEditDB.dbo.SMG_Events_baseball
             WHERE event_key = @eventKey AND [column] = 'event-credit'
             
            SELECT @team_win = team_key, @pitcher_win = sp.first_name + ' ' + sp.last_name
              FROM dbo.SMG_Players sp
             INNER JOIN @event_stats es
                ON es.player_key = sp.player_key AND value = 'win'

            IF (@team_win IS NOT NULL)
            BEGIN
                SELECT @logo_win = 'http://www.gannett-cdn.com/media/SMG/sports_logos/mlb-whitebg/60/' + team_abbreviation + '.png'
                  FROM dbo.SMG_Teams
                 WHERE season_key = @season_key AND team_key = @team_win
            END

            SELECT @team_loss = team_key, @pitcher_loss = sp.first_name + ' ' + sp.last_name
              FROM dbo.SMG_Players sp
             INNER JOIN @event_stats es
                ON es.player_key = sp.player_key AND value = 'loss'            

            IF (@team_loss IS NOT NULL)
            BEGIN
                SELECT @logo_loss = 'http://www.gannett-cdn.com/media/SMG/sports_logos/mlb-whitebg/60/' + team_abbreviation + '.png'
                  FROM dbo.SMG_Teams
                 WHERE season_key = @season_key AND team_key = @team_loss
            END

            SELECT @team_save = team_key, @pitcher_save = sp.first_name + ' ' + sp.last_name
              FROM dbo.SMG_Players sp
             INNER JOIN @event_stats es
                ON es.player_key = sp.player_key AND value = 'save'

            IF (@team_save IS NOT NULL)
            BEGIN
                SELECT @logo_save = 'http://www.gannett-cdn.com/media/SMG/sports_logos/mlb-whitebg/60/' + team_abbreviation + '.png'
                  FROM dbo.SMG_Teams
                 WHERE season_key = @season_key AND team_key = @team_save
            END
        END
    END  




    SELECT
	(
        SELECT @away_key AS away_key, @away_id AS away_id, @home_key AS home_key, @home_id AS home_id, @away_score AS away_score, @home_score AS home_score,
               @date_time AS date_time, @game_status AS game_status, @venue AS venue, ISNULL(@coverage, '') AS coverage,
               -- pre
               @pitcher_away AS pitcher_away, @pitcher_home AS pitcher_home,
               -- mid
               @outs AS outs, @strikes AS strikes, @balls AS balls, @umpire_call AS umpire_call,
               @runner_on_first AS runner_on_first, @runner_on_second AS runner_on_second, @runner_on_third AS runner_on_third, @last_play AS last_play,
               dbo.SMG_fnEventId(@pitcher_key) AS pitcher_id, @pitcher_name AS pitcher_name, @pitcher_head_shot AS pitcher_head_shot,
               @earned_runs AS [earned-runs], @strikeouts AS strikeouts, @bases_on_balls AS [bases-on-balls],
               @innings_pitched AS [innings-pitched], @pitch_count AS pitch_count,
               dbo.SMG_fnEventId(@batter_key) AS batter_id, @batter_name AS batter_name, @batter_position AS batter_postion, @batter_head_shot AS batter_head_shot,
               @average AS average, @rbi AS rbi, @home_runs AS [home-runs],
               @season_average AS [season-average], @season_rbi AS [season-rbi], @season_home_runs AS [season-home-runs],                
               -- post
               @pitcher_win AS pitcher_win, @pitcher_loss AS pitcher_loss, @pitcher_save AS pitcher_save,
               @logo_win AS logo_win, @logo_loss AS logo_loss, @logo_save AS logo_save,
		       (
			       SELECT first_name, last_name, head_shot, uniform_number
                     FROM @on_deck
                    ORDER BY id ASC
                      FOR XML RAW('on_deck'), TYPE
               ),
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
               )
           FOR XML RAW('gamecast'), TYPE
	)
    FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF;
END

GO
