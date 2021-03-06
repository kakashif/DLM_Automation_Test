USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetStandings_Tennis_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetStandings_Tennis_XML]
    @leagueId VARCHAR(100)
AS
-- =============================================
-- Author:		ikenticus
-- Create date:	07/09/2014
-- Description:	get tennis standings
-- Update:		07/24/2014 - ikenticus: updating standings to columns/rows
--				08/26/2014 - ikenticus: changing nodes from leagues/standings to gender/rankings
--				09/24/2014 - ikenticus: adding commas to points and winnings
--				03/25/2015 - ikenticus: adding stats_switch to cutover to STATS when data ingestion complete
--				04/14/2015 - ikenticus: SJ-1473 fixing stats_switch for league_key
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--				06/11/2015 - ikenticus: smarter leagues listing with SMG_fnGetSoloLeagues
--				06/30/2015 - ikenticus: using player_key in addition to player_name for some mismatched players
-- =============================================
	
BEGIN

    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueId)
	DECLARE @fixture_key VARCHAR(100)
	DECLARE @season_key INT

	IF (@leagueId IS NULL OR @leagueId = '')
	BEGIN

		SELECT TOP 1 @season_key = season_key
		  FROM dbo.SMG_Solo_leagues
		 WHERE league_name = 'tennis'
		 ORDER BY season_key DESC

		DECLARE @league_keys TABLE
		(
			id VARCHAR(100),
			display VARCHAR(100),
			tab_endpoint VARCHAR(100)
		)

		INSERT INTO @league_keys (id, display)
		SELECT id, display
		  FROM SMG_fnGetSoloLeagues('tennis', @season_key)

		UPDATE @league_keys
		   SET tab_endpoint = '/Standings.svc/tennis/' + id

		SELECT
		(
			SELECT tab_endpoint, display
			  FROM @league_keys
			   FOR XML RAW('gender'), TYPE
		)
		FOR XML PATH(''), ROOT('root')

	END
	ELSE
	BEGIN

		SELECT TOP 1 @season_key = season_key
		  FROM dbo.SMG_Solo_Standings
		 WHERE league_key = @league_key
		 ORDER BY season_key DESC

		DECLARE @stats TABLE
		(
			player		VARCHAR(100),
			[column]	VARCHAR(100),
			value		VARCHAR(100)
		)

		DECLARE @standings TABLE
		(
			rank		INT,
			points		VARCHAR(100),
			player		VARCHAR(100),
			player_key	VARCHAR(100),
			winnings	VARCHAR(100)
		)

		IF (@leagueId = 'womens-tennis')
		BEGIN
			SET @fixture_key = 'rankings-wta'
		END
		ELSE
		BEGIN
			SET @fixture_key = 'rankings-atp'
		END

		INSERT INTO @standings (player, rank)
		SELECT player_name, [value]
		  FROM dbo.SMG_Solo_standings
		 WHERE league_key = @league_key AND season_key = @season_key AND [column] = 'rank' AND fixture_key = @fixture_key

		-- Add player_key for a few randomly mismatched players
		UPDATE @standings
		   SET player_key = t.player_key
		  FROM @standings AS s
		 INNER JOIN dbo.SMG_Solo_standings AS t
			ON t.league_key = @league_key AND t.player_name = s.player

		UPDATE @standings
		   SET winnings = '$ ' + REPLACE(CONVERT(VARCHAR, CAST(t.[value] AS MONEY), 1), '.00', '')
		  FROM @standings AS s
		 INNER JOIN dbo.SMG_Solo_standings AS t
			ON t.league_key = @league_key AND t.season_key = @season_key AND [column] = 'winnings'
		   AND t.player_name = s.player

		-- Obtain winnings via player_key in case of mismatched names
		UPDATE @standings
		   SET winnings = '$ ' + REPLACE(CONVERT(VARCHAR, CAST(t.[value] AS MONEY), 1), '.00', '')
		  FROM @standings AS s
		 INNER JOIN dbo.SMG_Solo_standings AS t
			ON t.league_key = @league_key AND t.season_key = @season_key AND [column] = 'winnings'
		   AND t.player_key = s.player_key
		 WHERE s.winnings IS NULL

		UPDATE @standings
		   SET points = REPLACE(CONVERT(VARCHAR, CAST(t.[value] AS MONEY), 1), '.00', '')
		  FROM @standings AS s
		 INNER JOIN dbo.SMG_Solo_standings AS t
			ON t.league_key = @league_key AND t.season_key = @season_key AND [column] = @fixture_key
		   AND t.player_name = s.player

		DECLARE @columns TABLE (
			display		VARCHAR(100),
			[column]	VARCHAR(100),
			[order]		INT
		)

		INSERT INTO @columns ([order], display, [column])
		VALUES (1, 'RK', 'rank'), (2, 'PLAYER', 'player'), (3, 'PTS', 'points'), (4, 'WINNINGS', 'winnings')

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
				SELECT rank, points, winnings,
					   LEFT(player, 1) + '. ' + RIGHT(player, LEN(player) - CHARINDEX(' ', player)) AS player
				  FROM @standings
				 ORDER BY rank
				   FOR XML RAW('rows'), TYPE
			)
			FOR XML RAW('rankings'), TYPE
		)
		FOR XML PATH(''), ROOT('root')
	
	END

    SET NOCOUNT OFF

END

GO
