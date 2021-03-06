USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetEventPlays_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetEventPlays_XML] 
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:      John Lin
-- Create date: 07/29/2014
-- Description: get event plays
-- Update:      08/19/2014 - ikenticus - reverse chronological order when NFL not post-event
--				08/28/2014 - ikenticus - forcing "plays" to always be a JSON list
--				02/20/2015 - ikenticus - migrating SMG_Team_Season_Statistics to SMG_Statistics
--              07/29/2015 - John Lin - SDI migration
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    IF (@leagueName NOT IN ('mlb', 'ncaaf', 'nfl', 'nhl'))
    BEGIN
        RETURN
    END

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @event_key VARCHAR(100)
    DECLARE @event_status VARCHAR(100)

    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/ncaa-whitebg/60/'
    DECLARE @logo_suffix VARCHAR(100) = '.png'

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
        play_type VARCHAR(100),
        -- MLB
        inning_value INT,
        inning_half VARCHAR(100),
        -- NFL, NCAAF
        period_time_remaining VARCHAR(100),
        period VARCHAR(100),
        -- NHL
        period_time_elapsed VARCHAR(100),
        end_position INT DEFAULT 1
    )
        
    IF (@leagueName = 'mlb')
    BEGIN
        INSERT INTO @plays (sequence_number, team_key, inning_value, inning_half, value)
        SELECT sequence_number, team_key, inning_value, inning_half, value
          FROM SportsDB.dbo.SMG_Plays_MLB
         WHERE event_key = @event_key

        UPDATE @plays
           SET team_logo = @logo_prefix + @leagueName + '/' + @leagueName + REPLACE(team_key, @league_key + '-t.', '') + @logo_suffix
           
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
	                    ORDER BY s_q.sequence_order DESC
	                      FOR XML PATH(''), TYPE
	               )
              FROM @plays s
             GROUP BY s.inning_value, s.inning_half, s.team_logo
             ORDER BY s.inning_value DESC, s.inning_half ASC
               FOR XML RAW('innings'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
        
        RETURN
    END

    IF (@leagueName IN ('ncaaf', 'nfl'))
    BEGIN
        INSERT INTO @plays (sequence_number, team_key, period_value, period_time_remaining, play_type, value)
        SELECT sequence_number, team_key, period_value, period_time_remaining, play_type, value
          FROM SportsDB.dbo.SMG_Plays_NFL
         WHERE event_key = @event_key
         
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
                            ELSE 'Overtime'
                        END,
               play_type = CASE
                               WHEN play_type = 'extra-point' THEN 'Extra Point'
                               WHEN play_type = 'field-goal' THEN 'Field Goal'
                               WHEN play_type = 'kickoff' THEN 'Kickoff'
                               WHEN play_type = 'pass-complete' THEN 'Pass Complete'
                               WHEN play_type = 'pass-incomplete' THEN 'Pass Incomplete'
                               WHEN play_type = 'pass-intercepted' THEN 'Interception'
                               WHEN play_type = 'punt' THEN 'Punt'
                               WHEN play_type = 'rush' THEN 'Rush'
                               WHEN play_type = 'sack' THEN 'Sack'
                               WHEN play_type = 'timeout' THEN 'Timeout'
                               WHEN play_type = 'touchdown' THEN 'Touchdown'
                               WHEN play_type = 'two-point-conversion' THEN 'Two Point Conversion Attempt'
                               ELSE play_type
                           END

        UPDATE p
           SET p.team_logo = @logo_prefix + st.team_abbreviation + @logo_suffix
          FROM @plays p
         INNER JOIN dbo.SMG_Teams st
            ON st.season_key = @seasonKey AND p.team_key = st.team_key 

		-- determine sequence order
		IF (@event_status = 'post-event')
		BEGIN
			UPDATE @plays
			   SET sequence_order = sequence_number, period_order = period_value
		END
		ELSE
		BEGIN
			UPDATE @plays
			   SET sequence_order = 1000 - sequence_number, period_order = 100 - period_value
		END

		;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
        SELECT
	    (
	        SELECT 'true' AS 'json:Array',
	               s.period AS [quarter],
	               (
	                   SELECT s_q.play_type + ' - ' + s_q.value AS play, s_q.period_time_remaining AS time_left, s_q.team_logo
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
    
/*    
    ELSE IF (@leagueName = 'nhl')
    BEGIN
        INSERT INTO @matchup (name, [column])
        VALUES ('POINTS PER GAME', 'points-scored-total-per-game'),
               ('FIELD GOAL %', 'field-goals-percentage'),
               ('REBOUNDS PER GAME', 'rebounds-total-per-game'),
               ('ASSISTS PER GAME', 'assists-total-per-game'),
               ('STEALS PER GAME', 'steals-total-per-game'),
               ('TURNOVERS PER GAME', 'turnovers-total-per-game'),
               ('BLOCKS PER GAME', 'blocks-total-per-game')
        SELECT @away_team_class = team_abbreviation
          FROM SportsDB.dbo.SMG_Teams 
         WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @away_team_key

        SELECT @home_team_class = team_abbreviation
          FROM SportsDB.dbo.SMG_Teams 
          WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @home_team_key
        
    END


    UPDATE m
       SET m.away_value = stst.value
      FROM @matchup m
     INNER JOIN dbo.SMG_Statistics stst
	    ON stst.league_key = @league_key AND stst.season_key = @seasonKey AND stst.sub_season_type = @sub_season_type AND
	       stst.team_key = @away_team_key AND stst.[column] = m.[column] AND stst.category = 'feed' AND stst.player_key = 'team'
	
    UPDATE m
       SET m.home_value = stst.value
      FROM @matchup m
     INNER JOIN dbo.SMG_Statistics stst
	    ON stst.league_key = @league_key AND stst.season_key = @seasonKey AND stst.sub_season_type = @sub_season_type AND
	       stst.team_key = @home_team_key AND stst.[column] = m.[column] AND stst.category = 'feed' AND stst.player_key = 'team'

    UPDATE @matchup
       SET away_percentage = ROUND(CAST(away_value AS FLOAT) / (CAST(away_value AS FLOAT) + CAST(home_value AS FLOAT)) * 100, 2)

    UPDATE @matchup
       SET home_percentage = ROUND(CAST(home_value AS FLOAT) / (CAST(away_value AS FLOAT) + CAST(home_value AS FLOAT)) * 100, 2)
*/        
    SET NOCOUNT OFF;
END

GO
