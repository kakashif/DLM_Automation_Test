USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetScoresByMonthSolo_Golf_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PSA_GetScoresByMonthSolo_Golf_XML]
	@leagueId	VARCHAR(100),
	@year		INT,
	@month		INT
AS
--=============================================
-- Author:		ikenticus
-- Create date:	08/01/2014
-- Description: get scores by month for golf
-- Update:		09/04/2014 - ikenticus: re-order the events accordingly by current, upcoming and completed rules
--				09/10/2014 - ikenticus: moving events into a sub-node of event_dates and adding event_date_display
--				09/30/2014 - ikenticus: exclude rank=0 from top player listings
--				10/01/2014 - ikenticus: updating to SJ-495 110px flags
--				10/14/2014 - ikenticus: For PGA/Euro, get the stats using event_id
--				10/20/2014 - ikenticus: adjusting max_round to avoid catching non-golf events
--				11/20/2014 - ikenticus: SJ-899, appending ET to all pre-event game_status, removing UTC crap
--				12/16/2014 - ikenticus: SJ-1100, adjusting code for Team Stroke Play
--				01/28/2015 - ikenticus: adding event_type to output for improved testing
--				02/12/2015 - ikenticus: adapting same THRU and TOTAL logic as EventRounds
--				03/09/2015 - ikenticus: fixing dupes via @event_dates table
--				03/24/2015 - ikenticus: adding stats_switch to cutover to STATS when data ingestion complete
--				04/16/2015 - ikenticus: fixing missing R# for stroke-empty tournament types
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--				05/07/2015 - ikenticus: fixing WGC match play "leaders" with final results
--				06/11/2015 - ikenticus: using new league_key function
--				06/17/2015 - ikenticus: tweaking STATS logic
--				06/26/2015 - ikenticus: fix score for cut/unfinished players
--				07/02/2015 - ikenticus: fix exclude empty/zero rounds
--				07/16/2015 - ikenticus: fixing odd Top3 when Round1 mid-event (with Round2 tee-times)
--				07/17/2015 - ikenticus: optimizing by replacing table calls with temp table
--              07/18/2015 - John Lin - HACK
--				07/19/2015 - ikenticus: refactored to use SMG_Solo_Leaders and eliminate leftover TSN/XTS logic
--				07/23/2015 - ikenticus: moving stableford total calculation to ingest
--				08/07/2015 - ikenticus: adding SDI golf scoring-system to the mix
--				09/02/2015 - ikenticus: adjusting monthly to display tournaments spanning months on both months
--				10/08/2015 - ikenticus: fixing iOS hard-coding display bug for cups and SDI scoring-system
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueId)
	DECLARE @type VARCHAR(100) = 'monthly'

	DECLARE @events TABLE
	(
		event_date_display VARCHAR(100),
		status_order INT,
		season_key INT,
		event_id VARCHAR(100),
		event_key VARCHAR(100),
		event_type VARCHAR(100),
		event_status VARCHAR(100),
		tv_coverage VARCHAR(100),
		end_date_time_EST DATETIME,
		start_date_time_EST DATETIME,
		game_status VARCHAR(100),
		ribbon VARCHAR(100),
		sub_ribbon VARCHAR(100),
        detail_endpoint VARCHAR(100),

		[round] INT,
		site_name VARCHAR(100),
		winner VARCHAR(100),
		finals VARCHAR(100)
	)

	DECLARE @date VARCHAR(6)
	SET @date = CONVERT(VARCHAR(6), CAST((CAST(@year AS VARCHAR) + '-' + CAST(@month AS VARCHAR) + '-1') AS DATE), 112)

	INSERT INTO @events (season_key, event_key, tv_coverage, event_status, start_date_time_EST, end_date_time_EST, ribbon, site_name)
	SELECT season_key, event_key, tv_coverage, event_status, start_date_time, end_date_time, event_name, site_name
	  FROM dbo.SMG_Solo_Events
	 WHERE league_key = @league_key
	   AND (CONVERT(VARCHAR(6), start_date_time, 112) = @date OR CONVERT(VARCHAR(6), end_date_time, 112) = @date)
	 ORDER BY start_date_time DESC

    UPDATE @events
       SET event_id = dbo.SMG_fnEventId(event_key)

    UPDATE @events
       SET detail_endpoint = '/Event.svc/detail/golf/' + @leagueId + '/' + CAST(season_key AS VARCHAR) + '/' + event_id

	UPDATE @events
	   SET event_date_display = DATENAME(WEEKDAY, start_date_time_EST) + ', ' + DATENAME(MONTH, start_date_time_EST) + ' ' + CAST(DAY(start_date_time_EST) AS VARCHAR)
	                  + ' - ' + DATENAME(WEEKDAY, end_date_time_EST) + ', ' + DATENAME(MONTH, end_date_time_EST) + ' ' + CAST(DAY(end_date_time_EST) AS VARCHAR)


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


	UPDATE @events
	   SET sub_ribbon = site_name

	DECLARE @event_dates TABLE (
		event_date_display VARCHAR(100),
		status_order INT
	)

	INSERT INTO @event_dates (event_date_display, status_order)
	SELECT event_date_display, MIN(status_order)
	  FROM @events
	 GROUP BY event_date_display


	DECLARE @stats TABLE (
		event_key	VARCHAR(100),
		team_key	VARCHAR(100),
		player_key	VARCHAR(100),
		player_name VARCHAR(100),
		[round]		VARCHAR(100), 
		[column]	VARCHAR(100), 
		[value]		VARCHAR(100)
	)

	INSERT INTO @stats (event_key, team_key, player_key, player_name, [round], [column], value)
	SELECT e.event_key, team_key, player_key, player_name, r.[round], [column], value
	  FROM @events AS e
	 INNER JOIN dbo.SMG_Solo_Leaders AS r ON r.league_key = @league_key
	   AND r.season_key = e.season_key AND r.event_key = e.event_key

	UPDATE e
	   SET round = s.round
	  FROM @stats AS s
	 INNER JOIN @events AS e ON e.event_key = s.event_key
	 WHERE s.round <> ''

	UPDATE @events
	   SET game_status = value
	  FROM @stats AS s
	 INNER JOIN @events AS e ON e.event_key = s.event_key AND [column] = 'round-name'

	UPDATE @events
	   SET game_status = 'Round ' + CAST(round AS VARCHAR)
	 WHERE game_status IS NULL

	UPDATE @events
	   --SET game_status = CONVERT(VARCHAR, CAST(start_date_time_EST AS TIME), 100) + ' ET'
	   SET game_status = DATENAME(WEEKDAY, start_date_time_EST) + ', ' + DATENAME(MONTH, start_date_time_EST) + ' ' + CAST(DAY(start_date_time_EST) AS VARCHAR)
	 WHERE event_status = 'pre-event'

	UPDATE @events
	   SET game_status = 'Completed'
	 WHERE event_status = 'post-event'


	UPDATE e
	   SET event_type = r.value
	  FROM @events AS e
	 INNER JOIN @stats AS r ON r.event_key = e.event_key AND r.[column] = 'scoring-system'

	UPDATE @events
	   SET event_type = 'cup'
	 WHERE event_type IN ('ryder-cup', 'presidents-cup')

