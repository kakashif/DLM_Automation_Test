USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamLeaders_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetTeamLeaders_XML]
	@leagueName VARCHAR(100),
	@teamSlug VARCHAR(100)
AS
--=============================================
-- Author:	  ikenticus
-- Create date: 09/27/2013
-- Description: get team leaders for single team
-- Update:		09/30/2013 - ikenticus: adding season/subseason when NULL
--				10/16/2013 - John Lin - call SMG_GetTeamLeadersByYear_XML
--				06/17/2014 - John Lin - use league name for SMG_Default_Dates
--				02/20/2015 - ikenticus - migrating SMG_Player_Season_Statistics to SMG_Statistics
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DECLARE @league_key VARCHAR(100)
    DECLARE @season_key INT
    DECLARE @team_key VARCHAR(100)

	SELECT @league_key = league_display_name
	  FROM sportsDB.dbo.USAT_leagues
     WHERE league_name = LOWER(@leagueName)
     
    SELECT @season_key = season_key
	  FROM dbo.SMG_Default_Dates
	 WHERE league_key = @leagueName AND page = 'statistics'	 

    SELECT @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @season_key AND team_slug = @teamSlug	 
	 
    SELECT TOP 1 @season_key = season_key 
	  FROM SportsEditDB.dbo.SMG_Statistics
	 WHERE league_key = @league_key AND sub_season_type = 'season-regular' AND team_key = @team_key
	 ORDER BY season_key DESC 

    EXEC SMG_GetTeamLeadersByYear_XML @leagueName, @teamSlug, @season_key

END


GO
