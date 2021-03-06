USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventBriefSolo_Tennis_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventBriefSolo_Tennis_XML]
	@leagueId VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 08/11/2014
-- Description: get event brief for tennis
-- Update:		08/27/2014 - ikenticus: moving linescore node inside brief node
--				09/10/2014 - ikenticus: making players into list
--				10/01/2014 - ikenticus: updating to SJ-495 110px flags
--				10/10/2014 - ikenticus: SJ-558, pre-event game status should show date
--				11/11/2014 - ikenticus: setting game_status to event_status if still NULL at the end
--				11/20/2014 - ikenticus: SJ-899, appending ET to all pre-event game_status, removing UTC crap
--              01/22/2015 - John Lin - add UTC
--				03/24/2015 - ikenticus: adding stats_switch to cutover to STATS when data ingestion complete
--				03/30/2015 - ikenticus: fixing bug in STATS event_key logic
--				04/27/2015 - ikenticus: replacing stats_switch with source from SMG_Default_Dates/SMG_Mappings
--				06/11/2015 - ikenticus: using new league_key function
--				07/17/2016 - ikenticus: optimizing by replacing table calls with temp table
--				07/21/2015 - ikenticus: solo sports failover event_id logic similar to team sports
--				09/08/2015 - ikenticus: fixing round name for SDI
--				09/09/2015 - ikenticus: switching to using SMG_Solo_Leaders
--				09/15/2015 - ikenticus: set tennis cups to Final during post-event
-- 				09/29/2015 - ikenticus - using colon in the event_key because tennis event_id are too small
--				10/07/2015 - ikenticus: fixing UTC conversion
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueId)
    DECLARE @event_key VARCHAR(100)
	DECLARE @event_status VARCHAR(100)
    DECLARE @tv_coverage VARCHAR(100)
    DECLARE @start_date_time_EST DATETIME
    DECLARE @start_date_time_UTC DATETIME
    DECLARE @game_status VARCHAR(100)
    DECLARE @match_status VARCHAR(100)
    DECLARE @ribbon VARCHAR(100)
    DECLARE @sub_ribbon VARCHAR(100)
    DECLARE @detail_endpoint VARCHAR(100)

	SET @detail_endpoint = '/Event.svc/detail/tennis/' + @leagueId + '/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR)

	SELECT @event_key = event_key, @event_status = event_status, @tv_coverage = tv_coverage, @start_date_time_EST = start_date_time, @ribbon = event_name,
		   @sub_ribbon = CONVERT(VARCHAR(6), start_date_time, 107) +'-' + CONVERT(VARCHAR(6), end_date_time, 107) + ', ' + site_city + ', ' + site_state
	  FROM dbo.SMG_Solo_Events
	 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%:' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key,
			   @event_key = event_key, @event_status = event_status, @tv_coverage = tv_coverage, @start_date_time_EST = start_date_time, @ribbon = event_name,
			   @sub_ribbon = CONVERT(VARCHAR(6), start_date_time, 107) +'-' + CONVERT(VARCHAR(6), end_date_time, 107) + ', ' + site_city + ', ' + site_state
		  FROM dbo.SMG_Solo_Events AS e
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = e.league_key AND m.value_to = @leagueId AND m.value_type = 'league'
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		 ORDER BY league_key DESC
	END

    SET @start_date_time_UTC = DATEADD(HOUR, DATEDIFF(HOUR, GETDATE(), GETUTCDATE()), @start_date_time_EST)

	DECLARE @tabs TABLE (
		[order] INT,
		[round] VARCHAR(100),
		display VARCHAR(100),
		page_endpoint VARCHAR(100)
	)

	DECLARE @linescores TABLE (
		-- cup
		country_display VARCHAR(100),
		country_code VARCHAR(100),
		logo VARCHAR(100),
		-- solo
		player_name VARCHAR(100),
		period VARCHAR(100),
		status VARCHAR(100),
		rank INT,
		[order] INT,
		-- shared
		score VARCHAR(100),
		winner INT
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

	IF (@event_status = 'pre-event' OR @event_status IS NULL)
	BEGIN
		--SET @game_status = CONVERT(VARCHAR, CAST(@start_date_time_EST AS TIME), 100) + ' ET'
		SET @game_status = DATENAME(WEEKDAY, @start_date_time_EST) + ', ' + DATENAME(MONTH, @start_date_time_EST) + ' ' + CAST(DAY(@start_date_time_EST) AS VARCHAR)
	END
	ELSE
	BEGIN

		IF (@ribbon LIKE 'Davis Cup%' OR @ribbon LIKE 'Fed Cup%')
		BEGIN

			SET @game_status = 'In Progress'

			INSERT INTO @linescores (country_display, country_code, score)
			SELECT player_name, team_key, value
			  FROM @stats
			 WHERE [column] = 'score-total'

			UPDATE @linescores
			   SET logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/countries/flags/110/' + country_code + '.png'

			IF (@event_status = 'post-event')
			BEGIN
				SET @game_status = 'Final'

				DECLARE @high_score INT
				SELECT @high_score = MAX(score) FROM @linescores

				UPDATE @linescores
				   SET winner = FLOOR(score / @high_score)
			END

		END
		ELSE
		BEGIN

			IF (@event_status = 'post-event')
			BEGIN
				SET @game_status = 'Completed'
			END
			ELSE
			BEGIN
				SELECT @game_status = value
				  FROM @stats
			END

			INSERT INTO @linescores (player_name, period, score)
			SELECT player_name, [column], value
			  FROM @stats
			 WHERE [column] IN ('SET 1', 'SET 2', 'SET 3', 'SET 4', 'SET 5')

			UPDATE l
			   SET l.rank = r.value
			  FROM @linescores AS l
			 INNER JOIN @stats AS r ON r.player_name = l.player_name
			 WHERE team_key = '' AND [column] = 'rank'

			UPDATE @linescores SET [order] = rank
			UPDATE @linescores SET [order] = 1000, rank = NULL WHERE rank = 0

			IF (@event_status = 'post-event')
			BEGIN
				UPDATE l
				   SET l.status = r.value
				  FROM @linescores AS l
				 INNER JOIN @stats AS r ON r.player_name = l.player_name
				 WHERE team_key = '' AND [column] = 'status'

				UPDATE @linescores SET winner = 1 WHERE status = 'win'
				UPDATE @linescores SET winner = 0 WHERE status = 'loss'

				SET @match_status = 'Final'
			END
			ELSE
			BEGIN
				SELECT TOP 1 @game_status = 'Finals ' + period
				  FROM @linescores
				 ORDER BY period DESC

				SELECT TOP 1 @match_status = period
				  FROM @linescores
				 ORDER BY period DESC
			END

			UPDATE @linescores
			   SET period = REPLACE(period, 'SET ', '')
		END
	END


	IF (@ribbon LIKE 'Davis Cup%' OR @ribbon LIKE 'Fed Cup%')
	BEGIN

		SELECT
			(
				SELECT @event_status AS event_status, @tv_coverage AS tv_coverage, @start_date_time_EST AS start_date_time_EST,
					   @start_date_time_UTC AS start_date_time_UTC, @ribbon AS ribbon, @sub_ribbon AS sub_ribbon,
					   @game_status AS game_status, @detail_endpoint AS detail_endpoint
				   FOR XML RAW('brief'), TYPE
			),
			(
				SELECT winner, score, logo, country_display AS country
				  FROM @linescores
				   FOR XML RAW('linescore'), TYPE
				)
		   FOR XML PATH(''), ROOT('root')	

	END
	ELSE
	BEGIN

		-- Do not leave game_status as null
		IF (@game_status IS NULL)
		BEGIN
		   SET @game_status = UPPER(LEFT(@event_status, 1)) + LOWER(RIGHT(@event_status, LEN(@event_status) - 1)) 
		END

		;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
		SELECT
			(
				SELECT @event_status AS event_status, @tv_coverage AS tv_coverage, @start_date_time_EST AS start_date_time_EST,
					   @start_date_time_UTC AS start_date_time_UTC, @ribbon AS ribbon, @sub_ribbon AS sub_ribbon,
					   @game_status AS game_status, @detail_endpoint AS detail_endpoint, 'tennis' AS league_name,
						(
							SELECT @match_status AS match_status,
								(
									SELECT winner, rank,
										(
											SELECT 'true' AS 'json:Array',
													LEFT(player_name, 1) + '. ' + RIGHT(player_name, LEN(player_name) - CHARINDEX(' ', player_name)) AS name
											  FROM @linescores AS player
											 WHERE player.player_name = team.player_name
											 GROUP BY player_name
											   FOR XML RAW('player'), TYPE
										),
										(
											SELECT score AS sub_score
											  FROM @linescores AS score
											 WHERE score.player_name = team.player_name
											 ORDER BY period ASC
											   FOR XML PATH(''), TYPE
										)
									  FROM @linescores AS team
									 GROUP BY player_name, winner, rank, [order]
									 ORDER BY [order] ASC
									   FOR XML RAW('team'), TYPE		
								),
								(
									SELECT period AS periods
									  FROM @linescores
									 GROUP BY period
									 ORDER BY period ASC
									   FOR XML PATH(''), TYPE
								)
							   FOR XML RAW('linescore'), TYPE
							)
				   FOR XML RAW('brief'), TYPE
			)
		   FOR XML PATH(''), ROOT('root')

	END

        
    SET NOCOUNT OFF;
END

GO
