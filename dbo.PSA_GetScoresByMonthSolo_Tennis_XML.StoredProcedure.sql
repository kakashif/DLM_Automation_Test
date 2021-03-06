USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetScoresByMonthSolo_Tennis_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetScoresByMonthSolo_Tennis_XML]
	@leagueId	VARCHAR(100),
	@year		INT,
	@month		INT
AS
--=============================================
-- Author:		ikenticus
-- Create date:	08/11/2014
-- Description: get scores by month for tennis
-- Update:		09/04/2014 - ikenticus: re-order the events accordingly by current, upcoming and completed rules
--				09/10/2014 - ikenticus: moving events into a sub-node of event_dates and adding event_date_display
--				09/18/2014 - ikenticus: fixing duplicating events due to event_order
--				09/22/2014 - ikenticus: fixing missing events due to null event_key (forcing to pre-event)
--				09/24/2014 - ikenticus: fixing game_status for Round# and *finals
--				10/01/2014 - ikenticus: updating to SJ-495 110px flags
--				10/27/2014 - ikenticus: fixing game_status Finalfinals still occurring mid-event
--				10/30/2014 - ikenticus: logic fix for singles team_key containing player_key
--				11/04/2014 - ikenticus: adding end_date to events grouping to avoid dupes with same start_date but different durations
--				11/10/2014 - ikenticus: setting game_status to event_status if still NULL at the end
--				11/20/2014 - ikenticus: SJ-899, appending ET to all pre-event game_status, removing UTC crap
--				02/10/2015 - ikenticus: SJ-1364, correcting game_status/match_status for RETIRED FINAL game in tennis
--				03/24/2015 - ikenticus: adding stats_switch to cutover to STATS when data ingestion complete
--				04/10/2015 - ikenticus: tweaks to Tennis schedule due to STATS data
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--				05/12/2015 - ikenticus: ordering by alphabetical country to maintain linescore and match order
--				06/11/2015 - ikenticus: using new league_key function
--				06/30/2015 - ikenticus: fixing withdrew finals
--				07/17/2015 - ikenticus: optimizing by replacing table calls with temp table
--				08/05/2015 - ikenticus: adjusting logic to provide correct winner flag
--				08/06/2015 - ikenticus: adjusting max_round logic for non-numerical SDI rounds
--				09/02/2015 - ikenticus: adjusting monthly to display tournaments spanning months on both months
--				09/09/2015 - ikenticus: switching to using SMG_Solo_Leaders
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueId)
	DECLARE @league_source VARCHAR(100)
	DECLARE @type VARCHAR(100) = 'monthly'

	SELECT TOP 1 @league_source = filter
	  FROM dbo.SMG_Default_Dates
	 WHERE page = 'source' AND league_key = @leagueId

	DECLARE @events TABLE
	(
		event_date_display VARCHAR(100),
		status_order INT,
		season_key INT,
		event_id VARCHAR(100),
		event_key VARCHAR(100),
		event_status VARCHAR(100),
		tv_coverage VARCHAR(100),
		end_date_time_EST DATETIME,
		start_date_time_EST DATETIME,
		game_status VARCHAR(100),
		match_status VARCHAR(100),
		ribbon VARCHAR(100),
		sub_ribbon VARCHAR(100),
        detail_endpoint VARCHAR(100),

		[round] VARCHAR(100),
		site_name VARCHAR(100),
		site_loc VARCHAR(100),
		winner VARCHAR(100)
	)

	DECLARE @date VARCHAR(6)
	SET @date = CONVERT(VARCHAR(6), CAST((CAST(@year AS VARCHAR) + '-' + CAST(@month AS VARCHAR) + '-1') AS DATE), 112)

	INSERT INTO @events (season_key, event_key, tv_coverage, event_status, start_date_time_EST, end_date_time_EST, ribbon, site_name, site_loc)
	SELECT season_key, event_key, tv_coverage, event_status, start_date_time, end_date_time, event_name, site_name, site_city + ', ' + site_state
	  FROM dbo.SMG_Solo_Events
	 WHERE league_key = @league_key
	   AND (CONVERT(VARCHAR(6), start_date_time, 112) = @date OR CONVERT(VARCHAR(6), end_date_time, 112) = @date)
	 ORDER BY start_date_time DESC

	UPDATE @events
	   SET event_date_display = DATENAME(WEEKDAY, start_date_time_EST) + ', ' + DATENAME(MONTH, start_date_time_EST) + ' ' + CAST(DAY(start_date_time_EST) AS VARCHAR)
	                  + ' - ' + DATENAME(WEEKDAY, end_date_time_EST) + ', ' + DATENAME(MONTH, end_date_time_EST) + ' ' + CAST(DAY(end_date_time_EST) AS VARCHAR)

    UPDATE @events
       SET event_id = dbo.SMG_fnEventId(event_key)

    UPDATE @events
       SET detail_endpoint = '/Event.svc/detail/tennis/' + @leagueId + '/' + CAST(season_key AS VARCHAR) + '/' + event_id

	UPDATE @events
	   SET sub_ribbon = site_name

	UPDATE @events
	   SET sub_ribbon = site_loc
	 WHERE sub_ribbon = ''

	UPDATE @events
	   SET event_status = 'pre-event'
	 WHERE event_status IS NULL


