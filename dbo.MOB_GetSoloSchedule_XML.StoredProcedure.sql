USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetSoloSchedule_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[MOB_GetSoloSchedule_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
	@leagueId VARCHAR(100)
AS
--=============================================
-- Author:		ikenticus
-- Create date: 11/24/2014
-- Description: get Schedule for Solo Sports
-- Update:		02/25/2015 - ikenticus: adding stats_switch to cutover to STATS when data ingestion complete
--				03/26/2015 - ikenticus: unifying nascar and motor
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--				06/12/2015 - ikenticus: using function for current source league_key
--				08/25/2015 - ikenticus: using function for event_id
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
			('DATE', 'date_range'), ('TOURNAMENT', 'event_name'), ('WINNER', 'winner')
	END
	ELSE IF @leagueName = 'tennis'
	BEGIN
		INSERT INTO @columns (display, [column])
		VALUES
			('DATE', 'date_range'), ('TOURNAMENT', 'event_name'), ('WINNER', 'winner')
	END
	ELSE IF @leagueName IN ('motor', 'motor-sports', 'nascar')
	BEGIN
		INSERT INTO @columns (display, [column])
		VALUES
			('DATE', 'date_range'), ('RACE', 'event_name'), ('WINNER', 'winner')
	END
	-- Set the default ribbon column
	UPDATE @columns SET ribbon = '0'


    DECLARE @rows TABLE (
        date_range VARCHAR(100),
		start_date_time DATETIME,
		event_status VARCHAR(100),
        event_id VARCHAR(100),
        event_key VARCHAR(100),
        event_name VARCHAR(100),
        winner VARCHAR(100),
		link VARCHAR(100),
		ribbon VARCHAR(100)
    )
	INSERT INTO @rows (date_range, start_date_time, event_status, event_key, event_name, winner, link, ribbon)
	SELECT (CASE
				WHEN end_date_time IS NULL THEN CAST(CONVERT(DATETIME, start_date_time) AS VARCHAR(11))
				ELSE (CAST(CONVERT(DATETIME, start_date_time) AS VARCHAR(6)) + ' - ' + CAST(CONVERT(DATETIME, end_date_time) AS VARCHAR(6)))
				END) AS date_range,
			start_date_time,
			ISNULL(event_status, CASE WHEN start_date_time < CURRENT_TIMESTAMP THEN 'post-event' ELSE 'pre-event' END) AS event_status,
			event_key,
			REPLACE(event_name, '&amp', ' & '),
			ISNULL(winner, '--') AS winner,
			NULL, '0'
	FROM dbo.SMG_Solo_Events
	WHERE season_key = @seasonKey AND league_key = @league_key
	ORDER BY start_date_time

	UPDATE @rows
	   SET event_id = SportsDB.dbo.SMG_fnEventId(event_key)

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
		SELECT display, [column], 'Davis Cup' FROM @columns WHERE ribbon = '0' AND [column] <> 'purse'

		UPDATE @rows SET ribbon = 'FED CUP' WHERE event_name LIKE 'FED CUP%'

		INSERT INTO @columns (display, [column], ribbon)
		SELECT display, [column], 'FED CUP' FROM @columns WHERE ribbon = '0' AND [column] <> 'purse'
	END

	-- output XML
	SELECT
	(
		SELECT ribbon AS ribbon,
		(
			SELECT date_range, start_date_time, event_status, event_name, winner, link
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
