USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventLinescore_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventLinescore_XML] 
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:      John Lin
-- Create date: 06/27/2014
-- Description: get event linescore
-- Update:		09/19/2014 - ikenticus: adding EPL/Champions
--              09/26/2014 - John Lin - suppress data base on event status
--              11/25/2014 - John Lin - ncaa check if team last is null
--				03/05/2015 - ikenticus - SJ-1399: NCAA @ Majors
--				03/09/2015 - ikenticus - SOC-183: adjusting MLS short names to use team_display
--				04/13/2015 - ikenticus: preparing for STATS soccer by adding the simpler league_keys
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--				04/29/2015 - ikenticus: adjusting event_key to handle multiple sources
--              05/15/2015 - ikenticus: adjusting for world cup
--              06/11/2015 - John Lin - team first for world cup
--				06/24/2015 - ikenticus - adding failover event_key logic for source transitions
--				10/07/2015 - ikenticus: fixing UTC conversion
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
    DECLARE @tv_coverage VARCHAR(100)
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
        
    SELECT TOP 1 @event_status = event_status, @tv_coverage = tv_coverage, @start_date_time_EST = start_date_time_EST,
           @game_status = game_status, @away_key = away_team_key, @home_key = home_team_key, @event_key = event_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key,
			   @event_status = event_status, @tv_coverage = tv_coverage, @start_date_time_EST = start_date_time_EST,
			   @game_status = game_status, @away_key = away_team_key, @home_key = home_team_key, @event_key = event_key
		  FROM SportsDB.dbo.SMG_Schedules AS s
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = s.league_key AND m.value_to = @leagueName AND m.value_type = 'league'
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		 ORDER BY league_key DESC
	END

    IF (@event_status = 'pre-event')
    BEGIN
        SELECT '' AS linescore
           FOR XML PATH(''), ROOT('root')
        
        RETURN
    END
    
    
    SET @start_date_time_UTC = DATEADD(HOUR, DATEDIFF(HOUR, GETDATE(), GETUTCDATE()), @start_date_time_EST)

    IF (@leagueName IN ('ncaab', 'ncaaf'))
    BEGIN
        SELECT @away_short = team_first, @away_long = CASE
                                                          WHEN team_last IS NULL THEN team_first
                                                          ELSE team_first + ' ' + team_last
                                                      END
          FROM dbo.SMG_Teams
         WHERE season_key = @seasonKey AND team_key = @away_key

        SELECT @home_short = team_first, @home_long = CASE
                                                          WHEN team_last IS NULL THEN team_first
                                                          ELSE team_first + ' ' + team_last
                                                      END
          FROM dbo.SMG_Teams
         WHERE season_key = @seasonKey AND team_key = @home_key
    END
    ELSE IF (@leagueName = 'mls')
    BEGIN
        SELECT @away_short = team_display, @away_long = team_first + ' ' + team_last
          FROM dbo.SMG_Teams
         WHERE season_key = @seasonKey AND team_key = @away_key

        SELECT @home_short = team_display, @home_long = team_first + ' ' + team_last
          FROM dbo.SMG_Teams
         WHERE season_key = @seasonKey AND team_key = @home_key
	END
    ELSE IF (@leagueName IN ('natl', 'wwc', 'epl', 'champions'))
    BEGIN
        SELECT @away_short = team_first, @away_long = team_first
          FROM dbo.SMG_Teams
         WHERE season_key = @seasonKey AND team_key = @away_key

        SELECT @home_short = team_first, @home_long = team_first
          FROM dbo.SMG_Teams
         WHERE season_key = @seasonKey AND team_key = @home_key
	END
    ELSE
    BEGIN
        SELECT @away_short = team_last, @away_long = team_first + ' ' + team_last
          FROM dbo.SMG_Teams
         WHERE season_key = @seasonKey AND team_key = @away_key

        SELECT @home_short = team_last, @home_long = team_first + ' ' + team_last
          FROM dbo.SMG_Teams
         WHERE season_key = @seasonKey AND team_key = @home_key
    END

	-- HACK: pre-season NCAA at Majors (apparently, pre-season is not passed for daily)
    IF (@away_short IS NULL) 
	BEGIN
		SELECT @away_short = team_first
		  FROM dbo.SMG_Teams
		 WHERE season_key = @seasonKey AND team_key = @away_key

		SELECT @away_short = team_abbreviation,
		       @away_long = team_first, @away_key = team_key
		  FROM dbo.SMG_Teams
		 WHERE team_abbreviation IS NOT NULL AND team_abbreviation <> '' AND
		       (team_abbreviation = @away_short OR team_key LIKE '%' + RIGHT(@away_key, CHARINDEX('.t-', REVERSE(@away_key))))
    END

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
     WHERE event_key = @event_key


    -- suppress
    IF (@event_status NOT IN ('pre-event', 'mid-event', 'intermission', 'weather-delay'))
    BEGIN
        SET @tv_coverage = ''
    END



    SELECT
	(
        SELECT @event_status AS event_status, @game_status AS game_status, @tv_coverage AS tv_coverage,
               @start_date_time_EST AS start_date_time_EST, @start_date_time_UTC AS start_date_time_UTC,
               (
                   SELECT period_value AS periods
                     FROM @linescore
                    ORDER BY period ASC
                      FOR XML PATH(''), TYPE
               ),
               (
                   SELECT @away_short AS short, @away_long AS long,
                          (
                              SELECT away_value AS sub_score
                                FROM @linescore
                               ORDER BY period ASC
                                 FOR XML PATH(''), TYPE
                              
                          )
                      FOR XML RAW('away'), TYPE
               ),
               (
                   SELECT @home_short AS short, @home_long AS long,
                          (
                              SELECT home_value AS sub_score
                                FROM @linescore
                               ORDER BY period ASC
                                 FOR XML PATH(''), TYPE
                              
                          )
                      FOR XML RAW('home'), TYPE
               )
           FOR XML RAW('linescore'), TYPE
	)
    FOR XML PATH(''), ROOT('root')

        
    SET NOCOUNT OFF;
END

GO
