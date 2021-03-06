USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetTeamsByLeague_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HUB_GetTeamsByLeague_XML]
    @leagueName	VARCHAR(100)
AS
-- =============================================
-- Author:		ikenticus
-- Create date:	09/25/2014
-- Description: get teams for league name
-- Update:		10/24/2014 - ikenticus - show latest season season_key is NULL
--				10/28/2914 - ikenticus - defaulting team_display to team_first/team_last when missing
--              10/20/2015 - John Lin - replace USAT_Leagues with SMG_Mappings
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	
	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)	
	DECLARE @season_key INT

	SELECT @season_key = season_key
	  FROM dbo.SMG_Default_Dates
	 WHERE league_key = @leagueName AND page = 'schedules'

	IF (@season_key IS NULL OR @season_key = 0)
	BEGIN
		SELECT TOP 1 @season_key = season_key
		  FROM dbo.SMG_Teams
		 WHERE league_key = @league_key
		 ORDER BY season_key DESC
	END



	SELECT
	(
		  SELECT team_first, team_last, team_abbreviation, team_slug,
				 team_first + ' ' + team_last AS team_name,
				 ISNULL(team_display, CASE WHEN CHARINDEX('ncaa', @league_key) > 0 THEN team_first ELSE team_last END) AS team_display
			FROM dbo.SMG_Teams
		   WHERE league_key = @league_key AND season_key = @season_key
			 AND 'All-Stars' NOT IN (team_first, team_last) AND team_first <> 'Team'
		   ORDER BY team_first ASC, team_last ASC
			 FOR XML RAW('teams'), TYPE
	)
	FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF
END 

GO