--	ORDER the events appropriately

	DECLARE @status TABLE (
		event_key VARCHAR(100),
		status_int INT,
		order_int INT
	)

	INSERT INTO @status (event_key, status_int, order_int)
	SELECT event_key, 1, RANK() OVER(ORDER BY start_date_time_EST DESC)
	  FROM @events
	 WHERE event_status = 'mid-event'

	INSERT INTO @status (event_key, status_int, order_int)
	SELECT event_key, 2, RANK() OVER(ORDER BY start_date_time_EST ASC)
	  FROM @events
	 WHERE event_status = 'pre-event'

	INSERT INTO @status (event_key, status_int, order_int)
	SELECT event_key, 3, RANK() OVER(ORDER BY start_date_time_EST DESC)
	  FROM @events
	 WHERE event_status NOT IN ('pre-event, mid-event')

	UPDATE e
	   SET e.status_order = s.status_int * 10 + order_int
	  FROM @events AS e
	 INNER JOIN @status AS s ON s.event_key = e.event_key



	DECLARE @stats TABLE (
		event_status VARCHAR(100),
		event_key	VARCHAR(100),
		team_key	VARCHAR(100),
		player_key	VARCHAR(100),
		player_name VARCHAR(100),
		max_round	VARCHAR(100), 
		[round]		VARCHAR(100), 
		[column]	VARCHAR(100), 
		[value]		VARCHAR(100)
	)

	INSERT INTO @stats (event_key, team_key, player_key, player_name, max_round, [round], [column], value)
	SELECT e.event_key, team_key, player_key, player_name, e.[round], r.[round], [column], value
	  FROM @events AS e
	 INNER JOIN dbo.SMG_Solo_Leaders AS r ON r.league_key = @league_key
	   AND r.season_key = e.season_key AND r.event_key = e.event_key

	DELETE @stats
	 WHERE player_name IS NULL

--	IF PRE-EVENT (using start date instead of time, since multiple day tournament)

	UPDATE @events
	   --SET game_status = CONVERT(VARCHAR, CAST(start_date_time_EST AS TIME), 100) + ' ET'
	   SET game_status = DATENAME(WEEKDAY, start_date_time_EST) + ', ' + DATENAME(MONTH, start_date_time_EST) + ' ' + CAST(DAY(start_date_time_EST) AS VARCHAR)
	 WHERE event_status = 'pre-event'

--	ELSE

	UPDATE e
	   SET [round] = s.[round]
	  FROM @events AS e
	 INNER JOIN @stats AS s ON s.event_key = e.event_key


	-- IF POST-EVENT

	UPDATE @events
	   SET game_status = 'Completed'
	 WHERE event_status = 'post-event'

	-- ELSE (MID-EVENT)

	UPDATE @events
	   SET game_status = 'Round ' + CAST([round] AS VARCHAR)
	 WHERE event_status NOT IN ('pre-event', 'post-event') AND LEN(round) = 1

	UPDATE @events
	   SET game_status = CASE 
							WHEN round = 'final' THEN 'Finals'
							WHEN @league_source = 'sdi' THEN UPPER(LEFT(round, 1)) + RIGHT(REPLACE(round, '-r', ' R'), LEN(round) - 1)
							ELSE UPPER(LEFT(round, 1)) + LOWER(RIGHT(round, LEN(round) - 1)) + 'finals' END
	 WHERE event_status NOT IN ('pre-event', 'post-event') AND LEN(round) > 1


	DECLARE @linescores TABLE (
		player_name VARCHAR(100),
		period VARCHAR(100),
		status VARCHAR(100),
		rank INT,
		[order] INT,
		event_key VARCHAR(100),
		score VARCHAR(100),
		winner INT
	)

	INSERT INTO @linescores (event_key, player_name, period, score, rank)
	SELECT e.event_key, player_name, [column], value, RANK() OVER (PARTITION BY s.event_key ORDER BY s.player_name ASC)
	  FROM @stats AS s
	 INNER JOIN @events AS e ON e.event_key = s.event_key
	 WHERE [column] IN ('SET 1', 'SET 2', 'SET 3', 'SET 4', 'SET 5', 'status')
	 ORDER BY e.event_key, s.[column]

	UPDATE e
	   SET game_status = 'Finals ' + l.period, match_status = l.period
	  FROM @events AS e
	 INNER JOIN @linescores AS l ON l.event_key = e.event_key AND l.rank = 1
	 WHERE (event_status <> 'post-event' OR event_status IS NULL)

	UPDATE e
	   SET event_status = r.value
	  FROM @events AS e
	 INNER JOIN @stats AS r ON r.event_key = e.event_key AND r.[column] = 'match-event-status'
	 WHERE e.round = 'final'

	UPDATE e
	   SET match_status = UPPER(r.value), game_status = 'Completed'
	  FROM @events AS e
	 INNER JOIN @stats AS r ON r.event_key = e.event_key AND r.[column] = 'status' AND r.value <> 'win'
	 WHERE e.event_status = 'post-event'

	UPDATE @events
	   SET match_status = 'FINAL'
	 WHERE match_status = 'LOSS'

	/*
	UPDATE l
	   SET l.rank = s.value
	  FROM @linescores AS l
	 INNER JOIN @stats AS s ON s.player_name = l.player_name AND s.event_key = l.event_key
	 WHERE [column] = 'rank'
	*/

	UPDATE @linescores SET [order] = rank
	UPDATE @linescores SET [order] = 1000, rank = NULL WHERE rank = 0

	UPDATE l 
	   SET status = s.score
	  FROM @linescores AS l
	 INNER JOIN @linescores AS s ON s.player_name = l.player_name AND s.event_key = l.event_key
	 WHERE s.period = 'status'

	UPDATE @linescores SET winner = 1 WHERE status = 'win'
	UPDATE @linescores SET winner = 0 WHERE status = 'loss'
	UPDATE @linescores SET period = REPLACE(period, 'SET ', '')


