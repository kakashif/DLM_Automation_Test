USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetEventBoxscore_hockey_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DES_GetEventBoxscore_hockey_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:		ikenticus
-- Create date:	09/26/2014
-- Description:	get boxscore for desktop for hockey
-- Update:		10/16/2014 - ikenticus - fixing SCI-519: tooltip, plays, OT shots on goal
--				06/24/2015 - ikenticus - adding failover event_key logic for source transitions
--				09/17/2015 - ikenticus: adding recap logic
--				09/25/2015 - John Lin - replace cast for period time elapsed
--				10/21/2015 - ikenticus: updating suppression logic in preparation for CMS tool
--				10/26/2015 - ikenticus - adding display_status logic for column suppression
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @event_key VARCHAR(100)
    DECLARE @sub_season_type VARCHAR(100)
    DECLARE @event_status VARCHAR(100)
    DECLARE @away_team_key VARCHAR(100)
    DECLARE @home_team_key VARCHAR(100)
    DECLARE @officials VARCHAR(100)
    DECLARE @date_time VARCHAR(100)
    DECLARE @recap VARCHAR(100)
   
    SELECT TOP 1 @event_key = event_key, @sub_season_type = sub_season_type, @event_status = event_status,
           @away_team_key = away_team_key, @home_team_key = home_team_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

    IF (@event_key IS NULL)
    BEGIN
        -- Failover during source transitions
        SELECT TOP 1 @league_key = league_key,
               @event_key = event_key, @sub_season_type = sub_season_type, @event_status = event_status,
               @away_team_key = away_team_key, @home_team_key = home_team_key
          FROM SportsDB.dbo.SMG_Schedules AS s
         INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = s.league_key AND m.value_to = @leagueName AND m.value_type = 'league'
         WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
         ORDER BY league_key DESC
    END

    -- LINESCORE
    DECLARE @linescore TABLE
    (
        period       INT,
        period_value VARCHAR(100),
        away_value   VARCHAR(100),
        home_value   VARCHAR(100),
        away_shots   VARCHAR(100),
        home_shots   VARCHAR(100)
    )
    INSERT INTO @linescore (period, period_value, away_value, home_value)
    SELECT period, period_value, away_value, home_value
      FROM dbo.SMG_Periods
     WHERE event_key = @event_key

    -- SHOTS ON GOAL
    DECLARE @shots_on_goal TABLE
    (
        period       INT IDENTITY(1,1),
        period_value VARCHAR(100),
        away_shots   VARCHAR(100),
        home_shots   VARCHAR(100)
    )
    INSERT INTO @shots_on_goal (period_value, away_shots)
    SELECT [column], value
      FROM dbo.SMG_Scores
     WHERE event_key = @event_key AND team_key = @away_team_key AND column_type = 'period-shots'

    UPDATE l
       SET home_shots = s.value
      FROM @shots_on_goal AS l
     INNER JOIN dbo.SMG_Scores AS s
        ON s.event_key = @event_key AND s.team_key = @home_team_key AND s.column_type = 'period-shots' AND l.period_value = s.[column]

    IF (@sub_season_type = 'season-regular')
    BEGIN
        DELETE FROM @shots_on_goal
         WHERE period_value = '5'
    END

    UPDATE @shots_on_goal
       SET period_value = (CASE WHEN period_value = '4' THEN 'OT'
                                WHEN CAST(period_value AS INT) > 4 THEN CAST((period - 3) AS VARCHAR) + 'OT'
                                ELSE period_value
                          END)
     WHERE period_value <> 'Total' AND CAST(period_value AS INT) > 3


    -- BOXSCORE
    DECLARE @tables TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        table_name VARCHAR(100),    
        table_display VARCHAR(100)
    )
    INSERT INTO @tables (table_name, table_display)
    VALUES ('goaltending', 'Goaltending'), ('skaters', '')

    DECLARE @columns TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        table_name     VARCHAR(100),
        column_name    VARCHAR(100),
        column_display VARCHAR(100),
        tooltip        VARCHAR(100)
    )        
    INSERT INTO @columns (table_name, column_name, column_display, tooltip)
    VALUES ('skaters', 'player_display', 'PLAYER', 'Player'),
           ('skaters', 'goals', 'G', 'Goals'),
           ('skaters', 'assists', 'A', 'Assists'),
           ('skaters', 'plus_minus', '+/-', 'Plus/Minus Rating'),
           ('skaters', 'shots', 'S', 'Shots'),
           ('skaters', 'penalty_minutes', 'PIM', 'Penalty Minutes'),
           ('skaters', 'blocked_shots', 'BS', 'Block Shots'),
           ('skaters', 'shifts', 'SHF', 'Shifts'),
           ('skaters', 'time-on-ice', 'TOI', 'Time On Ice'),
           ('skaters', 'time-on-ice-power-play', 'PPM', 'Power-Play Minutes'),
           ('skaters', 'time-on-ice-short-handed', 'SHM', 'Short-Handed Minutes'),
           ('skaters', 'time-on-ice-even-strength', 'EVM', 'Even Strength Minutes'),
           ('skaters', 'faceoffs_won', 'FW', 'Faceoffs Won'),
           ('skaters', 'faceoffs_lost', 'FL', 'Faceoffs Lost'),
           ('skaters', 'hits', 'H', 'Hits'),
           ('skaters', 'goals_power_play', 'PPG', 'Goals Power Play'),           
           ('skaters', 'points_power_play', 'PPP', 'Points Power Play'),           

           ('goaltending', 'player_display', 'PLAYER', 'player'),
           ('goaltending', 'shots_against', 'SA', 'Shots Against'),
           ('goaltending', 'goals_against', 'GA', 'Goals Against'),
           ('goaltending', 'saves', 'SAVES', 'Saves'),
           ('goaltending', 'save-percentage', 'SV%', 'Save Percentage'),
           ('goaltending', 'time-on-ice', 'TOI', 'Time On Ice')

    DECLARE @stats TABLE
    (
        team_key       VARCHAR(100),
        player_key     VARCHAR(100),
        player_display VARCHAR(100),
        column_name    VARCHAR(100), 
        value          VARCHAR(100)
    )
    INSERT INTO @stats (team_key, player_key, column_name, value)
    SELECT team_key, player_key, REPLACE([column], '-', '_'), value 
      FROM SportsEditDB.dbo.SMG_Events_hockey
     WHERE season_key = @seasonKey AND sub_season_type = @sub_season_type AND event_key = @event_key

    DECLARE @hockey TABLE
    (
        team_key       VARCHAR(100),
        player_key     VARCHAR(100),
        player_display VARCHAR(100),
        -- skaters
        goals            INT,
        assists          INT,
        plus_minus       INT,
        shots            INT,
        penalty_minutes  INT,
        blocked_shots    INT,
        shifts           INT,
        time_on_ice_secs INT,
        [time-on-ice]                  VARCHAR(100),        
        time_on_ice_power_play_secs    INT,
        [time-on-ice-power-play]       VARCHAR(100),
        time_on_ice_short_handed_secs  INT,
        [time-on-ice-short-handed]     VARCHAR(100),
        time_on_ice_even_strength_secs INT,
        [time-on-ice-even-strength]    VARCHAR(100),        
        faceoffs_won      INT,
        faceoffs_lost     INT,
        hits              INT,
        goals_power_play  INT,
        points_power_play INT,
        -- goaltending
        shots_against     INT,
        goals_against     INT,
        [saves]           INT,
        [save-percentage] VARCHAR(100),
        -- head to head
        faceoff_total_wins   INT,
        faceoff_total_losses INT,
        player_hits          INT
    )
    INSERT INTO @hockey (player_key, team_key,
                         goals, assists, plus_minus, shots, penalty_minutes, blocked_shots, shifts,
                         time_on_ice_secs, time_on_ice_power_play_secs, time_on_ice_short_handed_secs, time_on_ice_even_strength_secs,
                         faceoffs_won, faceoffs_lost, hits, goals_power_play, points_power_play,
                         shots_against, goals_against,
                         faceoff_total_wins, faceoff_total_losses, player_hits)
    SELECT p.player_key, p.team_key,
           ISNULL(goals, 0), ISNULL(assists, 0), ISNULL(plus_minus, 0), ISNULL(shots, 0), ISNULL(penalty_minutes, 0), ISNULL(blocked_shots, 0), ISNULL(shifts, 0),
           ISNULL(time_on_ice_secs, 0), ISNULL(time_on_ice_power_play_secs, 0), ISNULL(time_on_ice_short_handed_secs, 0), ISNULL(time_on_ice_even_strength_secs, 0),
           ISNULL(faceoffs_won, 0), ISNULL(faceoffs_lost, 0), ISNULL(hits, 0), ISNULL(goals_power_play, 0), ISNULL(points_power_play, 0),
           ISNULL(shots_against, 0), ISNULL(goals_against, 0),
           ISNULL(faceoff_total_wins, 0), ISNULL(faceoff_total_losses, 0), ISNULL(player_hits, 0)
      FROM (SELECT player_key, team_key, column_name, value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.column_name IN (goals, assists, plus_minus, shots, penalty_minutes, blocked_shots, shifts,
                                               time_on_ice_secs, time_on_ice_power_play_secs, time_on_ice_short_handed_secs, time_on_ice_even_strength_secs,
                                               faceoffs_won, faceoffs_lost, hits, goals_power_play, points_power_play,
                                               shots_against, goals_against,
                                               faceoff_total_wins, faceoff_total_losses, player_hits)) AS p

    -- calculations
    UPDATE @hockey
       SET [saves] = (shots_against - goals_against),
           [time-on-ice] = CAST((CAST(time_on_ice_secs AS INT)/ 60) AS VARCHAR) + ':' +
                           CASE
                               WHEN CAST(time_on_ice_secs AS INT) % 60 > 9 THEN CAST((CAST(time_on_ice_secs AS INT) % 60) AS VARCHAR)
                               ELSE '0' + CAST((CAST(time_on_ice_secs AS INT) % 60) AS VARCHAR)
                           END,
           [time-on-ice-power-play] = CAST((CAST(time_on_ice_power_play_secs AS INT)/ 60) AS VARCHAR) + ':' +
                                      CASE
                                          WHEN CAST(time_on_ice_power_play_secs AS INT) % 60 > 9 THEN CAST((CAST(time_on_ice_power_play_secs AS INT) % 60) AS VARCHAR)
                                          ELSE '0' + CAST((CAST(time_on_ice_power_play_secs AS INT) % 60) AS VARCHAR)
                                      END,
           [time-on-ice-short-handed] = CAST((CAST(time_on_ice_short_handed_secs AS INT)/ 60) AS VARCHAR) + ':' +
                                        CASE
                                            WHEN CAST(time_on_ice_short_handed_secs AS INT) % 60 > 9 THEN CAST((CAST(time_on_ice_short_handed_secs AS INT) % 60) AS VARCHAR)
                                            ELSE '0' + CAST((CAST(time_on_ice_short_handed_secs AS INT) % 60) AS VARCHAR)
                                        END,
           [time-on-ice-even-strength] = CAST((CAST(time_on_ice_even_strength_secs AS INT)/ 60) AS VARCHAR) + ':' +
                                         CASE
                                             WHEN CAST(time_on_ice_even_strength_secs AS INT) % 60 > 9 THEN CAST((CAST(time_on_ice_even_strength_secs AS INT) % 60) AS VARCHAR)
                                             ELSE '0' + CAST((CAST(time_on_ice_even_strength_secs AS INT) % 60) AS VARCHAR)
                                         END


    UPDATE @hockey
       SET [save-percentage] = CAST(CAST((CAST([saves] AS FLOAT) / shots_against * 100) AS DECIMAL(5, 1)) AS VARCHAR)
     WHERE shots_against > 0

    -- team
    -- head to head
    DECLARE @team_totals TABLE
    (
        team_key    VARCHAR(100),
        column_name VARCHAR(100),
        value       VARCHAR(100)
    )
    INSERT INTO @team_totals (team_key, column_name, value)
    SELECT team_key, column_name, value
      FROM @stats
     WHERE player_key = 'team' AND
           column_name IN ('shots', 'goals_power_play', 'power_plays', 'faceoff_total_wins', 'faceoff_total_losses', 'player_hits', 'penalty_minutes')

    DECLARE @head2head TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        display     VARCHAR(100),
        away_value  VARCHAR(100),
        home_value  VARCHAR(100),
        column_name VARCHAR(100)
    )
    
    INSERT INTO @head2head (display, column_name)
    VALUES ('Shots on Goal', 'shots'), ('Power Plays', ''), ('goals_power_play', 'goals_power_play'), ('power_plays', 'power_plays'),
           ('Faceoffs Won', 'faceoff_total_wins'), ('Faceoffs Lost', 'faceoff_total_losses'), ('Hits', 'player_hits'), ('Penalty Minutes', 'penalty_minutes')

    UPDATE h2h
       SET h2h.away_value = tt.value
      FROM @head2head h2h
     INNER JOIN @team_totals tt
        ON tt.column_name = h2h.column_name AND tt.team_key = @away_team_key

    UPDATE h2h
       SET h2h.home_value = tt.value
      FROM @head2head h2h
     INNER JOIN @team_totals tt
        ON tt.column_name = h2h.column_name AND tt.team_key = @home_team_key

    UPDATE h2h
       SET h2h.away_value = g.away_value + ' for ' + t.away_value,
           h2h.home_value = g.home_value + ' for ' + t.home_value
      FROM @head2head AS h2h
     INNER JOIN @head2head AS g
        ON g.column_name = 'goals_power_play'
     INNER JOIN @head2head AS t
        ON t.column_name = 'power_plays'
     WHERE h2h.display = 'Power Plays'

    DELETE FROM @head2head
     WHERE column_name IN ('goals_power_play', 'power_plays')

    -- player
    UPDATE b
       SET b.player_display = s.first_name + ' ' + s.last_name
      FROM @hockey AS b
     INNER JOIN SportsDB.dbo.SMG_Players AS s
        ON s.player_key = b.player_key AND s.first_name <> 'TEAM'

    DELETE @hockey
     WHERE player_display IS NULL


    -- SCORING/PENALTY DETAILS
    DECLARE @plays_tables TABLE (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        play_score INT,
        table_name VARCHAR(100),    
        table_display VARCHAR(100)
    )
    INSERT INTO @plays_tables (play_score, table_name, table_display)
    VALUES (1, 'scoring', 'SCORING DETAIL'), (0, 'penalty', 'PENALTY DETAIL')

    DECLARE @plays_columns TABLE (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        column_name    VARCHAR(100),
        column_display VARCHAR(100)
    )
    INSERT INTO @plays_columns (column_name, column_display)
    VALUES ('period_time_elapsed', 'TIME'),
           ('team_display', 'TEAM'),
           ('play_detail', 'DETAIL')

    DECLARE @plays_columns_count INT = (SELECT COUNT(*) FROM @plays_columns)

    DECLARE @plays TABLE (
        period_display VARCHAR(100),
        period_value INT,
        period_time_elapsed VARCHAR(100),
        team_key VARCHAR(100),
        team_display VARCHAR(100),
        play_detail VARCHAR(100),
        play_score INT
    )
    INSERT INTO @plays (period_value, period_time_elapsed, team_key, play_detail, play_score)
    SELECT period_value, period_time_elapsed, team_key, value, play_score
      FROM SMG_Plays_NHL
     WHERE event_key = @event_key AND period_value > 0

    UPDATE @plays
       SET period_display = (CASE
                                WHEN period_value = 1 THEN CAST(period_value AS VARCHAR) + 'st' + ' Period'
                                WHEN period_value = 2 THEN CAST(period_value AS VARCHAR) + 'nd' + ' Period'
                                WHEN period_value = 3 THEN CAST(period_value AS VARCHAR) + 'rd' + ' Period'
                                WHEN period_value > 3 THEN 'Overtime ' + CAST((period_value - 3) AS VARCHAR)
                                ELSE ''
                            END)

    UPDATE p
       SET p.team_display = t.team_display
      FROM @plays AS p
     INNER JOIN dbo.SMG_Teams AS t
        ON t.team_key = p.team_key AND t.season_key = @seasonKey

    -- goaltending
    DECLARE @goaltending TABLE
    (
        team_key             VARCHAR(100),
        player_display       VARCHAR(100),
        shots_against        INT,
        goals_against        INT,
        [saves]              INT,
        [save-percentage]    VARCHAR(100),
        [time-on-ice] VARCHAR(100)
    )
	INSERT INTO @goaltending (team_key, player_display, shots_against, goals_against, [saves], [save-percentage], [time-on-ice])
	SELECT team_key, player_display, shots_against, goals_against, [saves], [save-percentage], [time-on-ice]
	  FROM @hockey
     WHERE player_key <> 'team' AND shots_against > 0

	IF ((SELECT COUNT(*) FROM @goaltending) > 0)
	BEGIN
		INSERT INTO @goaltending (team_key, player_display, shots_against, goals_against, [saves], [save-percentage], [time-on-ice])
		SELECT @away_team_key, 'TEAM', SUM(shots_against), SUM(goals_against), SUM([saves]),
		       CAST(CAST((CAST(SUM([saves]) AS FLOAT) / SUM(shots_against) * 100) AS DECIMAL(5, 1)) AS VARCHAR), '-'
		  FROM @goaltending
		 WHERE team_key = @away_team_key 

		INSERT INTO @goaltending (team_key, player_display, shots_against, goals_against, [saves], [save-percentage], [time-on-ice])
		SELECT @home_team_key, 'TEAM', SUM(shots_against), SUM(goals_against), SUM([saves]),
		       CAST(CAST((CAST(SUM([saves]) AS FLOAT) / SUM(shots_against) * 100) AS DECIMAL(5, 1)) AS VARCHAR), '-'
		  FROM @goaltending
		 WHERE team_key = @home_team_key 
	END
	ELSE IF (@eventId <> 999999999)
	BEGIN
		DELETE FROM @tables WHERE table_name = 'goaltending'
	END

    -- skaters
    DECLARE @skaters TABLE
    (
        team_key        VARCHAR(100),
        player_display  VARCHAR(100),
        goals           INT,
        assists         INT,
        plus_minus      INT,
        shots           INT,
        penalty_minutes INT,
        blocked_shots   INT,
        shifts          INT,
        [time-on-ice]               VARCHAR(100),        
        [time-on-ice-power-play]    VARCHAR(100),
        [time-on-ice-short-handed]  VARCHAR(100),
        [time-on-ice-even-strength] VARCHAR(100),        
        faceoffs_won      INT,
        faceoffs_lost     INT,
        hits              INT,
        goals_power_play  INT,
        points_power_play INT
    )
	INSERT INTO @skaters (team_key, player_display, goals, assists, plus_minus, shots, penalty_minutes, blocked_shots, shifts,
                         [time-on-ice], [time-on-ice-power-play], [time-on-ice-short-handed], [time-on-ice-even-strength],
                         faceoffs_won, faceoffs_lost, hits, goals_power_play, points_power_play)
	SELECT team_key, player_display, goals, assists, plus_minus, shots, penalty_minutes, blocked_shots, shifts,
           [time-on-ice], [time-on-ice-power-play], [time-on-ice-short-handed], [time-on-ice-even-strength],
           faceoffs_won, faceoffs_lost, hits, goals_power_play, points_power_play
	  FROM @hockey
     WHERE player_key <> 'team' AND shots_against = 0

	IF ((SELECT COUNT(*) FROM @skaters) > 0)
	BEGIN
		INSERT INTO @skaters (team_key, player_display, goals, assists, plus_minus, shots, penalty_minutes, blocked_shots, shifts,
                              [time-on-ice], [time-on-ice-power-play], [time-on-ice-short-handed], [time-on-ice-even-strength],
                              faceoffs_won, faceoffs_lost, hits, goals_power_play, points_power_play)
		SELECT @away_team_key, 'TEAM', SUM(goals), SUM(assists), '-', SUM(shots), SUM(penalty_minutes), SUM(blocked_shots), SUM(shifts),
		       '-', '-', '-', '-',
		       SUM(faceoffs_won), SUM(faceoffs_lost), SUM(hits), SUM(goals_power_play), SUM(points_power_play)
		  FROM @skaters
		 WHERE team_key = @away_team_key 

		INSERT INTO @skaters (team_key, player_display, goals, assists, plus_minus, shots, penalty_minutes, blocked_shots, shifts,
                              [time-on-ice], [time-on-ice-power-play], [time-on-ice-short-handed], [time-on-ice-even-strength],
                              faceoffs_won, faceoffs_lost, hits, goals_power_play, points_power_play)
		SELECT @home_team_key, 'TEAM', SUM(goals), SUM(assists), '-', SUM(shots), SUM(penalty_minutes), SUM(blocked_shots), SUM(shifts),
		       '-', '-', '-', '-',
		       SUM(faceoffs_won), SUM(faceoffs_lost), SUM(hits), SUM(goals_power_play), SUM(points_power_play)
		  FROM @skaters
		 WHERE team_key = @home_team_key 
	END
	ELSE IF (@eventId <> 999999999)
	BEGIN
		DELETE FROM @tables WHERE table_name = 'passing'
	END

    
    -- officials
    DECLARE @referee TABLE
    (
        position VARCHAR(100),
        judge VARCHAR(100),
        [order] INT
    )
    INSERT INTO @referee (position, judge)
    SELECT [column], REPLACE(value, ',', ';')
      FROM dbo.SMG_Scores
     WHERE event_key = @event_key AND column_type = 'officials'

    SELECT @officials = COALESCE(@officials + ', ', '') + position + ': ' + judge
      FROM @referee
     ORDER BY [order] ASC

    -- DATETIME
    SELECT TOP 1 @date_time = date_time
      FROM SportsDB.dbo.SMG_Scores
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key = @event_key
     ORDER BY date_time DESC

    IF (@event_status = 'post-event')
    BEGIN
        -- Recap
        SELECT @recap = '/sports/' + @leagueName + '/event/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR) + '/recap/'
          FROM SportsDB.dbo.SMG_Scores
         WHERE league_key = @league_key AND season_key = @seasonKey AND event_key = @event_key AND column_type = 'post-event-coverage'
    END

	-- Display Column Status suppression
	IF (@eventID <> '999999999')
	BEGIN
		DELETE c
		  FROM @columns c
		 INNER JOIN SportsEditDB.dbo.SMG_Column_Display_Status s
		    ON s.table_name = c.table_name AND s.column_name = c.column_name
		 WHERE s.platform = 'DES' AND s.page = 'boxscore' AND s.league_name = @leagueName
		   AND display_status = 'hidden'
	END

	SELECT @recap AS recap,
	(
		SELECT t.table_name, t.table_display,
		       (
				   SELECT c.column_name, c.column_display, c.tooltip
					 FROM @columns c
					WHERE c.table_name = t.table_name
					ORDER BY c.id ASC
					  FOR XML PATH('columns'), TYPE
			   ),
			   -- away
               (
                   SELECT player_display, shots_against, goals_against, [saves], [save-percentage], [time-on-ice]
                     FROM @goaltending
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'goaltending'
                    ORDER BY shots_against DESC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT player_display, shots_against, goals_against, [saves], [save-percentage], [time-on-ice]
                     FROM @goaltending
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'goaltending'
                      FOR XML PATH('away_total'), TYPE
               ),
               (
                   SELECT player_display, goals, assists, plus_minus, shots, penalty_minutes, blocked_shots, shifts,
                          [time-on-ice], [time-on-ice-power-play], [time-on-ice-short-handed], [time-on-ice-even-strength],
                          faceoffs_won, faceoffs_lost, hits, goals_power_play, points_power_play
                     FROM @skaters
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'skaters'
                    ORDER BY goals DESC, assists DESC, shots DESC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT player_display, goals, assists, plus_minus, shots, penalty_minutes, blocked_shots, shifts,
                          [time-on-ice], [time-on-ice-power-play], [time-on-ice-short-handed], [time-on-ice-even-strength],
                          faceoffs_won, faceoffs_lost, hits, goals_power_play, points_power_play
                     FROM @skaters
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'skaters'
                      FOR XML PATH('away_total'), TYPE
               ),
               -- home               
               (
                   SELECT player_display, shots_against, goals_against, [saves], [save-percentage], [time-on-ice]
                     FROM @goaltending
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'goaltending'
                    ORDER BY shots_against DESC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT player_display, shots_against, goals_against, [saves], [save-percentage], [time-on-ice]
                     FROM @goaltending
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'goaltending'
                      FOR XML PATH('home_total'), TYPE
               ),
               (
                   SELECT player_display, goals, assists, plus_minus, shots, penalty_minutes, blocked_shots, shifts,
                          [time-on-ice], [time-on-ice-power-play], [time-on-ice-short-handed], [time-on-ice-even-strength],
                          faceoffs_won, faceoffs_lost, hits, goals_power_play, points_power_play
                     FROM @skaters
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'skaters'
                    ORDER BY goals DESC, assists DESC, shots DESC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT player_display, goals, assists, plus_minus, shots, penalty_minutes, blocked_shots, shifts,
                          [time-on-ice], [time-on-ice-power-play], [time-on-ice-short-handed], [time-on-ice-even-strength],
                          faceoffs_won, faceoffs_lost, hits, goals_power_play, points_power_play
                     FROM @skaters
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'skaters'
                      FOR XML PATH('home_total'), TYPE
               )
   		  FROM @tables t
		 ORDER BY t.id ASC
		   FOR XML PATH('boxscore'), TYPE		   
	),
    (
        SELECT display, away_value, home_value
          FROM @head2head
         ORDER BY id ASC
           FOR XML PATH('head_to_head'), TYPE
    ),
    (
	    SELECT @officials
	       FOR XML PATH('officials'), TYPE
	),
	(
	    SELECT @date_time
	       FOR XML PATH('updated_date'), TYPE
	),
	(
	    SELECT (
                   SELECT period_value AS periods
                     FROM @linescore
                    ORDER BY period ASC
                      FOR XML PATH(''), TYPE
               ),
               (
                   SELECT away_value AS away_sub_score
                     FROM @linescore
                    ORDER BY period ASC
                      FOR XML PATH(''), TYPE                              
               ),
               (
                   SELECT home_value AS home_sub_score
                     FROM @linescore
                    ORDER BY period ASC
                      FOR XML PATH(''), TYPE                              
               )
           FOR XML PATH('linescore'), TYPE
    ),
    (
        SELECT 'Shots On Goal' AS ribbon,
               (
                   SELECT period_value AS periods
                     FROM @shots_on_goal
                    ORDER BY period ASC
                      FOR XML PATH(''), TYPE
               ),
               (
                   SELECT away_shots AS away_sub_score
                     FROM @shots_on_goal
                    ORDER BY period ASC
                      FOR XML PATH(''), TYPE                              
               ),
               (
                   SELECT home_shots AS home_sub_score
                     FROM @shots_on_goal
                    ORDER BY period ASC
                      FOR XML PATH(''), TYPE                              
               )
           FOR XML PATH('shots_on_goal'), TYPE
    ),
    (
        SELECT p.period_display AS ribbon, @plays_columns_count AS columns_count,
        (
            SELECT
            (
                SELECT column_name,
                      (CASE WHEN column_display = 'DETAIL' THEN d.table_display ELSE column_display END) AS column_display
                  FROM @plays_columns
                 ORDER BY id ASC
                   FOR XML PATH('columns'), TYPE
            ),
            (
                SELECT period_time_elapsed, team_display, play_detail
                  FROM @plays AS r
                 WHERE r.play_score = d.play_score AND r.period_value = p.period_value
                 ORDER BY CAST(REPLACE(period_time_elapsed, ':', '') AS INT) ASC
                   FOR XML PATH('rows'), TYPE
            )
            FROM @plays_tables AS d
            ORDER BY id ASC
            FOR XML PATH('details'), TYPE
        )
        FROM @plays AS p
        GROUP BY period_display, period_value
        ORDER BY period_value ASC
        FOR XML PATH('period_details'), TYPE           
    )
	FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF;
END


GO
