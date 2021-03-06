USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetEventExtra_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetEventExtra_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:		John Lin
-- Create date: 02/19/2014
-- Description:	get additional event data
-- Update: 09/05/2014 - John Lin - add comma to attendance
--         07/29/2015 - John Lin - SDI migration
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    IF (@leagueName NOT IN ('mlb', 'mls', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba'))
    BEGIN
        RETURN
    END
           
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @event_key VARCHAR(100)
    DECLARE @event_status VARCHAR(100)
    DECLARE @site_name VARCHAR(100)
    DECLARE @odds VARCHAR(100)
    DECLARE @attendance VARCHAR(100)
    DECLARE @ribbon VARCHAR(100)
   
    SELECT TOP 1 @event_key = event_key, @event_status = event_status, @site_name = site_name, @odds = odds
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR) 

    IF (@event_status = 'pre-event')
    BEGIN
        SELECT '' AS extra
           FOR XML PATH(''), ROOT('root')

        RETURN
    END


    SELECT @attendance = PARSENAME(CONVERT(VARCHAR, CONVERT(MONEY, value), 1), 2)
      FROM dbo.SMG_Scores
     WHERE event_key = @event_key AND column_type = 'attendance'

    SELECT @ribbon = score
      FROM dbo.SMG_Event_Tags
     WHERE event_key = @event_key



    SELECT
	(
        SELECT @site_name AS site_name, @odds AS odds, @attendance AS attendance, @ribbon AS ribbon        
           FOR XML RAW('extra'), TYPE
    )
    FOR XML PATH(''), ROOT('root')
    	    
    SET NOCOUNT OFF;
END

GO
