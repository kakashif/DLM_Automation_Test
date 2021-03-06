USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetStandings_NASCAR_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetStandings_NASCAR_XML]
    @leagueId VARCHAR(100)
AS
-- =============================================
-- Author:		ikenticus
-- Create date:	07/09/2014
-- Description:	get nascar standings
-- Update:		07/24/2014 - ikenticus: updating standings to columns/rows
--				07/31/2014 - ikenticus: adding rank change from table
--				08/26/2014 - ikenticus: changing nodes from leagues to series
--				10/08/2014 - ikenticus: flipping negatives on behind and change columns
--				10/30/2014 - ikenticus: replacing Craftsman with Camping World
--				11/20/2014 - ikenticus: setting change to '--' when null
--				01/14/2015 - ikenticus: removing hardcoded Craftsman/Camping logic
--				02/25/2015 - ikenticus: adding stats_switch to cutover to STATS when data ingestion complete
--				03/25/2015 - ikenticus: fixing stats_switch to cutover to STATS when data ingestion complete
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--				06/10/2015 - ikenticus: smarter leagues listing with SMG_fnGetSoloLeagues
--				09/01/2015 - ikenticus: adding bonus points to standing points
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
		 WHERE league_name = 'nascar'
		 ORDER BY season_key DESC

		DECLARE @league_keys TABLE
		(
			id VARCHAR(100),
			display VARCHAR(100),
			tab_endpoint VARCHAR(100)
		)

		INSERT INTO @league_keys (id, display)
		SELECT id, display
		  FROM SMG_fnGetSoloLeagues('nascar', @season_key)

		UPDATE @league_keys
		   SET tab_endpoint = '/Standings.svc/nascar/' + id

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
			bonus		INT,
			behind		INT,
			driver		VARCHAR(100),
			change		VARCHAR(100)
		)

		INSERT INTO @standings (driver, rank, change, points, behind, bonus)
		SELECT p.player_name, [rank], -1 * CAST([rank-change] AS INT), REPLACE(CAST([points] AS VARCHAR), '.00', ''),
			   [points-back], [points-bonus]
		  FROM (SELECT player_name, [column], value
				  FROM dbo.SMG_Solo_Standings
				 WHERE league_key = @league_key AND season_key = @season_key) AS s
		 PIVOT (MAX(s.value) FOR s.[column] IN ([rank], [rank-change], [points], [points-back], [points-bonus])) AS p

		UPDATE @standings
		   SET points = points + bonus
		 WHERE bonus IS NOT NULL

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

		SELECT @league_key,
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
