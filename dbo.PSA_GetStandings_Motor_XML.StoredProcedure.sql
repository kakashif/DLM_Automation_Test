USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetStandings_Motor_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetStandings_Motor_XML]
    @leagueId VARCHAR(100)
AS
-- =============================================
-- Author:		ikenticus
-- Create date:	03/26/2015
-- Description:	get motor standings, cloning motor
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--				06/11/2015 - ikenticus: smarter leagues listing with SMG_fnGetSoloLeagues
-- =============================================
	
BEGIN

    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueId)
	DECLARE @season_key INT

	IF (@leagueId IS NULL OR @leagueId = '')
	BEGIN

		SELECT TOP 1 @season_key = season_key
		  FROM dbo.SMG_Solo_leagues
		 WHERE league_name = 'motor'
		 ORDER BY season_key DESC

		DECLARE @league_keys TABLE
		(
			id VARCHAR(100),
			display VARCHAR(100),
			tab_endpoint VARCHAR(100)
		)

		INSERT INTO @league_keys (id, display)
		SELECT id, display
		  FROM SMG_fnGetSoloLeagues('motor', @season_key)

		UPDATE @league_keys
		   SET tab_endpoint = '/Standings.svc/motor/' + id

		SELECT
		(
			SELECT tab_endpoint, display
			  FROM @league_keys
			   FOR XML RAW('series'), TYPE
		)
		FOR XML PATH(''), ROOT('root')

	END
	ELSE
	BEGIN

		SELECT TOP 1 @season_key = season_key
		  FROM dbo.SMG_Solo_Standings
		 WHERE league_key = @league_key
		 ORDER BY season_key DESC

		DECLARE @standings TABLE
		(
			rank		INT,
			points		INT,
			behind		INT,
			driver		VARCHAR(100),
			change		VARCHAR(100)
		)

		INSERT INTO @standings (driver, rank)
		SELECT player_name, [value]
		  FROM dbo.SMG_Solo_standings
		 WHERE league_key = @league_key AND season_key = @season_key AND [column] = 'rank'

		UPDATE @standings
		   SET s.points = REPLACE(CAST(t.[value] AS VARCHAR), '.00', '')
		  FROM @standings AS s
		 INNER JOIN dbo.SMG_Solo_standings AS t
			ON t.league_key = @league_key AND t.season_key = @season_key AND [column] = 'points'
		   AND t.player_name = s.driver

		UPDATE @standings
		   SET s.behind = CAST(t.[value] AS INT)
		  FROM @standings AS s
		 INNER JOIN dbo.SMG_Solo_standings AS t
			ON t.league_key = @league_key AND t.season_key = @season_key AND [column] = 'points-back'
		   AND t.player_name = s.driver

		UPDATE @standings
		   SET s.change = -CAST(t.[value] AS INT)
		  FROM @standings AS s
		 INNER JOIN dbo.SMG_Solo_standings AS t
			ON t.league_key = @league_key AND t.season_key = @season_key AND [column] = 'rank-change'
		   AND t.player_name = s.driver

		UPDATE @standings
		   SET change = '--'
		 WHERE change IS NULL

		--SELECT * FROM @standings

		DECLARE @columns TABLE (
			display		VARCHAR(100),
			[column]	VARCHAR(100),
			[order]		INT
		)

		INSERT INTO @columns ([order], display, [column])
		VALUES (1, 'POS', 'rank'), (2, 'DRIVER', 'driver'), (3, 'PTS', 'points'), (4, 'BEHIND', 'behind'), (5, 'CHG', 'change')

		SELECT
		(
			SELECT
			(
				SELECT display, [column]
				  FROM @columns
				 ORDER BY [order] ASC
				   FOR XML RAW('columns'), TYPE	
			),
			(
				SELECT rank, driver, points, behind, change
				  FROM @standings
				 ORDER BY rank
				   FOR XML RAW('rows'), TYPE
			)
			FOR XML RAW('standings'), TYPE
		)
		FOR XML PATH(''), ROOT('root')
	
	END

    SET NOCOUNT OFF

END

GO
