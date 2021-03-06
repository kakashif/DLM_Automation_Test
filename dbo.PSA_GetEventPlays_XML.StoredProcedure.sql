USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventPlays_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventPlays_XML] 
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:      John Lin
-- Create date: 06/27/2014
-- Description: get event plays
-- Update: 09/09/2014 - John Lin - update NCAA logo
--         09/11/2014 - ikenticus - reverse chronological order when NFL not post-event
--         09/19/2014 - John Lin - reverse chronological order for MLB
--         09/26/2014 - ikenticus - NHL enhancements like shootouts
--         10/09/2014 - John Lin - whitebg
--         10/21/2014 - ikenticus - return empty node when no plays present to avoid error
--         10/30/2014 - ikenticus - SJ-715: setting NCAAF overtime clock to 0:00
--         10/31/2014 - ikenticus - SJ-777: similiar to hockey, adding ordinal overtime for football
--         11/04/2014 - ikenticus - SJ-844: cleaning up shootout code for hockey
--         04/13/2015 - ikenticus: preparing for STATS soccer by adding the simpler league_keys (preliminary)
--         04/29/2015 - ikenticus: adjusting event_key to handle multiple sources
--         05/14/2015 - ikenticus - obtain league_key from SMG_fnGetLeagueKey
--         08/11/2015 - John Lin - remove type play for NFL
--         08/27/2015 - ikenticus - excluding MLB player substitution for SDI
--         09/29/2015 - ikenticus - adding no_play + penalty to NFL TD plays
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    IF (@leagueName NOT IN ('mlb','nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba',
							'champions', 'natl', 'wwc', 'epl', 'chlg', 'mls'))
    BEGIN
        RETURN
    END

    IF (@leagueName NOT IN ('mlb', 'ncaaf', 'nfl', 'nhl'))
    BEGIN
        SELECT '' AS plays
           FOR XML PATH(''), ROOT('root')
        
        RETURN
    END

    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/'
    DECLARE @logo_folder VARCHAR(100) = '-whitebg/110/'
    DECLARE @logo_suffix VARCHAR(100) = '.png'    
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    
    DECLARE @event_status VARCHAR(100)
    DECLARE @event_key VARCHAR(100)
    DECLARE @away_key VARCHAR(100)
    DECLARE @home_key VARCHAR(100)

    SELECT TOP 1 @event_key = event_key, @event_status = event_status
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
       
    DECLARE @plays TABLE
    (
        period_order INT,
        sequence_order INT,
        sequence_number INT,
        team_key VARCHAR(100),
        value VARCHAR(MAX),
        team_logo VARCHAR(100),
        -- common
        period_value INT,
        play_score INT,
        play_type VARCHAR(100),
        -- MLB
        inning_value INT,
        inning_half VARCHAR(100),
        -- NFL, NCAAF
        period_time_remaining VARCHAR(100),
        period VARCHAR(100),
        end_position INT DEFAULT 1,
        no_play VARCHAR(100),
        -- NHL
        goalie_key VARCHAR(100),
        shooter_key VARCHAR(100),
        period_time_elapsed VARCHAR(100)
    )
        
    IF (@leagueName = 'mlb')
    BEGIN
        INSERT INTO @plays (sequence_number, team_key, inning_value, inning_half, value)
        SELECT sequence_number, team_key, inning_value, inning_half, value
          FROM SportsDB.dbo.SMG_Plays_MLB
         WHERE event_key = @event_key AND play_type NOT IN ('pitcher_entrance', 'pinch_hitter_entrance', 'pinch_runner_entrance') 

        UPDATE p
           SET p.team_logo = @logo_prefix + 'mlb' + @logo_folder + st.team_abbreviation + @logo_suffix
          FROM @plays p
         INNER JOIN dbo.SMG_Teams st
            ON st.season_key = @seasonKey AND st.team_key = p.team_key

		-- assume post event
		UPDATE @plays
		   SET sequence_order = sequence_number, period_order = inning_value * 10

        UPDATE @plays
           SET period_order = period_order + 5
         WHERE inning_half = 'bottom'

		IF (@event_status <> 'post-event')
		BEGIN
			UPDATE @plays
			   SET sequence_order = 1000000 - sequence_order, period_order = 1000 - period_order
		END

        SELECT
	    (
	        SELECT s.inning_half, s.team_logo,
	               CASE
	                   WHEN s.inning_value <> 11 AND (s.inning_value % 10) = 1 THEN CAST(s.inning_value AS VARCHAR) + 'st'
	                   WHEN s.inning_value <> 12 AND (s.inning_value % 10) = 2 THEN CAST(s.inning_value AS VARCHAR) + 'nd'
	                   WHEN s.inning_value <> 13 AND (s.inning_value % 10) = 3 THEN CAST(s.inning_value AS VARCHAR) + 'rd'
	                   ELSE CAST(s.inning_value AS VARCHAR) + 'th'	                  
	               END AS inning_value,
	               (
	                   SELECT s_q.value AS plays
	                     FROM @plays s_q
	                    WHERE s_q.inning_value = s.inning_value AND s_q.inning_half = s.inning_half
	                    ORDER BY s_q.sequence_order ASC
	                      FOR XML PATH(''), TYPE
	               )
              FROM @plays s
             GROUP BY s.inning_value, s.inning_half, s.team_logo, s.period_order
             ORDER BY s.period_order ASC
               FOR XML RAW('innings'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
        
        RETURN
    END

    IF (@leagueName IN ('ncaaf', 'nfl'))
    BEGIN
        INSERT INTO @plays (sequence_number, team_key, period_value, period_time_remaining, value, play_type, no_play)
        SELECT sequence_number, team_key, period_value, period_time_remaining, value, play_type, no_play
          FROM SportsDB.dbo.SMG_Plays_NFL
         WHERE event_key = @event_key

       -- delete challenge_play_reversed
       DELETE p
         FROM @plays p
        INNER JOIN dbo.SMG_Plays_Info i
           ON i.event_key = @event_key AND i.sequence_number = p.sequence_number AND i.play_type IN ('challenge') AND i.[column] = 'play_reversed' AND i.value = 'true'

        -- set end position to dash
        UPDATE @plays
           SET end_position = CHARINDEX(' - ', value) + 3
         WHERE CHARINDEX(' - ', value) > 0 

        UPDATE @plays
           SET value = SUBSTRING(value, end_position, LEN(value)),
               period = CASE
                            WHEN period_value = 1 THEN '1st Quarter'
                            WHEN period_value = 2 THEN '2nd Quarter'
                            WHEN period_value = 3 THEN '3rd Quarter'
                            WHEN period_value = 4 THEN '4th Quarter'
                            WHEN period_value = 5 THEN 'Overtime'
                            WHEN period_value = 6 THEN '2nd Overtime'
                            WHEN period_value = 7 THEN '3rd Overtime'
                            ELSE CAST(period_value - 4 AS VARCHAR) + 'th Overtime'
                        END

		-- Add penalty text for No Play
		UPDATE p
		   SET value = p.value + ' PENALTY: ' + i.value
		  FROM @plays AS p
		 INNER JOIN dbo.SMG_Plays_Info AS i ON i.sequence_number = p.sequence_number
		 WHERE i.event_key = @event_key AND i.[column] = 'penalty_type'

		UPDATE @plays
		   SET value = value + ' - No Play.'
		 WHERE no_play = 'true'

        -- logo
        IF (@leagueName = 'nfl')
        BEGIN
            UPDATE p
               SET p.team_logo = @logo_prefix + 'nfl' + @logo_folder + st.team_abbreviation + @logo_suffix
              FROM @plays p
             INNER JOIN dbo.SMG_Teams st
                ON st.season_key = @seasonKey AND st.team_key = p.team_key
        END
        ELSE
        BEGIN
            UPDATE p
               SET p.team_logo = @logo_prefix + 'ncaa' + @logo_folder + st.team_abbreviation + @logo_suffix
              FROM @plays p
             INNER JOIN dbo.SMG_Teams st
                ON st.season_key = @seasonKey AND st.team_key = p.team_key
        END 

		-- assume post event
		UPDATE @plays
		   SET sequence_order = sequence_number, period_order = period_value

		-- NCAAF Overtime has no clock
		IF (@leagueName = 'ncaaf')
		BEGIN
			UPDATE @plays
			   SET period_time_remaining = '0:00'
			 WHERE period_order > 4
		END

		IF (@event_status <> 'post-event')
		BEGIN
			UPDATE @plays
			   SET sequence_order = 100000 - sequence_order, period_order = 100 - period_order
		END

        SELECT
	    (
	        SELECT s.period AS [quarter],
	               (
	                   SELECT s_q.value AS play, s_q.period_time_remaining AS time_left, s_q.team_logo
	                     FROM @plays s_q
	                    WHERE s_q.period_value = s.period_value
	                    ORDER BY s_q.sequence_order ASC
	                      FOR XML RAW('plays'), TYPE
	               )
              FROM @plays s
             GROUP BY s.period_value, s.period, s.period_order
             ORDER BY s.period_order ASC
               FOR XML RAW('quarters'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
        
        RETURN
    END
    
    IF (@leagueName = 'nhl')
	BEGIN
        INSERT INTO @plays (sequence_number, team_key, shooter_key, goalie_key, period_value, period_time_elapsed, play_score, value)
        SELECT sequence_number, team_key, shooter_key, goalie_key, period_value, period_time_elapsed, play_score, value
          FROM SportsDB.dbo.SMG_Plays_NHL
         WHERE event_key = @event_key

        UPDATE @plays
           SET period = CASE
                            WHEN period_value = 0 THEN 'Shootout'
                            WHEN period_value = 1 THEN '1st Period'
                            WHEN period_value = 2 THEN '2nd Period'
                            WHEN period_value = 3 THEN '3rd Period'
                            WHEN period_value = 4 THEN 'Overtime'
                            WHEN period_value = 5 THEN '2nd Overtime'
                            WHEN period_value = 6 THEN '3rd Overtime'
                            ELSE CAST(period_value - 3 AS VARCHAR) + 'th Overtime'
                        END

        UPDATE p
           SET p.team_logo = @logo_prefix + 'nhl' + @logo_folder + st.team_abbreviation + @logo_suffix
          FROM @plays p
         INNER JOIN dbo.SMG_Teams st
            ON st.season_key = @seasonKey AND st.team_key = p.team_key

		-- assume post event
		UPDATE @plays
		   SET sequence_order = sequence_number, period_order = period_value

		UPDATE @plays
		   SET period_order = 100
		 WHERE period = 'Shootout'

		UPDATE @plays
		   SET value = CASE
						WHEN play_score > 0 THEN 'Goal - ' + value
						ELSE 'Penalty - ' + value END
		 WHERE period <> 'Shootout'

		UPDATE hp
		   SET hp.value = 'Shootout - ' + (CASE
											WHEN hp.play_score > 0 THEN 'Goal'
											WHEN hp.play_score = 0 THEN 'No Goal'
											END) + ' - ' + sp.first_name + ' ' + sp.last_name
		  FROM @plays AS hp
		 INNER JOIN dbo.SMG_Players AS sp ON sp.player_key = hp.shooter_key
		 WHERE period = 'Shootout'

		UPDATE hp
		   SET hp.shooter_key = LEFT(sp.first_name, 1) + '. ' + sp.last_name
		  FROM @plays AS hp
		 INNER JOIN dbo.SMG_Players AS sp ON sp.player_key = hp.shooter_key

		UPDATE hp
		   SET hp.goalie_key = LEFT(sp.first_name, 1) + '. ' + sp.last_name
		  FROM @plays AS hp
		 INNER JOIN dbo.SMG_Players AS sp ON sp.player_key = hp.goalie_key

		IF (@event_status <> 'post-event')
		BEGIN
			UPDATE @plays
			   SET sequence_order = 100000 - sequence_order, period_order = 100 - period_order
		END

		IF (NOT EXISTS(SELECT 1 FROM @plays))
		BEGIN
			SELECT '' AS periods
			   FOR XML PATH(''), ROOT('root')

			RETURN
		END

        ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
		SELECT
	    (
	        SELECT s.period,
	               (
	                   SELECT 'true' AS 'json:Array', p.team_logo, p.value, p.period_time_elapsed AS time_elapsed
	                     FROM @plays p
	                    WHERE p.period_value = s.period_value
	                    ORDER BY p.sequence_order ASC
	                      FOR XML RAW('plays'), TYPE
	               )
              FROM @plays s
             GROUP BY s.period_value, s.period, s.period_order
             ORDER BY s.period_order ASC
               FOR XML RAW('periods'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
        
        RETURN
	END


    SET NOCOUNT OFF;
END

GO
