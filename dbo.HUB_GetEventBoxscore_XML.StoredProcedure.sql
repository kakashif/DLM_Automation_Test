USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetEventBoxscore_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetEventBoxscore_XML] 
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:      John Lin
-- Create date: 07/29/2014
-- Description: get event boxscore
-- Update: 11/21/2014 - John Lin - add basketball
--         07/29/2015 - John Lin - SDI migration
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

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
        SELECT
	    (
            SELECT '' AS boxscore
               FOR XML PATH(''), TYPE
        )
        FOR XML PATH(''), ROOT('root')
        
        RETURN
    END

/*
    IF (@leagueName = 'mlb')
    BEGIN
        EXEC dbo.PSA_GetEventBoxscore_baseball_XML @seasonKey, @event_key, @team_key
    END
    ELSE IF (@leagueName = 'mls')
    BEGIN
        EXEC dbo.PSA_GetEventBoxscore_soccer_XML @seasonKey, @event_key, @team_key
    END
*/    
    IF (@leagueName IN ('nba', 'ncaab', 'ncaaw', 'wnba'))
    BEGIN
        EXEC dbo.HUB_GetEventBoxscore_basketball_XML @leagueName, @seasonKey, @eventId
    END
    ELSE IF (@leagueName IN ('ncaaf', 'nfl'))
    BEGIN
        EXEC dbo.HUB_GetEventBoxscore_football_XML @leagueName, @seasonKey, @eventId
    END
/*    
    ELSE IF (@leagueName = 'nhl')
    BEGIN
        EXEC dbo.PSA_GetEventBoxscore_hockey_XML @seasonKey, @event_key, @team_key
    END
*/          
    SET NOCOUNT OFF;
END

GO
