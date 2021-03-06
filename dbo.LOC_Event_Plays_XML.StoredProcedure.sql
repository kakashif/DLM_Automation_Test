USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[LOC_Event_Plays_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[LOC_Event_Plays_XML] 
    @leagueName VARCHAR(100),
    @eventId INT,
    @sequenceNumber INT
AS
-- =============================================
-- Author:      John Lin
-- Create date: 05/11/2015
-- Description: get event plays for USCP
-- Update: 06/23/2015 - John Lin - STATS migration
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    IF (@leagueName NOT IN ('mlb', 'mls', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba'))
    BEGIN
        RETURN
    END

    
    IF (@leagueName IN ('nfl', 'ncaaf'))
    BEGIN
        EXEC dbo.LOC_Event_Plays_football_XML @leagueName, @eventId, @sequenceNumber
        RETURN
    END


    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @season_key INT
    DECLARE @event_key VARCHAR(100)
    DECLARE @event_status VARCHAR(100)

    SELECT TOP 1 @season_key = season_key, @event_key = event_key, @event_status = event_status
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
     
    DECLARE @plays TABLE
    (
        team_key VARCHAR(100),
        inning_value INT,                   -- MLB
        inning_half VARCHAR(100),           -- MLB
        period_value INT,                   -- NFL
        period_time_remaining VARCHAR(100), -- NFL
        play_type VARCHAR(100),             -- NFL
        sequence_number INT,
        play VARCHAR(MAX)
    )
        
    IF (@leagueName = 'mlb')
    BEGIN
        INSERT INTO @plays (team_key, inning_value, inning_half, sequence_number, play)
        SELECT team_key, inning_value, inning_half, sequence_number, value
          FROM SportsDB.dbo.SMG_Plays_MLB
         WHERE event_key = @event_key AND sequence_number > @sequenceNumber

         
        ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
        SELECT
	    (
	        SELECT 'true' AS 'json:Array', 
	               i.team_key, i.inning_value, i.inning_half, 
	               (
	                   SELECT 'true' AS 'json:Array', 
	                          p.sequence_number, p.play
	                     FROM @plays p
	                    WHERE p.team_key = i.team_key AND p.inning_value = i.inning_value AND i.inning_half = i.inning_half
	                    ORDER BY p.sequence_number ASC
	                      FOR XML RAW('plays'), TYPE
	               )
              FROM @plays i
             GROUP BY i.team_key, i.inning_value, i.inning_half
             ORDER BY i.inning_value DESC, i.inning_half ASC
               FOR XML RAW('innings'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
        
        RETURN
    END

    IF (@leagueName IN ('ncaaf', 'nfl'))
    BEGIN
        INSERT INTO @plays (sequence_number, team_key, period_value, period_time_remaining, play_type, play)
        SELECT sequence_number, team_key, period_value, period_time_remaining, play_type, value
          FROM SportsDB.dbo.SMG_Plays_NFL
         WHERE event_key = @event_key

		-- NCAAF Overtime has no clock
		IF (@leagueName = 'ncaaf')
		BEGIN
			UPDATE @plays
			   SET period_time_remaining = '0:00'
			 WHERE period_value > 4
		END

        SELECT
	    (
	        SELECT s.period_value AS quarter_value,
	               (
	                   SELECT s_q.play AS narrative, s_q.period_time_remaining AS time_left
	                     FROM @plays s_q
	                    WHERE s_q.period_value = s.period_value
	                    ORDER BY s_q.sequence_number ASC
	                      FOR XML RAW('plays'), TYPE
	               )
              FROM @plays s
             GROUP BY s.period_value
               FOR XML RAW('quarters'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
        
        RETURN
    END
/*    
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


		-- assume post event
		UPDATE @plays
		   SET sequence_order = sequence_number, period_order = period_value

		UPDATE @plays
		   SET period_order = 100
		 WHERE period = 'Shootout'

		UPDATE @plays
		   SET value = CASE
						WHEN play_score = 1 THEN 'Goal - ' + value
						ELSE 'Penalty - ' + value END
		 WHERE period <> 'Shootout'

		UPDATE hp
		   SET hp.value = 'Shootout - ' + (CASE
											WHEN hp.play_score = 1 THEN 'Goal'
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
*/
    SET NOCOUNT OFF;
END

GO