-- Configure all columns based on event_type/status

	DECLARE @columns TABLE (
		type		VARCHAR(100),
		status		VARCHAR(100),
		display		VARCHAR(100),
		[column]	VARCHAR(100),
		[order]		INT
	)

	INSERT INTO @columns ([order], status, type, display, [column])
	VALUES	(1, 'post-event', 'stroke', 'POS', 'rank'),
			(2, 'post-event', 'stroke', 'PLAYER', 'player'),
			(3, 'post-event', 'stroke', 'TOTAL (PAR)', 'total'),

			(1, 'post-event', 'stableford', 'POS', 'rank'),
			(2, 'post-event', 'stableford', 'PLAYER', 'player'),
			(3, 'post-event', 'stableford', 'TOTAL', 'score_total'),
-- HACK BEGIN
/*
			(1, 'mid-event', 'stroke', 'POS', 'rank'),
			(2, 'mid-event', 'stroke', 'PLAYER', 'player'),
			(3, 'mid-event', 'stroke', 'R', 'score'),
			(4, 'mid-event', 'stroke', 'THRU', 'hole'),
			(5, 'mid-event', 'stroke', 'TOTAL (PAR)', 'total'),

			(1, 'mid-event', 'stableford', 'POS', 'rank'),
			(2, 'mid-event', 'stableford', 'PLAYER', 'player'),
			(3, 'mid-event', 'stableford', 'R', 'score'),
			(4, 'mid-event', 'stableford', 'TOTAL', 'score_total'),
*/
			(1, 'mid-event', 'stroke', 'POS', 'rank'),
			(2, 'mid-event', 'stroke', 'PLAYER', 'player'),
			(5, 'mid-event', 'stroke', 'TOTAL (PAR)', 'total'),

			(1, 'mid-event', 'stableford', 'POS', 'rank'),
			(2, 'mid-event', 'stableford', 'PLAYER', 'player'),
			(4, 'mid-event', 'stableford', 'TOTAL', 'score_total'),
