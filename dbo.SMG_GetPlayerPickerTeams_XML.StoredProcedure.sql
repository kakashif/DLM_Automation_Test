USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetPlayerPickerTeams_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetPlayerPickerTeams_XML]
    @leagueName	VARCHAR(100),
	@seasonKey	INT	
AS
-- =============================================
-- Author:     	ikenticus
-- Create date: 11/05/2013
-- Description: get playerpicker teams for league name and season key
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	

	-- Determine leagueKey from leagueName
	DECLARE @leagueKey VARCHAR(100)
	SELECT @leagueKey = league_display_name
	FROM SportsDB.dbo.USAT_leagues
    WHERE league_name = LOWER(@leagueName)

	-- Check for valid seasonKey
	DECLARE @seasons TABLE (season_key INT)
	INSERT INTO @seasons
	SELECT season_key FROM SportsDB.dbo.SMG_Teams
	WHERE league_key = @leagueKey
	GROUP BY season_key ORDER BY season_key DESC

	IF @seasonKey NOT IN (SELECT season_key FROM @seasons)
	BEGIN
		SELECT TOP 1 @seasonKey = season_key FROM @seasons
	END


	SELECT (
		SELECT	
			 team_first AS first_name,
			 team_last AS last_name,
			 team_key,
			 team_first + ' ' + team_last AS team_name,
			 team_slug
		FROM SportsDB.dbo.SMG_Teams
		WHERE league_key = @leagueKey
			AND season_key = @seasonKey
			AND team_last <> 'All-Stars'
		ORDER BY team_first ASC, team_last ASC
		FOR XML RAW('team'), TYPE
	)
	FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF
END 

GO
