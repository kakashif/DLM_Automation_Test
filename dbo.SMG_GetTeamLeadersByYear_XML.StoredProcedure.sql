USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamLeadersByYear_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetTeamLeadersByYear_XML]
	@leagueName VARCHAR(100),
	@teamSlug VARCHAR(100),
	@seasonKey INT
AS
--=============================================
-- Author:	  ikenticus
-- Create date: 09/27/2013
-- Description: get team leaders for single team
-- Update:		09/30/2013 - ikenticus: adding season/subseason when NULL
--         10/18/2013 - John Lin - code review
--         12/21/2013 - ikenticus - adding MLS to return empty
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


    IF (@leagueName = 'mlb')
    BEGIN
        EXEC SMG_GetTeamLeaders_baseball_XML @teamSlug, @seasonKey, 'season-regular'
    END
    ELSE IF (@leagueName IN ('nba', 'ncaab', 'wnba'))
    BEGIN
        EXEC SMG_GetTeamLeaders_basketball_XML @leagueName, @teamSlug, @seasonKey, 'season-regular'
    END
    ELSE IF (@leagueName IN ('nfl', 'ncaaf'))
    BEGIN
        EXEC SMG_GetTeamLeaders_football_XML @leagueName, @teamSlug, @seasonKey, 'season-regular'
    END
    ELSE IF (@leagueName IN ('nhl', 'mls'))
    BEGIN
        EXEC SMG_GetTeamLeaders_hockey_XML @teamSlug, @seasonKey, 'season-regular'
    END

END


GO
