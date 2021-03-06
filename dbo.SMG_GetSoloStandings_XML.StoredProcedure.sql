USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetSoloStandings_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetSoloStandings_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
	@leagueId VARCHAR(100)
AS
--=============================================
-- Author:		ikenticus
-- Create date: 10/10/2013
-- Description: get Standings for Solo Sports
-- Update:		02/19/2014 - ikenticus - setting points as default sort, adding sort/type to columns
--				02/20/2014 - ikenticus - isolating rank (rankings-xxx vs leaders-money)
--				04/09/2014 - ikenticus - removing golf standings where rank is null
--				02/25/2015 - ikenticus: adding stats_switch to cutover to STATS when data ingestion complete
--				03/26/2015 - ikenticus - adding motor
--				04/22/2015 - ikenticus: enabling autorank and changing numeric to formatted-num (SOC-219)
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--				05/01/2015 - ikenticus: replace events-started with events-played for golf
--				06/12/2015 - ikenticus: using function for current source league_key
--				06/23/2015 - ikenticus: refactor Golf standings to display cup points
--				07/14/2015 - ikenticus: display winning correctly from backend to avoid UX formatting
--              07/15/2015 - John Lin - golf points sort by integer
--              08/26/2015 - John Lin - golf winnings sorted as money (when no cup points available)
--				08/31/2015 - ikenticus - removed cents from winnings
--				09/02/2015 - ikenticus: adding bonus points to standing points
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


	-- get league_key
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueId)

	DECLARE @columns TABLE (
		display VARCHAR(100),
		[column] VARCHAR(100),
		sort VARCHAR(100),
		type VARCHAR(100)
	)

	DECLARE @stats TABLE (
		fixture_key	VARCHAR(100),
		player_key	VARCHAR(100),
		player_name VARCHAR(100),
		[column]	VARCHAR(100), 
		value		VARCHAR(100)
	)

	DECLARE @standings TABLE (
		[rank]				INT,
		player_key			VARCHAR(100),
		player_name			VARCHAR(100),
		points				VARCHAR(100),
		points_back			INT,
		events_started		INT,
		wins				INT,

		-- nascar
		points_bonus		INT,
		finishes_top_5		INT,
		finishes_top_10		INT,
		laps_completed		INT,
		laps_leading_total	INT,
		non_finishes		INT,

		-- golf
		fedex							VARCHAR(100),

		--tennis
		country				VARCHAR(100),
		ranking_points		VARCHAR(100),
		rankings_atp		VARCHAR(100),
		rankings_wta		VARCHAR(100),

		winnings			VARCHAR(100)
	)


	IF @leagueName = 'tennis'
	BEGIN

		INSERT INTO @columns (display, [column], sort, type)
		VALUES
			('RANK', 'rank', 'desc,asc', 'numeric'),
			('PLAYER', 'player_name', 'asc,desc', 'string'),
			('COUNTRY', 'country', 'asc,desc', 'string'),
			('POINTS', 'ranking_points', 'desc,asc', 'formatted-num'),
			('WINNINGS', 'winnings', 'desc,asc', 'formatted-num')

		INSERT INTO @stats (player_name, [column], value)
		SELECT player_name, [column], value
		FROM SportsDB.dbo.SMG_Solo_Standings
		WHERE league_key = @league_key AND season_key = @seasonKey AND fixture_key <> 'leaders-money'
			AND [column] IN ('rank')

		INSERT INTO @stats (player_name, [column], value)
		SELECT player_name, [column], value
		FROM SportsDB.dbo.SMG_Solo_Standings
		WHERE league_key = @league_key AND season_key = @seasonKey
			AND [column] IN ('winnings', 'country', 'rankings-atp', 'rankings-wta')
			AND value IS NOT NULL

		INSERT INTO @standings (player_name, rank, winnings, country, rankings_atp, rankings_wta)
		SELECT p.player_name, [rank], [winnings], [country], [rankings-atp], [rankings-wta]
		FROM (SELECT player_key, player_name, [column], value FROM @stats) AS s
		PIVOT (MAX(s.value) FOR s.[column] IN ([rank], [winnings], [country], [rankings-atp], [rankings-wta])) AS p

		IF @leagueId = 'mens-tennis'
		BEGIN
			UPDATE @standings SET ranking_points = rankings_atp
		END

		IF @leagueId = 'womens-tennis'
		BEGIN
			UPDATE @standings SET ranking_points = REPLACE(rankings_wta, '.00', '')
		END

		IF NOT EXISTS(SELECT 1 FROM @standings WHERE country IS NOT NULL)
		BEGIN
			DELETE @columns
			 WHERE [column] = 'country'
		END

		UPDATE @standings
		   SET winnings = '$ ' + REPLACE(CONVERT(VARCHAR, CAST(CAST(winnings AS DECIMAL(10)) AS MONEY), 1), '.00', '')
		 WHERE winnings IS NOT NULL

		SELECT
		(
			SELECT 'ranking_points' AS sort, 1 AS autorank, 
			(
				SELECT player_name, rank, winnings, ranking_points, country
				  FROM @standings
			     WHERE ranking_points IS NOT NULL
			  ORDER BY CAST(ranking_points AS INT) DESC, winnings DESC
				   FOR XML RAW('row'), TYPE
			)
			FOR XML RAW('table'), TYPE
		),
		(
			SELECT display, [column], sort, type
			  FROM @columns
			   FOR XML RAW('column'), TYPE
		)
		FOR XML PATH(''), ROOT('root')

	END
	ELSE IF @leagueName = 'golf'
	BEGIN

		INSERT INTO @columns (display, [column], sort, type)
		VALUES
			('RANK', 'rank', 'desc,asc', 'numeric'),
			('PLAYER', 'player_name', 'asc,desc', 'string'),
			('EVENTS', 'events_started', 'desc,asc', 'formatted-num'),
			('WON', 'wins', 'desc,asc', 'formatted-num'),
			('POINTS', 'points', 'desc,asc', 'formatted-num'),
			('WINNINGS', 'winnings', 'desc,asc', 'formatted-num')

		INSERT INTO @stats (fixture_key, player_name, [column], value)
		SELECT fixture_key, player_name, [column], value
		  FROM SportsDB.dbo.SMG_Solo_Standings
		 WHERE league_key = @league_key AND season_key = @seasonKey
		   AND [column] IN ('rank', 'cup-points', 'fedex-cup-points', 'events-played', 'wins', 'winnings')
		   AND player_name NOT IN ('PGA Tour Avg.', '')

		INSERT INTO @standings (player_name, rank, fedex, points, events_started, wins, winnings)
		SELECT p.player_name, [rank], [fedex-cup-points], [cup-points], [events-played], [wins], [winnings]
		  FROM (SELECT player_name, [column], value FROM @stats WHERE fixture_key <> 'rankings-world') AS s
		 PIVOT (MAX(s.value) FOR s.[column] IN ([rank], [fedex-cup-points], [cup-points], [events-played], [wins], [winnings])) AS p

		UPDATE @standings
		   SET points = CAST(REPLACE(fedex, ',', '') AS INT)
		 WHERE points IS NULL

		DELETE @standings
		 WHERE rank IS NULL

		IF NOT EXISTS (SELECT 1 FROM @standings WHERE events_started IS NOT NULL)
		BEGIN
			DELETE @columns
			 WHERE [column] = 'events_started'
		END

		IF NOT EXISTS (SELECT 1 FROM @standings WHERE wins IS NOT NULL)
		BEGIN
			DELETE @columns
			 WHERE [column] = 'wins'
		END

		IF NOT EXISTS (SELECT 1 FROM @standings WHERE points IS NOT NULL)
		BEGIN
			DELETE @columns
			 WHERE [column] = 'points'
		END

		IF NOT EXISTS (SELECT 1 FROM @standings WHERE winnings IS NOT NULL)
		BEGIN
			DELETE @columns
			 WHERE [column] = 'winnings'
		END

		UPDATE @standings
		   SET winnings = '$ ' + REPLACE(CONVERT(VARCHAR, CAST(CAST(winnings AS DECIMAL(10)) AS MONEY), 1), '.00', '')
		 WHERE winnings IS NOT NULL

		SELECT
		(
			SELECT 'points' AS sort, 1 AS autorank,
			(
				SELECT player_name, rank, points, events_started, wins, winnings
				  FROM @standings
			     ORDER BY CAST(points AS INT) DESC, CAST(winnings AS MONEY) DESC
				   FOR XML RAW('row'), TYPE
			)
			FOR XML RAW('table'), TYPE
		),
		(
			SELECT display, [column], sort, type
			  FROM @columns
			   FOR XML RAW('column'), TYPE
		)
		FOR XML PATH(''), ROOT('root')

	END
	ELSE IF @leagueName IN ('motor', 'motor-sports', 'nascar')
	BEGIN

		INSERT INTO @columns (display, [column], sort, type)
		VALUES
			('RANK', 'rank', 'desc,asc', 'numeric'),
			('DRIVER', 'player_name', 'asc,desc', 'string'),
			('POINTS', 'points', 'desc,asc', 'formatted-num'),
			('PB', 'points_back', 'desc,asc', 'formatted-num'),
			('STARTS', 'events_started', 'desc,asc', 'formatted-num'),
			('WINS', 'wins', 'desc,asc', 'formatted-num'),
			('TOP 5', 'finishes_top_5', 'desc,asc', 'formatted-num'),
			('TOP 10', 'finishes_top_10', 'desc,asc', 'formatted-num'),
			('LAPS COMPLETED', 'laps_completed', 'desc,asc', 'formatted-num'),
			('LAPS LED', 'laps_leading_total', 'desc,asc', 'formatted-num'),
			('DNFS', 'non_finishes', 'desc,asc', 'formatted-num'),
			('WINNINGS', 'winnings', 'desc,asc', 'formatted-num')

		INSERT INTO @stats (player_key, player_name, [column], value)
		SELECT player_key, player_name, [column], value
		FROM SportsDB.dbo.SMG_Solo_Standings
		WHERE league_key = @league_key AND season_key = @seasonKey

		INSERT INTO @standings (player_key, player_name, rank, events_started, wins, winnings,
							points, points_back, points_bonus, laps_completed, laps_leading_total,
							finishes_top_5, finishes_top_10, non_finishes)
		SELECT p.player_key, p.player_name, [rank], [events-started], [wins], [winnings],
							[points], [points-back], [points-bonus], [laps-completed], [laps-leading-total],
							[finishes-top-5], [finishes-top-10], [non-finishes]
		FROM (SELECT player_key, player_name, [column], value FROM @stats) AS s
		PIVOT (MAX(s.value) FOR s.[column] IN ([rank], [events-started], [wins], [winnings],
							[points], [points-back], [points-bonus], [laps-completed], [laps-leading-total],
							[finishes-top-5], [finishes-top-10], [non-finishes])) AS p

		UPDATE @standings
		   SET points = points + points_bonus
		 WHERE points_bonus IS NOT NULL

		UPDATE @standings
		   SET winnings = '$ ' + REPLACE(CONVERT(VARCHAR, CAST(CAST(winnings AS DECIMAL(10)) AS MONEY), 1), '.00', '')
		 WHERE winnings IS NOT NULL

		SELECT
		(
			SELECT 'points' AS sort, 1 AS autorank, 
			(
				SELECT player_name, rank, events_started, wins, winnings,
					   points, points_back, laps_completed, laps_leading_total,
					   finishes_top_5, finishes_top_10, non_finishes
				  FROM @standings
			  ORDER BY CAST(points AS INT) DESC, winnings DESC
				   FOR XML RAW('row'), TYPE
			)
			FOR XML RAW('table'), TYPE
		),
		(
			SELECT display, [column], sort, type
			  FROM @columns
			   FOR XML RAW('column'), TYPE
		)
		FOR XML PATH(''), ROOT('root')

	END

END


GO
