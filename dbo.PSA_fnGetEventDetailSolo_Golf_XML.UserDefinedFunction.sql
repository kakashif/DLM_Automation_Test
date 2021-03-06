USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[PSA_fnGetEventDetailSolo_Golf_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[PSA_fnGetEventDetailSolo_Golf_XML] (	
	@leagueId VARCHAR(100),
    @seasonKey INT,
    @eventId INT
)
RETURNS XML
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 09/09/2015
-- Description: migrate event detail solo for golf from sproc to function
-- Update:		09/18/2015 - ikenticus: hiding later rounds without score
--				10/08/2015 - ikenticus: fixing max round
--				10/09/2015 - ikenticus: delete rounds >= max round
-- =============================================
BEGIN
	DECLARE @detail_xml XML

	DECLARE @league_source VARCHAR(100)

	SELECT TOP 1 @league_source = filter
	  FROM dbo.SMG_Default_Dates
	 WHERE page = 'source' AND league_key = @leagueId

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueId)
    DECLARE @event_key VARCHAR(100)
    DECLARE @event_type VARCHAR(100) = 'stroke'
    DECLARE @event_status VARCHAR(100)
    DECLARE @tv_coverage VARCHAR(100)
    DECLARE @end_date_time_EST DATETIME
    DECLARE @start_date_time_EST DATETIME
    DECLARE @game_status VARCHAR(100)
    DECLARE @site_name VARCHAR(100)
    DECLARE @ribbon VARCHAR(100)
    DECLARE @sub_ribbon VARCHAR(100)

	DECLARE @par INT
	DECLARE @purse VARCHAR(100)
	DECLARE @distance VARCHAR(100)

	DECLARE @winner VARCHAR(100)
	DECLARE @finals VARCHAR(100)

    DECLARE @preview XML
    DECLARE @recap XML
    DECLARE @body XML
    DECLARE @abstract VARCHAR(MAX)
    DECLARE @coverage VARCHAR(MAX)

	SELECT @event_key = event_key, @event_status = event_status, @tv_coverage = tv_coverage, @start_date_time_EST = start_date_time, @ribbon = event_name,
		   @sub_ribbon = CONVERT(VARCHAR(6), start_date_time, 107) +'-' + CONVERT(VARCHAR(6), end_date_time, 107) + ', ' + site_name + ', ' + site_city + ', ' + site_state,
		   @purse = purse, @par = site_count, @distance = site_size, @site_name = site_name,
		   @preview = pre_event_coverage, @recap = post_event_coverage
	  FROM dbo.SMG_Solo_Events
	 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key,
			   @event_key = event_key, @event_status = event_status, @tv_coverage = tv_coverage, @start_date_time_EST = start_date_time, @ribbon = event_name,
			   @sub_ribbon = CONVERT(VARCHAR(6), start_date_time, 107) +'-' + CONVERT(VARCHAR(6), end_date_time, 107) + ', ' + site_name + ', ' + site_city + ', ' + site_state,
			   @purse = purse, @par = site_count, @distance = site_size, @site_name = site_name,
			   @preview = pre_event_coverage, @recap = post_event_coverage
		  FROM dbo.SMG_Solo_Events AS e
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = e.league_key AND m.value_to = @leagueId AND m.value_type = 'league'
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		 ORDER BY league_key DESC
	END

	DECLARE @tabs TABLE (
		[round] INT,
		display VARCHAR(100),
		page_endpoint VARCHAR(100)
	)

	DECLARE @columns TABLE (
		display		VARCHAR(100),
		[column]	VARCHAR(100),
		[order]		INT
	)

	DECLARE @leaders TABLE (
		player			VARCHAR(100),
		player_key		VARCHAR(100),
		player_name		VARCHAR(100),
		team_key		VARCHAR(100),
		team			VARCHAR(100),
		logo			VARCHAR(100),
		hole			VARCHAR(100),
		score			VARCHAR(100),
		score_total		VARCHAR(100),
		strokes			VARCHAR(100),
		strokes_total	VARCHAR(100),
		total			VARCHAR(100),
		position_event	VARCHAR(100),
		winner			INT,
		priority		INT
	)

	DECLARE @stats TABLE (
		player_key	VARCHAR(100),
		player_name VARCHAR(100),
		[round]		VARCHAR(100), 
		[column]	VARCHAR(100), 
		[value]		VARCHAR(100)
	)

	INSERT INTO @stats (player_key, player_name, [round], [column], value)
	SELECT player_key, player_name, [round], [column], value
	  FROM dbo.SMG_Solo_Results
	 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key = @event_key

	-- GALLERY (SportsImages searchAPI)
	DECLARE @gallery_start_date INT = DATEDIFF(SECOND, '1970-01-01', @start_date_time_EST)
	DECLARE	@gallery_end_date INT = DATEDIFF(SECOND, '1970-01-01', @start_date_time_EST) + (86400 * 7)
   	DECLARE @gallery_limit INT = 100
	DECLARE @gallery_terms VARCHAR(100) = @ribbon
	DECLARE @gallery_keywords VARCHAR(100) = 'Golf'

	-- Cannot just use @league_key due to PGA/Euro crossover matches
	IF EXISTS (
		SELECT 1
		  FROM SportsDB.dbo.SMG_Solo_Events
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		   AND league_key IN ('l.pga.com', 'pga')
		)
	BEGIN
		SET @gallery_keywords = 'PGA'
	END

	IF LOWER(@gallery_terms) = 'the masters'
	BEGIN
		SET @gallery_keywords = 'Golf'
	END

	-- Remove ordinal from event_name
	IF (PATINDEX('%[0-9]%', @gallery_terms) = 1)
	BEGIN
		SET @gallery_terms = RIGHT(@gallery_terms, LEN(@gallery_terms) - PATINDEX('% %', @gallery_terms))
	END

	-- Remove other terms that cause zero search results
	SET @gallery_terms = REPLACE(@gallery_terms, ' Matches', '')

	SELECT @event_type = value
	  FROM @stats
	 WHERE [column] = 'scoring-system'

	IF (@event_status = 'pre-event')
	BEGIN
		--SET @game_status = CONVERT(VARCHAR, CAST(@start_date_time_EST AS TIME), 100) + ' ET'
		SET @game_status = DATENAME(WEEKDAY, @start_date_time_EST) + ', ' + DATENAME(MONTH, @start_date_time_EST) + ' ' + CAST(DAY(@start_date_time_EST) AS VARCHAR)
		SET @sub_ribbon = @site_name
		SET @body = @preview
	END
	ELSE
	BEGIN
		DECLARE @round INT

		SELECT @round = MAX([round])
		  FROM @stats
		 WHERE [round] <> '' AND [column] IN ('score-total', 'score') AND value NOT IN ('', '0')

		IF (@event_status = 'post-event')
		BEGIN
			SET @game_status = 'Completed'
			SET @body = @recap
		END
		ELSE
		BEGIN
			IF (@round IS NOT NULL)
			BEGIN
				SELECT @game_status = [value]
				  FROM @stats
				 WHERE [round] = @round AND [column] = 'round-name'

				IF (@game_status IS NULL AND LEN(@round) = 1)
				BEGIN
					SET @game_status = 'Round ' + CAST(@round AS VARCHAR)
				END
			END
		END

		IF (@event_type IN ('match', 'match-play'))
		BEGIN
			INSERT INTO @columns (display, [column], [order])
			VALUES ('', 'player', 1), ('', 'score', 2)
		END
		ELSE IF (@event_type IN ('cup', 'ryder-cup', 'presidents-cup'))
		BEGIN
			INSERT INTO @columns (display, [column], [order])
			VALUES ('', 'team', 1), ('', 'score', 2)
		END


        INSERT INTO @tabs (page_endpoint, [round], display)
        SELECT '/Event.svc/round/golf/' + @leagueId + '/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR) + '/' + CAST([round] AS VARCHAR),
				[round], [value]
		  FROM @stats
		 WHERE [round] <> '' AND [column] = 'round-name'
		 ORDER BY [round] ASC

		IF ((SELECT COUNT(*) FROM @tabs) = 0)
		BEGIN
			INSERT INTO @tabs (page_endpoint, [round], display)
			SELECT '/Event.svc/round/golf/' + @leagueId + '/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR) + '/' + CAST([round] AS VARCHAR),
					[round], 'Round ' + CAST([round] AS VARCHAR)
			  FROM @stats
			 WHERE [round] <> ''
			 GROUP BY [round]
			 ORDER BY [round] ASC
		END

		IF EXISTS (SELECT 1 FROM @stats WHERE [column] = 'round-type' AND value <> 'singles')
		BEGIN
			UPDATE t
			   SET display = display + ' ' + UPPER(LEFT(value, 1)) + RIGHT(value, LEN(value) - 1)
			  FROM @tabs AS t
			 INNER JOIN @stats AS s ON s.[round] = t.[round]
			 WHERE s.[column] = 'round-type'
		END

		IF (@event_type IN ('stroke', 'stroke-play', 'stableford', 'modified-stableford'))
		BEGIN
			UPDATE @tabs
			   SET display = 'Playoff'
			 WHERE [round] = '5'

			IF NOT EXISTS (SELECT 1
							 FROM @stats
							WHERE [round] = '5' AND [column] = 'course-hole')
			BEGIN
				DELETE @tabs
				 WHERE [round] = '5'
			END
		END
	END

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
				   @coverage = CAST(node.query('body.content[p or div]/*') AS VARCHAR(MAX))
							 + CAST(node.query('body.content/note/body.content/*') AS VARCHAR(MAX))
		  FROM @body.nodes('//body') AS SMG(node)
	END

	-- If there are no leaders, purge the columns table
	IF ((SELECT COUNT(*) FROM @leaders) = 0)
	BEGIN
		DELETE FROM @columns
	END


	-- If tee-time is tomorrow, delete the round from tabs
	DECLARE @round_tee_time DATE
	
	SELECT TOP 1 @round_tee_time = CAST(value AS DATE)
	  FROM @stats
	 WHERE [round] = @round AND [column] = 'tee-time'
	 ORDER BY CAST(value AS DATETIME) ASC

	IF (@round_tee_time IS NOT NULL)
	BEGIN
		IF (CAST(GETDATE() AS DATE) < @round_tee_time)
		BEGIN
			DELETE @tabs
			 WHERE [round] >= @round

			SELECT TOP 1 @game_status = display
			  FROM @tabs
			 ORDER BY [round] DESC
		END
	END


	DECLARE @max_scoring_round INT

	SELECT @max_scoring_round = MAX(round)
	  FROM @stats
	 WHERE [column] = 'score'

	DELETE @tabs
	 WHERE [round] > @max_scoring_round


	IF (@event_type IN ('cup', 'ryder-cup', 'presidents-cup'))
	BEGIN
		DELETE @stats

		INSERT INTO @stats (player_key, player_name, [round], [column], value)
		SELECT player_key, player_name, [round], [column], value
		  FROM dbo.SMG_Solo_Leaders
		 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key = @event_key

		INSERT INTO @leaders (player_key, player_name, hole, score, score_total, strokes_total, total, position_event, priority)
		SELECT p.player_key, p.player_name, [hole], [score], [score-total], [strokes-total], [total], [position-event], [rank]
		  FROM (SELECT player_key, player_name, [column], value FROM @stats) AS s
		 PIVOT (MAX(s.value) FOR s.[column] IN ([hole], [score], [score-total], [strokes-total], [total], [position-event], [rank])) AS p

		UPDATE @leaders
		   SET team = player_name, score = score_total

		UPDATE @leaders
		   SET winner = 1
		 WHERE position_event = 1

		UPDATE @leaders
		   SET logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/countries/flags/110/' + team + '.png'

		DELETE @leaders
		 WHERE priority IS NULL
	END

	SELECT @detail_xml = (
		SELECT
		(
			SELECT @event_type AS event_type, @event_status AS event_status,
				   @tv_coverage AS tv_coverage, @start_date_time_EST AS start_date_time_EST,
				   @ribbon AS ribbon, @sub_ribbon AS sub_ribbon,
				   @game_status AS game_status, @purse AS purse, @par AS par, @distance AS yards,
				   @abstract AS abstract, @coverage AS coverage,
					(
						SELECT display, [column]
						  FROM @columns
						 ORDER BY [order] ASC
						   FOR XML RAW('columns'), TYPE	
					),
					(
						SELECT position_event AS [rank], total, strokes, logo, team, score, hole, player, winner
						  FROM @leaders
						 ORDER BY priority ASC
						   FOR XML RAW('rows'), TYPE	
					)
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
			SELECT display, page_endpoint
			  FROM @tabs
			 ORDER BY [round] ASC
			   FOR XML RAW('tabs'), TYPE
		)
		FOR XML PATH(''), ROOT('root')
	)
	
	RETURN @detail_xml
END

GO
