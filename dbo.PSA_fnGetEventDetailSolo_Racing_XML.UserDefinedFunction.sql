USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[PSA_fnGetEventDetailSolo_Racing_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[PSA_fnGetEventDetailSolo_Racing_XML] (	
	@leagueId VARCHAR(100),
    @seasonKey INT,
    @eventId INT
)
RETURNS XML
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 09/10/2015
-- Description: migrate event detail solo for racing from sproc to function
-- Update:		10/07/2015 - ikenticus: fixing UTC conversion
-- =============================================
BEGIN
	DECLARE @detail_xml XML

	DECLARE @league_source VARCHAR(100)

	SELECT TOP 1 @league_source = filter
	  FROM dbo.SMG_Default_Dates
	 WHERE page = 'source' AND league_key = @leagueId

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueId)
    DECLARE @event_key VARCHAR(100)
	DECLARE @event_status VARCHAR(100)
    DECLARE @tv_coverage VARCHAR(100)
    DECLARE @start_date_time_EST DATETIME
    DECLARE @start_date_time_UTC DATETIME
    DECLARE @game_status VARCHAR(100)
    DECLARE @ribbon VARCHAR(100)
    DECLARE @sub_ribbon VARCHAR(100)

	DECLARE @total INT
	DECLARE @distance VARCHAR(100)
	DECLARE @site_size VARCHAR(100)
	DECLARE @site_size_unit VARCHAR(100)

    DECLARE @preview XML
    DECLARE @recap XML
    DECLARE @body XML
    DECLARE @abstract VARCHAR(MAX)
    DECLARE @coverage VARCHAR(MAX)

	SELECT @event_key = event_key, @event_status = event_status, @tv_coverage = tv_coverage, @start_date_time_EST = start_date_time,
		   @sub_ribbon = CONVERT(VARCHAR(6), @start_date_time_EST, 107) + ', ' + site_name + ', ' + site_city + ', ' + site_state,
		   @ribbon = event_name, @total = site_count, @site_size = site_size, @site_size_unit = site_size_unit,
		   @preview = pre_event_coverage, @recap = post_event_coverage
	  FROM dbo.SMG_Solo_Events
	 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key,
			   @event_key = event_key, @event_status = event_status, @tv_coverage = tv_coverage, @start_date_time_EST = start_date_time,
			   @sub_ribbon = CONVERT(VARCHAR(6), @start_date_time_EST, 107) + ', ' + site_name + ', ' + site_city + ', ' + site_state,
			   @ribbon = event_name, @total = site_count, @site_size = site_size, @site_size_unit = site_size_unit,
			   @preview = pre_event_coverage, @recap = post_event_coverage
		  FROM dbo.SMG_Solo_Events AS e
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = e.league_key AND m.value_to = @leagueId AND m.value_type = 'league'
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		 ORDER BY league_key DESC
	END

	DECLARE @columns TABLE (
		display		VARCHAR(100),
		[column]	VARCHAR(100),
		[order]		INT
	)

	DECLARE @stats TABLE (
		player_key	VARCHAR(100),
		player_name	VARCHAR(100),
		[column]	VARCHAR(100), 
		value		VARCHAR(100)
	)

	DECLARE @leaders TABLE (
		driver			VARCHAR(100),
		rank			INT,
		points			INT,
		laps_complete	INT,
		laps_behind		VARCHAR(100),
		laps_led		INT
	)

	INSERT INTO @stats (player_key, player_name, [column], value)
	SELECT player_key, player_name, REPLACE([column], '-', '_'), value
	  FROM dbo.SMG_Solo_Results
	 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key = @event_key

	IF (@league_source IS NULL OR @league_source = 'xmlteam')
	BEGIN
		SET @distance = REPLACE(REPLACE(@site_size, '.000', ''), '.500', '.5') + ' ' + @site_size_unit
	END
	ELSE
	BEGIN
		SET @distance = CAST(@total * CAST(@site_size AS FLOAT) AS VARCHAR) + ' Miles'
	END

	SET @start_date_time_UTC = DATEADD(HOUR, DATEDIFF(HOUR, GETDATE(), GETUTCDATE()), @start_date_time_EST)

	-- GALLERY (SportsImages searchAPI)
	DECLARE @gallery_terms VARCHAR(100) = 'nascar'
	DECLARE @gallery_keywords VARCHAR(100) = @ribbon
	DECLARE @gallery_start_date INT = DATEDIFF(SECOND, '1970-01-01', @start_date_time_EST)
	DECLARE	@gallery_end_date INT = DATEDIFF(SECOND, '1970-01-01', @start_date_time_EST) + 86400
   	DECLARE @gallery_limit INT = 100

	IF (@event_status = 'pre-event')
	BEGIN
		SET @game_status = CONVERT(VARCHAR, CAST(@start_date_time_EST AS TIME), 100) + ' ET'
		SET @body = @preview

		IF (@league_source = 'stats')
		BEGIN
			SELECT @abstract = CAST(node.query('header/headline/text()') AS VARCHAR(MAX)),
				   @coverage = CAST(node.query('content/paragraphs/paragraph') AS VARCHAR(MAX))
			  FROM @body.nodes('//story') AS SMG(node)

			IF (@coverage IS NULL)
			BEGIN
				SELECT @abstract = CAST(node.query('header/headline/text()') AS VARCHAR(MAX)),
					   @coverage = CAST(node.query('paragraphs/paragraph') AS VARCHAR(MAX))
				  FROM @body.nodes('//content') AS SMG(node)
			END
			
			SET @coverage = REPLACE(REPLACE(@coverage, 'paragraph>', 'p>'), '''''', '"')
		END
		ELSE
		BEGIN
			SELECT @abstract = CAST(node.query('body.head/hedline') AS VARCHAR(MAX)),
				   @coverage = CAST(node.query('body.content/p') AS VARCHAR(MAX)) + CAST(node.query('body.content/note/body.content/*') AS VARCHAR(MAX))
			  FROM @body.nodes('//body') AS SMG(node)
		END

	END
	ELSE
	BEGIN
		DECLARE @done INT

		INSERT INTO @stats (player_key, player_name, [column], value)
		SELECT player_key, player_name, REPLACE([column], '-', '_'), value 
		  FROM dbo.SMG_Solo_Results
		 WHERE event_key = @event_key
		   AND [column] IN ('rank', 'vehicle-number', 'points', 'laps-leading-total', 'laps-completed')

		SELECT @done = MAX(CAST(value AS INT))
		  FROM @stats
		 WHERE [column] = 'laps-completed'

		IF (@event_status = 'post-event')
		BEGIN
			SET @game_status = 'Completed'
			SET @body = @recap

			INSERT INTO @columns (display, [column], [order])
			VALUES ('POS', 'rank', 1), ('DRIVER', 'driver', 2), ('PTS', 'points', 3), ('LED', 'laps_led', 4)

			IF (@league_source = 'stats')
			BEGIN
				SELECT @abstract = CAST(node.query('header/headline/text()') AS VARCHAR(MAX)),
					   @coverage = CAST(node.query('content/paragraphs/paragraph') AS VARCHAR(MAX))
				  FROM @body.nodes('//story') AS SMG(node)

				IF (@coverage IS NULL)
				BEGIN
					SELECT @abstract = CAST(node.query('header/headline/text()') AS VARCHAR(MAX)),
						   @coverage = CAST(node.query('paragraphs/paragraph') AS VARCHAR(MAX))
					  FROM @body.nodes('//content') AS SMG(node)
				END
				
				SET @coverage = REPLACE(REPLACE(@coverage, 'paragraph>', 'p>'), '''''', '"')
			END
			ELSE
			BEGIN
				SELECT @abstract = CAST(node.query('body.head/abstract/p') AS VARCHAR(MAX)),
					   @coverage = CAST(node.query('body.content/p') AS VARCHAR(MAX)) + CAST(node.query('body.content/note/body.content/*') AS VARCHAR(MAX))
				  FROM @body.nodes('//body') AS SMG(node)
			END

		END
		ELSE
		BEGIN
			IF (@total IS NOT NULL AND @done IS NOT NULL)
			BEGIN
				SET @game_status = 'Lap ' + CAST(@done AS VARCHAR) + ' of ' + CAST(@total AS VARCHAR)
			END

			INSERT INTO @columns (display, [column], [order])
			VALUES ('POS', 'rank', 1), ('DRIVER', 'driver', 2), ('BEHIND', 'laps_behind', 3), ('LED', 'laps_led', 4)
		END

		INSERT INTO @leaders (rank, points, laps_led, laps_complete, laps_behind, driver)
		SELECT rank, points, laps_leading_total, laps_completed, laps_behind,
			   LEFT(p.player_name, 1) + '. ' + RIGHT(p.player_name, LEN(p.player_name) - CHARINDEX(' ', p.player_name)) + ' (' + p.vehicle_number + ')'
		  FROM (SELECT player_key, player_name, [column], value FROM @stats) AS s
		 PIVOT (MAX(s.value) FOR s.[column] IN (rank, vehicle_number, points,
												   laps_leading_total, laps_completed, laps_behind)) AS p
		 ORDER BY rank

		UPDATE @leaders
		   SET laps_behind = '--'
		 WHERE laps_complete = @done

		UPDATE @leaders
		   SET laps_behind = CAST((@done - CAST(laps_complete AS VARCHAR)) AS VARCHAR) + ' laps'
		 WHERE laps_complete < @done

		DELETE @leaders
		 WHERE laps_complete = 0

		DELETE @leaders
		 WHERE driver IS NULL
	END


	SELECT @detail_xml = (
		SELECT
		(
			SELECT @event_status AS event_status, @tv_coverage AS tv_coverage, @start_date_time_EST AS start_date_time_EST,
				   @start_date_time_UTC AS start_date_time_UTC, @ribbon AS ribbon, @sub_ribbon AS sub_ribbon,
				   @game_status AS game_status, @total AS total_laps, @distance AS distance,
				   @abstract AS abstract, @coverage AS coverage
			   FOR XML RAW('detail'), TYPE
		),
		(
			SELECT @gallery_terms AS terms,
				   @gallery_keywords AS keywords,
				   @gallery_start_date AS [start_date],
				   @gallery_end_date AS end_date,
				   @gallery_limit AS limit
			   FOR XML RAW('gallery'), TYPE
		),
		(
			SELECT display, [column]
			  FROM @columns
			 ORDER BY [order] ASC
			   FOR XML RAW('columns'), TYPE	
		),
		(
			SELECT rank, points, laps_led, laps_complete, laps_behind, driver
			  FROM @leaders
			 ORDER BY rank
			   FOR XML RAW('rows'), TYPE	
		)
		FOR XML PATH(''), ROOT('root')
	)


	RETURN @detail_xml
END

GO
