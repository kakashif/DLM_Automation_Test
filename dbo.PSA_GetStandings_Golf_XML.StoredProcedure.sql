USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetStandings_Golf_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetStandings_Golf_XML]
    @leagueId VARCHAR(100),
	@fixtureKey VARCHAR(100)
AS
-- =============================================
-- Author:		ikenticus
-- Create date:	07/08/2014
-- Description:	get golf standings
-- Update:		07/24/2014 - ikenticus: updating standings to columns/rows
--				08/26/2014 - ikenticus: changing nodes from leagues/standings to tour/rankings
--				08/27/2014 - ikenticus: changing leaders node to affiliations
--				09/16/2014 - ikenticus: fixing world rankings
--				09/24/2014 - ikenticus: adding comma to money leaders value
--				10/21/2014 - ikenticus: fixing query error for wins
--				10/31/2014 - ikenticus: limiting the decimal significance for average
--				11/04/2014 - ikenticus: displaying events (win) as events when wins are null
--				01/30/2015 - ikenticus - using [l]pga-tour league display for Golf instead of hard-coding
--				03/25/2015 - ikenticus: adding stats_switch to cutover to STATS when data ingestion complete
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--				06/11/2015 - ikenticus: smarter leagues listing with SMG_fnGetSoloLeagues
--				06/23/2015 - ikenticus: adding cup points from STATS into mix
--				07/20/2015 - ikenticus: STATS does not provide any scoring leaders, so removing
--				08/11/2015 - ikenticus: SDI does not provide any world ranking, so removing
--				08/26/2015 - ikenticus: fixing missing cup points for non-PGATour golf
--				08/31/2015 - ikenticus - removed cents from winnings
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
		 WHERE league_name = 'golf'
		 ORDER BY season_key DESC

		DECLARE @league_keys TABLE
		(
			id VARCHAR(100),
			display VARCHAR(100),
			tab_endpoint VARCHAR(100)
		)

		INSERT INTO @league_keys (id, display)
		SELECT id, display
		  FROM SMG_fnGetSoloLeagues('golf', @season_key)

		UPDATE @league_keys
		   SET tab_endpoint = '/Standings.svc/golf/' + id

		SELECT
		(
			SELECT tab_endpoint, display
			  FROM @league_keys
			   FOR XML RAW('tour'), TYPE
		)
		FOR XML PATH(''), ROOT('root')

	END
	ELSE IF (@fixtureKey IS NULL OR @fixtureKey = '')
	BEGIN

		DECLARE @fixture_keys TABLE
		(
			display VARCHAR(100),
			tab_endpoint VARCHAR(100)
		)

		/*
		-- Removing World Rankings
		IF (@leagueId IN ('pga-tour', 'lpga-tour'))
		BEGIN
			INSERT INTO @fixture_keys (display, tab_endpoint)
			VALUES ('World Rankings', '/Standings.svc/golf/' + @leagueId + '/rankings-world')
		END

		-- Removing Scoring Leaders
		ELSE
		BEGIN
			INSERT INTO @fixture_keys (display, tab_endpoint)
			VALUES ('Scoring Leaders', '/Standings.svc/golf/' + @leagueId + '/leaders-scoring')
		END
		*/

		IF (@leagueId IN ('pga-tour', 'lpga-tour', 'champions-tour'))
		BEGIN
			INSERT INTO @fixture_keys (tab_endpoint)
			SELECT TOP 1 '/Standings.svc/golf/' + @leagueId + '/' + fixture_key
			  FROM dbo.SMG_Solo_Standings
			 WHERE league_key = @league_key AND fixture_key LIKE 'leaders%cup' AND [column] = 'rank'

			IF (@leagueId = 'pga-tour')
			BEGIN
				UPDATE @fixture_keys
				   SET display = 'FedEx Cup Points'
				 WHERE tab_endpoint LIKE '%leaders%cup'
			END
			ELSE IF (@leagueId = 'champions-tour')
			BEGIN
				UPDATE @fixture_keys
				   SET display = 'Charles Schwab Cup Points'
				 WHERE tab_endpoint LIKE '%leaders%cup'
			END
			ELSE IF (@leagueId = 'lpga-tour')
			BEGIN
				UPDATE @fixture_keys
				   SET display = 'CME Globe Cup Points'
				 WHERE tab_endpoint LIKE '%leaders%cup'
			END
		END

		INSERT INTO @fixture_keys (display, tab_endpoint)
		VALUES ('Money Leaders', '/Standings.svc/golf/' + @leagueId + '/leaders-money')

		;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
		SELECT
		(
			SELECT tab_endpoint, display, 'true' AS 'json:Array'
			  FROM @fixture_keys
			   FOR XML RAW('affiliations'), TYPE
		)
		FOR XML PATH(''), ROOT('root')

	END
	ELSE
	BEGIN

		SELECT TOP 1 @season_key = season_key
		  FROM dbo.SMG_Solo_Standings
		 WHERE league_key = @league_key AND fixture_key = @fixtureKey
		 ORDER BY season_key DESC


		DECLARE @leader_value VARCHAR(100)

		DECLARE @stats TABLE (
			fixture_key VARCHAR(100),
			player_name VARCHAR(100),
			[column]	VARCHAR(100), 
			value		VARCHAR(100)
		)

		DECLARE @standings TABLE
		(
			rank		INT,
			wins		INT,
			events		INT,
			events_win	VARCHAR(100),
			avg_points	VARCHAR(100),
			player		VARCHAR(100),
			[value]		VARCHAR(100)
		)

		IF (@fixtureKey = 'leaders-money')
		BEGIN
			SET @leader_value = 'winnings'
		END
		ELSE IF (@fixtureKey = 'leaders-cup')
		BEGIN
			SET @leader_value = 'cup-points'
		END
		ELSE IF (@fixtureKey = 'leaders-fedex-cup')
		BEGIN
			SET @leader_value = 'fedex-cup-points'
		END
		ELSE IF (@fixtureKey = 'rankings-world')
		BEGIN
			SET @leader_value = 'world-rankings'
		END
		ELSE IF (@fixtureKey = 'leaders-scoring')
		BEGIN
			SET @leader_value = 'scoring-average'
		END

		INSERT INTO @stats (fixture_key, player_name, [column], value)
		SELECT fixture_key, player_name, [column], value
		  FROM dbo.SMG_Solo_Standings
		 WHERE league_key = @league_key AND season_key = @season_key
		   AND [column] IN ('rank', 'events-played', 'wins', @leader_value)

		UPDATE @stats
		   SET [column] = 'leader-value'
		 WHERE [column] = @leader_value

		INSERT INTO @standings (player, rank, events, wins, value)
		SELECT p.player_name, [rank], [events-played], [wins], [leader-value]
		  FROM (SELECT player_name, [column], value FROM @stats WHERE fixture_key = @fixtureKey) AS s
		 PIVOT (MAX(s.value) FOR s.[column] IN ([rank], [events-played], [wins], [leader-value])) AS p

		IF NOT EXISTS (SELECT 1 FROM @standings WHERE events IS NOT NULL)
		BEGIN
			UPDATE s
			   SET events = t.value
			  FROM @standings AS s
			 INNER JOIN @stats AS t ON t.player_name = s.player
			 WHERE t.fixture_key = 'leaders-money' AND t.[column] = 'events-played'

			UPDATE s
			   SET wins = t.value
			  FROM @standings AS s
			 INNER JOIN @stats AS t ON t.player_name = s.player
			 WHERE t.fixture_key = 'leaders-money' AND t.[column] = 'wins'
		END

		UPDATE @standings
		   SET events_win = CAST(events AS VARCHAR) + (CASE
														WHEN wins IS NULL THEN ''
														ELSE ' (' + CAST(wins AS VARCHAR) + ')'
														END)

		--SELECT * FROM @standings

		DECLARE @columns TABLE (
			display		VARCHAR(100),
			[column]	VARCHAR(100),
			[order]		INT
		)

		INSERT INTO @columns ([order], display, [column])
		VALUES (1, 'RK', 'rank'), (2, 'PLAYER', 'player')

		IF (@fixtureKey = 'leaders-money')
		BEGIN
			INSERT INTO @columns ([order], display, [column])
			VALUES (3, 'EVENTS (W)', 'events_win'), (4, 'WINNINGS', 'value')

			UPDATE @standings
			   SET value = '$ ' + REPLACE(CONVERT(VARCHAR, CAST(CAST(value AS DECIMAL(10)) AS MONEY), 1), '.00', '')
		END
		ELSE IF (@fixtureKey IN ('leaders-cup', 'leaders-fedex-cup'))
		BEGIN
			INSERT INTO @columns ([order], display, [column])
			VALUES (3, 'EVENTS (W)', 'events_win'), (4, 'POINTS', 'value')
		END
		ELSE IF (@fixtureKey = 'rankings-world')
		BEGIN
			INSERT INTO @columns ([order], display, [column])
			VALUES (3, 'AVG PTS', 'avg_points'), (4, 'POINTS', 'value'), (5, 'EVENTS', 'events')

			UPDATE @standings
			   SET avg_points = CAST(CAST(value AS FLOAT) / CAST(events AS FLOAT) AS DECIMAL(5,2))
		END
		ELSE IF (@fixtureKey = 'leaders-scoring')
		BEGIN
			INSERT INTO @columns ([order], display, [column])
			VALUES (3, 'AVG SCORE', 'value'), (5, 'EVENTS', 'events')
		END

		IF NOT EXISTS (SELECT 1 FROM @standings WHERE events_win IS NOT NULL)
		BEGIN
			DELETE @columns
			 WHERE [column] = 'events_win'
		END

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
				SELECT rank, avg_points, events_win, events, wins, [value],
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