-- Davis/Fed Cup logic
	DECLARE @cup_linescores TABLE (
		country_display VARCHAR(100),
		country_code VARCHAR(100),
		logo VARCHAR(100),
		event_key VARCHAR(100),
		event_status VARCHAR(100),
		score VARCHAR(100),
		high_score INT,
		winner INT
	)

	UPDATE @events
	   SET game_status = 'In Progress'
	 WHERE (ribbon LIKE 'Davis Cup%' OR ribbon LIKE 'Fed Cup%') AND event_status NOT IN ('pre-event', 'post-event')

	INSERT INTO @cup_linescores (event_key, event_status, country_display, country_code, score, winner)
	SELECT event_key, event_status, player_name, team_key, value, RANK() OVER (PARTITION BY event_key ORDER BY value DESC)
	  FROM @stats
	 WHERE [column] = 'score-total'

	UPDATE @cup_linescores
	   SET winner = NULL
	 WHERE event_status <> 'post-event'

	UPDATE @cup_linescores
	   SET winner = 0
	 WHERE winner > 1

	UPDATE @cup_linescores
	   SET logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/countries/flags/110/' + country_code + '.png'


	-- Do not leave game_status as null
	UPDATE @events
	   SET game_status = UPPER(LEFT(event_status, 1)) + LOWER(RIGHT(event_status, LEN(event_status) - 1)) 
	 WHERE game_status IS NULL


    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
	SELECT @type AS [type],
		(
			SELECT 'true' AS 'json:Array',
				CAST(g.start_date_time_EST AS DATE) AS event_date, g.event_date_display,
				(
					SELECT 'true' AS 'json:Array', 
						e.event_status, e.tv_coverage, e.start_date_time_EST, e.ribbon, e.sub_ribbon, e.game_status, e.event_id, e.event_key, e.detail_endpoint,
						(
							SELECT winner, score, logo, country_display AS country
							  FROM @cup_linescores AS cup
							 WHERE cup.event_key = e.event_key
							 ORDER BY country_display ASC
							   FOR XML RAW('linescore'), TYPE
						),
						(
							SELECT e.match_status,
								(
									SELECT winner,
										(
											SELECT 'true' AS 'json:Array',
													LEFT(player_name, 1) + '. ' + RIGHT(player_name, LEN(player_name) - CHARINDEX(' ', player_name)) AS name
											  FROM @linescores AS player
											 WHERE player.player_name = team.player_name AND player.event_key = e.event_key
											 GROUP BY player_name
											   FOR XML RAW('player'), TYPE
										),
										(
											SELECT score AS sub_score
											  FROM @linescores AS score
											 WHERE score.player_name = team.player_name AND score.event_key = e.event_key AND period <> 'status'
											 ORDER BY period ASC
											   FOR XML PATH(''), TYPE
										)
									  FROM @linescores AS team
									 WHERE team.event_key = e.event_key
									 GROUP BY player_name, winner, rank, [order]
									 ORDER BY [order] ASC
									   FOR XML RAW('team'), TYPE		
								),
								(
									SELECT period AS periods
									  FROM @linescores AS period
									 WHERE period.event_key = e.event_key AND period <> 'status'					
									 GROUP BY period
									 ORDER BY period ASC
									   FOR XML PATH(''), TYPE
								)
							   FOR XML RAW('linescore'), TYPE
						)
					  FROM @events AS e
					 WHERE e.event_date_display = g.event_date_display
					   AND e.status_order = g.status_order
					 --ORDER BY e.status_order ASC
					   FOR XML RAW('events'), TYPE
				)
			  FROM @events g
			 GROUP BY g.status_order, g.start_date_time_EST, g.end_date_time_EST, g.event_date_display
			 ORDER BY g.status_order, g.start_date_time_EST, g.end_date_time_EST ASC
			   FOR XML RAW('event_dates'), TYPE
		)
	  FOR XML PATH(''), ROOT('root')
  
END

GO
