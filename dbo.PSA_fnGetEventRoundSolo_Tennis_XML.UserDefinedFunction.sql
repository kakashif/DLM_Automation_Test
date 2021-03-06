USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[PSA_fnGetEventRoundSolo_Tennis_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[PSA_fnGetEventRoundSolo_Tennis_XML] (	
	@leagueId VARCHAR(100),
    @seasonKey INT,
    @eventId INT,
	@round VARCHAR(100)
)
RETURNS XML
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 08/11/2014
-- Description: migrate event round solo for tennis from sproc to function
--				08/29/2014 - ikenticus: fixing up XML return for doubles
--				09/10/2014 - ikenticus: making players into list
--				09/18/2014 - ikenticus: fixing Cup bug where match_key is incorrectly overwritten
--				10/01/2014 - ikenticus: updating to SJ-495 110px flags
--				10/27/2014 - ikenticus: SJ-702, using player-key-match-id for singles team_key to handle round robin
--				10/31/2014 - ikenticus: SJ-776, removing country/flag from non-Cup tournaments
--				11/05/2014 - ikenticus: building linescores for Davis/Fed Cup
--				03/30/2015 - ikenticus: fixing bug in STATS event_key logic
--				04/08/2015 - ikenticus: adding additional ordering to matches
--				04/10/2015 - ikenticus: tweaks to Tennis schedule due to STATS data
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--				05/12/2015 - ikenticus: ordering by alphabetical country to maintain linescore and match order
--				06/11/2015 - ikenticus: using new league_key function
--				06/30/2015 - ikenticus: fixing STATS Tennis doubles team grouping
--				07/17/2016 - ikenticus: optimizing by replacing table calls with temp table
--				07/21/2015 - ikenticus: solo sports failover event_id logic similar to team sports
-- 				09/29/2015 - ikenticus - using colon in the event_key because tennis event_id are too small
-- =============================================
BEGIN
	DECLARE @match_xml XML

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueId)
    DECLARE @event_key VARCHAR(100)
    DECLARE @event_status VARCHAR(100)

	SELECT @event_key = event_key, @event_status = event_status, @event_key = event_key
	  FROM dbo.SMG_Solo_Events
	 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%:' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key, @event_key = event_key, @event_status = event_status, @event_key = event_key
		  FROM dbo.SMG_Solo_Events AS e
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = e.league_key AND m.value_to = @leagueId AND m.value_type = 'league'
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		 ORDER BY league_key DESC
	END

	DECLARE @stats TABLE (
		team_key	VARCHAR(100), 
		player_key	VARCHAR(100),
		player_name VARCHAR(100),
		[round]		VARCHAR(100), 
		[column]	VARCHAR(100), 
		[value]		VARCHAR(MAX)
	)

	DECLARE @results TABLE (
		[round]				VARCHAR(100), 
		player_key			VARCHAR(100),
		player_name			VARCHAR(100),
		rank				INT,
		[order]				INT,
		country				VARCHAR(100),
		team_key			VARCHAR(100),
		logo				VARCHAR(100),
		match_key			VARCHAR(100),
		match_status		VARCHAR(100),
		game_status			VARCHAR(100),
		status				VARCHAR(100),
		winner				INT
	)

	-- Build the stats
	IF (@round = 'cup')
	BEGIN
		INSERT INTO @stats ([round], player_key, player_name, team_key, [column], value)
		SELECT [round], player_key, player_name, team_key, [column], value
		  FROM SportsDB.dbo.SMG_Solo_Results
		 WHERE league_key = @league_key AND event_key = @event_key
	END
	ELSE
	BEGIN
		INSERT INTO @stats ([round], player_key, player_name, team_key, [column], value)
		SELECT [round], player_key, player_name, team_key, [column], value
		  FROM SportsDB.dbo.SMG_Solo_Results
		 WHERE league_key = @league_key AND event_key = @event_key AND [round] = @round
	END

	--SELECT * FROM @stats

	-- Build the results
	INSERT INTO @results ([round], player_key, player_name, team_key, rank, country, status, match_key, match_status)
	SELECT p.[round], p.player_key, p.player_name, team_key, [rank], [country], [status], [match-event-key], [match-event-status]
	  FROM (SELECT [round], player_key, player_name, team_key, [column], value FROM @stats) AS s
	 PIVOT (MAX(s.value) FOR s.[column] IN ([rank], [country], [status], [match-event-key], [match-event-status])) AS p
	 ORDER BY [match-event-key]

	--SELECT * FROM @results

	UPDATE @results
	   SET team_key = player_key
	 WHERE team_key = ''


	UPDATE @results
	   SET logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/countries/flags/110/' + country + '.png'
	 WHERE country <> 'map'

	UPDATE @results SET [order] = rank
	UPDATE @results SET [order] = 1000, rank = NULL WHERE rank = 0

	UPDATE @results SET winner = 1 WHERE status = 'win'
	UPDATE @results SET winner = 0 WHERE status = 'loss'

	UPDATE @results SET game_status = UPPER(status) WHERE status NOT IN ('win', 'loss', 'undecided')

	UPDATE r1
	   SET r1.game_status = r2.game_status
	  FROM @results AS r1
	 INNER JOIN @results AS r2 ON r1.match_key = r2.match_key AND r1.game_status IS NULL AND r2.game_status IS NOT NULL


	DECLARE @matches TABLE (
		team_key			VARCHAR(100),
		match_key			VARCHAR(100),
		match_status		VARCHAR(100),
		game_status			VARCHAR(100),
		[order]				INT
	)

	-- Singles first
	INSERT INTO @matches (match_key, match_status, game_status, team_key, [order])
	SELECT match_key, match_status, game_status, team_key,
		   CASE WHEN match_status = 'post-event' THEN 13
				WHEN match_status = 'pre-event' THEN 12
				ELSE 11 END
	  FROM @results
	 WHERE match_key IS NOT NULL AND (player_key = team_key OR CHARINDEX(player_key, team_key) > 0)

	-- the Doubles
	INSERT INTO @matches (match_key, match_status, game_status, team_key, [order])
	SELECT match_key, match_status, game_status, team_key,
		   CASE WHEN match_status = 'post-event' THEN 23
				WHEN match_status = 'pre-event' THEN 22
				ELSE 21 END
	  FROM @results
	 WHERE match_key IS NOT NULL AND player_key <> team_key AND CHARINDEX(player_key, team_key) = 0


	DECLARE @teams TABLE (
		match_key			VARCHAR(100),
		team_key			VARCHAR(100),
		team_country		VARCHAR(100),
		team_logo			VARCHAR(100),
		player_key			VARCHAR(100),
		player_name			VARCHAR(100),
		player_country		VARCHAR(100),
		player_logo			VARCHAR(100),
		rank				INT,
		[order]				INT,
		winner				INT
	)

	INSERT INTO @teams (match_key, team_key, player_key, player_name, rank, [order], player_country, player_logo, winner)
	SELECT match_key, team_key, player_key, player_name, rank, [order], country, logo, winner
	  FROM @results
	 WHERE country IS NOT NULL
	 ORDER BY player_name

	-- For doubles
	UPDATE t
	   SET t.match_key = r.match_key
	  FROM @teams AS t
	 INNER JOIN @results AS r ON r.team_key = t.team_key AND r.match_key IS NOT NULL AND t.match_key IS NULL

	UPDATE t
	   SET t.winner = r.winner
	  FROM @teams AS t
	 INNER JOIN @results AS r ON r.team_key = t.team_key AND r.match_key = t.match_key AND r.match_key IS NOT NULL

	UPDATE @teams
	   SET team_logo = player_logo, team_country = player_country, player_logo = NULL, player_country = NULL
	 WHERE team_key NOT LIKE '%.%'

	UPDATE @teams
	   SET team_logo = NULL, team_country = NULL
	 WHERE team_country = 'map'


	DECLARE @linescores TABLE (
		player_key VARCHAR(100),
		match_key VARCHAR(100),
		team_key VARCHAR(100),
		period VARCHAR(100),
		score VARCHAR(100)
	)

	INSERT INTO @linescores (player_key, team_key, period, score)
	SELECT player_key, team_key, [column], value
	  FROM @stats
	 WHERE [column] IN ('SET 1', 'SET 2', 'SET 3', 'SET 4', 'SET 5')

	UPDATE l
	   SET l.match_key = m.match_key
	  FROM @linescores AS l
	 INNER JOIN @matches AS m ON m.team_key = l.team_key

	UPDATE @matches SET game_status = 'Upcoming' WHERE match_status = 'pre-event'
	UPDATE @matches SET game_status = 'Final' WHERE match_status = 'post-event' AND game_status IS NULL

	UPDATE m
	   SET m.game_status = l.period
	  FROM @matches AS m
	 INNER JOIN @linescores AS l ON l.match_key = m.match_key
	 WHERE m.match_status NOT IN ('pre-event', 'post-event')

	UPDATE @linescores
	   SET period = REPLACE(period, 'SET ', '')

	
	-- If event_status = 'post-event' purge all remaining Upcoming matches
	IF (@event_status = 'post-event')
	BEGIN
		DELETE FROM @matches WHERE game_status = 'Upcoming'
	END


	-- Build the stats
	IF (@round <> 'cup')
	BEGIN
		UPDATE @teams
		   SET player_logo = NULL, player_country = NULL
	END

	-- STATS lists Bye matches as well, purge them to avoid weird results
	DELETE @matches
	 WHERE match_status = 'Bye'


	-- This endpoint should never have been called from pre-event state
	IF (@event_status <> 'pre-event')
	BEGIN

		WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
		SELECT @match_xml = (
			SELECT --game_status, match_key AS event_key, --match_status AS event_status
				(
					SELECT match.game_status AS match_status,
						(
							SELECT winner, team_logo AS logo, team_country AS country, rank, -- team_key,
								(
									SELECT 'true' AS 'json:Array',
										   player_logo AS logo, player_country AS country, -- player_key,
										   LEFT(player_name, 1) + '. ' + RIGHT(player_name, LEN(player_name) - CHARINDEX(' ', player_name)) AS name
									  FROM @teams AS player
									 WHERE player.match_key = match.match_key AND player.team_key = team.team_key
									   FOR XML RAW('player'), TYPE
								),
								(
									SELECT score AS sub_score
									  FROM @linescores AS score
									 WHERE score.match_key = match.match_key AND score.team_key = team.team_key
									 ORDER BY period ASC
									   FOR XML PATH(''), TYPE
								)
							  FROM @teams AS team
							 WHERE team.match_key = match.match_key
							 GROUP BY team.team_key, winner, team_logo, team_country, player_country, rank, [order]
							 ORDER BY [order] ASC, player_country ASC
							   FOR XML RAW('team'), TYPE
						),
						(
							SELECT period AS periods
							  FROM @linescores AS period
							 WHERE period.match_key = match.match_key
							 GROUP BY period
							 ORDER BY period ASC
							   FOR XML PATH(''), TYPE
						)
					   FOR XML RAW('linescore'), TYPE
				)
			  FROM @matches AS match
			 WHERE match.match_key IS NOT NULL
			 GROUP BY [order], match_key, game_status
			 ORDER BY [order]
			   FOR XML RAW('match'), TYPE
		)

	END
	
	RETURN @match_xml
END

GO
