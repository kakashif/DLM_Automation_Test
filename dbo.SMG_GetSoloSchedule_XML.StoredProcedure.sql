USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetSoloSchedule_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_GetSoloSchedule_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
	@leagueId VARCHAR(100)
AS
--=============================================
-- Author:		ikenticus
-- Create date: 10/10/2013
-- Description: get Schedule for Solo Sports
-- Update:      10/26/2013 - ikenticus: adding links to results page
--		        02/19/2014 - ikenticus: supporting multiple tables with ribbons
--				04/11/2014 - ikenticus: adding WTA FED CUP similar to ATP Davis Cup
--				04/14/2014 - pkamat: adding event status and start date time for Ticket City integration
--				05/09/2014 - pkamat: handle null event status for Ticket City integration
--              05/21/2014 - cchiu : convert &amp to & for event_name 
--				05/30/2014 - ikenticus: renaming asphalt to hardcourt for tennis
--				07/21/2014 - ikenticus: removing link for tennis results until sports-tennis UX released
--				02/25/2015 - ikenticus: adding stats_switch to cutover to STATS when data ingestion complete
--				03/24/2015 - ikenticus: SCI-603 - explicitly sorting events by start_date_time, end_date_time, event_name
--										adding distance calculations for NASCAR and Motor Sports
--				04/08/2015 - ikenticus: SOC-210 - restrict site_size calculations to NASCAR/Motor
--				04/10/2015 - ikenticus: tweaks to Tennis schedule due to STATS data
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--				06/12/2015 - ikenticus: using function for current source league_key
--				07/02/2015 - ikenticus: setting winner to event_status when postponed, link to rescheduled event
--				07/07/2015 - ikenticus: removing scoring-system pre-events links, enabling tennis results links
--				07/15/2015 - ikenticus: removing league_source logic, cleaning up xmlteam racing conditional
--				08/05/2015 - ikenticus: using event_id function
--				08/31/2015 - ikenticus: increase event_name to 200 chars to match table
--				09/01/2015 - ikenticus: only link to golf results if scores have come in
--				09/10/2015 - ikenticus: grab results from Archive prior to Results
--				09/15/2015 - ikenticus: removing surface from SDI tennis cups
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


    DECLARE @link VARCHAR(100) = '/sports/'
	DECLARE @results_name VARCHAR(100) = '/results/'
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueId)

    DECLARE @columns TABLE
    (
        display VARCHAR(100),
        [column] VARCHAR(100),
		ribbon VARCHAR(100)
    )

	IF @leagueName = 'golf'
	BEGIN
		SET @results_name = '/leaderboard/'
		INSERT INTO @columns (display, [column])
		VALUES
			('DATE', 'date_range'), ('TOURNAMENT', 'event_name'),
			('CITY/SITE', 'site_city'), ('STATE/COUNTRY', 'site_state'),
			('PAR', 'site_count'), ('YARDS', 'site_size'),
			('TOTAL PURSE', 'purse'), ('WINNER', 'winner')
	END
	ELSE IF @leagueName = 'tennis'
	BEGIN
		INSERT INTO @columns (display, [column])
		VALUES
			('DATE', 'date_range'), ('TOURNAMENT', 'event_name'),
			('CITY/SITE', 'site_city'), ('STATE/COUNTRY', 'site_state'),
			('SURFACE', 'site_surface'),
			('PURSE', 'purse'), ('WINNER', 'winner')
	END
	ELSE IF @leagueName IN ('motor', 'motor-sports', 'nascar')
	BEGIN
		INSERT INTO @columns (display, [column])
		VALUES
			('DATE', 'date_range'), ('RACE', 'event_name'),
			('CITY', 'site_city'), ('STATE', 'site_state'),
			('LAPS', 'site_count'), ('DISTANCE', 'site_size'),
			('WINNER', 'winner')
	END
	-- Set the default ribbon column
	UPDATE @columns SET ribbon = '0'


    DECLARE @rows TABLE (
        date_range VARCHAR(100),
		start_date_time DATETIME,
		event_status VARCHAR(100),
        event_id VARCHAR(100),
        event_key VARCHAR(100),
        event_name VARCHAR(200),
        site_name VARCHAR(100),
        site_city VARCHAR(100),
        site_state VARCHAR(100),
        site_count VARCHAR(100),
        site_size VARCHAR(100),
        site_size_unit VARCHAR(100),
        site_surface VARCHAR(100),
        purse VARCHAR(100),
        winner VARCHAR(100),
		link VARCHAR(100),
		ribbon VARCHAR(100)
    )

	INSERT INTO @rows (date_range, event_status, start_date_time, event_key, event_name, site_name,
		   site_city, site_state, site_count, site_size, site_size_unit, site_surface, purse, winner, ribbon)
	SELECT (CASE
			WHEN end_date_time IS NULL THEN CAST(CONVERT(DATETIME, start_date_time) AS VARCHAR(11))
			ELSE (CAST(CONVERT(DATETIME, start_date_time) AS VARCHAR(6)) + ' - ' + CAST(CONVERT(DATETIME, end_date_time) AS VARCHAR(6)))
			END) AS date_range,
		   ISNULL(event_status, CASE WHEN start_date_time < CURRENT_TIMESTAMP THEN 'post-event' ELSE 'pre-event' END) AS event_status,
		   start_date_time, event_key, REPLACE(event_name, '&amp', ' & '), site_name,
		   ISNULL(NULLIF(site_city, ''), '--') AS site_city,
		   ISNULL(NULLIF(site_state, ''), '--') AS site_state,
		   ISNULL(NULLIF(CAST(site_count AS VARCHAR(100)), '0'), '--') AS site_count,
		   ISNULL(NULLIF(site_size, ''), '--') AS site_size,
		   ISNULL(site_size_unit, '--') AS site_size_unit,
		   ISNULL(site_surface, '--') AS site_surface,
		   ISNULL(NULLIF(REPLACE(REPLACE(purse, '$', ''), '.00', ''), ''), '--') AS purse,
		   ISNULL(winner, '--') AS winner, '0'
	  FROM dbo.SMG_Solo_Events
	 WHERE season_key = @seasonKey AND league_key = @league_key
	 ORDER BY start_date_time ASC, end_date_time ASC, event_name ASC

	UPDATE @rows
	   SET purse = '$ ' + REPLACE(CONVERT(VARCHAR, CAST(purse AS MONEY), 1), '.00', '')
	 WHERE purse != '--'

	UPDATE @rows
	   SET site_surface = 'hardcourt'
	 WHERE site_surface IN ('asphalt', 'hard inside', 'hard outside')


	UPDATE @rows
	   SET event_id = dbo.SMG_fnEventId(event_key)


	IF (@leagueName IN ('nascar', 'motor', 'motor-sports'))
	BEGIN
		IF (@league_key LIKE 'l.%')
		BEGIN
			UPDATE @rows
			   SET site_size = CAST(NULLIF(site_count, '--') * CAST(NULLIF(site_size, '--') AS FLOAT) AS VARCHAR) + ' Miles'
		END
		ELSE
		BEGIN
			UPDATE @rows
			   SET site_size = REPLACE(REPLACE(site_size, '.000', ''), '.500', '.5') + ' ' + site_size_unit
		END
	END

	UPDATE @rows
	   SET site_size = 'N/A'
	 WHERE site_size IS NULL

	/*
	-- SMG_Parse_Feed_Results_Solo will insert winner into SMG_Solo_Events
	UPDATE s
	SET s.winner = r.player_name
	FROM @rows AS s
	INNER JOIN SportsDB.dbo.SMG_Solo_Results AS r
		ON s.event_key = r.event_key AND r.[column] = 'rank' AND r.[value] = '1'
	*/

	-- Retrieve results for current league+season
	DECLARE @results TABLE (
		event_key VARCHAR(100)
	)

	INSERT INTO @results (event_key)
	SELECT e.event_key
	  FROM dbo.SMG_Solo_Events AS e
	 INNER JOIN dbo.SMG_Solo_Archive AS a ON e.event_key LIKE '%' + CAST(a.event_id AS VARCHAR)
	 GROUP BY e.event_key

	IF (@leagueName = 'golf')
	BEGIN
		INSERT INTO @results (event_key)
		SELECT event_key FROM dbo.SMG_Solo_Results
		 WHERE season_key = @seasonKey AND league_key = @league_key AND [column] = 'score' AND value <> ''
		 GROUP BY event_key
	END
	ELSE
	BEGIN
		INSERT INTO @results (event_key)
		SELECT event_key FROM dbo.SMG_Solo_Results
		 WHERE season_key = @seasonKey AND league_key = @league_key
		 GROUP BY event_key
	END


	-- Update @rows with link, if result exists
	UPDATE @rows 
	  SET link = @link + @leagueName + @results_name + CAST(@seasonKey AS VARCHAR(100)) + '/' + @leagueId + '/' + event_id + '/'
	WHERE event_key IN (SELECT event_key FROM @results)


	-- Update @rows with 
	IF (@leagueName = 'tennis')
	BEGIN
		UPDATE @rows SET ribbon = 'Davis Cup' WHERE event_name LIKE 'Davis%'

		INSERT INTO @columns (display, [column], ribbon)
		SELECT display, [column], 'Davis Cup' FROM @columns WHERE ribbon = '0' AND [column] NOT IN ('purse', 'site_surface')

		UPDATE @rows SET ribbon = 'FED CUP' WHERE event_name LIKE 'FED CUP%'

		INSERT INTO @columns (display, [column], ribbon)
		SELECT display, [column], 'FED CUP' FROM @columns WHERE ribbon = '0' AND [column] NOT IN ('purse', 'site_surface')
	END


	UPDATE @rows
	   SET purse = '--'
	 WHERE purse = '$000'

	UPDATE @rows
	   SET winner = '[' + event_status + ']'
	 WHERE LOWER(event_status) = 'postponed'

	-- Set postponed link to rescheduled game, if possible
	UPDATE p
	   SET link = e.link
	  FROM @rows AS p
	 INNER JOIN @rows AS e ON e.event_name = p.event_name
	 WHERE LOWER(p.event_status) = 'postponed' AND LOWER(e.event_status) <> 'postponed'


	-- output XML
	SELECT
	(
		SELECT ribbon AS ribbon,
		(
			SELECT date_range, start_date_time, event_status, event_name, site_name, site_city, site_state,
				   site_count, site_size, site_size_unit, site_surface,
				   purse, winner, link
			  FROM @rows AS r
			 WHERE r.ribbon = t.ribbon
			   FOR XML RAW('row'), TYPE
		),
		(
			SELECT display, [column], ribbon
			  FROM @columns AS c
			 WHERE c.ribbon = t.ribbon
			   FOR XML RAW('column'), TYPE
		)
		FROM @rows AS t
		GROUP BY ribbon
		FOR XML RAW('table'), TYPE
	)
	FOR XML PATH(''), ROOT('root')
	
END

GO
