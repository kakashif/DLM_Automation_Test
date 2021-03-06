USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamRoster_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_GetTeamRoster_XML]
	@leagueName VARCHAR(100),
	@teamSlug VARCHAR(100),
	@seasonKey INT = NULL,
	@level VARCHAR(100) = NULL
AS
--=============================================
-- Author:	  ikenticus
-- Create date: 09/24/2013
-- Description: get roster
--              10/22/2013 - ikenticus: updated to leagueName and teamSlug
--              05/21/2015 - ikenticus: switching all league_key logic to leagueName
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


    -- Unsupported league key
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)

    IF NOT EXISTS(SELECT 1 FROM SportsDB.dbo.SMG_Rosters WHERE league_key = @league_key)
    BEGIN
        RETURN
    END


	-- Retrieving team_key from teamSlug
	DECLARE @team_key VARCHAR(100)

    SELECT @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @seasonKey AND team_slug = @teamSlug


    IF (@leagueName = 'mlb')
    BEGIN
        EXEC SMG_GetTeamRoster_MLB_XML @team_key, @seasonKey, @level
    END
    ELSE IF (@leagueName = 'nba')
    BEGIN
        EXEC SMG_GetTeamRoster_NBA_XML @team_key, @seasonKey, @level
    END
    ELSE IF (@leagueName = 'wnba')
    BEGIN
        EXEC SMG_GetTeamRoster_WNBA_XML @team_key, @seasonKey, @level
    END
    ELSE IF (@leagueName = 'ncaab')
    BEGIN
        EXEC SMG_GetTeamRoster_NCAAB_XML @team_key, @seasonKey, @level
    END
    ELSE IF (@leagueName = 'nfl')
    BEGIN
        EXEC SMG_GetTeamRoster_NFL_XML @team_key, @seasonKey, @level
    END
    ELSE IF (@leagueName = 'ncaaf')
    BEGIN
        EXEC SMG_GetTeamRoster_NCAAF_XML @team_key, @seasonKey, @level
    END
    ELSE IF (@leagueName = 'nhl')
    BEGIN
        EXEC SMG_GetTeamRoster_NHL_XML @team_key, @seasonKey, @level
    END
    ELSE IF (@leagueName IN ('mls', 'natl', 'wwc', 'epl', 'champions'))
    BEGIN
        EXEC SMG_GetTeamRoster_MLS_XML @team_key, @seasonKey, @level
    END


END


GO
