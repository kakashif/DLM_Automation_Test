USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetScoresByMonthSolo_MMA_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetScoresByMonthSolo_MMA_XML]
	@year		INT,
	@month		INT
AS
--=============================================
-- Author:		ikenticus
-- Create date:	10/02/2014
-- Description: get scores by month for MMA
-- Update:		10/09/2014 - ikenticus: adjusting for newly adjusted MMA leagues
--				11/11/2014 - ikenticus: adding event_date_display = 'Today' when applicable
--				11/12/2014 - ikenticus: remove tv_coverage for completed events
--				11/20/2014 - ikenticus: SJ-899, appending ET to all pre-event game_status, removing UTC crap
--				03/04/2015 - ikenticus: SJ-1400, removing  duplicate event_dates due to varying status_order
--				06/30/2015 - ikenticus: remove any mid-events older than 24 hours, using mma event id as event_key
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = 'mma'

	DECLARE @type VARCHAR(100) = 'monthly'

	DECLARE @events TABLE
	(
		event_date DATE,
		status_order INT,
		season_key INT,
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

	INSERT INTO @events (season_key, event_key, tv_coverage, event_status, start_date_time_EST, event_date, ribbon, site_name, total)
	SELECT e.season_key, event_key, tv_coverage, event_status, start_date_time, start_date_time, event_name, site_name, site_count
	  FROM dbo.SMG_Solo_Events AS e
	 INNER JOIN dbo.SMG_Solo_Leagues AS l ON league_name = 'mma'
	   AND l.league_key = e.league_key AND l.season_key = e.season_key
	 WHERE CONVERT(VARCHAR(6), e.start_date_time, 112) = @date AND event_key NOT LIKE '%-%'
	 ORDER BY e.start_date_time DESC

    UPDATE @events
       SET detail_endpoint = '/Event.svc/matchup/mma/' + CAST(season_key AS VARCHAR) + '/' + event_key


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

	-- IF POST-EVENT

	UPDATE @events
	   SET game_status = 'Completed', tv_coverage = ''
	 WHERE event_status = 'post-event'

	-- ELSE (MID-EVENT)

	UPDATE @events
	   SET game_status = 'In Progress'
	 WHERE event_status = 'mid-event'

	UPDATE @events
	   SET game_status = UPPER(LEFT(event_status, 1)) + RIGHT(event_status, LEN(event_status) - 1)
	 WHERE event_status NOT LIKE '%-event'

	-- Remove any mid-events older than 24 hours
	DELETE @events
	 WHERE event_status = 'mid-event' AND DATEADD(DD, 1, start_date_time_EST) < GETDATE()


	DECLARE @event_dates TABLE (
		event_date_display VARCHAR(100),
		event_date DATE,
		status_order INT
	)

	INSERT INTO @event_dates (event_date, status_order)
	SELECT event_date, MIN(status_order)
	  FROM @events
	 GROUP BY event_date

	UPDATE @event_dates
	   SET event_date_display = DATENAME(WEEKDAY, event_date) + ', ' + DATENAME(MONTH, event_date) + ' ' + CAST(DAY(event_date) AS VARCHAR)

	UPDATE @event_dates
	   SET event_date_display = 'Today'
	 WHERE event_date = CAST(GETDATE() AS DATE)


	;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
	SELECT @type AS [type],
		(
			SELECT 'true' AS 'json:Array',
				g.event_date,  g.event_date_display,
				(
					SELECT 'true' AS 'json:Array',
						e.event_status, e.tv_coverage, e.start_date_time_EST, e.ribbon, e.sub_ribbon, e.game_status, e.event_key, e.detail_endpoint
					  FROM @events e
					 WHERE e.event_date = g.event_date
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
