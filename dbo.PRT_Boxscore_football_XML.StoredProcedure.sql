USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PRT_Boxscore_football_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PRT_Boxscore_football_XML]
    @eventId INT
AS
-- =============================================
-- Author: John Lin
-- Create date: 08/03/2015
-- Description:	get boxscore for print for football
-- Update: 08/25/2015 - John Lin - update scoring summary
--         09/12/2015 - John Lin - NFL use time left of next play as end time left of current play
--         09/25/2015 - John Lin - scoring team key
--         10/07/2015 - John Lin - NF use time left of next possession for scoring
--         10/08/2015 - John Lin - revert
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('nfl')
    DECLARE @season_key INT
    DECLARE @event_key VARCHAR(100)
    DECLARE @start_date_time_EST DATETIME
    DECLARE @away_key VARCHAR(100)
    DECLARE @home_key VARCHAR(100)
    DECLARE @away_score VARCHAR(100)
    DECLARE @home_score VARCHAR(100)
    DECLARE @print_status VARCHAR(100)

    SELECT TOP 1 @season_key = season_key, @event_key = event_key, @start_date_time_EST = start_date_time_EST, @print_status = print_status,
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
        [order] INT
    )
    INSERT INTO @teams([key], alignment, score, [order])
    VALUES (@away_key, 'away', @away_score, 1), (@home_key, 'home', @home_score, 2)

    UPDATE t
       SET t.[first] = st.team_first, t.[last] = st.team_last, t.abbr = st.team_abbreviation
      FROM @teams t
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = @season_key AND st.team_key = t.[key]       

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
      FROM SportsEditDB.dbo.SMG_Events_football
     WHERE event_key = @event_key

	DECLARE @football TABLE
	(
		team_key VARCHAR(100),
		player_key VARCHAR(100),
        [first] VARCHAR(100),
        [last] VARCHAR(100),
        -- passing
		passing_plays_attempted INT,
		passing_plays_completed INT,
		passing_yards INT,
		passing_plays_intercepted INT,
		passing_touchdowns INT,
        -- rushing
		rushing_plays INT,
		rushing_net_yards INT,
		rushing_touchdowns INT,
        -- receiving
   		receiving_receptions INT,
		receiving_yards INT,
		receiving_touchdowns INT,
        -- tackles, assists, sacks        		
		defense_solo_tackles INT,
		defense_assisted_tackles INT,
		defense_sacks VARCHAR(100),
        -- interceptions
		defense_interceptions INT,
		defense_interception_yards INT,
		-- fumbles
		fumbles_lost INT,
		fumbles_recovered_lost_by_opposition INT,
		-- field goals
		field_goals_attempted INT,
		field_goals_succeeded INT,
		[failed-field-goal] VARCHAR(100)
	)
	INSERT INTO @football (player_key, team_key,
	                       passing_plays_attempted, passing_plays_completed, passing_yards, passing_plays_intercepted, passing_touchdowns,
		                   rushing_plays, rushing_net_yards, rushing_touchdowns,
   		                   receiving_receptions, receiving_yards, receiving_touchdowns,
                           defense_solo_tackles, defense_assisted_tackles, defense_sacks,
                           defense_interceptions, defense_interception_yards, fumbles_lost, fumbles_recovered_lost_by_opposition,
                           field_goals_attempted, field_goals_succeeded, [failed-field-goal])
    SELECT p.player_key, p.team_key,
	       passing_plays_attempted, ISNULL(passing_plays_completed, 0), ISNULL(passing_yards, 0), ISNULL(passing_plays_intercepted, 0), ISNULL(passing_touchdowns, 0),
		   rushing_plays, rushing_net_yards, rushing_touchdowns,
   		   receiving_receptions, ISNULL(receiving_yards, 0), receiving_touchdowns,
           ISNULL(defense_solo_tackles, 0), ISNULL(defense_assisted_tackles, 0), ISNULL(defense_sacks, 0),
           defense_interceptions, ISNULL(defense_interception_yards, 0), fumbles_lost, fumbles_recovered_lost_by_opposition,
           ISNULL(field_goals_attempted, 0), ISNULL(field_goals_succeeded, 0), [failed-field-goal]
      FROM (SELECT player_key, team_key, column_name, value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.column_name IN (passing_plays_attempted, passing_plays_completed, passing_yards, passing_plays_intercepted, passing_touchdowns,
		                                       rushing_plays, rushing_net_yards, rushing_touchdowns,
   		                                       receiving_receptions, receiving_yards, receiving_touchdowns,
                                               defense_solo_tackles, defense_assisted_tackles, defense_sacks,
                                               defense_interceptions, defense_interception_yards, fumbles_lost, fumbles_recovered_lost_by_opposition,
                                               field_goals_attempted, field_goals_succeeded, [failed-field-goal])) AS p


    UPDATE f
       SET f.[first] = p.first_name, f.[last] = p.last_name
      FROM @football f
     INNER JOIN dbo.SMG_Players p
        ON p.player_key = f.player_key

    -- passing
    DECLARE @passing TABLE
    (
        team_key VARCHAR(100),
        [first] VARCHAR(100),
        [last] VARCHAR(100),
		passing_plays_attempted INT,
		passing_plays_completed INT,
		passing_yards INT,
		passing_plays_intercepted INT,
		passing_touchdowns INT
    )
	INSERT INTO @passing (team_key, [first], [last], passing_plays_attempted, passing_plays_completed, passing_yards, passing_plays_intercepted, passing_touchdowns)
	SELECT team_key, [first], [last], passing_plays_attempted, passing_plays_completed, passing_yards, passing_plays_intercepted, passing_touchdowns
	  FROM @football
     WHERE player_key <> 'team' AND passing_plays_attempted IS NOT NULL

    -- rushing
    DECLARE @rushing TABLE
    (
        team_key VARCHAR(100),
        [first] VARCHAR(100),
        [last] VARCHAR(100),
		rushing_plays INT,
		rushing_net_yards INT,
		rushing_touchdowns INT
    )
	INSERT INTO @rushing (team_key, [first], [last], rushing_plays, rushing_net_yards, rushing_touchdowns)
	SELECT team_key, [first], [last], rushing_plays, rushing_net_yards, rushing_touchdowns
	  FROM @football
     WHERE player_key <> 'team' AND rushing_plays IS NOT NULL

    -- receiving
    DECLARE @receiving TABLE
    (
        team_key VARCHAR(100),
        [first] VARCHAR(100),
        [last] VARCHAR(100),
   		receiving_receptions INT,
		receiving_yards INT,
		receiving_touchdowns INT
    )
	INSERT INTO @receiving (team_key, [first], [last], receiving_receptions, receiving_yards, receiving_touchdowns)
	SELECT team_key, [first], [last], receiving_receptions, receiving_yards, receiving_touchdowns
	  FROM @football
     WHERE player_key <> 'team' AND receiving_receptions IS NOT NULL

    -- tackles
    DECLARE @tackles TABLE
    (
        team_key VARCHAR(100),
        [first] VARCHAR(100),
        [last] VARCHAR(100),
		defense_solo_tackles INT,
		defense_assisted_tackles INT,
		defense_sacks VARCHAR(100)
    )
	INSERT INTO @tackles (team_key, [first], [last], defense_solo_tackles, defense_assisted_tackles, defense_sacks)
	SELECT team_key, [first], [last], defense_solo_tackles, defense_assisted_tackles, defense_sacks
	  FROM @football
     WHERE player_key <> 'team' AND defense_solo_tackles + defense_assisted_tackles + CAST(defense_sacks AS FLOAT) > 0

    -- interceptions
    DECLARE @interceptions TABLE
    (
        team_key VARCHAR(100),
        [first] VARCHAR(100),
        [last] VARCHAR(100),
		defense_interceptions INT,
		defense_interception_yards INT
    )
	INSERT INTO @interceptions (team_key, [first], [last], defense_interceptions, defense_interception_yards)
	SELECT team_key, [first], [last], defense_interceptions, defense_interception_yards
	  FROM @football
     WHERE player_key <> 'team' AND defense_interceptions IS NOT NULL

    -- fumbles
    DECLARE @fumbles TABLE
    (
        team_key VARCHAR(100),
        [first] VARCHAR(100),
        [last] VARCHAR(100),
        fumbles_lost INT,
		fumbles_recovered_lost_by_opposition INT
    )
	INSERT INTO @fumbles (team_key, [first], [last], fumbles_lost, fumbles_recovered_lost_by_opposition)
	SELECT team_key, [first], [last], fumbles_lost, fumbles_recovered_lost_by_opposition
	  FROM @football
     WHERE player_key <> 'team' AND (fumbles_lost IS NOT NULL OR fumbles_recovered_lost_by_opposition IS NOT NULL)

    -- field goals
    DECLARE @field_goals TABLE
    (
        team_key VARCHAR(100),
        [first] VARCHAR(100),
        [last] VARCHAR(100),
        field_goals_attempted INT,
        field_goals_succeeded INT,
        [failed-field-goal] VARCHAR(100)
    )
	INSERT INTO @field_goals (team_key, [first], [last], field_goals_attempted, field_goals_succeeded, [failed-field-goal])
	SELECT team_key, [first], [last], field_goals_attempted, field_goals_succeeded, [failed-field-goal]
	  FROM @football
     WHERE player_key <> 'team' AND (field_goals_attempted > 0 OR [failed-field-goal] IS NOT NULL)


    -- event details
    DECLARE @details TABLE
    (
        team_key VARCHAR(100),
        -- details
        total_first_downs INT,
        rushing_first_downs INT,
        passing_first_downs INT,
        penalty_first_downs INT,
        third_downs_attempted INT,
        third_downs_succeeded INT,
        fourth_downs_attempted INT,
        fourth_downs_succeeded INT,
        passing_net_yards INT,
        passing_plays_attempted INT,
        passing_plays_completed INT,
        passing_plays_sacked INT,
        passing_sacked_yards INT,
        passing_plays_intercepted INT,
        rushing_net_yards INT,
        rushing_plays INT,
        punting_plays INT,
        punting_gross_yards INT,
        punt_returns INT,
        punt_return_yards INT,
        kickoff_returns INT,
        kickoff_return_yards INT,
        interception_returns INT,
        interception_return_yards INT,
        penalties INT,
        penalty_yards INT,
        fumbles INT,
        fumbles_lost INT,
        time_of_possession_secs VARCHAR(100)
    )
    INSERT INTO @details (team_key,
                          total_first_downs, rushing_first_downs, passing_first_downs, penalty_first_downs,
                          third_downs_attempted, third_downs_succeeded, fourth_downs_attempted, fourth_downs_succeeded,
                          passing_net_yards, passing_plays_attempted, passing_plays_completed,
                          passing_plays_sacked, passing_sacked_yards, passing_plays_intercepted,
                          rushing_net_yards, rushing_plays, punting_plays, punting_gross_yards,
                          punt_returns, punt_return_yards, kickoff_returns, kickoff_return_yards, interception_returns, interception_return_yards,
                          penalties, penalty_yards, fumbles, fumbles_lost, time_of_possession_secs)
    SELECT p.team_key,
           total_first_downs, rushing_first_downs, passing_first_downs, ISNULL(penalty_first_downs, 0),
           third_downs_attempted, third_downs_succeeded,  ISNULL(fourth_downs_attempted, 0),  ISNULL(fourth_downs_succeeded, 0),
           passing_net_yards, passing_plays_attempted, passing_plays_completed,
           passing_plays_sacked, ISNULL(passing_sacked_yards, 0), ISNULL(passing_plays_intercepted, 0),
           rushing_net_yards, rushing_plays, punting_plays, punting_gross_yards,
           ISNULL(punt_returns, 0), ISNULL(punt_return_yards, 0), kickoff_returns, kickoff_return_yards, ISNULL(interception_returns, 0), ISNULL(interception_return_yards, 0),
           penalties, penalty_yards, ISNULL(fumbles, 0), ISNULL(fumbles_lost, 0), time_of_possession_secs
      FROM (SELECT team_key, player_key, column_name, value FROM @stats WHERE player_key = 'team') AS c
     PIVOT (MAX(c.value) FOR c.column_name IN (total_first_downs, rushing_first_downs, passing_first_downs, penalty_first_downs,
                                               third_downs_attempted, third_downs_succeeded, fourth_downs_attempted, fourth_downs_succeeded,
                                               passing_net_yards, passing_plays_attempted, passing_plays_completed,
                                               passing_plays_sacked, passing_sacked_yards, passing_plays_intercepted,
                                               rushing_net_yards, rushing_plays, punting_plays, punting_gross_yards,
                                               punt_returns, punt_return_yards, kickoff_returns, kickoff_return_yards, interception_returns, interception_return_yards,
                                               penalties, penalty_yards, fumbles, fumbles_lost, time_of_possession_secs)) AS p

    UPDATE @details
       SET time_of_possession_secs = CAST((time_of_possession_secs / 60) AS VARCHAR) + ':' +
                                     CASE
                                         WHEN time_of_possession_secs % 60 > 9 THEN CAST((time_of_possession_secs % 60) AS VARCHAR)
                                         ELSE '0' + CAST((time_of_possession_secs % 60) AS VARCHAR)
                                     END
    
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
     
    -- extra quarters
    IF EXISTS (SELECT 1 FROM @linescore WHERE period_value = 'OT')
    BEGIN
        INSERT INTO @linescore ([key], period_value, score)
	    SELECT @away_key, [column], 0
          FROM @info
         WHERE column_type = 'period' AND CAST([column] AS INT) > 4

        INSERT INTO @linescore ([key], period_value, score)
	    SELECT @home_key, [column], 0
          FROM @info
         WHERE column_type = 'period' AND CAST([column] AS INT) > 4

        UPDATE l
           SET l.score = i.value
          FROM @linescore l
         INNER JOIN @info i
            ON i.team_key = l.[key] AND i.[column] = l.period_value AND i.column_type = 'period' AND CAST(i.[column] AS INT) > 4
    END

    DELETE @linescore 
     WHERE ISNUMERIC(period_value) <> 1


    -- drive
    DECLARE @scoring TABLE
    (
        sequence_number INT,
        period_value INT,
        period_time_remaining VARCHAR(100),
        team_key VARCHAR(100),
        play_type VARCHAR(100),
        away_score INT,
        home_score INT,
        value VARCHAR(MAX),
        -- drive
        drive_number INT,
        time_of_possession VARCHAR(100),
        number_of_plays INT,
        total_yards INT,
        -- display
        score_display VARCHAR(100) DEFAULT '',
        team VARCHAR(100),
        xp_sequence_number INT,
        max_number INT,
        min_number INT,
        time_of_possession_sec INT,
        score_time_remaining VARCHAR(100)
    )
    INSERT INTO @scoring (sequence_number, period_value, period_time_remaining, team_key, play_type, away_score, home_score, value)
    SELECT sequence_number, period_value, period_time_remaining, team_key, play_type, away_score, home_score, value
      FROM dbo.SMG_Plays_NFL
     WHERE event_key = @event_key AND no_play = 'false' AND (play_score > 0 OR play_type IN ('failed_one_point_conversion', 'failed_two_point_conversion'))

    UPDATE s
       SET s.team_key = p.scoring_team_key
      FROM @scoring s
     INNER JOIN dbo.SMG_Plays_NFL p
        ON p.event_key = @event_key AND p.sequence_number = s.sequence_number AND p.scoring_team_key IS NOT NULL

    -- extra point
    UPDATE s
       SET s.xp_sequence_number = (SELECT TOP 1 xp.sequence_number
                                     FROM @scoring xp
                                    WHERE xp.play_type IN ('one_point_conversion', 'failed_one_point_conversion', 'two_point_conversion', 'failed_two_point_conversion') AND
                                          xp.team_key = team_key AND xp.period_value = period_value AND xp.sequence_number BETWEEN s.sequence_number AND s.sequence_number + 3
                                    ORDER BY xp.sequence_number ASC)
      FROM @scoring s
     WHERE s.play_type IN ('touchdown', 'defensive_touchdown')
   
    UPDATE s
       SET s.away_score = xp.away_score, s.home_score = xp.home_score, s.period_time_remaining = xp.period_time_remaining,
           s.value = s.value + ' (' + xp.value + ')'
      FROM @scoring s
     INNER JOIN @scoring xp
        ON xp.sequence_number = s.xp_sequence_number
     WHERE s.play_type IN ('touchdown', 'defensive_touchdown')

    DELETE @scoring
     WHERE play_type IN ('one_point_conversion', 'failed_one_point_conversion', 'two_point_conversion', 'failed_two_point_conversion')     
       
    UPDATE @scoring
       SET score_display = CASE
                               WHEN away_score > home_score THEN (SELECT [last] FROM @teams WHERE [key] = @away_key) + ' ' + CAST(away_score AS VARCHAR) + '-' + CAST(home_score AS VARCHAR)
                               WHEN away_score < home_score THEN (SELECT [last] FROM @teams WHERE [key] = @home_key) + ' ' + CAST(home_score AS VARCHAR) + '-' + CAST(away_score AS VARCHAR)
                               ELSE CAST(away_score AS VARCHAR) + '-' + CAST(home_score AS VARCHAR)
                           END
     
    UPDATE @scoring
       SET team = (SELECT [first] FROM @teams WHERE [key] = team_key)

    -- adjust time_left
    UPDATE s
       SET s.score_time_remaining = (SELECT TOP 1 i.value
                                       FROM SMG_Plays_Info i
                                      WHERE i.event_key = @event_key AND i.play_type = 'possession' AND i.[column] = 'period_time_remaining' AND
                                            i.sequence_number >= s.sequence_number
                                      ORDER BY i.sequence_number ASC)
      FROM @scoring s

    UPDATE @scoring
       SET period_time_remaining = score_time_remaining
     WHERE score_time_remaining IS NOT NULL

    UPDATE @scoring
       SET period_time_remaining = ':00'
     WHERE period_time_remaining = '15:00'

    -- drive
    UPDATE s
       SET s.drive_number = p.drive_number
      FROM @scoring s
     INNER JOIN dbo.USCP_football_plays p
        ON p.event_key = @event_key AND p.sequence_number = s.sequence_number

    UPDATE s
       SET s.number_of_plays = d.number_of_plays, s.total_yards = d.total_yards
      FROM @scoring s
     INNER JOIN dbo.USCP_football_drives d
        ON d.event_key = @event_key AND d.drive_number = s.drive_number

    -- possession
    UPDATE s
       SET s.max_number = (SELECT TOP 1 CAST(REPLACE(i.value, ':', '') AS INT)
                             FROM SMG_Plays_Info i
                            WHERE i.event_key = @event_key AND i.play_type = 'possession' AND i.[column] = 'period_time_remaining' AND
                                  i.sequence_number < s.sequence_number
                            ORDER BY i.sequence_number DESC)
      FROM @scoring s

    UPDATE s
       SET s.min_number = (SELECT TOP 1 CAST(REPLACE(i.value, ':', '') AS INT)
                             FROM SMG_Plays_Info i
                            WHERE i.event_key = @event_key AND i.play_type = 'possession' AND i.[column] = 'period_time_remaining' AND
                                  i.sequence_number > s.sequence_number
                            ORDER BY i.sequence_number ASC)
      FROM @scoring s

    -- score on final play
    UPDATE @scoring
       SET min_number = 0
     WHERE min_number IS NULL
   
    UPDATE @scoring
       SET time_of_possession_sec = ((max_number / 100) - (min_number / 100)) * 60 + ((max_number % 100) - (min_number % 100))

    UPDATE @scoring
       SET time_of_possession_sec = time_of_possession_sec + (15 * 60)
     WHERE time_of_possession_sec < 0
 
    UPDATE @scoring
       SET time_of_possession = CAST((time_of_possession_sec / 60) AS VARCHAR)
                                + ':' +
                                CASE
                                    WHEN (time_of_possession_sec % 60) < 10 THEN '0' + CAST((time_of_possession_sec % 60) AS VARCHAR)
                                    ELSE CAST((time_of_possession_sec % 60) AS VARCHAR)
                                END


    SELECT @print_status AS '@print-status', @start_date_time_EST AS '@start-date-time-est', @event_key AS '@event-key', @duration AS '@duration', @attendance AS '@attendance',
    (
        SELECT
        (
            SELECT t.alignment AS '@alignment', t.[first] AS '@first', t.[last] AS '@last', t.abbr AS '@abbreviation', t.score AS '@score',
            (
                SELECT d.total_first_downs AS '@total-first-downs',
                       d.rushing_first_downs AS '@rushing-first-downs', d.passing_first_downs AS '@passing-first-downs', d.penalty_first_downs AS '@penalty-first-downs',
                       d.third_downs_attempted AS '@third-downs-attempted', d.third_downs_succeeded AS '@third-downs-succeeded',
                       d.fourth_downs_attempted AS '@fourth-downs-attempted', d.fourth_downs_succeeded AS '@fourth-downs-succeeded',
                       d.passing_net_yards AS '@passing-net-yards', d.passing_plays_attempted AS '@passing-plays-attempted', d.passing_plays_completed AS '@passing-plays-completed',
                       d.passing_plays_sacked AS '@passing-plays-sacked', d.passing_sacked_yards AS '@passing-sacked-yards', d.passing_plays_intercepted AS '@passing-plays-intercepted',
                       d.rushing_net_yards AS '@rushing-net-yards', d.rushing_plays AS '@rushing-plays',
                       d.punting_plays AS '@punting-plays', d.punting_gross_yards AS '@punting-gross-yards',
                       d.punt_returns AS '@punt-returns', d.punt_return_yards AS '@punt-return-yards',
                       d.kickoff_returns AS '@kickoff-returns', d.kickoff_return_yards AS '@kickoff-return-yards',
                       d.interception_returns AS '@interception-returns', d.interception_return_yards AS '@interception-return-yards',
                       d.penalties AS '@penalties', d.penalty_yards AS '@penalty-yards', d.fumbles AS '@fumbles', d.fumbles_lost AS '@fumbles-lost',
                       d.time_of_possession_secs AS '@time-of-possession-secs'                       
                  FROM @details d
                 WHERE d.team_key = t.[key] 
                   FOR XML PATH('details'), TYPE
            ),
            (
                SELECT
                (
                    SELECT
                    (
                        SELECT p.[first] AS '@first', p.[last] AS '@last', p.passing_plays_attempted AS '@passing-plays-attempted',
                               p.passing_plays_completed AS '@passing-plays-completed', p.passing_yards AS '@passing-yards',
                               p.passing_plays_intercepted AS '@passing-plays-intercepted', p.passing_touchdowns AS '@passing-touchdowns'
                          FROM @passing p
                         WHERE p.team_key = t.[key]
                         ORDER BY p.[last] ASC, p.[first] ASC
                           FOR XML PATH('player'), TYPE
                    )
                    FOR XML PATH('players'), TYPE
                )
                FOR XML PATH('passing'), TYPE
            ),
            (
                SELECT
                (
                    SELECT
                    (
                        SELECT r.[first] AS '@first', r.[last] AS '@last', r.rushing_plays AS '@rushing-plays',
                               r.rushing_net_yards AS '@rushing-net-yards', r.rushing_touchdowns AS '@rushing-touchdowns'
                          FROM @rushing r
                         WHERE r.team_key = t.[key]
                         ORDER BY r.[last] ASC, r.[first] ASC
                           FOR XML PATH('player'), TYPE
                    )
                    FOR XML PATH('players'), TYPE
                )
                FOR XML PATH('rushing'), TYPE
            ),
            (
                SELECT
                (
                    SELECT
                    (
                        SELECT r.[first] AS '@first', r.[last] AS '@last', r.receiving_receptions AS '@receiving-receptions',
                               r.receiving_yards AS '@receiving-yards', r.receiving_touchdowns AS '@receiving-touchdowns'
                          FROM @receiving r
                         WHERE r.team_key = t.[key]
                         ORDER BY r.[last] ASC, r.[first] ASC
                           FOR XML PATH('player'), TYPE
                    )
                    FOR XML PATH('players'), TYPE
                )
                FOR XML PATH('receiving'), TYPE
            ),
            (
                SELECT
                (
                    SELECT
                    (
                        SELECT ta.[first] AS '@first', ta.[last] AS '@last', ta.defense_solo_tackles AS '@defense-solo-tackles',
                               ta.defense_assisted_tackles AS '@defense-assisted-tackles', ta.defense_sacks AS '@defense-sacks'
                          FROM @tackles ta
                         WHERE ta.team_key = t.[key]
                         ORDER BY ta.[last] ASC, ta.[first] ASC
                           FOR XML PATH('player'), TYPE
                    )
                    FOR XML PATH('players'), TYPE
                )
                FOR XML PATH('tackles'), TYPE
            ),
            (
                SELECT
                (
                    SELECT
                    (
                        SELECT i.[first] AS '@first', i.[last] AS '@last', i.defense_interceptions AS '@defense-interceptions',
                               i.defense_interception_yards AS '@defense-interception-yards'
                          FROM @interceptions i
                         WHERE i.team_key = t.[key]
                         ORDER BY i.[last] ASC, i.[first] ASC
                           FOR XML PATH('player'), TYPE
                    )
                    FOR XML PATH('players'), TYPE
                )
                FOR XML PATH('interceptions'), TYPE
            ),
            (
                SELECT
                (
                    SELECT
                    (
                        SELECT f.[first] AS '@first', f.[last] AS '@last', f.fumbles_lost AS '@fumbles-lost',
                               f.fumbles_recovered_lost_by_opposition AS '@fumbles-recovered-lost-by-opposition'
                          FROM @fumbles f
                         WHERE f.team_key = t.[key]
                         ORDER BY f.[last] ASC, f.[first] ASC
                           FOR XML PATH('player'), TYPE
                    )
                    FOR XML PATH('players'), TYPE
                )
                FOR XML PATH('fumbles'), TYPE
            ),
            (
                SELECT
                (
                    SELECT
                    (
                        SELECT f.[first] AS '@first', f.[last] AS '@last', f.field_goals_attempted AS '@field-goals-attempted',
                               f.field_goals_succeeded AS '@field-goals-succeeded', f.[failed-field-goal] AS '@failed-field-goal'
                          FROM @field_goals f
                         WHERE f.team_key = t.[key]
                         ORDER BY f.[last] ASC, f.[first] ASC
                           FOR XML PATH('player'), TYPE
                    )
                    FOR XML PATH('players'), TYPE
                )
                FOR XML PATH('field_goals'), TYPE
            ),
            (
                SELECT
                (
                    SELECT l.period_value AS '@period-value', l.score AS '@score'
                      FROM @linescore l
                     WHERE l.[key] = t.[key]
                     ORDER BY CAST(period_value AS INT) ASC
                       FOR XML PATH('quarter'), TYPE         
                )
                FOR XML PATH('quarters'), TYPE
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
            SELECT p.period_value AS '@period',
            (
                SELECT s.team AS '@team', s.period_time_remaining AS '@time-of-score', s.number_of_plays AS '@number-of-plays',
                       s.total_yards AS '@drive-length', s.time_of_possession AS '@duration-of-drive', s.score_display AS '@new-score', s.value AS '@summary'
-- **DEBUG** , s.sequence_number as '@sequence-number', s.max_number as '@max-number', s.min_number as '@min-number' 
                  FROM @scoring s
                 WHERE s.period_value = p.period_value
                 ORDER BY sequence_number ASC
                   FOR XML PATH('score'), TYPE
            )
            FROM @scoring p
            GROUP BY p.period_value
            FOR XML PATH('scores'), TYPE
        )
        FOR XML PATH('scoring'), TYPE
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
