USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventShotsOnGoal_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventShotsOnGoal_XML] 
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 09/26/2014
-- Description: get event shots-on-goal and extricate from linescore sproc
-- Update: 10/31/2014 - John Lin - return NULL node if no record
--         07/29/2015 - John Lin - SDI migration
--         10/07/2015 - ikenticus: fixing UTC conversion
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 


    IF (@leagueName NOT IN ('nhl'))
    BEGIN
        RETURN
    END
        
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @event_key VARCHAR(100)
    DECLARE @event_status VARCHAR(100)
    DECLARE @sub_season_type VARCHAR(100)
    DECLARE @start_date_time_EST DATETIME
    DECLARE @start_date_time_UTC DATETIME
    DECLARE @game_status VARCHAR(100)
    -- away
    DECLARE @away_key VARCHAR(100)
    DECLARE @away_short VARCHAR(100)
    DECLARE @away_long VARCHAR(100)
    -- home
    DECLARE @home_key VARCHAR(100)
    DECLARE @home_short VARCHAR(100)
    DECLARE @home_long VARCHAR(100)
        
    SELECT TOP 1 @event_key = event_key, @event_status = event_status, @start_date_time_EST = start_date_time_EST, @sub_season_type = sub_season_type,
           @game_status = game_status, @away_key = away_team_key, @home_key = home_team_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

    IF (@event_status = 'pre-event')
    BEGIN
        SELECT '' AS shots_on_goal
           FOR XML PATH(''), ROOT('root')
        
        RETURN
    END
    
    
    SET @start_date_time_UTC = DATEADD(HOUR, DATEDIFF(HOUR, GETDATE(), GETUTCDATE()), @start_date_time_EST)

	SELECT @away_short = team_last, @away_long = team_first + ' ' + team_last
	  FROM dbo.SMG_Teams
	 WHERE season_key = @seasonKey AND team_key = @away_key

	SELECT @home_short = team_last, @home_long = team_first + ' ' + team_last
	  FROM dbo.SMG_Teams
	 WHERE season_key = @seasonKey AND team_key = @home_key


    DECLARE @shots_on_goal TABLE
    (
        period INT IDENTITY(1,1) PRIMARY KEY,
        period_value VARCHAR(100),
        away_shots INT,
        home_shots INT
    )

    INSERT INTO @shots_on_goal (period_value, away_shots)
    SELECT [column], RTRIM(LTRIM(value))
      FROM dbo.SMG_Scores
     WHERE event_key = @event_key AND team_key = @away_key AND column_type = 'period-shots'

	UPDATE sog
	   SET home_shots = RTRIM(LTRIM(s.value))
	  FROM @shots_on_goal AS sog
	 INNER JOIN dbo.SMG_Scores AS s ON s.event_key = @event_key AND s.column_type = 'period-shots'
			AND sog.period_value = s.[column] AND s.team_key = @home_key

	UPDATE @shots_on_goal
	   SET period_value = 'OT'
	 WHERE period_value = '4'

	UPDATE @shots_on_goal
	   SET period_value = CAST(period - 3 AS VARCHAR) + 'OT'
	 WHERE period > 4 AND period_value <> 'Total' AND @sub_season_type = 'post-season'

	-- Shootout does not count shots-on-goal
	DELETE FROM @shots_on_goal
	 WHERE period_value = '5' AND @sub_season_type <> 'post-season'

    -- return NULL node if no record
    IF NOT EXISTS (SELECT 1 FROM @shots_on_goal)
    BEGIN
        SELECT '' AS shots_on_goal
           FOR XML PATH(''), ROOT('root')
        
        RETURN
    END


    SELECT
	(
		SELECT @event_status AS event_status, @game_status AS game_status,
			   (
				   SELECT period_value AS periods
					 FROM @shots_on_goal
					ORDER BY period ASC
					  FOR XML PATH(''), TYPE
			   ),
               (
                   SELECT @away_short AS short, @away_long AS long,
                          (
                              SELECT away_shots AS sub_score
                                FROM @shots_on_goal
                               ORDER BY period ASC
                                 FOR XML PATH(''), TYPE                       
                          )
                      FOR XML RAW('away'), TYPE
               ),
               (
                   SELECT @home_short AS short, @home_long AS long,
                          (
                              SELECT home_shots AS sub_score
                                FROM @shots_on_goal
                               ORDER BY period ASC
                                 FOR XML PATH(''), TYPE    
                          )
                      FOR XML RAW('home'), TYPE
               )
		   FOR XML PATH('shots_on_goal'), TYPE
	)
    FOR XML PATH(''), ROOT('root')

        
    SET NOCOUNT OFF;
END

GO
