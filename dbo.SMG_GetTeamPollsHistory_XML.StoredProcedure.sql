USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamPollsHistory_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetTeamPollsHistory_XML]
	@leagueName	VARCHAR(100),
	@fixtureKey VARCHAR(100),
	@seasonKey	INT,
	@teamSlug   VARCHAR(100)
AS
-- =============================================
-- Author:		ikenticus
-- Create date: 06/05/2014
-- Description:	get team polls history
-- Update:		07/01/2015 - ikenticus - adjusting to STATS migration and SMG_Polls* conversion
-- =============================================
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
	DECLARE @team_key VARCHAR(100)
	DECLARE @team_first VARCHAR(100)
	DECLARE @team_last VARCHAR(100)
	DECLARE @team_abbr VARCHAR(100)
    
	SELECT @team_key = team_key, @team_first = team_first, @team_last = team_last, @team_abbr = team_abbreviation
	  FROM dbo.SMG_Teams
	 WHERE league_key = @league_key AND season_key = @seasonKey AND team_slug = @teamSlug

	DECLARE @history TABLE (
		week				INT,
		poll_date			DATE,
		ranking				INT,
		ranking_previous	INT,
		first_place_votes	INT,
		points				INT,
		wins				INT,
		losses				INT,
		ties				INT
	)

	INSERT INTO @history (week, poll_date)
	SELECT week, poll_date
	  FROM SportsEditDB.dbo.SMG_Polls
	 WHERE league_key = @leagueName AND season_key = @seasonKey AND fixture_key = @fixtureKey
	 GROUP BY week, poll_date
	 ORDER BY poll_date

	UPDATE h
       SET h.ranking = p.ranking,
           h.ranking_previous = p.ranking_previous,
           h.first_place_votes = p.first_place_votes,
           h.points = p.points,
           h.wins = p.wins,
           h.losses = p.losses,
		   h.ties = p.ties
	  FROM @history AS h
	 INNER JOIN SportsEditDB.dbo.SMG_Polls AS p ON p.week = h.week
	 WHERE p.league_key = @leagueName AND p.team_key = @team_abbr
	   AND p.season_key = @seasonKey AND p.fixture_key = @fixtureKey 

	SELECT
	(
		SELECT week, poll_date, ranking, ranking_previous, first_place_votes, points, wins, losses, ties
		  FROM @history
		   FOR XML RAW('weeks'), TYPE
	)
	FOR XML RAW('root'), TYPE


	SET NOCOUNT OFF;
END 

GO
