USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[LOC_Event_Plays_football_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[LOC_Event_Plays_football_XML]
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

    IF (@leagueName NOT IN ('ncaaf', 'nfl'))
    BEGIN
        RETURN
    END

    
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @event_key VARCHAR(100)
    DECLARE @last_sequence_number INT

    SELECT TOP 1 @event_key = event_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
                            
    DECLARE @plays TABLE
    (
        sequence_number INT,
        drive_number INT,
        quarter_value INT,
        scoring_type VARCHAR(100) DEFAULT '',
        down INT,
        yards_to_go INT,
        yards_gained INT,
        initial_yard_line INT,
        initial_field_key VARCHAR(100),
        initial_position INT,
        resulting_yard_line INT,
        resulting_field_key VARCHAR(100),
        resulting_position INT,
		resulting_away_score INT,
		resulting_home_score INT,
        play_type VARCHAR(100) DEFAULT '',       
        play_team_key VARCHAR(100),
        ball_carrier_id VARCHAR(100) DEFAULT '',
        time_left VARCHAR(100),
        narrative VARCHAR(MAX),
        play_id INT
    )
    INSERT INTO @plays (sequence_number, drive_number, quarter_value, scoring_type, down, yards_to_go, yards_gained,
                        initial_yard_line, initial_field_key, initial_position, resulting_yard_line, resulting_field_key, resulting_position,
                        resulting_away_score, resulting_home_score, play_type, play_team_key, ball_carrier_id, time_left, narrative, play_id)
    SELECT sequence_number, drive_number, quarter_value, scoring_type, down, yards_to_go, yards_gained,
           initial_yard_line, initial_field_key, initial_position, resulting_yard_line, resulting_field_key, resulting_position,
           resulting_away_score, resulting_home_score, play_type, play_team_key, player_key, time_left, narrative, play_id
      FROM dbo.USCP_football_plays
     WHERE event_key = @event_key

    SELECT @last_sequence_number = MAX(sequence_number)
      FROM @plays

    UPDATE @plays
       SET ball_carrier_id = dbo.SMG_fnEventId(ball_carrier_id)

    DECLARE @drives TABLE
    (
        drive_number INT,
        team_key VARCHAR(100),
        scoring_drive INT DEFAULT 0,
        primary_scoring_type VARCHAR(100) DEFAULT '',
        total_yards INT,
        time_of_possession VARCHAR(100),
        number_of_plays INT,
        starting_yard_line INT,
        starting_field_key VARCHAR(100),
        starting_position INT,
        ending_yard_line INT,
        ending_field_key VARCHAR(100),
        ending_position INT
    )
    INSERT INTO @drives(drive_number, team_key, scoring_drive, primary_scoring_type, total_yards, time_of_possession, number_of_plays,
                starting_yard_line, starting_field_key, starting_position, ending_yard_line, ending_field_key, ending_position)
    SELECT drive_number, team_key, scoring_drive, primary_scoring_type, total_yards, time_of_possession, number_of_plays,
           starting_yard_line, starting_field_key, starting_position, ending_yard_line, ending_field_key, ending_position
      FROM dbo.USCP_football_drives
     WHERE event_key = @event_key


    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT @last_sequence_number AS 'last_sequence_number',
	(
        SELECT d.drive_number, d.team_key, d.scoring_drive, d.primary_scoring_type,
               d.starting_yard_line, d.starting_field_key, d.starting_position,
               d.ending_yard_line, d.ending_field_key, d.ending_position,
               d.total_yards, d.time_of_possession, d.number_of_plays,
	           (
         	       SELECT 'true' AS 'json:Array',
         	              p.sequence_number, p.quarter_value, p.scoring_type, p.down, p.yards_to_go, p.yards_gained,
         	              p.initial_yard_line, p.initial_field_key, p.initial_position,
         	              p.resulting_yard_line, p.resulting_field_key, p.resulting_position,
         	              p.resulting_away_score, p.resulting_home_score,
               	          p.play_type, p.play_team_key, p.ball_carrier_id, p.time_left, p.narrative, p.play_id
	                 FROM @plays p
	                WHERE p.drive_number = d.drive_number
	                ORDER BY p.sequence_number DESC
	                  FOR XML RAW('plays'), TYPE
	           )
          FROM @drives d
         ORDER BY drive_number DESC
           FOR XML RAW('drives'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF;
END

GO
