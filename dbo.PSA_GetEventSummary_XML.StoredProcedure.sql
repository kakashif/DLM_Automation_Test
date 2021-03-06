USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventSummary_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PSA_GetEventSummary_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:		John Lin
-- Create date:	06/27/2014
-- Description:	get scoring summary / match summary
-- Update:		09/09/2014 - John Lin - update NCAA logo
--				09/12/2014 - John Lin - update MLS
-- 				09/19/2014 - ikenticus: adding EPL/Champions
--                         - John Lin - reverse chronological order for MLB, NFL, NCAAF
--              09/25/2014 - John Lin - baseball: find score/scoring, render to period, if name abbr render to next period
--              10/09/2014 - John Lin - whitebg
--              10/30/2014 - ikenticus - SJ-715: setting NCAAF overtime clock to 0:00
--              10/31/2014 - ikenticus - SJ-777: adding ordinal overtime for football, setting NCAAF overtime clock to empty string
--              11/11/2014 - ikenticus - SJ-574: modifying logic to compensate for extra-point=0 occurrences
--              11/11/2014 - ikenticus - SJ-904: using period_value > 4 for null clock instead of period_order
--				11/14/2014 - ikenticus - SJ-921: mark and flip own goals to other team column
--				12/23/2014 - ikenticus - SJ-1124: adding missing penalty-goal to summary
--				02/10/2015 - ikenticus - SJ-1367: making sure empty goal/card still displays away/home nodes
--				02/12/2015 - ikenticus - SJ-1368: ordering the match summary by minutes instead sequence_number
--				04/29/2015 - ikenticus: adjusting event_key to handle multiple sources
--              05/15/2015 - ikenticus: adjusting league_key for world cup
--				05/16/2015 - ikenticus: using player_key instead of value since non-datafactory contains entire play comment
--				06/08/2015 - ikenticus: adding 'penalty-kick---good' in addition to 'penalty-kick--good' due to WWC glitch
--				06/24/2015 - ikenticus - adding failover event_key logic for source transitions
--              07/04/2015 - John Lin - update play score for MLB
--              07/07/2015 - John Lin - return list
--              08/11/2015 - John Lin - SDI NFL comment
--				08/12/2015 - ikenticus - replacing logo with function
--				09/02/2015 - ikenticus - simplifying goal variations by standardizing in Feeds_SMG_Plays_MLS
--              09/12/2015 - John Lin - NFL use time left of next play as end time left of current play
--              09/25/2015 - John Lin - scoring team key
--              09/28/2015 - ikenticus - limit the XP/2PT sequence number range for when SDI fails to provide
--              10/07/2015 - John Lin - NF use time left of next possession for scoring
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    IF (@leagueName NOT IN ('mlb','nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba',
							'champions', 'natl', 'wwc', 'epl', 'chlg', 'mls'))

    BEGIN
        RETURN
    END
        
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @event_key VARCHAR(100)
    DECLARE @event_status VARCHAR(100)
    DECLARE @away_team_key VARCHAR(100)
    DECLARE @home_team_key VARCHAR(100)

    SELECT TOP 1 @event_key = event_key, @event_status = event_status, @away_team_key = away_team_key, @home_team_key = home_team_key
      FROM SportsDB.dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key,
			   @event_key = event_key, @event_status = event_status, @away_team_key = away_team_key, @home_team_key = home_team_key
		  FROM SportsDB.dbo.SMG_Schedules AS s
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = s.league_key AND m.value_to = @leagueName AND m.value_type = 'league'
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		 ORDER BY league_key DESC
	END

    IF (@leagueName NOT IN ('mlb', 'ncaaf', 'nfl', 'mls', 'epl', 'champions', 'natl', 'wwc') OR @event_status = 'pre-event')
    BEGIN
	    SELECT '' AS scoring_summary
           FOR XML PATH(''), ROOT('root')

        RETURN
    END


    DECLARE @summary TABLE
    (
        period_order INT,
        sequence_order INT,
        sequence_number INT,
        team_key VARCHAR(100),
        value VARCHAR(MAX),
        player_key VARCHAR(100),
        player_name VARCHAR(100),
        team_logo VARCHAR(100),
        -- common
        period_value INT,
        play_type VARCHAR(100),
        away_score INT,
        home_score INT,        
        -- MLB
        inning_value INT,
        inning_half VARCHAR(100),
        -- NFL, NCAAF
        period_time_remaining VARCHAR(100),
        period VARCHAR(100),
        xp_sequence_number INT,
        score_time_remaining VARCHAR(100),
        -- NHL
        period_time_elapsed VARCHAR(100),
        end_position INT DEFAULT 1,
        -- MLS
        minutes_elapsed VARCHAR(100),
        minutes_elapsed_int INT
    )
        
    IF (@leagueName = 'mlb')
    BEGIN
        INSERT INTO @summary (sequence_number, team_key, inning_value, inning_half, value, away_score, home_score) 
        SELECT sequence_number, team_key, inning_value, inning_half, value, away_score, home_score
          FROM SportsDB.dbo.SMG_Plays_MLB
         WHERE event_key = @event_key AND play_score > 0

        -- set end point to score/scoring
        UPDATE @summary
           SET end_position = CHARINDEX('score', value)
         WHERE end_position = 1  
   
        UPDATE @summary
           SET end_position = CHARINDEX('scoring', value)
         WHERE end_position = 1

        -- set end position to period
        UPDATE @summary
           SET end_position = CHARINDEX('.', value, end_position)

        -- re-set end position if char is capitial letter
        UPDATE @summary
           SET end_position = CHARINDEX('.', value, end_position + 1)
         WHERE SUBSTRING(value, end_position - 1, 1) <> LOWER(SUBSTRING(value, end_position - 1, 1)) COLLATE Latin1_General_CS_AI


        UPDATE s
           SET s.team_logo = dbo.SMG_fnTeamLogo('mlb', st.team_abbreviation, '110')
          FROM @summary s
         INNER JOIN dbo.SMG_Teams st
            ON st.season_key = @seasonKey AND st.team_key = s.team_key

		-- assume post event
		UPDATE @summary
		   SET sequence_order = sequence_number

		IF (@event_status <> 'post-event')
		BEGIN
			UPDATE @summary
			   SET sequence_order = 1000000 - sequence_order
		END

           
        ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
        SELECT
	    (
	        SELECT 'true' AS 'json:Array',
	               value AS play, team_logo, inning_half,
	               CAST(away_score AS VARCHAR) + '-' + CAST(home_score AS VARCHAR) AS score,
	               CASE
	                        WHEN inning_value <> 11 AND (inning_value % 10) = 1 THEN CAST(inning_value AS VARCHAR) + 'st'
	                        WHEN inning_value <> 12 AND (inning_value % 10) = 2 THEN CAST(inning_value AS VARCHAR) + 'nd'
	                        WHEN inning_value <> 13 AND (inning_value % 10) = 3 THEN CAST(inning_value AS VARCHAR) + 'rd'
	                        ELSE CAST(inning_value AS VARCHAR) + 'th'
	               END AS inning_value
              FROM @summary
             ORDER BY sequence_order ASC
               FOR XML RAW('scoring_summary'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
        
        RETURN
    END

    IF (@leagueName IN ('mls', 'epl', 'champions', 'natl', 'wwc'))
    BEGIN
        INSERT INTO @summary (sequence_number, team_key, away_score, home_score, minutes_elapsed_int, play_type, player_key) 
        SELECT sequence_number, team_key, away_score, home_score, minutes_elapsed, play_type, player_key
          FROM SportsDB.dbo.SMG_Plays_MLS
         WHERE event_key = @event_key AND play_type IN ('own-goal', 'goal', 'penalty-goal', 'red-card', 'yellow-card')

		UPDATE s
		   SET player_name = LEFT(first_name, 1) + '. ' + last_name
		  FROM @summary AS s
		 INNER JOIN dbo.SMG_Players AS p ON p.player_key = s.player_key

		-- Flip the own-goal scores to the opposite team
        UPDATE @summary
           SET value = '(' + CAST(away_score AS VARCHAR) + '-' + CAST(home_score AS VARCHAR) + ') ' + player_name + ' - OG',
			   play_type = 'goal', team_key = @home_team_key
         WHERE play_type = 'own-goal' AND team_key = @away_team_key

        UPDATE @summary
           SET value = player_name + ' - OG (' + CAST(away_score AS VARCHAR) + '-' + CAST(home_score AS VARCHAR) + ')',
			   play_type = 'goal', team_key = @away_team_key
         WHERE play_type = 'own-goal' AND team_key = @home_team_key

		-- According to PRD, AWAY Match Summary lists score on right side
        UPDATE @summary
           SET play_type = 'goal', value = player_name + ' (' + CAST(away_score AS VARCHAR) + '-' + CAST(home_score AS VARCHAR) + ')'
         WHERE play_type IN ('goal', 'penalty-goal') AND team_key = @away_team_key AND value IS NULL

		-- According to PRD, HOME Match Summary lists score on left side
        UPDATE @summary
           SET play_type = 'goal', value = '(' + CAST(away_score AS VARCHAR) + '-' + CAST(home_score AS VARCHAR) + ') ' + player_name
         WHERE play_type IN ('goal', 'penalty-goal') AND team_key = @home_team_key AND value IS NULL

		-- Penalties
        UPDATE @summary
           SET value = player_name
         WHERE value IS NULL

		UPDATE @summary
		   SET minutes_elapsed = CAST(minutes_elapsed_int AS VARCHAR) + ''''

		IF NOT EXISTS (SELECT 1 FROM @summary WHERE team_key = @away_team_key)
		BEGIN
			INSERT INTO @summary (team_key, play_type, minutes_elapsed, value)
			VALUES (@away_team_key, ' ', ' ', ' ')
		END

		IF NOT EXISTS (SELECT 1 FROM @summary WHERE team_key = @home_team_key)
		BEGIN
			INSERT INTO @summary (team_key, play_type, minutes_elapsed, value)
			VALUES (@home_team_key, ' ', ' ', ' ')
		END


        ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
        SELECT
	    (              
		    SELECT (
	                   SELECT 'true' AS 'json:Array',
	                          play_type, minutes_elapsed, value AS player_display
                         FROM @summary
                        WHERE team_key = @away_team_key
                        ORDER BY minutes_elapsed_int ASC
                          FOR XML RAW('away'), TYPE               
		           ),
				   ( 
	                   SELECT 'true' AS 'json:Array',
	                          play_type, minutes_elapsed, value AS player_display
                         FROM @summary
                        WHERE team_key = @home_team_key
                        ORDER BY minutes_elapsed_int ASC
                          FOR XML RAW('home'), TYPE               
                   )
				   FOR XML RAW('match_summary'), TYPE               
        )
        FOR XML PATH(''), ROOT('root')
        
        RETURN
    END

    IF (@leagueName IN ('ncaaf', 'nfl'))
    BEGIN
        INSERT INTO @summary (sequence_number, team_key, period_value, period_time_remaining, play_type, value, away_score, home_score)
        SELECT sequence_number, team_key, period_value, period_time_remaining, play_type, value, away_score, home_score
          FROM SportsDB.dbo.SMG_Plays_NFL
         WHERE event_key = @event_key AND no_play = 'false' AND (play_score > 0 OR play_type IN ('failed_one_point_conversion', 'failed_two_point_conversion'))

        UPDATE s
           SET s.team_key = p.scoring_team_key
          FROM @summary s
         INNER JOIN dbo.SMG_Plays_NFL p
            ON p.event_key = @event_key AND p.sequence_number = s.sequence_number AND p.scoring_team_key IS NOT NULL

        -- extra point
        UPDATE @summary
           SET value = SUBSTRING(value, 0, LEN(value))
         WHERE play_type IN ('one_point_conversion', 'two_point_conversion', 'failed_one_point_conversion', 'failed_two_point_conversion')

        UPDATE s
           SET s.xp_sequence_number = (SELECT TOP 1 xp.sequence_number
                                         FROM @summary xp
                                        WHERE xp.play_type IN ('one_point_conversion', 'two_point_conversion', 'failed_one_point_conversion', 'failed_two_point_conversion') AND
                                              xp.team_key = team_key AND xp.period_value = period_value AND
                                              xp.sequence_number BETWEEN s.sequence_number AND s.sequence_number + 3
                                        ORDER BY xp.sequence_number ASC)
          FROM @summary s
         WHERE s.play_type IN ('touchdown', 'defensive_touchdown')
         
        UPDATE s
           SET s.away_score = xp.away_score, s.home_score = xp.home_score, s.period_time_remaining = xp.period_time_remaining,
               s.value = s.value + ' (' +  xp.value + ')'
          FROM @summary s
         INNER JOIN @summary xp
            ON xp.sequence_number = s.xp_sequence_number
         WHERE s.play_type IN ('touchdown', 'defensive_touchdown')

        DELETE @summary
         WHERE play_type IN ('one_point_conversion', 'two_point_conversion', 'failed_one_point_conversion', 'failed_two_point_conversion')

        UPDATE @summary
           SET period = CASE
                            WHEN period_value = 1 THEN '1st Quarter'
                            WHEN period_value = 2 THEN '2nd Quarter'
                            WHEN period_value = 3 THEN '3rd Quarter'
                            WHEN period_value = 4 THEN '4th Quarter'
                            WHEN period_value = 5 THEN 'Overtime'
                            WHEN period_value = 6 THEN '2nd Overtime'
                            WHEN period_value = 7 THEN '3rd Overtime'
                            ELSE CAST(period_value - 4 AS VARCHAR) + 'th Overtime'
                        END

        -- adjust time_left
        IF (@event_status = 'post-event')
        BEGIN
            UPDATE s
               SET s.score_time_remaining = (SELECT TOP 1 i.value
                                               FROM SMG_Plays_Info i
                                              WHERE i.event_key = @event_key AND i.play_type = 'possession' AND i.[column] = 'period_time_remaining' AND
                                                    i.sequence_number >= s.sequence_number
                                              ORDER BY i.sequence_number ASC)
              FROM @summary s

            UPDATE @summary
               SET period_time_remaining = score_time_remaining
             WHERE score_time_remaining IS NOT NULL
        END

        UPDATE @summary
           SET period_time_remaining = ':00'
         WHERE period_time_remaining = '15:00'

        -- logo
        IF (@leagueName = 'nfl')
        BEGIN
            UPDATE s
               SET s.team_logo = dbo.SMG_fnTeamLogo('nfl', st.team_abbreviation, '110')
              FROM @summary s
             INNER JOIN dbo.SMG_Teams st
                ON st.season_key = @seasonKey AND st.team_key = s.team_key
        END
        ELSE
        BEGIN
            UPDATE s
               SET s.team_logo = dbo.SMG_fnTeamLogo('ncaa', st.team_abbreviation, '110')
              FROM @summary s
             INNER JOIN dbo.SMG_Teams st
                ON st.season_key = @seasonKey AND st.team_key = s.team_key
        END
        
		-- assume post event
		UPDATE @summary
		   SET sequence_order = sequence_number, period_order = period_value

		IF (@event_status <> 'post-event')
		BEGIN
			UPDATE @summary
			   SET sequence_order = 100000 - sequence_order, period_order = 100 - period_order
		END

		-- NCAAF Overtime has no clock
		IF (@leagueName = 'ncaaf')
		BEGIN
			UPDATE @summary
			   SET period_time_remaining = ''
			 WHERE period_value > 4
		END


        ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
        SELECT
	    (
	        SELECT 'true' AS 'json:Array',
	               s.period AS [quarter],
	               (
	                   SELECT s_q.value AS play, s_q.period_time_remaining AS time_left, s_q.team_logo,
	                          CAST(away_score AS VARCHAR) + '-' + CAST(home_score AS VARCHAR) AS score
	                     FROM @summary s_q
	                    WHERE s_q.period_value = s.period_value
	                    ORDER BY s_q.sequence_order ASC
	                      FOR XML RAW('scoring'), TYPE
	               )
              FROM @summary s
             GROUP BY s.period_value, s.period, s.period_order
             ORDER BY s.period_order ASC
               FOR XML RAW('scoring_summary'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
        
        RETURN
    END

    SET NOCOUNT OFF;
END

GO
