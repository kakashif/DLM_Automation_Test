USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[SMG_fnGetSoloResults_Tennis_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[SMG_fnGetSoloResults_Tennis_XML] (	
    @seasonKey INT,
	@leagueId VARCHAR(100),
	@eventId INT
)
RETURNS XML
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 09/10/2015
-- Description: migrate solo results for tennis from sproc to function
-- =============================================
BEGIN
	DECLARE @results_xml XML

	-- get league_key/event_key
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueId)
    DECLARE @event_key VARCHAR(100)
	DECLARE @event_name VARCHAR(100)

	SELECT @event_key = event_key, @event_name = event_name
	  FROM dbo.SMG_Solo_Events
	 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)


	DECLARE @stats TABLE (
		team_key	VARCHAR(100),
		player_key	VARCHAR(100),
		player_name VARCHAR(100),
		[round]		VARCHAR(100), 
		[column]	VARCHAR(100), 
		[value]		VARCHAR(100)
	)

	INSERT INTO @stats (team_key, player_key, player_name, [round], [column], value)
	SELECT team_key, player_key, player_name, [round], [column], value
	  FROM dbo.SMG_Solo_Results
	 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key = @event_key


	DECLARE @rounds TABLE (
		round_order		INT,
		round_id		VARCHAR(100),
		round_display	VARCHAR(100)
	)

	INSERT INTO @rounds (round_id, round_order)
	SELECT [round], RANK() OVER (ORDER BY COUNT(round) ASC, round DESC)
	  FROM @stats
	 WHERE [column] = 'match-event-status'
	GROUP BY [round]
	ORDER BY COUNT(round) ASC

	UPDATE r
	   SET round_display = value
	  FROM @rounds AS r
	 INNER JOIN @stats AS s ON r.round_id = s.[round] AND s.[column] = 'round-name'

	UPDATE @rounds
	   SET round_display = CASE
							WHEN round_id = 'cup' THEN ' Finals'
							WHEN ISNUMERIC(round_id) = 1 THEN 'round ' + CAST(round_id AS VARCHAR)
							WHEN round_id LIKE '%final%' THEN round_id
							ELSE round_id + 'finals'
							END
	 WHERE round_display IS NULL


	DECLARE @tables TABLE (
		game_type	VARCHAR(100),
		[round]		VARCHAR(100),
		ribbon		VARCHAR(100),
		[order]		INT
	)

	INSERT INTO @tables ([round], game_type)
	SELECT [round], 'singles'
	  FROM @stats
	 WHERE [column] = 'match-event-status' AND player_key <> ''
	 GROUP BY [round]
	
	UPDATE t
	   SET ribbon = @event_name + ': ' + r.round_display, [order] = r.round_order
	  FROM @tables AS t
	 INNER JOIN @rounds AS r on r.round_id = t.[round]
	 WHERE t.game_type = 'singles'

	INSERT INTO @tables ([round], game_type)
	SELECT [round], 'doubles'
	  FROM @stats
	 WHERE [column] = 'match-event-status' AND player_key = ''
	 GROUP BY [round]
	
	UPDATE t
	   SET ribbon = @event_name + ': Doubles ' + r.round_display, [order] = r.round_order
	  FROM @tables AS t
	 INNER JOIN @rounds AS r on r.round_id = t.[round]
	 WHERE t.game_type = 'doubles'

	--SELECT * FROM @tables ORDER BY game_type DESC, [order]


	DECLARE @matchups TABLE (
		game_type		VARCHAR(100),
		[round]			VARCHAR(100),
		outcome			VARCHAR(100),
		player_key		VARCHAR(100),
		team_key		VARCHAR(100),
		match_key		VARCHAR(100),
		event_key		VARCHAR(100),
		event_status	VARCHAR(100),
		team_winner		INT
	)

	INSERT INTO @matchups ([round], team_key, player_key, outcome, event_key, event_status)
	SELECT [round], team_key, player_key, [status], [match-event-key], [match-event-status]
	  FROM (SELECT [round], team_key, player_key, [column], value
			  FROM @stats
			 WHERE [round] <> '') AS s
	 PIVOT (MAX(s.value) FOR s.[column] IN ([status], [match-event-key], [match-event-status])) AS p

	UPDATE @matchups
	   SET match_key = dbo.SMG_fnEventId(event_key)

	UPDATE @matchups SET team_winner = 1 WHERE outcome IN ('win', 'walkover')
	UPDATE @matchups SET game_type = 'singles'
	UPDATE @matchups SET game_type = 'doubles' WHERE player_key = ''
	DELETE FROM @matchups WHERE event_key IS NULL
	--SELECT * FROM @matchups

	DECLARE @matches TABLE (
		game_type		VARCHAR(100),
		[round]			VARCHAR(100),
		event_key		VARCHAR(100),
		event_status	VARCHAR(100),
		game_status		VARCHAR(100),
		priority		INT
	)

	INSERT INTO @matches (game_type, [round], event_key, event_status, game_status)
	SELECT game_type, [round], event_key, event_status, outcome
	  FROM @matchups
	 WHERE outcome <> 'win'
	 GROUP BY game_type, [round], event_key, event_status, outcome

	UPDATE @matches
	   SET game_status = CASE
						 WHEN event_status = 'mid-event' THEN 'In Progress'
						 WHEN event_status = 'pre-event' THEN 'Upcoming'
						 WHEN event_status = 'post-event' AND game_status = 'loss' THEN 'Final'
						 ELSE UPPER(LEFT(game_status, 1)) + RIGHT(game_status, LEN(game_status) - 1)
						 END

	DELETE m1
	  FROM @matches AS m1
	 INNER JOIN @matches AS m2 ON m2.event_key = m1.event_key
	 WHERE m1.game_status = 'Final' AND m2.game_status = 'Walkover'

	UPDATE @matches
	   SET priority = CASE
						 WHEN event_status = 'mid-event' THEN 1
						 WHEN event_status = 'post-event' THEN 2
						 WHEN event_status = 'pre-event' THEN 3
						 END

	DECLARE @scores TABLE (
		[round]			VARCHAR(100),
		player_key		VARCHAR(100),
		team_key		VARCHAR(100),
		event_key		VARCHAR(100),
		score_key		VARCHAR(100),
		score			VARCHAR(100),
		period			INT
	)

	INSERT INTO @scores ([round], team_key, player_key, event_key, score, period)
     SELECT e.[round], e.team_key, e.player_key, e.[value], s.[value], REPLACE(s.[column], 'SET ', '')
	   FROM @stats AS e
      INNER JOIN @stats AS s ON s.[round] = e.[round]
	    AND s.player_key = e.player_key AND s.[column] LIKE 'SET %'
		AND ISNULL(s.team_key, '') = ISNULL(e.team_key, '')
	  WHERE e.[column] = 'match-event-key'

	UPDATE @scores SET score_key = team_key WHERE (team_key <> '' AND team_key IS NOT NULL)
	UPDATE @scores SET score_key = player_key WHERE score_key IS NULL
	--SELECT * FROM @scores ORDER BY [round], team_key, player_key


	DECLARE @periods TABLE (
		event_key		VARCHAR(100),
		period			INT
	)

	INSERT INTO @periods (event_key, period)
     SELECT event_key, period
	  FROM @scores
	 GROUP BY event_key, period
	--SELECT * FROM @periods


	DECLARE @teams TABLE (
		[round]			VARCHAR(100),
		[rank]			VARCHAR(100),
		[country]		VARCHAR(100),
		player_name		VARCHAR(100),
		player_key		VARCHAR(100),
		team_key		VARCHAR(100),
		match_key		VARCHAR(100)
	)

	INSERT INTO @teams ([round], team_key, player_key, player_name, [rank], country)
	SELECT [round], team_key, player_key, player_name, [rank], [country]
	  FROM (SELECT [round], team_key, player_key, player_name, [column], value
			  FROM @stats
			 WHERE player_key <> '') AS s
	 PIVOT (MAX(s.value) FOR s.[column] IN ([rank], [country])) AS p
	--SELECT * FROM @teams ORDER BY player_name

	UPDATE @teams
	   SET match_key = RIGHT(team_key, CHARINDEX('.', REVERSE(team_key)) - 1)
	 WHERE team_key LIKE '%.%'

	IF (@event_name NOT LIKE 'Davis Cup%' AND @event_name NOT LIKE 'Fed Cup%')
	BEGIN
		UPDATE @teams
		   SET country = NULL
	END

	SELECT @results_xml = (
		SELECT
			(
				SELECT ribbon, game_type,
					(
						SELECT event_key, event_status, game_status,
							(
								SELECT team_key, team_winner,
									(
										SELECT player_key, player_name AS player_display, rank, country
										  FROM @teams AS p
										 WHERE p.[round] = t.[round] AND p.team_key = e.team_key AND e.player_key = ''
										   FOR XML RAW('player'), TYPE
									),
									(
										SELECT player_key, player_name AS player_display, rank, country
										  FROM @teams AS p
										 WHERE p.[round] = t.[round] AND p.player_key = e.player_key
										   AND e.match_key = p.match_key AND p.player_key <> ''
										   FOR XML RAW('player'), TYPE
									),
									(
										SELECT score AS sub_score
										  FROM @scores AS s
										 WHERE s.[round] = t.[round] AND s.event_key = m.event_key AND s.score_key IN (e.team_key, e.player_key)
										   FOR XML PATH(''), TYPE
									)
								  FROM @matchups AS e
								 WHERE e.event_key = m.event_key
								   FOR XML RAW('team'), TYPE
							),
							(
								SELECT period AS periods
								  FROM @periods AS p
								 WHERE p.event_key = m.event_key
								   FOR XML PATH(''), TYPE
							)
							  FROM @matches AS m
						 WHERE m.game_type = t.game_type AND m.[round] = t.[round]
						 ORDER BY priority ASC
						   FOR XML RAW('score'), TYPE
					)
				  FROM @tables AS t
				 ORDER BY t.game_type DESC, t.[order]
				   FOR XML RAW('table'), TYPE
			)
		FOR XML RAW('root'), TYPE
	)


	RETURN @results_xml
END

GO
