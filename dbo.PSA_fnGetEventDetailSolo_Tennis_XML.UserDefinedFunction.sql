USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[PSA_fnGetEventDetailSolo_Tennis_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[PSA_fnGetEventDetailSolo_Tennis_XML] (	
	@leagueId VARCHAR(100),
    @seasonKey INT,
    @eventId INT
)
RETURNS XML
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 09/10/2015
-- Description: migrate event detail solo for tennis from sproc to function
-- Update:		09/29/2015 - ikenticus - using colon in the event_key because tennis event_id are too small
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
    DECLARE @end_date_time_EST DATETIME
    DECLARE @start_date_time_EST DATETIME
    DECLARE @game_status VARCHAR(100)
    DECLARE @ribbon VARCHAR(100)
    DECLARE @sub_ribbon VARCHAR(100)

	DECLARE @surface VARCHAR(100)
	DECLARE @purse VARCHAR(100)

    DECLARE @preview XML
    DECLARE @recap XML
    DECLARE @body XML
    DECLARE @abstract VARCHAR(MAX)
    DECLARE @coverage VARCHAR(MAX)

	SELECT @event_key = event_key, @event_status = event_status, @tv_coverage = tv_coverage, @start_date_time_EST = start_date_time, @ribbon = event_name,
		   @sub_ribbon = CONVERT(VARCHAR(6), start_date_time, 107) +'-' + CONVERT(VARCHAR(6), end_date_time, 107) + ', ' + site_city + ', ' + site_state,
		   @purse = '$' + REPLACE(CONVERT(VARCHAR, CAST(purse AS MONEY), 1), '.00', ''), @surface = site_surface,
		   @preview = pre_event_coverage, @recap = post_event_coverage
	  FROM dbo.SMG_Solo_Events
	 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%:' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key,
			   @event_key = event_key, @event_status = event_status, @tv_coverage = tv_coverage, @start_date_time_EST = start_date_time, @ribbon = event_name,
			   @sub_ribbon = CONVERT(VARCHAR(6), start_date_time, 107) +'-' + CONVERT(VARCHAR(6), end_date_time, 107) + ', ' + site_city + ', ' + site_state,
			   @purse = '$' + REPLACE(CONVERT(VARCHAR, CAST(purse AS MONEY), 1), '.00', ''), @surface = site_surface,
			   @preview = pre_event_coverage, @recap = post_event_coverage
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
		[value]		VARCHAR(100)
	)

	INSERT INTO @stats (team_key, player_key, player_name, [round], [column], value)
	SELECT team_key, player_key, player_name, [round], [column], value
	  FROM dbo.SMG_Solo_Results
	 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key = @event_key

	DECLARE @tabs TABLE (
		[order] INT,
		[round] VARCHAR(100),
		display VARCHAR(100),
		page_endpoint VARCHAR(100)
	)

	-- For Davis/Fed CUP tournaments
    DECLARE @matches XML
	DECLARE @linescores TABLE (
		country_display VARCHAR(100),
		country_code VARCHAR(100),
		logo VARCHAR(100),
		score VARCHAR(100),
		winner INT
	)

	-- GALLERY (SportsImages searchAPI)
	DECLARE @gallery_terms VARCHAR(100) = REPLACE(@leagueId, 's-tennis', '')
	DECLARE @gallery_keywords VARCHAR(100) = @ribbon + ' tennis'
	DECLARE @gallery_start_date INT = DATEDIFF(SECOND, '1970-01-01', @start_date_time_EST)
	DECLARE	@gallery_end_date INT = DATEDIFF(SECOND, '1970-01-01', @start_date_time_EST) + (86400 * 14)
   	DECLARE @gallery_limit INT = 100

	IF (@event_status = 'pre-event' OR @event_status IS NULL)
	BEGIN
		--SET @game_status = CONVERT(VARCHAR, CAST(@start_date_time_EST AS TIME), 100)
		SET @game_status = DATENAME(WEEKDAY, @start_date_time_EST) + ', ' + DATENAME(MONTH, @start_date_time_EST) + ' ' + CAST(DAY(@start_date_time_EST) AS VARCHAR)
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
		IF (@ribbon LIKE 'Davis Cup%' OR @ribbon LIKE 'Fed Cup%')
		BEGIN

			SET @purse = ''
			SET @game_status = 'In Progress'
			--SET @matches = dbo.PSA_fnGetEventRoundSolo_Tennis_XML(@leagueId, @seasonKey, @eventId, 'cup')
			INSERT INTO @tabs (display, page_endpoint)
			SELECT 'Matches', '/Event.svc/round/tennis/' + @leagueId + '/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR) + '/cup'
				   

			INSERT INTO @linescores (country_display, country_code, score)
			SELECT player_name, team_key, value
			  FROM @stats
			 WHERE [column] = 'score-total'

			UPDATE @linescores
			   SET logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/countries/flags/110/' + country_code + '.png'

			IF (@event_status = 'post-event')
			BEGIN
				DECLARE @high_score INT
				SELECT @high_score = MAX(score) FROM @linescores

				UPDATE @linescores
				   SET winner = FLOOR(score / @high_score)
				 WHERE score > 0
			END

		END
		ELSE
		BEGIN

			INSERT INTO @tabs ([round], [order])
			SELECT [round], RANK() OVER (ORDER BY COUNT(round) DESC, round ASC)
			  FROM @stats
			 WHERE [column] = 'match-event-status'
			GROUP BY [round]
			ORDER BY COUNT(round) DESC

			UPDATE @tabs
			   SET page_endpoint = '/Event.svc/round/tennis/' + @leagueId + '/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR) + '/' + [round]

			UPDATE t
			   SET display = value
			  FROM @tabs AS t
			 INNER JOIN @stats AS s ON t.[round] = s.[round] AND s.[column] = 'round-name'

			UPDATE @tabs
			   SET display = CASE
								WHEN ISNUMERIC([round]) = 1 THEN 'Round ' + CAST([round] AS VARCHAR)
								WHEN [round] LIKE '%final%' THEN UPPER(LEFT([round], 1)) + RIGHT([round], LEN([round]) - 1)
								ELSE UPPER(LEFT([round], 1)) + RIGHT([round], LEN([round]) - 1) + 'finals'
								END
			 WHERE display IS NULL


			DECLARE @round VARCHAR(100)

			SELECT TOP 1 @round = round
			  FROM @tabs
			 ORDER BY [order] DESC

		END

		IF (@event_status = 'post-event')
		BEGIN
			SET @game_status = 'Completed'
			SET @body = @recap

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
			SELECT @game_status = display
			  FROM @tabs
			 WHERE [round] = @round
		END
	END

	-- Do not leave game_status as null
	IF (@game_status IS NULL)
	BEGIN
	   SET @game_status = UPPER(LEFT(@event_status, 1)) + LOWER(RIGHT(@event_status, LEN(@event_status) - 1)) 
	END


	SELECT @detail_xml = (
		SELECT
		(
			SELECT @event_status AS event_status, @tv_coverage AS tv_coverage, @start_date_time_EST AS start_date_time_EST,
				   @ribbon AS ribbon, @sub_ribbon AS sub_ribbon,
				   @game_status AS game_status, @purse AS purse, @surface AS surface,
				   @abstract AS abstract, @coverage AS coverage
			   FOR XML RAW('detail'), TYPE
		),
		(
			SELECT winner, logo, country_display AS country, score
			  FROM @linescores
			 ORDER BY country_display ASC
			   FOR XML RAW('linescore'), TYPE
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
			 ORDER BY [order] ASC
			   FOR XML RAW('tabs'), TYPE
		),
		(
			SELECT node.query('match') FROM @matches.nodes('/') AS SMG(node)
		)
		FOR XML PATH(''), ROOT('root')
	)
	
	RETURN @detail_xml
END

GO
