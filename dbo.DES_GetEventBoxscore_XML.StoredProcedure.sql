USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetEventBoxscore_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DES_GetEventBoxscore_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:		John Lin
-- Create date:	02/24/2014
-- Description:	get boxscore for desktop
-- Update:		02/24/2014 - ikenticus: rendering basketball as key-value instead of ordered value-list
--				03/06/2014 - ikenticus: adding footer (under total) for basketball, order by status (default to unknown)
--				03/13/2014 - John Lin - check if div by zero
--				04/08/2014 - John Lin - split into sports
--				06/02/2014 - thlam - adding football boxscores
--				09/25/2014 - ikenticus - adding hockey boxscores
--              06/01/2015 - John Lin - add soccer
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    IF (@leagueName = 'mlb')
    BEGIN
        EXEC dbo.DES_GetEventBoxscore_baseball_XML @leagueName, @seasonKey, @eventId
    END
    ELSE IF (@leagueName IN ('nba', 'ncaab', 'ncaaw', 'wnba'))
    BEGIN
        EXEC dbo.DES_GetEventBoxscore_basketball_XML @leagueName, @seasonKey, @eventId
    END
    ELSE IF (@leagueName IN ('nfl', 'ncaaf'))
    BEGIN
        EXEC dbo.DES_GetEventBoxscore_football_XML @leagueName, @seasonKey, @eventId
    END
    ELSE IF (@leagueName = 'nhl')
    BEGIN
        EXEC dbo.DES_GetEventBoxscore_hockey_XML @leagueName, @seasonKey, @eventId
    END
    ELSE IF (@leagueName IN ('champions', 'epl', 'mls', 'natl', 'wwc'))
    BEGIN
        EXEC dbo.DES_GetEventBoxscore_soccer_XML @leagueName, @seasonKey, @eventId
    END

    SET NOCOUNT OFF;
END

GO
