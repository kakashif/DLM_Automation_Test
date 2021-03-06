USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetScoresByMonthSolo_Motor_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetScoresByMonthSolo_Motor_XML]
	@leagueId	VARCHAR(100),
	@year		INT,
	@month		INT
AS
--=============================================
-- Author:		ikenticus
-- Create date:	03/26/2015
-- Description: get scores by month for motor, cloning motor
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--				06/11/2015 - ikenticus: using new league_key function
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
		event_status VARCHAR(100),
		tv_coverage VARCHAR(100),
		start_date_time_EST DATETIME,
		game_status VARCHAR(100),
		ribbon VARCHAR(100),
		sub_ribbon VARCHAR(100),
        detail_endpoint VARCHAR(100),

		site_name VARCHAR(100),
		done INT,
		total INT
	)

	DECLARE @date VARCHAR(6)
	SET @date = CONVERT(VARCHAR(6), CAST((CAST(@year AS VARCHAR) + '-' + CAST(@month AS VARCHAR) + '-1') AS DATE), 112)

	INSERT INTO @events (season_key, event_key, tv_coverage, event_status, start_date_time_EST, ribbon, site_name, total)
	SELECT season_key, event_key, tv_coverage, event_status, start_date_time, event_name, site_name, site_count
	  FROM dbo.SMG_Solo_Events
	 WHERE league_key = @league_key
	   AND CONVERT(VARCHAR(6), start_date_time, 112) = @date
	 ORDER BY start_date_time DESC

	UPDATE @events
	   SET event_date_display = DATENAME(WEEKDAY, start_date_time_EST) + ', ' + DATENAME(MONTH, start_date_time_EST) + ' ' + CAST(DAY(start_date_time_EST) AS VARCHAR)

	UPDATE @events
	   SET event_date_display = 'Today'
	 WHERE CAST(start_date_time_EST AS DATE) = CAST(GETDATE() AS DATE)

    -- endpoint: xmlteam
    UPDATE @events
       SET event_id = REPLACE(event_key, @league_key + '-' + CAST(season_key AS VARCHAR) + '-e.', '')
	 WHERE event_key LIKE '%-e.%'

    -- endpoint: sdi
    UPDATE @events
       SET event_id = REVERSE(LEFT(REVERSE(event_key), CHARINDEX(':', REVERSE(event_key)) - 1))
	 WHERE event_key LIKE '%:%'

    -- endpoint: stats (fallback)
    UPDATE @events
       SET event_id = event_key
	 WHERE event_id IS NULL

    UPDATE @events
       SET detail_endpoint = '/Event.svc/detail/motor/' + @leagueId + '/' + CAST(season_key AS VARCHAR) + '/' + event_id


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


--	IF PRE-EVENT

	UPDATE @events
	   SET game_status = CONVERT(VARCHAR, CAST(start_date_time_EST AS TIME), 100) + ' ET'
	 WHERE event_status = 'pre-event'

	UPDATE @events
	   SET sub_ribbon = site_name
	 WHERE event_status = 'pre-event'

--	ELSE

	UPDATE e
	   SET done = r.value	-- MAX ?
	  FROM @events AS e
	 INNER JOIN dbo.SMG_Solo_Results AS r ON r.event_key = e.event_key AND r.[column] = 'laps-completed'


	-- IF POST-EVENT

	UPDATE @events
	   SET game_status = 'Completed'
	 WHERE event_status = 'post-event'

	-- ELSE (MID-EVENT)

	UPDATE @events
	   SET game_status = 'Lap ' + CAST(done AS VARCHAR) + ' of ' + CAST(total AS VARCHAR)
	 WHERE total IS NOT NULL AND done IS NOT NULL AND event_status NOT IN ('pre-event', 'post-event')


	DECLARE @columns TABLE (
		status		VARCHAR(100),
		display		VARCHAR(100),
		[column]	VARCHAR(100),
		[order]		INT
	)

	INSERT INTO @columns (display, [column], [order])
	VALUES ('POS', 'rank', 1), ('DRIVER', 'driver', 2), ('PTS', 'points', 3), ('LED', 'laps_led', 4)
	UPDATE @columns SET status = 'post-event' WHERE status IS NULL

	INSERT INTO @columns (display, [column], [order])
	VALUES ('POS', 'rank', 1), ('DRIVER', 'driver', 2), ('BEHIND', 'laps_behind', 3), ('LED', 'laps_led', 4)
	UPDATE @columns SET status = 'mid-event' WHERE status IS NULL


    DECLARE @stats TABLE (
        event_key	VARCHAR(100),
        player_key	VARCHAR(100),
        player_name	VARCHAR(100),
        column_name	VARCHAR(100), 
        value		VARCHAR(100)
    )
    
    INSERT INTO @stats (event_key, player_key, player_name, column_name, value)
    SELECT e.event_key, player_key, player_name, REPLACE([column], '-', '_'), value 
      FROM dbo.SMG_Solo_Leaders AS l
	 INNER JOIN @events AS e ON e.event_key = l.event_key
	 WHERE l.[column] IN ('rank', 'vehicle-number', 'points', 'laps-leading-total', 'laps-completed', 'laps-behind')

	DECLARE @leaders TABLE (
		event_key		VARCHAR(100),
		driver			VARCHAR(100),
		rank			INT,
		points			INT,
		laps_complete	INT,
		laps_behind		VARCHAR(100),
		laps_led		INT
	)

	INSERT INTO @leaders (event_key, rank, points, laps_led, laps_complete, laps_behind, driver)
    SELECT p.event_key, rank, points, laps_leading_total, laps_completed, laps_behind,
		   LEFT(p.player_name, 1) + '. ' + RIGHT(p.player_name, LEN(p.player_name) - CHARINDEX(' ', p.player_name)) + ' (' + p.vehicle_number + ')'
      FROM (SELECT event_key, player_key, player_name, column_name, value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.column_name IN (rank, vehicle_number, points,
											   laps_leading_total, laps_completed, laps_behind)) AS p
	 ORDER BY event_key, rank


	;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
	SELECT @type AS [type],
		(
			SELECT 'true' AS 'json:Array',
				CAST(g.start_date_time_EST AS DATE) AS event_date,  g.event_date_display,
				(
					SELECT 'true' AS 'json:Array',
						e.event_status, e.tv_coverage, e.start_date_time_EST, e.ribbon, e.sub_ribbon, e.game_status, e.event_id, e.detail_endpoint,
						(
							SELECT c.display, c.[column]
							  FROM @columns AS c
							 WHERE c.status = e.event_status OR (c.status = 'mid-event' AND e.event_status NOT IN ('pre-event', 'post-event'))
							 ORDER BY c.[order] ASC
							   FOR XML RAW('columns'), TYPE	
						),
						(
							SELECT l.rank, l.points, l.laps_led, l.laps_complete, l.laps_behind, l.driver
							  FROM @leaders AS l
							 WHERE l.event_key = e.event_key
							   FOR XML RAW('rows'), TYPE	
						)
					  FROM @events e
					 WHERE e.start_date_time_EST = g.start_date_time_EST
					 ORDER BY e.status_order ASC
					   FOR XML RAW('events'), TYPE
				)
			  FROM @events g
			 GROUP BY g.status_order, g.start_date_time_EST, g.event_date_display
			 ORDER BY g.status_order, g.start_date_time_EST ASC
			   FOR XML RAW('event_dates'), TYPE
		)
	  FOR XML PATH(''), ROOT('root')
   
END

GO
