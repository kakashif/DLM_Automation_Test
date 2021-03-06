USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetEventTabs_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetEventTabs_XML] 
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:      John Lin
-- Create date: 08/04/2014
-- Description: get addional event detail by event status
-- Update: 08/15/2014 - thlam - show preview only in pre-event
--         09/15/2014 - thlam - remove redundant pre-event if statement and boxscore tab
--         09/26/2014 - thlam - remove preview when pre-event as only one tab
--         11/19/2014 - John Lin - men -> mens
--         03/13/2015 - John Lin - always return preview tab
--         07/29/2015 - John Lin - SDI migration
--         09/16/2015 - John Lin - SDI without play by play for NCAAF
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

    SELECT TOP 1 @event_key = event_key, @event_status = event_status
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)    

    -- TABS
    DECLARE @tabs TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        display VARCHAR(100),
        link VARCHAR(100)
    )
    DECLARE @link VARCHAR(100) = '/' + CASE WHEN @leagueName IN ('ncaab', 'ncaaf', 'ncaaw') THEN 'ncaa' ELSE @leagueName END + '/' +
                                 CASE
                                     WHEN @leagueName = 'ncaab' THEN 'mens-basketball/'
                                     WHEN @leagueName = 'ncaaf' THEN 'football/'
                                     WHEN @leagueName = 'ncaaw' THEN 'womens-basketball/'
                                     ELSE ''
                                 END + 'event/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR) + '/'

	INSERT INTO @tabs (display, link)
	VALUES ('Preview', @link + 'preview/')

	IF (@event_status <> 'pre-event')
	BEGIN
		IF (@leagueName IN ('mlb', /*'ncaaf',*/'nfl'))
		BEGIN
			INSERT INTO @tabs (display, link)
			VALUES ('Plays', @link + 'plays/')
		END

		INSERT INTO @tabs (display, link)
		VALUES ('Boxscore', @link + 'boxscore/')

		IF (@event_status = 'post-event')
		BEGIN
			IF EXISTS (SELECT 1 FROM dbo.SMG_Scores WHERE event_key = @event_key AND column_type = 'post-event-coverage')
			BEGIN 
				INSERT INTO @tabs (display, link)
				VALUES ('Recap', @link + 'recap/')
			END
		END
	END



    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT
    (
        SELECT 'true' AS 'json:Array',
               display, link
          FROM @tabs
         ORDER BY id ASC
           FOR XML RAW('tabs'), TYPE
    )
    FOR XML PATH(''), ROOT('root')
        
    SET NOCOUNT OFF;
END

GO
