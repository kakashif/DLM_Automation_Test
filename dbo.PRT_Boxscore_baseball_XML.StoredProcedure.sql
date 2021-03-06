USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PRT_Boxscore_baseball_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PRT_Boxscore_baseball_XML]
    @eventId INT
AS
-- =============================================
-- Author: John Lin
-- Create date: 07/13/2015
-- Description:	get boxscore for print for baseball
-- Update: 08/04/2015 - John Lin - player select
--         10/07/2015 - John Lin - default season era
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('mlb')
    DECLARE @season_key INT
    DECLARE @sub_season_type VARCHAR(100)
    DECLARE @event_key VARCHAR(100)
    DECLARE @start_date_time_EST DATETIME
    DECLARE @away_key VARCHAR(100)
    DECLARE @home_key VARCHAR(100)
    DECLARE @away_score VARCHAR(100)
    DECLARE @home_score VARCHAR(100)
    DECLARE @print_status VARCHAR(100)

    SELECT TOP 1 @season_key = season_key, @sub_season_type = sub_season_type, @event_key = event_key, @start_date_time_EST = start_date_time_EST, @print_status = print_status,
                 @away_key = away_team_key, @home_key = home_team_key, @away_score = away_team_score, @home_score = home_team_score
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

    -- team
    DECLARE @teams TABLE
    (
        [key] VARCHAR(100),
        [first] VARCHAR(100),
        [last] VARCHAR(100),
        abbr VARCHAr(100),
        alignment VARCHAR(100),
        score INT,
        [order] INT,
        -- details
        [team-left-on-base] VARCHAR(100),
        [double-plays] VARCHAR(100),
        [triple-plays] VARCHAR(100)
    )    
    INSERT INTO @teams([key], alignment, score, [order])
    VALUES (@away_key, 'away', @away_score, 1), (@home_key, 'home', @home_score, 2)

    UPDATE t
       SET t.[first] = st.team_first, t.[last] = st.team_last, t.abbr = st.team_abbreviation
      FROM @teams t
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = @season_key AND st.team_key = t.[key]       

    -- linescore
    DECLARE @linescore TABLE
    (
        [key] VARCHAR(100),
        period_value VARCHAR(100),
        score VARCHAR(100)
    )
    INSERT INTO @linescore ([key], period_value, score)
    SELECT @away_key, period_value, away_value
      FROM dbo.SMG_Periods
     WHERE event_key = @event_key

    INSERT INTO @linescore ([key], period_value, score)
    SELECT @home_key, period_value, home_value
      FROM dbo.SMG_Periods
     WHERE event_key = @event_key
     
    DELETE @linescore 
     WHERE period_value IN ('R', 'H', 'E')

    -- boxscore
    DECLARE @stats TABLE
    (
        team_key       VARCHAR(100),
        player_key     VARCHAR(100),
        column_name    VARCHAR(100), 
        value          VARCHAR(100)
    )
    INSERT INTO @stats (team_key, player_key, column_name, value)
    SELECT team_key, player_key, [column], value 
      FROM SportsEditDB.dbo.SMG_Events_baseball
     WHERE event_key = @event_key

	DECLARE @baseball TABLE
	(
		team_key VARCHAR(100),
		player_key VARCHAR(100),
        [first] VARCHAR(100),
        [last] VARCHAR(100),
		[position-event] VARCHAR(100),
		--batting
		[at-bats] INT,
		[runs-scored] INT,
		hits INT,
		rbi INT,
		[bases-on-balls] INT,
		strikeouts INT,
        average VARCHAR(100),
		-- pitching
		[innings-pitched] VARCHAR(100),
		[pitching-hits] INT,
		[runs-allowed] INT,
		[earned-runs] INT,
		[pitching-bases-on-balls] INT,
		[pitching-strikeouts] INT,
		era VARCHAR(100),		
		-- detail
		[errors-wild-pitch] INT,
		balks INT,
		[footnote-pitching] VARCHAR(100),
		-- matchup
		[batters-at-bats-against] INT,
		[number-of-pitches] INT,
		[number-of-strikes] INT,
		-- extra
	    [lineup-slot-sequence] INT,
	    [lineup-slot] INT,
	    [pitching-order] INT,
		[event-credit] VARCHAR(100),
		[save-credit] VARCHAR(100),
		[wins-season] INT,
		[losses-season] INT,
		[saves-season] INT,
		[holds-season] INT,
		blown_saves_season INT,
		outs_pitched INT,
		earned_run_average_season VARCHAR(100),
		[batters-against] INT,
		[hit-by-pitch] INT
	)
	INSERT INTO @baseball (player_key, team_key, [position-event],
	                       [lineup-slot-sequence], [lineup-slot], [pitching-order], [event-credit], [save-credit], [wins-season], [losses-season], [saves-season], [holds-season], blown_saves_season,
		                   [at-bats], [runs-scored], hits, rbi, [bases-on-balls], strikeouts, average,
                    	   [innings-pitched], [pitching-hits], [runs-allowed], [earned-runs], [pitching-bases-on-balls], [pitching-strikeouts], era,
                    	   [errors-wild-pitch], balks, [footnote-pitching],
                    	   [batters-at-bats-against], [number-of-pitches], [number-of-strikes], outs_pitched, earned_run_average_season, [batters-against],
                    	   [hit-by-pitch])
    SELECT p.player_key, p.team_key, [position-event],
           [lineup-slot-sequence], [lineup-slot], [pitching-order], [event-credit], [save-credit], ISNULL([wins-season], 0), ISNULL([losses-season], 0),
           ISNULL([saves-season], 0), ISNULL([holds-season], 0), ISNULL(blown_saves_season, 0),
		   ISNULL([at-bats], 0), ISNULL([runs-scored], 0), ISNULL(hits, 0), ISNULL(rbi, 0), ISNULL([bases-on-balls], 0), ISNULL(strikeouts, 0), batting_average_season,
           ISNULL([innings-pitched], '0'), ISNULL([pitching-hits], 0), ISNULL([runs-allowed], 0), ISNULL([earned-runs], 0), ISNULL([pitching-bases-on-balls], 0),
           ISNULL([pitching-strikeouts], 0), ISNULL(era, '0.00'),
           ISNULL([errors-wild-pitch], 0), ISNULL(balks, 0), [footnote-pitching],
           ISNULL([batters-at-bats-against], 0), ISNULL([number-of-pitches], 0), ISNULL([number-of-strikes], 0), ISNULL(outs_pitched, 0), ISNULL(earned_run_average_season, '0.00'),
           ISNULL([batters-against], 0), ISNULL([hit-by-pitch], 0)
      FROM (SELECT player_key, team_key, column_name, value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.column_name IN ([position-event], [lineup-slot-sequence],
                                               [lineup-slot], [pitching-order], [event-credit], [save-credit], [wins-season], [losses-season], [saves-season], [holds-season], blown_saves_season,
                                               [at-bats], [runs-scored], hits, rbi, [bases-on-balls], strikeouts, batting_average_season,
                                               [innings-pitched], [pitching-hits], [runs-allowed], [earned-runs], [pitching-bases-on-balls], [pitching-strikeouts], era,
                                               [errors-wild-pitch], balks, [footnote-pitching],
                                               [batters-at-bats-against], [number-of-pitches], [number-of-strikes], outs_pitched, earned_run_average_season,
                                               [batters-against], [hit-by-pitch])) AS p

    UPDATE @baseball
       SET average = REPLACE(CAST(CAST(average AS DECIMAL(6, 3)) AS VARCHAR), '0.', '.')
     WHERE average IS NOT NULL

    UPDATE @baseball
       SET average = '1.000'
     WHERE average IS NOT NULL AND CAST(average AS FLOAT) = 1

    UPDATE @baseball
       SET earned_run_average_season = CAST(CAST(earned_run_average_season AS DECIMAL(6, 2)) AS VARCHAR)
     WHERE earned_run_average_season IS NOT NULL

    UPDATE @baseball
       SET earned_run_average_season = '1.00'
     WHERE earned_run_average_season IS NOT NULL AND CAST(earned_run_average_season AS FLOAT) = 1

    UPDATE @baseball
       SET era = CAST(CAST(era AS DECIMAL(6, 2)) AS VARCHAR)
     WHERE era IS NOT NULL

    UPDATE @baseball
       SET era = '1.00'
     WHERE era IS NOT NULL AND CAST(era AS FLOAT) = 1
       
    UPDATE b
       SET b.[first] = p.first_name, b.[last] = p.last_name
      FROM @baseball b
     INNER JOIN dbo.SMG_Players p
        ON p.player_key = b.player_key

    -- batting
    DECLARE @batting TABLE
    (
        team_key VARCHAR(100),
        [first] VARCHAR(100),
        [last] VARCHAR(100),
        [position-event] VARCHAR(100),
		[at-bats] INT,
		[runs-scored] INT,
		hits INT,
		rbi INT,
		[bases-on-balls] INT,
		strikeouts INT,
        average VARCHAR(100),
		--extra               
        [lineup-slot] INT,
        [lineup-slot-sequence] INT
    )
	INSERT INTO @batting (team_key, [first], [last], [position-event],
	                     [at-bats], [runs-scored], hits, rbi, [bases-on-balls], strikeouts, average, [lineup-slot], [lineup-slot-sequence])
	SELECT team_key, [first], [last], [position-event], [at-bats],
	       [runs-scored], hits, rbi, [bases-on-balls], strikeouts, average, [lineup-slot], [lineup-slot-sequence]
	  FROM @baseball
     WHERE player_key <> 'TEAM' AND [lineup-slot-sequence] > 0 OR [lineup-slot] > 0

	INSERT INTO @batting (team_key, [first], [at-bats], [runs-scored], hits, rbi, [bases-on-balls], strikeouts)
	SELECT @away_key, 'TEAM', SUM([at-bats]), SUM([runs-scored]), SUM(hits), SUM(rbi), SUM([bases-on-balls]), SUM(strikeouts)
	  FROM @batting
	 WHERE team_key = @away_key 

	INSERT INTO @batting (team_key, [first], [at-bats], [runs-scored], hits, rbi, [bases-on-balls], strikeouts)
	SELECT @home_key, 'TEAM', SUM([at-bats]), SUM([runs-scored]), SUM(hits), SUM(rbi), SUM([bases-on-balls]), SUM(strikeouts)
	  FROM @batting
	 WHERE team_key = @home_key 

    -- pitching
    DECLARE @pitching TABLE
    (
        team_key VARCHAR(100),
        [first] VARCHAR(100),
        [last] VARCHAR(100),
		[innings-pitched] VARCHAR(100),
		hits INT,
		[runs-allowed] INT,
		[earned-runs] INT,
		[bases-on-balls] INT,
		strikeouts INT,
		era VARCHAR(100),
		-- detail
		[errors-wild-pitch] INT,
		balks INT,
		[footnote-pitching] VARCHAR(100),
		-- matchup
		[batters-at-bats-against] INT,
		[number-of-pitches] INT,
		[number-of-strikes] INT,
        -- extra        
        [pitching-order] INT,
		[event-credit] VARCHAR(100),
		[save-credit] VARCHAR(100),
		[wins-season] VARCHAR(100),
		[losses-season] VARCHAR(100),
		[saves-season] VARCHAR(100),
		[holds-season] INT,
		blown_saves_season INT,
		outs_pitched INT
    )
	INSERT INTO @pitching (team_key, [first], [last],
	                       [innings-pitched], hits, [runs-allowed], [earned-runs], [bases-on-balls], strikeouts, era,
	                       [errors-wild-pitch], balks, [footnote-pitching],
	                       [batters-at-bats-against], [number-of-pitches], [number-of-strikes],
	                       [pitching-order], [event-credit], [save-credit], [wins-season], [losses-season], [saves-season], [holds-season], blown_saves_season,
	                       outs_pitched)
	SELECT team_key, [first], [last],
	       [innings-pitched], [pitching-hits], [runs-allowed], [earned-runs], [pitching-bases-on-balls], [pitching-strikeouts],
	       earned_run_average_season,
	       [errors-wild-pitch], balks, [footnote-pitching],
	       [batters-against], [number-of-pitches], [number-of-strikes],
	       [pitching-order], [event-credit], [save-credit], [wins-season], [losses-season], [saves-season], [holds-season], blown_saves_season,
	       outs_pitched
	  FROM @baseball
     WHERE player_key <> 'TEAM' AND [pitching-order] > 0
     
    UPDATE @pitching
       SET [errors-wild-pitch] = NULL
     WHERE [errors-wild-pitch] = '0'

    UPDATE @pitching
       SET balks = NULL
     WHERE balks = '0'

    UPDATE @pitching
       SET [wins-season] = NULL, [losses-season] = NULL
     WHERE [event-credit] IS NULL

    UPDATE @pitching
       SET [saves-season] = NULL, [holds-season] = NULL, blown_saves_season = NULL
     WHERE [save-credit] IS NULL

    UPDATE @pitching
       SET [saves-season] = NULL
     WHERE [save-credit] <> 'save'

    UPDATE @pitching
       SET [holds-season] = NULL
     WHERE [save-credit] <> 'hold'

    UPDATE @pitching
       SET blown_saves_season = NULL
     WHERE [save-credit] <> 'blown'

    -- miscellanies
    DECLARE @miscellanies TABLE
    (
        [column] VARCHAR(100),
        team_key VARCHAR(100),
        pitcher_key VARCHAR(100),
        pitcher_first VARCHAR(100),
        pitcher_last VARCHAR(100),
        batter_key VARCHAR(100),
        batter_first VARCHAR(100),
        batter_last VARCHAR(100)        
    )
    INSERT INTO @miscellanies ([column], team_key, pitcher_key, batter_key)
    SELECT 'hit-by-pitch', team_key, player_key, value
      FROM @stats
     WHERE column_name = 'footnote-pitcher-bean-batter'

    INSERT INTO @miscellanies ([column], team_key, pitcher_key, batter_key)
    SELECT 'bases-on-balls-intentional', team_key, player_key, value
      FROM @stats
     WHERE column_name = 'footnote-pitcher-walk-batter'

    UPDATE m
       SET m.pitcher_first = p.first_name, m.pitcher_last = p.last_name
      FROM @miscellanies m
     INNER JOIN dbo.SMG_Players p
        ON p.player_key = m.pitcher_key

    UPDATE m
       SET m.batter_first = p.first_name, m.batter_last = p.last_name
      FROM @miscellanies m
     INNER JOIN dbo.SMG_Players p
        ON p.player_key = m.batter_key

    -- event details
    DECLARE @details TABLE
    (
        team_key VARCHAR(100),
        player_key VARCHAR(100),
        [first] VARCHAR(100),
        [last] VARCHAR(100),        
        category VARCHAR(100),
        [column] VARCHAR(100),
        value VARCHAR(100),
        total VARCHAR(100)
    )
    INSERT INTO @details (team_key, player_key, category, [column], value)
    SELECT team_key, player_key, 'batting', column_name, value
      FROM @stats
     WHERE player_key <> 'team' AND value <> '0' AND
           column_name IN ('doubles', 'triples', 'home-runs', 'rbi', 'sacrifices', 'sac-flies', 'grounded-into-double-play', 'stolen-bases', 'stolen-bases-caught')

    INSERT INTO @details (team_key, player_key, category, [column], value)
    SELECT team_key, player_key, 'fielding', column_name, value
      FROM @stats
     WHERE player_key <> 'team' AND value <> '0' AND column_name IN ('fielding-errors', 'errors-passed-ball')

    UPDATE d
       SET d.[first] = sp.first_name, d.[last] = sp.last_name
      FROM @details d
     INNER JOIN dbo.SMG_Players sp
        ON sp.player_key = d.player_key

    UPDATE d
       SET d.total = s.value
      FROM @details d
     INNER JOIN @stats s
        ON s.team_key = s.team_key AND s.player_key = d.player_key AND s.column_name = d.[column] + '-season'

    UPDATE d
       SET d.total = s.value
      FROM @details d
     INNER JOIN @stats s
        ON s.team_key = s.team_key AND s.player_key = d.player_key AND s.column_name = 'runs_batted_in_season'
     WHERE d.[column] = 'rbi'

    UPDATE d
       SET d.total = s.value
      FROM @details d
     INNER JOIN @stats s
        ON s.team_key = s.team_key AND s.player_key = d.player_key AND s.column_name = 'sacrifice_hits_season'
     WHERE d.[column] = 'sacrifices'

    UPDATE d
       SET d.total = s.value
      FROM @details d
     INNER JOIN @stats s
        ON s.team_key = s.team_key AND s.player_key = d.player_key AND s.column_name = 'sacrifice_flys_season'
     WHERE d.[column] = 'sac-flies'

    UPDATE d
       SET d.total = s.value
      FROM @details d
     INNER JOIN @stats s
        ON s.team_key = s.team_key AND s.player_key = d.player_key AND s.column_name = 'grounded_into_double_plays_season'
     WHERE d.[column] = 'grounded-into-double-play'

    UPDATE d
       SET d.total = s.value
      FROM @details d
     INNER JOIN @stats s
        ON s.team_key = s.team_key AND s.player_key = d.player_key AND s.column_name = 'caught_stealing_season'
     WHERE d.[column] = 'stolen-bases-caught'

    UPDATE d
       SET d.total = s.value
      FROM @details d
     INNER JOIN @stats s
        ON s.team_key = s.team_key AND s.player_key = d.player_key AND s.column_name = 'fielding_errors_season'
     WHERE d.[column] = 'fielding-errors'

    UPDATE @details
       SET [column] = 'errors-defense'
     WHERE [column] = 'fielding-errors'

    UPDATE d
       SET d.total = s.value
      FROM @details d
     INNER JOIN @stats s
        ON s.team_key = s.team_key AND s.player_key = d.player_key AND s.column_name = 'passed_balls_season'
     WHERE d.[column] = 'errors-passed-ball'


    -- team details
    UPDATE t
       SET t.[team-left-on-base] = s.value
      FROM @teams t
     INNER JOIN @stats s
        ON s.team_key = t.[key] AND s.player_key = 'team' AND s.column_name = 'team-left-on-base'
       
    UPDATE t
       SET t.[double-plays] = s.value
      FROM @teams t
     INNER JOIN @stats s
        ON s.team_key = t.[key] AND s.player_key = 'team' AND s.column_name = 'double-plays' AND s.value <> '0'

    UPDATE t
       SET t.[triple-plays] = s.value
      FROM @teams t
     INNER JOIN @stats s
        ON s.team_key = t.[key] AND s.player_key = 'team' AND s.column_name = 'triple-plays' AND s.value <> '0'       

    -- event info
    DECLARE @info TABLE
    (
       team_key VARCHAR(100),
       [column] VARCHAR(100),
       column_type VARCHAR(100),
       value VARCHAR(MAX)
    )
    INSERT INTO @info (team_key, [column], column_type, value)
    SELECT team_key, [column], column_type, value
      FROM dbo.SMG_Scores
     WHERE event_key = @event_key

    -- extra innings
    DECLARE @min_inning INT
        
    SELECT TOP 1 @min_inning = CAST(period_value AS INT)
      FROM @linescore
     ORDER BY CAST(period_value AS INT) ASC

    IF (@min_inning > 1 )
    BEGIN
        INSERT INTO @linescore ([key], period_value, score)
	    SELECT team_key, [column], value
          FROM @info
         WHERE column_type = 'period' AND CAST([column] AS INT) < @min_inning
    END

    -- umpires
    DECLARE @officials TABLE
    (
        position VARCHAR(100),
        [full] VARCHAR(100),
        [first] VARCHAR(100),
        [last] VARCHAR(100)
    )
    INSERT INTO @officials (position, [full])
    SELECT [column], value
      FROM @info
     WHERE column_type = 'officials'

    UPDATE @officials
       SET [first] = LEFT([full], CHARINDEX(' ', [full]) - 1),
           [last] = RIGHT([full], LEN([full]) - CHARINDEX(' ', [full]))

    UPDATE @officials
        SET position = CASE
                           WHEN position = 'First Base' THEN '1B'
                           WHEN position = 'Second Base' THEN '2B'
                           WHEN position = 'Third Base' THEN '3B'
                           WHEN position = 'Homeplate' THEN 'HP'
                       END
      
    -- duration, attendance
    DECLARE @duration VARCHAR(100)
    DECLARe @attendance VARCHAR(100)

    SELECT @duration = CAST((CAST(value AS INT)/ 60) AS VARCHAR) + ':' +
                       CASE
                           WHEN CAST(value AS INT) % 60 > 9 THEN CAST((CAST(value AS INT) % 60) AS VARCHAR)
                           ELSE '0' + CAST((CAST(value AS INT) % 60) AS VARCHAR)
                       END
      FROM @info
     WHERE [column] = 'game-duration-mins'

    SELECT @attendance = value
      FROM @info
     WHERE [column] = 'attendance'



    SELECT @print_status AS '@print-status', @start_date_time_EST AS '@start-date-time-est', @event_key AS '@event-key', @duration AS '@duration', @attendance AS '@attendance',
    (
        SELECT
        (
            SELECT t.alignment AS '@alignment', t.[first] AS '@first', t.[last] AS '@last', t.abbr AS '@abbreviation', t.score AS '@score',
            (
                SELECT
                (
                    SELECT
                    (
                        SELECT p.[first] AS '@first', p.[last] AS '@last',
                               p.[innings-pitched] AS '@innings-pitched', p.hits AS '@hits', p.[runs-allowed] AS '@runs-allowed',
                               p.[earned-runs] AS '@earned-runs', p.[bases-on-balls] AS '@bases-on-balls', p.strikeouts AS '@strikeouts', p.era AS '@era',
        		               p.[errors-wild-pitch] AS '@errors-wild-pitch', p.balks AS '@balks', p.[footnote-pitching] AS '@footnote',
        		               p.[batters-at-bats-against] AS '@batters-at-bats-against',
        		               p.[number-of-pitches] AS '@number-of-pitches', p.[number-of-strikes] AS '@number-of-strikes',
        		               p.[pitching-order] AS '@pitching-order', p.[event-credit] AS '@event-credit', p.[save-credit] AS '@save-credit',
                               p.[wins-season] AS '@wins-season', p.[losses-season] AS '@losses-season', p.[saves-season] AS '@saves-season',
        		               p.[holds-season] AS '@holds-season', p.blown_saves_season AS '@saves-blown-season'
                          FROM @pitching p
                         WHERE p.team_key = t.[key]
                         ORDER BY p.[pitching-order] ASC
                           FOR XML PATH('player'), TYPE
                    )
                    FOR XML PATH('players'), TYPE
                )
                FOR XML PATH('pitching'), TYPE
            ),
            (
                SELECT t.[double-plays] AS '@double-plays', t.[triple-plays] AS '@triple-plays',
                (
                    SELECT d.[column] AS '@category', d.[first] AS '@first', d.[last] AS '@last', d.value AS '@event-value', d.total AS '@season-value'
                      FROM @details d
                     WHERE d.team_key = t.[key] AND d.category = 'fielding'
                       FOR XML PATH('fielding'), TYPE
                )
                FOR XML PATH('fieldings'), TYPE
            ),
            (
                SELECT
                (
                    SELECT
                    (
                        SELECT b.[first] AS '@first', b.[last] AS '@last', b.[position-event] AS '@position-event', b.[at-bats] AS '@at-bats',
                               b.[runs-scored] AS '@runs-scored', b.hits AS '@hits', b.rbi AS '@rbi', b.[bases-on-balls] AS '@bases-on-balls',
                               b.strikeouts AS '@strikeouts', b.average AS '@average', b.[lineup-slot] AS '@lineup-slot', b.[lineup-slot-sequence] AS '@lineup-slot-sequence'
                          FROM @batting b
                         WHERE b.team_key = t.[key] AND b.[first] <> 'TEAM'
                         ORDER BY b.[lineup-slot] ASC, b.[lineup-slot-sequence] ASC
                           FOR XML PATH('player'), TYPE
                    ),
                    (
                        SELECT b.[at-bats] AS '@at-bats', b.[runs-scored] AS '@runs-scored', b.hits AS '@hits',
                               b.rbi AS '@rbi', b.[bases-on-balls] AS '@bases-on-balls', b.strikeouts AS '@strikeouts'
                          FROM @batting b
                         WHERE b.team_key = t.[key] AND b.[first] = 'TEAM'
                         ORDER BY b.[lineup-slot] ASC, b.[lineup-slot-sequence] ASC
                           FOR XML PATH('total'), TYPE
                    )
                    FOR XML PATH('players'), TYPE
                ),
                (
                    SELECT t.[team-left-on-base] AS '@left-on-base',
                    (
                        SELECT d.[column] AS '@category', d.[first] AS '@first', d.[last] AS '@last', d.value AS '@event-value', d.total AS '@season-value'
                          FROM @details d
                         WHERE d.team_key = t.[key] AND d.category = 'batting'
                           FOR XML PATH('detail'), TYPE
                    ),
                    (
                        SELECT
                        (
                            SELECT m.[column] AS '@category',
                            (
                                SELECT m.pitcher_first AS '@first', m.pitcher_last AS '@last'
                                   FOR XML PATH('pitcher'), TYPE
                            ),
                            (
                                SELECT m.batter_first AS '@first', m.batter_last AS '@last'
                                   FOR XML PATH('batter'), TYPE
                            )
                            FROM @miscellanies m
                            WHERE m.team_key = t.[key]
                            FOR XML PATH('miscellany'), TYPE
                        )
                        FOR XML PATH('miscellanies'), TYPE
                    )
                    FOR XML PATH('details'), TYPE
                )
                FOR XML PATH('batting'), TYPE
            ),
            (
                SELECT
                (
                    SELECT l.period_value AS '@period-value', l.score AS '@score'
                      FROM @linescore l
                     WHERE l.[key] = t.[key]
                     ORDER BY CAST(period_value AS INT) ASC
                       FOR XML PATH('inning'), TYPE         
                )
                FOR XML PATH('innings'), TYPE
            )
            FROM @teams t
            ORDER BY t.[order] ASC
            FOR XML PATH('team'), TYPE
        )
        FOR XML PATH('teams'), TYPE
    ),
    (
        SELECT
        (
            SELECT position AS '@position', [first] AS '@first', [last] AS '@last'
              FROM @officials
               FOR XML PATH('official'), TYPE
        )
        FOR XML PATH('officials'), TYPE
        
    )
	FOR XML PATH('boxscore')


    SET NOCOUNT OFF;
END

GO
