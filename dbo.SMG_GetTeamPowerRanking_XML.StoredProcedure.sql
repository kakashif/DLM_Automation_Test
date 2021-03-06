USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamPowerRanking_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_GetTeamPowerRanking_XML] 
	@leagueName	VARCHAR(100),
	@teamSlug	VARCHAR(100)
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 12/19/2014
-- Description:	get team power ranking, migrated to SportsEdit
-- Update:		06/24/2015 - ikenticus: removing TSN/XTS league_key
-- =============================================
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
	DECLARE @season_key INT
	DECLARE @week INT

    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/'
    DECLARE @logo_folder VARCHAR(100) = '-whitebg/80/'
    DECLARE @logo_suffix VARCHAR(100) = '.png'

	DECLARE @team_rgb VARCHAR(100)
	DECLARE @team_logo VARCHAR(100)
	DECLARE @team_abbr VARCHAR(100)
	DECLARE @team_first VARCHAR(100)
	DECLARE @team_key VARCHAR(100)
	DECLARE @team_last VARCHAR(100)

	DECLARE @ranking INT
	DECLARE @ranking_diff INT
	DECLARE @ranking_hilo VARCHAR(100)
	DECLARE @ranking_previous INT

	SELECT TOP 1 @week = week, @season_key = season_key
	  FROM SportsEditDB.dbo.SMG_PowerRankings
	 WHERE league_key = @leagueName
	 ORDER BY season_key DESC, week DESC

	SELECT @team_key = team_key, @team_first = team_first, @team_last = team_last, @team_abbr = team_abbreviation, @team_rgb = rgb,
		   @team_logo = @logo_prefix + @leagueName + @logo_folder + team_abbreviation + @logo_suffix
	  FROM dbo.SMG_Teams
	 WHERE league_key = @league_key AND season_key = @season_key AND team_slug = @teamSlug

	SELECT TOP 1 @ranking = ranking, @ranking_previous = ranking_previous, @ranking_diff = ranking_diff, @ranking_hilo = ranking_hilo
	  FROM SportsEditDB.dbo.SMG_PowerRankings
	 WHERE league_key = @leagueName AND season_key = @season_key AND week = @week AND team_key = @teamSlug

	SELECT @team_first AS team_first, @team_last AS team_last, @team_abbr AS team_class, @season_key AS season_key, @week AS week,
		   @team_logo AS team_logo, @team_rgb AS team_rgb,
		   @ranking AS ranking, @ranking_previous AS ranking_previous, @ranking_diff AS ranking_diff, @ranking_hilo AS ranking_hilo
	   FOR XML RAW('root'), TYPE

	SET NOCOUNT OFF;
END 

GO
