USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventBriefSolo_Golf_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventBriefSolo_Golf_XML]
	@leagueId VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 08/01/2014
-- Description: get event brief for golf
--				10/01/2014 - ikenticus: updating to SJ-495 110px flags
--				10/10/2014 - ikenticus: SJ-558, pre-event game status should show date
--				10/14/2014 - ikenticus: For PGA/Euro, get the stats using @eventId
--				10/20/2014 - ikenticus: fixing game_status, adjusting round to avoid catching non-golf events
--				11/20/2014 - ikenticus: SJ-899, appending ET to all pre-event game_status, removing UTC crap
--				12/16/2014 - ikenticus: SJ-1100, adjusting code for Team Stroke Play
--              01/22/2015 - John Lin - add UTC
--				02/16/2015 - ikenticus - correcting priority order for leaders
--				03/24/2015 - ikenticus: adding stats_switch to cutover to STATS when data ingestion complete
--				03/30/2015 - ikenticus: fixing bug in STATS event_key logic
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--				06/11/2015 - ikenticus: using new league_key function
--				06/17/2015 - ikenticus: adjusting STATS Golf logic
--				07/02/2015 - ikenticus: eliminating unstarted round from STATS leaders
--				07/17/2015 - ikenticus: optimizing by replacing table calls with temp table
--              07/18/2015 - John Lin - HACK
--				07/19/2015 - ikenticus: refactored to use SMG_Solo_Leaders and eliminate leftover TSN/XTS logic
--				07/21/2015 - ikenticus: solo sports failover event_id logic similar to team sports
--				08/07/2015 - ikenticus: adding SDI golf scoring-system to the mix
--				10/07/2015 - ikenticus: fixing UTC conversion
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueId)
    DECLARE @event_key VARCHAR(100)
    DECLARE @event_type VARCHAR(100) = 'stroke'
	DECLARE @event_status VARCHAR(100)
    DECLARE @tv_coverage VARCHAR(100)
    DECLARE @start_date_time_EST DATETIME
    DECLARE @start_date_time_UTC DATETIME
    DECLARE @game_status VARCHAR(100)
    DECLARE @site_name VARCHAR(100)
    DECLARE @ribbon VARCHAR(100)
    DECLARE @sub_ribbon VARCHAR(100)
    DECLARE @detail_endpoint VARCHAR(100)

	SET @detail_endpoint = '/Event.svc/detail/golf/' + @leagueId + '/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR)

	SELECT @event_key = event_key, @event_status = event_status, @tv_coverage = tv_coverage,
		   @start_date_time_EST = start_date_time, @ribbon = event_name, @site_name = site_name
	  FROM dbo.SMG_Solo_Events
	 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key,
			   @event_key = event_key, @event_status = event_status, @tv_coverage = tv_coverage,
			   @start_date_time_EST = start_date_time, @ribbon = event_name, @site_name = site_name
		  FROM dbo.SMG_Solo_Events AS e
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = e.league_key AND m.value_to = @leagueId AND m.value_type = 'league'
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		 ORDER BY league_key DESC
	END

    SET @start_date_time_UTC = DATEADD(HOUR, DATEDIFF(HOUR, GETDATE(), GETUTCDATE()), @start_date_time_EST)

	DECLARE @columns TABLE (
		display		VARCHAR(100),
		[column]	VARCHAR(100),
		[order]		INT
	)

	DECLARE @leaders TABLE (
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
	  FROM dbo.SMG_Solo_Leaders
	 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key = @event_key

	SELECT @event_type = value
	  FROM @stats
	 WHERE [column] = 'scoring-system'

	IF (@event_status = 'pre-event')
	BEGIN
		--SET @game_status = CONVERT(VARCHAR, CAST(@start_date_time_EST AS TIME), 100) + ' ET'
		SET @game_status = DATENAME(WEEKDAY, @start_date_time_EST) + ', ' + DATENAME(MONTH, @start_date_time_EST) + ' ' + CAST(DAY(@start_date_time_EST) AS VARCHAR)
		SET @sub_ribbon = @site_name
	END
	ELSE
	BEGIN
		DECLARE @round INT

		SELECT @round = MAX([round])
		  FROM @stats
		 WHERE [round] IS NOT NULL

		IF (@event_status = 'post-event')
		BEGIN
			SET @game_status = 'Completed'
		END
		ELSE
		BEGIN
			IF (@round IS NOT NULL)
			BEGIN
				SELECT @game_status = [value]
				  FROM @stats
				 WHERE [round] = @round AND [column] = 'round-name'

				IF (@game_status IS NULL)
				BEGIN
					SET @game_status = 'Round ' + CAST(@round AS VARCHAR)
				END
			END

			IF (@round IS NOT NULL)
			BEGIN
				UPDATE @columns
				   SET display = display + CAST(@round AS VARCHAR)
				 WHERE [column] = 'score'
			END
		END

		IF (@event_type IN ('stroke', 'stroke-play', 'stableford', 'modified-stableford'))
		BEGIN
			IF (@event_status = 'post-event')
			BEGIN
				INSERT INTO @columns (display, [column], [order])
				VALUES ('POS', 'rank', 1), ('PLAYER', 'player', 2), ('TOTAL (PAR)', 'total', 3)
			END
			ELSE
			BEGIN
				INSERT INTO @columns (display, [column], [order])
				-- HACK BEGIN
				-- VALUES ('POS', 'rank', 1), ('PLAYER', 'player', 2), ('R', 'score', 3), ('THRU', 'hole', 4), ('TOTAL (PAR)', 'total', 5)
				VALUES ('POS', 'rank', 1), ('PLAYER', 'player', 2), ('TOTAL (PAR)', 'total', 5)
				-- HACK END
			END
		END
		ELSE IF (@event_type IN ('match', 'match-play'))
		BEGIN
			INSERT INTO @columns (display, [column], [order])
			VALUES ('', 'player', 1), ('', 'score', 2)
		END
		ELSE IF (@event_type IN ('cup', 'ryder-cup', 'presidents-cup'))
		BEGIN
			INSERT INTO @columns (display, [column], [order])
			VALUES ('', 'team', 1), ('', 'score', 2)
		END

		INSERT INTO @leaders (player_name, hole, score, score_total, total, position_event, priority)
		SELECT p.player_name, [hole], [score], [score-total], [total], [position-event], [rank]
		  FROM (SELECT player_name, [column], value FROM @stats) AS s
		 PIVOT (MAX(s.value) FOR s.[column] IN ([hole], [score], [score-total], [total], [position-event], [rank])) AS p

		IF (@event_type IN ('cup', 'ryder-cup', 'presidents-cup'))
		BEGIN
			UPDATE @leaders
			   SET team = player_name, score = score_total

			UPDATE @leaders
			   SET winner = 1
			 WHERE position_event = 1

			UPDATE @leaders
			   SET logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/countries/flags/110/' + team + '.png'
		END
		ELSE
		BEGIN
			UPDATE @leaders
			   SET player = LEFT(player_name, 1) + '. ' + RIGHT(player_name, LEN(player_name) - CHARINDEX(' ', player_name))
		END

		DELETE @leaders
		 WHERE priority IS NULL

	END


	-- If there are no leaders, purge the columns table
	IF ((SELECT COUNT(*) FROM @leaders) = 0)
	BEGIN
		DELETE @columns
	END

    -- HACK
    UPDATE @leaders
       SET position_event = RIGHT(position_event, LEN(position_event) - 1) + 'T'
     WHERE LEFT(position_event, 1) = 'T'
    -- HACK

	IF (@event_type IN ('stroke', 'stroke-play', 'stableford', 'modified-stableford'))
	BEGIN

		SELECT
		(
			SELECT @event_status AS event_status, @tv_coverage AS tv_coverage, @start_date_time_EST AS start_date_time_EST,
				   @start_date_time_UTC AS start_date_time_UTC, @ribbon AS ribbon, @sub_ribbon AS sub_ribbon,
				   @game_status AS game_status, @detail_endpoint AS detail_endpoint, 'golf' AS league_name, 
				(
					SELECT display, [column]
					  FROM @columns
					 ORDER BY [order] ASC
					   FOR XML RAW('columns'), TYPE	
				),
				(
					-- HACK BEGIN
					/*
					SELECT position_event AS [rank], total, player, score, hole
				  FROM @leaders
					 ORDER BY priority ASC
					   FOR XML RAW('rows'), TYPE
					*/	
					SELECT position_event AS [rank], total, player
					  FROM @leaders
					 ORDER BY priority ASC
					   FOR XML RAW('rows'), TYPE
				)
			   FOR XML RAW('brief'), TYPE
		)
		FOR XML PATH(''), ROOT('root')
	
	END
	ELSE
	BEGIN

		SELECT
		(
			SELECT @event_status AS event_status, @tv_coverage AS tv_coverage, @start_date_time_EST AS start_date_time_EST,
				   @start_date_time_UTC AS start_date_time_UTC, @ribbon AS ribbon, @sub_ribbon AS sub_ribbon,
				   @game_status AS game_status, @detail_endpoint AS detail_endpoint, 'golf' AS league_name, 
				(
					SELECT display, [column]
					  FROM @columns
					 ORDER BY [order] ASC
					   FOR XML RAW('columns'), TYPE	
				),
				(
					SELECT position_event AS [rank], total, logo, team, score, hole, player, winner
					  FROM @leaders
					 ORDER BY priority ASC
					   FOR XML RAW('rows'), TYPE
				)
			   FOR XML RAW('brief'), TYPE
		)
		FOR XML PATH(''), ROOT('root')

	END
        
    SET NOCOUNT OFF;
END


GO
