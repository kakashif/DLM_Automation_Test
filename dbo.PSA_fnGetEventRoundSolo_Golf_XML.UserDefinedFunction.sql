USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[PSA_fnGetEventRoundSolo_Golf_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[PSA_fnGetEventRoundSolo_Golf_XML] (	
	@leagueId VARCHAR(100),
    @seasonKey INT,
    @eventId INT,
	@round VARCHAR(100)
)
RETURNS XML
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 09/09/2015
-- Description: migrate event round solo for golf from sproc to function
-- Update:		10/08/2015 - ikenticus: fixing iOS hard-coding display bug for cups
--				10/22/2015 - ikenticus: using fallback score for Golf in first round total, display both score for ties
-- =============================================
BEGIN
	DECLARE @round_xml XML

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueId)
    DECLARE @event_key VARCHAR(100)
    DECLARE @event_type VARCHAR(100) = 'stroke'
    DECLARE @event_show VARCHAR(100) = 'leaderboard'
    DECLARE @event_status VARCHAR(100)

	SELECT TOP 1 @event_status = event_status, @event_key = event_key
	  FROM dbo.SMG_Solo_Events
	 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
	 ORDER BY date_time DESC

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key, @event_status = event_status, @event_key = event_key
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
		[value]		VARCHAR(MAX)
	)

	DECLARE @columns TABLE (
		display		VARCHAR(100),
		[column]	VARCHAR(100),
		[order]		INT
	)

	DECLARE @leaders TABLE (
		[order]			INT,
		team			VARCHAR(100),
		team_key		VARCHAR(100),
		player			VARCHAR(100),
		player_key		VARCHAR(100),
		player_name		VARCHAR(100),
		position_event	VARCHAR(100),
		logo			VARCHAR(100),
		hole			VARCHAR(100),
		score			VARCHAR(100),
		score_total		VARCHAR(100),
		strokes			VARCHAR(100),
		strokes_total	VARCHAR(100),
		total			VARCHAR(100),
		status			VARCHAR(100),
		priority		INT,
		tee_time		DATETIME
	)

	INSERT INTO @stats (team_key, player_key, player_name, [round], [column], value)
	SELECT team_key, player_key, player_name, [round], [column], value
	  FROM SportsDB.dbo.SMG_Solo_Results
	 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key = @event_key

	SELECT @event_type = value
	  FROM @stats
	 WHERE [column] = 'scoring-system'

	-- This endpoint should never have been called from pre-event state
	IF (@event_status <> 'pre-event')
	BEGIN

		IF EXISTS (SELECT 1 FROM @stats WHERE [round] = @round AND [column] = 'round-type' AND value = 'playoff')
		BEGIN
			SET @event_type = 'playoff'

			INSERT INTO @columns (display, [column], [order])
			VALUES ('POS', 'rank', 1), ('PLAYER', 'player', 2), ('HOLES', 'team_key', 3), ('TOTAL (PAR)', 'total', 4)
			--VALUES ('POS', 'rank', 1), ('PLAYER', 'player', 2), ('R', 'team_key', 3), ('TOTAL (PAR)', 'total', 4)
		END
		ELSE

		IF (@event_type IN ('stroke', 'stroke-play'))
		BEGIN
			INSERT INTO @columns (display, [column], [order])
			VALUES ('POS', 'rank', 1), ('PLAYER', 'player', 2), ('R', 'score', 3), ('THRU', 'hole', 4), ('TOTAL (PAR)', 'total', 5)
		END
		ELSE IF (@event_type IN ('stableford', 'modified-stableford'))
		BEGIN
			INSERT INTO @columns (display, [column], [order])
			VALUES ('POS', 'rank', 1), ('PLAYER', 'player', 2), ('R', 'score', 3), ('THRU', 'hole', 4), ('TOTAL', 'total', 5)
		END
		ELSE IF (@event_type IN ('match', 'match-play'))
		BEGIN
			INSERT INTO @columns (display, [column], [order])
			VALUES ('', 'player', 1), ('', 'score', 2)
		END
		ELSE
		BEGIN
			INSERT INTO @columns (display, [column], [order])
			VALUES ('', 'team', 1), ('', 'score', 2)
		END

		IF (@round IS NOT NULL)
		BEGIN
			UPDATE @columns
			   SET display = display + CAST(@round AS VARCHAR)
			 WHERE [column] = 'score'
		END

		IF (@event_status = 'post-event')
		BEGIN
			DELETE @columns WHERE display = 'THRU'
		END
        
		IF (@event_type = 'playoff')
		BEGIN
			
			DECLARE @max_round INT

			SELECT @max_round = MAX([team_key])
			  FROM @stats
			 WHERE [round] = @round AND team_key <> 'round-info'

            INSERT INTO @leaders (team_key, player_key, player_name, [hole], [score], [score_total], [strokes_total], [position_event], [priority])            
            SELECT team_key, player_key, player_name, [course-hole], [score], [score-total], [strokes-total], [position-event],
				   RANK() OVER (ORDER BY CAST(REPLACE([position-event], 'T', '') AS INT) ASC, CAST([score] AS INT) ASC, CAST([strokes-total] AS INT) DESC)
			  FROM (SELECT team_key, player_key, player_name, [column], value
					  FROM @stats
					 WHERE round = @round AND team_key <> 'round-info' AND team_key = @max_round) AS s
			 PIVOT (MAX(s.value) FOR s.[column] IN ([course-hole], [score], [score-total], [strokes-total], [position-event])) AS p

			UPDATE @leaders
			   SET total = strokes_total + ' (' + score_total + ')'

			/*
            INSERT INTO @leaders (team_key, player_key, player_name, [hole], [score], [strokes], [position_event], [priority])            
            SELECT team_key, player_key, player_name, [course-hole], [score], [strokes], [position-event],
				   RANK() OVER (ORDER BY CAST(team_key AS INT), CAST(REPLACE([position-event], 'T', '') AS INT) ASC, CAST([score] AS INT) ASC, CAST([strokes] AS INT) DESC)
			  FROM (SELECT team_key, player_key, player_name, [column], value
					  FROM @stats
					 WHERE round = @round AND team_key <> 'round-info') AS s
			 PIVOT (MAX(s.value) FOR s.[column] IN ([course-hole], [score], [strokes], [position-event])) AS p

			UPDATE @leaders
			   SET total = strokes + ' (' + score + ')'
			*/

			UPDATE @leaders
			   SET player = LEFT(player_name, 1) + '. ' + RIGHT(player_name, LEN(player_name) - CHARINDEX(' ', player_name))

			SELECT @round_xml = (
				SELECT
				(
					SELECT @event_type AS event_type,
					(
						SELECT display, [column]
						  FROM @columns
						 ORDER BY [order] ASC
						   FOR XML RAW('columns'), TYPE	
					),
					(
						SELECT position_event AS rank, player, team_key, strokes, total, hole, score, score_total, strokes_total
						  FROM @leaders
						 ORDER BY priority ASC
						   FOR XML RAW('rows'), TYPE
					)
					FOR XML RAW('round'), TYPE
				)
				FOR XML PATH(''), ROOT('root')
			)
		END
		ELSE

		IF (@event_type IN ('stroke', 'stableford', 'stroke-play', 'modified-stableford'))	-- Stroke Play
		BEGIN
            INSERT INTO @leaders (team_key, player_key, player_name, [hole], [score], [score_total], [strokes_total], [position_event], [status], [tee_time], [priority])            
            SELECT team_key, player_key, player_name, [hole], [score], [score-total], [strokes-total], [position-event],[status], [tee-time],
				   RANK() OVER (ORDER BY CAST(REPLACE(ISNULL(NULLIF([position-event], ''), '1000'), 'T', '') AS INT) ASC, CAST(hole AS INT) DESC, CAST([score] AS INT) ASC, CAST([strokes-total] AS INT) DESC)
			  FROM (SELECT team_key, player_key, player_name, [column], value FROM @stats WHERE round = @round) AS s
			 PIVOT (MAX(s.value) FOR s.[column] IN ([hole], [score], [score-total], [strokes-total], [position-event], [status], [tee-time])) AS p

			DELETE @leaders
			 WHERE ISNULL(status, 'cut') <> 'qualified'
				
			UPDATE @leaders
			   SET hole = 'F'
			 WHERE hole = '18'

			-- tee time
			UPDATE @leaders
			   SET hole = '-' --LOWER(RIGHT(CONVERT(DATETIME, tee_time, 110), 7)) + ' ET'
			 WHERE hole = ''

			UPDATE @leaders
			   SET score = '-'
			 WHERE score = ''

			UPDATE @leaders
			   SET strokes_total = ' '
			 WHERE strokes_total = '0'

			IF (@event_type IN ('stableford', 'modified-stableford'))
			BEGIN
				UPDATE @leaders
				   SET total = score_total

				UPDATE @columns
				   SET display = 'TOTAL'
				 WHERE [column] = 'total'
			END
			ELSE
			BEGIN
				UPDATE @leaders
				   SET score = 'E'
				 WHERE score = '0'

				UPDATE @leaders
				   SET score_total = 'E'
				 WHERE score_total = '0'

				UPDATE @leaders
				   SET total = strokes_total + ' (' + score_total + ')'

				UPDATE @leaders
				   SET total = strokes + ' (' + score + ')'
				 WHERE total IS NULL

				UPDATE @leaders
				   SET total = score
				 WHERE total IS NULL

				UPDATE @leaders
				   SET total = '-'
				 WHERE score_total = 'E' AND strokes_total = '-' AND hole = '-'
			END

			UPDATE @leaders
			   SET player = LEFT(player_name, 1) + '. ' + RIGHT(player_name, LEN(player_name) - CHARINDEX(' ', player_name))

			IF NOT EXISTS(SELECT 1 FROM @leaders WHERE ISNULL(hole, '') NOT IN ('F', ''))
			BEGIN
				DELETE @columns WHERE [column] = 'hole'
			END
            -- HACK BEGIN
	    	ELSE
	    	BEGIN
				IF (@event_status <> 'post-event')
				BEGIN
					DELETE @columns WHERE [column] = 'score'
				END
		    END
		    -- HACK END

			SELECT @round_xml = (
				SELECT
				(
					SELECT @event_type AS event_type,
					(
						SELECT display, [column]
						  FROM @columns
						 ORDER BY [order] ASC
						   FOR XML RAW('columns'), TYPE	
					),
					(
						SELECT position_event AS rank, player, logo, strokes, total, hole, score, score_total, strokes_total
						  FROM @leaders
						 ORDER BY priority ASC
						   FOR XML RAW('rows'), TYPE
					)
					FOR XML RAW('round'), TYPE
				)
				FOR XML PATH(''), ROOT('root')
			)
		END
		ELSE	-- Match Play
		BEGIN
			DECLARE @results TABLE (
				player				VARCHAR(100),
				player_key			VARCHAR(100),
				player_name			VARCHAR(100),
				hole				INT,
				score				VARCHAR(100),
				team_key			VARCHAR(100),
				team				VARCHAR(100),
				logo				VARCHAR(100),
				match_key			VARCHAR(100),
				match_status		VARCHAR(100),
				match_ribbon		VARCHAR(100),
				status				VARCHAR(100),
				winner				INT,
				tee_time			VARCHAR(100)
			)

			DECLARE @country_order TABLE (
				name VARCHAR(100),
				[order] INT
			)
			INSERT INTO @country_order ([order], name)
			VALUES (1, 'USA'), (2, 'GBI'), (3, 'EUR'), (4, 'INT')

			-- Build the Golf Match Play results
			INSERT INTO @results (player_key, player_name, team_key, score, hole, status, match_key, match_status, tee_time)
			SELECT p.player_key, p.player_name, team_key, [score], [hole], [status], [match-event-key], [match-event-status], [tee-time]
			FROM (SELECT player_key, player_name, team_key, [column], value FROM @stats WHERE [round] = @round) AS s
			PIVOT (MAX(s.value) FOR s.[column] IN ([score], [hole], [status], [match-event-key], [match-event-status], [tee-time])) AS p
			ORDER BY [match-event-key]

			-- Modify the halved based on match-event-status
			UPDATE @results
			   SET status = 'tie', score = '1/2'
			 WHERE LOWER(score) = 'halved' AND match_status = 'post-event'

			UPDATE @results
			   SET status = 'tie', score = '1/2'
			 WHERE LEFT(score, 1) = '0' AND match_status = 'post-event'

			UPDATE @results
			   SET status = 'tie', score = 'AS'
			 WHERE LOWER(score) = 'halved' AND match_status = 'mid-event'

			UPDATE @results
			   SET status = 'tie', score = LOWER(RIGHT(CONVERT(DATETIME, tee_time, 110), 7)) + ' ET'
			 WHERE match_status = 'pre-event'


			-- Remove the scores if loss or not leading
			UPDATE @results
			   SET score = NULL
			 WHERE status = 'loss' OR score = '0'

			-- Modify the match ribbon based on match-event-status
			UPDATE @results SET match_ribbon = 'Final' WHERE match_status = 'post-event'
			UPDATE @results SET match_ribbon = 'Upcoming' WHERE match_status = 'pre-event'
			UPDATE @results SET match_ribbon = 'Hole ' + CAST(hole AS VARCHAR) WHERE match_status = 'mid-event'

			--UPDATE @results SET winner = 1 WHERE status = 'win'
			--UPDATE @results SET winner = 0 WHERE status = 'loss'
			

			UPDATE r
			   SET r.team = s.[value]
			  FROM @results AS r
			 INNER JOIN @stats AS s ON s.team_key = r.team_key AND s.[column] = 'country'

			UPDATE @results
			   SET team_key = player_key
			 WHERE team_key = '' AND team IS NULL

			UPDATE @results
			   SET logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/countries/flags/110/' + team + '.png'


			/*
			-- remove score display from each pair of ties
			DECLARE @ties TABLE (
				match_key VARCHAR(100),
				team_key VARCHAR(100)
			)

			INSERT INTO @ties (match_key)
			SELECT match_key
			  FROM @results
			 WHERE match_key IS NOT NULL AND status = 'tie'
			 GROUP BY match_key

			UPDATE t
			   SET team_key = r.team_key
			  FROM @ties AS t
			 INNER JOIN @results AS r ON r.match_key = t.match_key

			UPDATE r
			   SET score = NULL
			  FROM @results AS r
			 INNER JOIN @ties AS t ON t.match_key = r.match_key AND t.team_key = r.team_key
			*/

			UPDATE @results
			   SET player = LEFT(player_name, 1) + '. ' + RIGHT(player_name, LEN(player_name) - CHARINDEX(' ', player_name))

			IF (@event_type IN ('match', 'match-play'))
			BEGIN
				SELECT @round_xml = (
					SELECT
					(
						SELECT @event_type AS event_type,
						(
							SELECT match_ribbon AS match_status, --match_key, match_status,
								(
									SELECT logo, score, winner, --status, team,
										(
											SELECT player --, player_key, status,
											  FROM @results AS player
											 WHERE match.[match_key] = player.match_key AND team.team_key = player.team_key
											   FOR XML PATH(''), TYPE
										)
									  FROM @results AS team
									 WHERE match.[match_key] = team.match_key
									 GROUP BY team, team_key, logo, score, winner
									 ORDER BY winner DESC
									   FOR XML RAW('team'), TYPE
								)
							  FROM @results AS match
							 WHERE match.match_key IS NOT NULL
							 GROUP BY match_key, match_ribbon
							   FOR XML RAW('match'), TYPE
						)
						FOR XML RAW('round'), TYPE
					)
					FOR XML PATH(''), ROOT('root')
				)
			END
			ELSE
			BEGIN
				SELECT @round_xml = (
					SELECT
					(
						SELECT @event_type AS event_type,
						(
							SELECT match_ribbon AS match_status, --match_key, match_status,
								(
									SELECT logo, score, winner, --status, team_key, team,
										(
											SELECT player --, player_key, status,
											  FROM @results AS player
											 WHERE match.[match_key] = player.match_key AND team.team_key = player.team_key
											   FOR XML PATH(''), TYPE
										)
									  FROM @results AS team
									 INNER JOIN @country_order AS c ON c.name = team.team
									 WHERE match.[match_key] = team.match_key
									 GROUP BY team_key, team, logo, score, winner, c.[order]
									 ORDER BY c.[order]
									   FOR XML RAW('team'), TYPE
								)
							  FROM @results AS match
							 WHERE match.match_key IS NOT NULL
							 GROUP BY match_key, match_ribbon
							   FOR XML RAW('match'), TYPE
						)
						FOR XML RAW('round'), TYPE
					)
					FOR XML PATH(''), ROOT('root')
				)
			END
		END
	END
	
	RETURN @round_xml
END

GO
