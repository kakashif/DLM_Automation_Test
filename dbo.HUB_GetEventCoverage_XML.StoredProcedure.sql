USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetEventCoverage_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetEventCoverage_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT,
    @page VARCHAR(100)
AS
-- =============================================
-- Author:		John Lin
-- Create date: 07/29/2014
-- Description:	get event coverage
-- Update:      07/29/2015 - John Lin - SDI migration
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
    DECLARE @coverage VARCHAR(MAX)
   
    SELECT TOP 1 @event_key = event_key, @event_status = event_status
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR) 

    IF (@page = 'preview')
    BEGIN
		SELECT @coverage = value
		  FROM dbo.SMG_Scores
		 WHERE event_key = @event_key AND column_type = 'pre-event-coverage'
    END
    ELSE IF (@page = 'recap')
    BEGIN
		SELECT @coverage = value
		  FROM dbo.SMG_Scores
		 WHERE event_key = @event_key AND column_type = 'post-event-coverage'
    END
    ELSE
    BEGIN
        IF (@event_status = 'post-event')
        BEGIN
			SELECT @coverage = value
			  FROM dbo.SMG_Scores
			 WHERE event_key = @event_key AND column_type = 'post-event-coverage'
        END
    END



    SELECT
	(
	    SELECT ISNULL(@coverage, '') AS coverage
	       FOR XML PATH(''), TYPE
    )
    FOR XML PATH(''), ROOT('root')
    	    
    SET NOCOUNT OFF;
END

GO