-- HACK END
			(1, 'post-event', 'match', '', 'rank'),
			(2, 'post-event', 'match', '', 'player'),
			(3, 'post-event', 'match', '', 'score'),

			(1, 'mid-event', 'match', '', 'rank'),
			(2, 'mid-event', 'match', '', 'player'),
			(3, 'mid-event', 'match', '', 'score'),

			(1, 'post-event', 'cup', '', 'rank'),
			(2, 'post-event', 'cup', '', 'player'),
			(3, 'post-event', 'cup', '', 'score'),

			(1, 'mid-event', 'cup', '', 'rank'),
			(2, 'mid-event', 'cup', '', 'player'),
			(3, 'mid-event', 'cup', '', 'score')


-- Populate all leaders

	DECLARE @leaders TABLE (
		event_key		VARCHAR(100),
		player			VARCHAR(100),
		player_name		VARCHAR(100),
		team			VARCHAR(100),
		logo			VARCHAR(100),
		hole			VARCHAR(100),
		score			VARCHAR(100),
		score_total		VARCHAR(100),
		total			VARCHAR(100),
		position_event	VARCHAR(100),
		winner			INT,
		priority		INT
	)

	INSERT INTO @leaders (event_key, player_name, hole, score, score_total, total, position_event, priority)
	SELECT p.event_key, p.player_name, [hole], [score], [score-total], [total], [position-event], [rank]
	  FROM (SELECT event_key, player_name, [column], value FROM @stats) AS s
	 PIVOT (MAX(s.value) FOR s.[column] IN ([hole], [score], [score-total], [strokes-total], [total], [position-event], [rank])) AS p

	UPDATE l
	   SET player = player_name, score = score_total
	  FROM @leaders AS l
	 INNER JOIN @events AS e ON e.event_key = l.event_key
	 WHERE event_type = 'cup'

	UPDATE l
	   SET winner = 1
	  FROM @leaders AS l
	 INNER JOIN @events AS e ON e.event_key = l.event_key
	 WHERE event_type = 'cup' AND priority = 1

	UPDATE l
	   SET logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/countries/flags/110/' + team + '.png'
	  FROM @leaders AS l
	 INNER JOIN @events AS e ON e.event_key = l.event_key
	 WHERE event_type = 'cup'

	UPDATE l
	   SET player = LEFT(player_name, 1) + '. ' + RIGHT(player_name, LEN(player_name) - CHARINDEX(' ', player_name))
	  FROM @leaders AS l
	 INNER JOIN @events AS e ON e.event_key = l.event_key
	 WHERE event_type <> 'cup'

	DELETE @leaders
	 WHERE priority IS NULL

	-- If there are no leaders, purge the columns table
	IF ((SELECT COUNT(*) FROM @leaders) = 0)
	BEGIN
		DELETE @columns
	END

-- HACK BEGIN (do NOT remove score/hole from FOR XML because other scoring-systems need it)
	UPDATE l
	   SET score = NULL, hole = NULL, score_total = NULL
	  FROM @leaders AS l
	 INNER JOIN @events AS e ON e.event_key = l.event_key
	 WHERE event_type IN ('stroke', 'stroke-play')
-- HACK END


	;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
	SELECT @type AS [type],
		(
			SELECT 'true' AS 'json:Array',
				g.event_date_display,
				(
					SELECT 'true' AS 'json:Array',
						e.event_type, e.event_status, e.tv_coverage, e.start_date_time_EST, e.ribbon, e.sub_ribbon, e.game_status, e.event_id, e.detail_endpoint,
						(
							SELECT c.[column],
								   (CASE 
										WHEN c.[column] = 'score' AND c.type LIKE 'stroke%' THEN c.display + CAST(e.[round] AS VARCHAR)
										ELSE c.display END
								   ) AS display
							  FROM @columns AS c
							 WHERE (c.status = e.event_status OR (c.status = 'mid-event' AND e.event_status NOT IN ('pre-event', 'post-event'))) AND e.event_type LIKE '%' + c.type + '%'
							 ORDER BY c.[order] ASC
							   FOR XML RAW('columns'), TYPE	
						),
						(
							SELECT l.position_event AS [rank], l.winner, l.team, l.logo, l.total, l.player, l.score, l.hole, l.score_total
							  FROM @leaders AS l
							 WHERE l.event_key = e.event_key
							 ORDER BY l.priority
							   FOR XML RAW('rows'), TYPE
						)
					  FROM @events e
					 WHERE e.event_date_display = g.event_date_display
					 ORDER BY e.status_order ASC
					   FOR XML RAW('events'), TYPE
				)
			  FROM @event_dates g
			 ORDER BY g.status_order ASC
			   FOR XML RAW('event_dates'), TYPE
		)
	  FOR XML PATH(''), ROOT('root')
  
END

GO
