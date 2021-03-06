USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventBoxscore_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventBoxscore_XML] 
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT,
    @alignment VARCHAR(100)
AS
-- =============================================
-- Author:		John Lin
-- Create date:	06/27/2014
-- Description:	get event boxscore
-- 				09/19/2014 - ikenticus: adding EPL/Champions
--				04/13/2015 - ikenticus: preparing for STATS soccer by adding the simpler league_keys
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--				04/29/2015 - ikenticus: adjusting event_key to handle multiple sources
--				10/26/2015 - ikenticus: passing league_name to soccer sproc
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
    DECLARE @away_key VARCHAR(100)
    DECLARE @home_key VARCHAR(100)

    
    SELECT TOP 1 @event_key = event_key, @event_status = event_status, @away_key = away_team_key, @home_key = home_team_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

    IF (@event_status NOT IN ('mid-event', 'intermission', 'weather-delay', 'post-event'))
    BEGIN
        SELECT '' AS boxscore
           FOR XML PATH(''), ROOT('root')
        
        RETURN
    END

    DECLARE @team_key VARCHAR(100) = @away_key

    IF (@alignment = 'home')
    BEGIN
        SET @team_key = @home_key
    END


    IF (@leagueName = 'mlb')
    BEGIN
        EXEC dbo.PSA_GetEventBoxscore_baseball_XML @seasonKey, @event_key, @team_key
    END
    ELSE IF (@leagueName IN ('mls', 'epl', 'champions', 'natl', 'wwc', 'chlg'))
    BEGIN
        EXEC dbo.PSA_GetEventBoxscore_soccer_XML @leagueName, @seasonKey, @event_key, @team_key
    END
    ELSE IF (@leagueName IN ('nba', 'ncaab', 'ncaaw', 'wnba'))
    BEGIN
        EXEC dbo.PSA_GetEventBoxscore_basketball_XML @leagueName, @seasonKey, @event_key, @team_key
    END
    ELSE IF (@leagueName IN ('ncaaf', 'nfl'))
    BEGIN
        EXEC dbo.PSA_GetEventBoxscore_football_XML @leagueName, @seasonKey, @event_key, @team_key
    END
    ELSE IF (@leagueName = 'nhl')
    BEGIN
        EXEC dbo.PSA_GetEventBoxscore_hockey_XML @seasonKey, @event_key, @team_key
    END    
            
    SET NOCOUNT OFF;
END

GO
