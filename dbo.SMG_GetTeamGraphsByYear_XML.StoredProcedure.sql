USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamGraphsByYear_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetTeamGraphsByYear_XML]
	@leagueName VARCHAR(100),
	@teamSlug VARCHAR(100),
	@seasonKey INT
AS
--=============================================
-- Author:	  ikenticus
-- Create date: 09/29/2013
-- Description: get team statistics graph data for single team
-- Update:		09/30/2013 - ikenticus: adding season/subseason when NULL
--         10/18/2013 - John Lin - code review
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


    IF (@leagueName = 'mlb')
    BEGIN
        EXEC SMG_GetTeamGraphs_baseball_XML @teamSlug, @seasonKey, 'season-regular'
    END
    ELSE IF (@leagueName IN ('nba', 'ncaab', 'wnba'))
    BEGIN
        EXEC SMG_GetTeamGraphs_basketball_XML @leagueName, @teamSlug, @seasonKey, 'season-regular'
    END
    ELSE IF (@leagueName IN ('nfl', 'ncaaf'))
    BEGIN
        EXEC SMG_GetTeamGraphs_football_XML @leagueName, @teamSlug, @seasonKey, 'season-regular'
    END
    ELSE IF (@leagueName = 'nhl')
    BEGIN
        EXEC SMG_GetTeamGraphs_hockey_XML @teamSlug, @seasonKey, 'season-regular'
    END

END


GO
