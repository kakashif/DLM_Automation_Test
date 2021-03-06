USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[LOC_Event_Matchup_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[LOC_Event_Matchup_XML] 
    @leagueName VARCHAR(100),
    @eventId INT
AS
-- =============================================
-- Author:      John Lin
-- Create date: 05/11/2015
-- Description: get event details for USCP
-- Update: 05/19/2015 - John Lin - add team logo for pitcher
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    IF (@leagueName NOT IN ('mlb', /*'mls',*/ 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba'))
    BEGIN
        RETURN
    END


    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @season_key INT
    DECLARE @event_key VARCHAR(100)

    SELECT TOP 1 @season_key = season_key, @event_key = event_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
     
    IF (@leagueName = 'mlb')
    BEGIN
        EXEC dbo.LOC_Event_Matchup_baseball_XML @event_key
    END
    ELSE IF (@leagueName IN ('nba', 'wnba', 'ncaab', 'ncaaw'))
    BEGIN
        EXEC dbo.LOC_Event_Matchup_basketball_XML @leagueName, @event_key
    END
    ELSE IF (@leagueName IN ('nfl', 'ncaaf'))
    BEGIN
        EXEC dbo.LOC_Event_Matchup_football_XML @leagueName, @event_key
    END
    ELSE IF (@leagueName = 'nhl')
    BEGIN
        EXEC dbo.LOC_Event_Matchup_hockey_XML @event_key
    END

    SET NOCOUNT OFF;
END

GO
