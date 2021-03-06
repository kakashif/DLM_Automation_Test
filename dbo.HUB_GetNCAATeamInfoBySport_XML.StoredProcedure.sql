USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNCAATeamInfoBySport_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetNCAATeamInfoBySport_XML]
	@sport		VARCHAR(100),
	@teamSlug   VARCHAR(100)
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 08/06/2014
-- Description:	get team info by sport (currently for Fan Index, maybe more later)
-- Update:		09/11/2014 - ikenticus: udpated to remove the forced 2013 season key
--				07/01/2015 - ikenticus - adjusting to STATS migration and SMG_Polls* conversion
-- =============================================
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


-- Sports
	DECLARE @ncaa_sports TABLE (
	    id VARCHAR(100),
	    display VARCHAR(100),
		league_name VARCHAR(100),
		[order] INT
	)
	INSERT INTO @ncaa_sports ([order], id, display, league_name)
	VALUES
		(1, 'football',			'Football',				'ncaaf'),
		(2, 'basketball-men',	'Men''s Basketball',	'ncaab'),
		(3, 'basketball-women',	'Women''s Basketball',	'ncaaw'),
		(4, 'baseball',			'Baseball',				'cws')

	-- Determine league info from sport
	DECLARE @league_name VARCHAR(100)

	SELECT @league_name = league_name
	  FROM @ncaa_sports
	 WHERE id = @sport

	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@league_name)


	-- Determine the latest coaches poll
	DECLARE @fixture_key VARCHAR(100) = 'smg-usat'
	DECLARE @poll_date DATE
	DECLARE @season_key INT
	DECLARE @week INT
	SELECT TOP 1 @season_key = season_key, @week = week, @poll_date = poll_date
	  FROM SportsEditDB.dbo.SMG_Polls
	 WHERE league_key = @league_name AND fixture_key = @fixture_key
	 ORDER BY poll_date DESC


	-- Determine the current team_key
	DECLARE @team_key VARCHAR(100)
	DECLARE @team_school VARCHAR(100)
	DECLARE @team_name VARCHAR(100)
	DECLARE @conf_name VARCHAR(100)
	DECLARE @div_name VARCHAR(100)
	SELECT TOP 1 @team_key = team_key, @team_school = team_first, @team_name = team_last, @div_name = division_name, @conf_name = conference_display
	  FROM SportsDB.dbo.SMG_Teams AS t
	 INNER JOIN SportsDB.dbo.SMG_Leagues AS l ON l.league_key = @league_key AND l.division_key = t.division_key AND l.conference_key = t.conference_key AND l.season_key = t.season_key
	 WHERE team_slug = @teamSlug
	 ORDER BY t.season_key DESC


	-- Determine team record
	DECLARE @wins INT
	DECLARE @losses INT
	DECLARE @record VARCHAR(100)
	SELECT TOP 1 @wins = wins, @losses = losses
	  FROM SportsEditDB.dbo.SMG_Team_Records
	 WHERE league_key = @league_key AND season_key = @season_key AND team_key = @team_key
	 ORDER BY date_time_EST DESC

	SET @record = CAST(@wins AS VARCHAR) + '-' + CAST (@losses AS VARCHAR)


	-- Determine the current coaches poll rank
	DECLARE @ranking VARCHAR(100)
	SELECT @ranking = ranking
	  FROM SportsEditDB.dbo.SMG_Polls
	 WHERE league_key = @league_name AND fixture_key = @fixture_key AND season_key = @season_key AND week = @week AND team_key = @team_key
	 ORDER BY poll_date DESC

	IF (@ranking IS NULL)
	BEGIN
		SET @ranking = 'NR'
	END


	SELECT
		(
			SELECT @team_school AS school, @team_name AS name, @record AS record, @conf_name AS conference, @div_name AS division, @ranking AS coachespoll
			   FOR XML RAW('team'), TYPE
		)
	   FOR XML RAW('root'), TYPE


	SET NOCOUNT OFF;
END 

GO
