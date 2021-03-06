USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetPlayerPickerPlayers_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetPlayerPickerPlayers_XML]
    @leagueName	VARCHAR(100),
	@teamSlug   VARCHAR(100),
	@seasonKey	INT	
AS
-- =============================================
-- Author:     	ikenticus
-- Create date: 11/05/2013
-- Description: get playerpicker players for league/team/season
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	

	-- Determine leagueKey from leagueName
	DECLARE @leagueKey VARCHAR(100)
	SELECT @leagueKey = league_display_name
	FROM SportsDB.dbo.USAT_leagues
    WHERE league_name = LOWER(@leagueName)

	-- Determine team_key
	DECLARE @team_key VARCHAR(100)
	SELECT @team_key = team_key
	  FROM SportsDB.dbo.SMG_Teams
	 WHERE league_key = @leagueKey AND season_key = @seasonKey AND team_slug = @teamSlug

	-- Check for valid seasonKey
	DECLARE @seasons TABLE (season_key INT)
	INSERT INTO @seasons
	SELECT season_key FROM SportsDB.dbo.SMG_Teams
	WHERE league_key = @leagueKey AND team_slug = @teamSlug
	GROUP BY season_key ORDER BY season_key DESC

	IF @seasonKey NOT IN (SELECT season_key FROM @seasons)
	BEGIN
		SELECT TOP 1 @seasonKey = season_key FROM @seasons
	END


	SELECT (
		SELECT
			sp.first_name,
			sp.last_name,
			sp.first_name + ', ' + sp.last_name AS full_name,
			sp.last_name + ', ' + sp.first_name AS display_name,
			REPLACE(REPLACE(LOWER(sp.first_name), ' ' ,'-'), '.', '') + '-' + REPLACE(REPLACE(LOWER(sp.last_name), ' ', '-'), '.', '') AS player_slug,
			REPLACE(sr.player_key, @leagueKey + '-p.', '') AS player_id,
			sr.uniform_number
		FROM SportsDB.dbo.SMG_Rosters AS sr
		INNER JOIN SportsDB.dbo.SMG_Players AS sp
			ON sp.player_key = sr.player_key
		WHERE sr.league_key = @leagueKey
			AND sr.team_key = @team_key
			AND sr.season_key = @seasonKey
			AND sp.first_name != 'OPEN'
			AND sp.last_name != 'OPEN'
		ORDER BY sp.last_name ASC, sp.first_name ASC
		FOR XML RAW('team'), TYPE
	)
	FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF
END 

GO
