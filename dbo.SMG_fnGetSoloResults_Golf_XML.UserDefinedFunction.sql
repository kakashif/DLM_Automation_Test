USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[SMG_fnGetSoloResults_Golf_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[SMG_fnGetSoloResults_Golf_XML] (	
    @seasonKey INT,
	@leagueId VARCHAR(100),
	@eventId INT
)
RETURNS XML
AS
-- =============================================
-- Author:      ikenticus
-- Create date: 09/09/2015
-- Description: migrate solo results for golf from sproc to function
-- Update:		10/08/2015 - ikenticus: adjusting SDI cup rounds to suppress unplayed rounds
-- =============================================
BEGIN
	DECLARE @results_xml XML

	-- get league_key/event_key
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueId)
	DECLARE @event_type VARCHAR(100) = 'stroke'
	DECLARE @event_name VARCHAR(100)
    DECLARE @event_key VARCHAR(100)
	DECLARE @purse VARCHAR(100)

	SELECT @event_key = event_key, @event_name = event_name, @purse = purse
	  FROM dbo.SMG_Solo_Events
	 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

	IF (@purse NOT IN ('$', '$000.00'))
	BEGIN
		SET @event_name = @purse + ' ' + @event_name
	END


	DECLARE @stats TABLE (
		team_key	VARCHAR(100),
		player_key	VARCHAR(100),
		player_name VARCHAR(100),
		[round]		VARCHAR(100),
		[column]	VARCHAR(100),
		value		VARCHAR(MAX)
	)

	INSERT INTO @stats (team_key, player_key, player_name, [round], [column], value)
	SELECT team_key, player_key, player_name, [round], [column], value
	  FROM dbo.SMG_Solo_Results
	 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key = @event_key


	DECLARE @columns TABLE (
		display VARCHAR(100),
		[column] VARCHAR(100)
	)

	DECLARE @results TABLE (
		player_key			VARCHAR(100),
		player_name			VARCHAR(100),
		points				INT,
		hole				INT,
		score				VARCHAR(100),
		score_last			VARCHAR(100),
		strokes				INT,
		position_event		VARCHAR(100),
		[round]				VARCHAR(100), 
		team_key			VARCHAR(100),
		country				VARCHAR(100),
		match_key			VARCHAR(100),
		match_status		VARCHAR(100),
		status				VARCHAR(100),
		money				VARCHAR(100),
		[rank]				INT
	)


	SELECT @event_type = value
	  FROM @stats
	 WHERE [column] = 'scoring-system'


	DECLARE @link_text VARCHAR(100)
	DECLARE @link_href VARCHAR(100)

	SET @link_text = 'VIEW FULL LEADERBOARD'

	SELECT TOP 1 @link_href =  link_href
	  FROM SportsEditDB.dbo.SMG_Sports_Nav_Menu
	 WHERE front_name = 'sports_golf' AND menu_name = 'Leaderboard'

	IF (@link_href NOT LIKE 'http://www.pgatour.com/%')
	BEGIN
		SET @link_href = 'http://www.pgatour.com/leaderboard.html/?cid=USAT_fullLB'
	END


	IF (@event_type IN ('stroke', 'stableford', 'stroke-play', 'modified-stableford'))
	BEGIN

		INSERT INTO @columns (display, [column])
		VALUES
			('RANK', 'position_event'), ('PLAYER', 'player_name'), ('TODAY', 'score_last'), ('THRU', 'hole'), ('TO PAR', 'score')

		INSERT INTO @columns (display, [column])
		SELECT [round], 'r'+[round]
		  FROM @stats
		 WHERE [round] <> '' AND [round] < 5
		 GROUP BY [round]
		 ORDER BY [round]

		INSERT INTO @columns (display, [column])
		VALUES ('TOTAL', 'strokes')--, ('WINNINGS', 'money')

		DECLARE @pga_result TABLE
		(
			player_key VARCHAR(100),
			player_name VARCHAR(100),
			[rank] VARCHAR(100),
			[position-event] VARCHAR(100),
			[score] VARCHAR(100),
			[strokes] VARCHAR(100),
			[money] VARCHAR(100)
		)

		INSERT INTO @pga_result (player_key, player_name, [rank], [position-event], [score], [strokes], [money])
		SELECT p.player_key, p.player_name, [rank], [position-event], [score], [strokes], [money]
		  FROM (SELECT player_key, player_name, [column], value FROM @stats WHERE [round] = '') AS s
		 PIVOT (MAX(s.value) FOR s.[column] IN ([rank], [position-event], [score], [strokes], [money])) AS p

		DELETE FROM @pga_result WHERE [rank] IN ('MC', 'WD', 'DQ')

		DECLARE @round_last INT

		SELECT @round_last = MAX([round])
		  FROM @stats
		 WHERE [round] <> '' AND [round] < 5

		IF (@leagueId = 'pga-tour')
		BEGIN
			DELETE @pga_result
			 WHERE CAST([rank] AS INT) > 5
		END

		DELETE @pga_result
		 WHERE [rank] = 0

		IF (NOT EXISTS(SELECT 1 FROM @pga_result))
		BEGIN
			-- Team Stroke Play (i.e. Franklin Templeton Shootout)
			DELETE @columns
			 WHERE [column] IN ('score_last', 'hole', 'score')

			UPDATE @columns
			   SET display = 'TEAM'
			 WHERE [column] = 'player_name'

			UPDATE @columns
			   SET display = 'SCORE', [column] = 'score'
			 WHERE [column] = 'strokes'

			SELECT @results_xml = (
				SELECT @event_name AS ribbon, 'leaderboard' AS pagetype, @event_type AS event_type,
				(
					SELECT
					(
						SELECT display, [column]
						  FROM @columns
						   FOR XML RAW('column'), TYPE
					),
					(
						SELECT total.player_name, total.score, total.position_event, period.[r1], period.[r2], period.[r3], period.[r4]
						  FROM	(
									SELECT team_key, player_name, [rank] AS position_event, [score-total] AS score
									  FROM	(
												SELECT team_key, player_name, [round], [column], value
												  FROM @stats
												 WHERE [column] IN ('rank', 'score-total') AND [round] = @round_last
											) AS s
									 PIVOT (MAX(s.value) FOR s.[column] IN ([rank], [score-total])) AS p
								) AS total
						 INNER JOIN (
									SELECT team_key, [r1], [r2], [r3], [r4]
									  FROM (
											SELECT team_key, 'r'+[round] AS [round], MAX([score]) AS score
											  FROM (SELECT team_key, [round], [column], value FROM @stats WHERE ([round] <> '' AND [round] IS NOT NULL)) AS s
											 PIVOT (MAX(s.value) FOR s.[column] IN ([score])) AS p
											 GROUP BY team_key, [round]
											) AS rs
									 PIVOT (MAX(rs.[score]) FOR rs.[round] IN ([r1], [r2], [r3], [r4])) AS rp
								) AS period ON period.team_key = total.team_key
						 ORDER BY CAST(REPLACE(total.position_event, 'T', '') AS INT) ASC, CAST(total.score AS INT) ASC
						   FOR XML RAW('row'), TYPE
					)
					FOR XML RAW('table'), TYPE
				),
				(
					SELECT '_blank' AS link_target, @link_text AS link_text, @link_href AS link_href
					   FOR XML RAW('link'), TYPE
				)
				FOR XML PATH(''), ROOT('root')
			)

		END
		ELSE
		BEGIN

			IF NOT EXISTS (SELECT 1 FROM @pga_result WHERE score <> strokes)
			BEGIN
				-- Modified Stableford only displays points so scores/strokes are the same value
				DELETE @columns
				 WHERE [column] = 'score'
			END

			DECLARE @playoff_columns TABLE (
				display VARCHAR(100),
				[column] VARCHAR(100)
			)

			INSERT INTO @playoff_columns ([column])
			VALUES
				('player_name'), ('title')

			INSERT INTO @playoff_columns ([column])
			SELECT 'h'+team_key
			  FROM @stats
			 WHERE [round] = '5' AND team_key <> 'round-info'
			 GROUP BY team_key
			 ORDER BY CAST(team_key AS INT)

			INSERT INTO @playoff_columns ([column])
			VALUES ('score_total')

			DECLARE @playoff_stats TABLE (
				[round] VARCHAR(100),
				player_key VARCHAR(100),
				player_name VARCHAR(100),
				[column] VARCHAR(100),
				value VARCHAR(100)
			)

			INSERT INTO @playoff_stats ([round], player_key, player_name, [column], value)
			SELECT team_key, player_key, player_name, [column], value
			  FROM @stats
			 WHERE [round] = '5' AND team_key <> 'round-info'

			DECLARE @playoff_max INT

			SELECT @playoff_max = MAX([round])
			  FROM @playoff_stats

			DECLARE @playoff_result TABLE (
				player_key VARCHAR(100),
				player_name VARCHAR(100),
				position_event VARCHAR(100),
				score_total VARCHAR(100)
			)

			INSERT INTO @playoff_result (player_key, player_name, position_event, score_total)
			SELECT p.player_key, p.player_name, [position-event], [score-total]
			  FROM (SELECT player_key, player_name, [column], value FROM @playoff_stats WHERE [round] = @playoff_max) AS s
			 PIVOT (MAX(s.value) FOR s.[column] IN ([position-event], [score-total])) AS p

			IF EXISTS (SELECT 1 FROM @playoff_result)
			BEGIN
				UPDATE @playoff_result
				   SET score_total = 'E'
				 WHERE score_total = '0'

			END
			ELSE
			BEGIN
				DELETE @playoff_columns
			END

			SELECT @results_xml = (
				SELECT @event_name AS ribbon, 'leaderboard' AS pagetype, @event_type AS event_type,
				(
					SELECT
						(
							SELECT [column]
							  FROM @playoff_columns
							   FOR XML RAW('column'), TYPE
						),
						(
							SELECT '1' AS header, 'PLAYOFF HOLE' AS title,
								   [h1], [h2], [h3], [h4], [h5], [h6], [h7], [h8]
							  FROM (
									SELECT 'h'+[round] AS [round], [round] AS hole
									  FROM @playoff_stats
									 GROUP BY [round]
								) AS rs
							 PIVOT (MAX(rs.[hole]) FOR rs.[round] IN ([h1], [h2], [h3], [h4], [h5], [h6], [h7], [h8])) AS rp
							   FOR XML RAW('row'), TYPE
						),
						(
							SELECT '1' AS header, 'COURSE HOLE' AS title,
								   [h1], [h2], [h3], [h4], [h5], [h6], [h7], [h8]
							  FROM (
									SELECT 'h'+[round] AS [round], [course-hole]
									  FROM (SELECT [round], [column], value
											  FROM @playoff_stats
											 GROUP BY [round], [column], value) AS s
									 PIVOT (MAX(s.value) FOR s.[column] IN ([course-hole])) AS p
								) AS rs
							 PIVOT (MAX(rs.[course-hole]) FOR rs.[round] IN ([h1], [h2], [h3], [h4], [h5], [h6], [h7], [h8])) AS rp
							   FOR XML RAW('row'), TYPE
						),
						(
							SELECT '1' AS header, 'PLAYER' AS player_name, 'PAR' AS title, 'TOTAL' AS score_total,
								   [h1], [h2], [h3], [h4], [h5], [h6], [h7], [h8]
							  FROM (
									SELECT 'h'+[round] AS [round], [par]
									  FROM (SELECT [round], [column], value
											  FROM @playoff_stats
											 GROUP BY [round], [column], value) AS s
									 PIVOT (MAX(s.value) FOR s.[column] IN ([par])) AS p
								) AS rs
							 PIVOT (MAX(rs.[par]) FOR rs.[round] IN ([h1], [h2], [h3], [h4], [h5], [h6], [h7], [h8])) AS rp
							   FOR XML RAW('row'), TYPE
						),
						(
							SELECT total.player_key, total.player_name, total.score_total,
								   period.[h1], period.[h2], period.[h3], period.[h4],
								   period.[h5], period.[h6], period.[h7], period.[h8]
							  FROM @playoff_result AS total
							 INNER JOIN (
									SELECT player_key, player_name, [h1], [h2], [h3], [h4], [h5], [h6], [h7], [h8]
									  FROM (
											SELECT player_key, player_name, 'h'+[round] AS [round], ISNULL([strokes], '--') AS [strokes]
											  FROM (SELECT player_key, player_name, [round], [column], value
													  FROM @playoff_stats) AS s
											 PIVOT (MAX(s.value) FOR s.[column] IN ([strokes])) AS p
										) AS rs
									 PIVOT (MAX(rs.[strokes]) FOR rs.[round] IN ([h1], [h2], [h3], [h4], [h5], [h6], [h7], [h8])) AS rp
								) AS period ON total.player_key = period.player_key
							 ORDER BY position_event ASC
							   FOR XML RAW('row'), TYPE
						)
					   FOR XML RAW('playoff'), TYPE
				),
				(
					SELECT
					(
						SELECT display, [column]
						  FROM @columns
						   FOR XML RAW('column'), TYPE
					),
					(
						SELECT total.player_key, total.player_name,
							   total.[rank], total.[position-event] AS position_event,
							   total.[score], total.[strokes], total.[money],
							   period.[r1], period.[r2], period.[r3], period.[r4],
							   latest.[hole], ISNULL(NULLIF(latest.[score_last], '0'), 'E') AS score_last
						  FROM @pga_result AS total
						 INNER JOIN (
								SELECT player_key, player_name, [r1], [r2], [r3], [r4]
								  FROM (
										SELECT player_key, player_name, 'r'+[round] AS [round], [strokes]
										  FROM (SELECT player_key, player_name, [round], [column], value
												  FROM @stats
												 WHERE ([round] <> '' AND [round] IS NOT NULL AND [round] < 5)) AS s
										 PIVOT (MAX(s.value) FOR s.[column] IN ([strokes])) AS p
									) AS rs
								 PIVOT (MAX(rs.[strokes]) FOR rs.[round] IN ([r1], [r2], [r3], [r4])) AS rp
							) AS period ON total.player_key = period.player_key
						 INNER JOIN (
								SELECT p.player_key, p.player_name, [score] AS [score_last],
									   REPLACE(REPLACE(UPPER([hole]), 'inished', ''), '18', 'F') AS [hole]
								  FROM (SELECT player_key, player_name, [column], value
										  FROM @stats
										 WHERE [round] = @round_last) AS s
								 PIVOT (MAX(s.value) FOR s.[column] IN ([hole], [score])) AS p
							) AS latest ON total.player_key = latest.player_key
						 ORDER BY CAST(total.[rank] AS INT), CAST(total.[score] AS INT)
						   FOR XML RAW('row'), TYPE
					)
					FOR XML RAW('table'), TYPE
				),
				(
					SELECT '_blank' AS link_target, @link_text AS link_text, @link_href AS link_href
					   FOR XML RAW('link'), TYPE
				)
				FOR XML PATH(''), ROOT('root')
			)

		END

	END
	ELSE
	BEGIN
		-- Global country order
		DECLARE @country_order TABLE (
			name VARCHAR(100),
			[order] INT
		)
		INSERT INTO @country_order ([order], name)
		VALUES (1, 'USA'), (2, 'GBI'), (3, 'EUR'), (4, 'INT')

		-- Build the Golf Match Play results
		INSERT INTO @results (player_key, player_name, team_key, [round], score, hole, status, match_key, match_status, rank)
		SELECT p.player_key, p.player_name, team_key, [round], [score], [hole], [status], [match-event-key], [match-event-status], [rank]
		  FROM (SELECT player_key, player_name, team_key, [round], [column], value FROM @stats WHERE ([round] <> '' AND [round] IS NOT NULL)) AS s
		 PIVOT (MAX(s.value) FOR s.[column] IN ([score], [hole], [status], [match-event-key], [match-event-status], [rank])) AS p
		 ORDER BY [match-event-key]

		DELETE @results
		 WHERE score IS NULL

		-- Remove the conflicting scores if status is undecided
		UPDATE @results SET score = '--' WHERE status = 'undecided'

		-- Update the team country
		UPDATE r
		   SET r.country = s.value
		  FROM @results AS r
		 INNER JOIN @stats AS s ON s.player_key = r.player_key AND s.[column] = 'country' AND (s.[round] = '' OR s.[round] IS NULL)

		-- Build round info table
		DECLARE @rounds TABLE (
			[round]		VARCHAR(100),
			ribbon		VARCHAR(MAX),
			highlights	VARCHAR(MAX)
		)

		INSERT INTO @rounds ([round], ribbon, highlights)
		SELECT [round], @event_name + ': ' + [round-name] AS ribbon, [highlights]
		  FROM (SELECT [round], [column], value FROM @stats WHERE player_name = 'round-info') AS s
		 PIVOT (MAX(s.value) FOR s.[column] IN ([round-name], [highlights])) AS p

		-- Set the ribbon to round number if empty
		UPDATE @rounds
		   SET ribbon = @event_name + ': Round ' + CAST([round] AS VARCHAR(10))
		 WHERE ribbon IS NULL

		IF EXISTS (SELECT 1 FROM @stats WHERE [column] = 'round-type' AND value <> 'singles')
		BEGIN
			UPDATE r
			   SET ribbon = ribbon + ' ' + UPPER(LEFT(value, 1)) + RIGHT(value, LEN(value) - 1)
			  FROM @rounds AS r
			 INNER JOIN @stats AS s ON s.[round] = r.[round]
			 WHERE s.[column] = 'round-type'
		END

		-- Determine the opposing countries for this event
		DECLARE @countries TABLE (
			name VARCHAR(100),
			[order] INT
		)

		INSERT INTO @countries (name, [order])
		SELECT country, [order]
		  FROM @results AS r
		 INNER JOIN @country_order AS c ON c.name = r.country
		 GROUP BY country, [order]
		 ORDER BY [order] DESC

		IF (@event_type NOT IN ('cup', 'ryder-cup', 'presidents-cup'))
		BEGIN

			-- Build the columns based on the opposing countries
			INSERT INTO @columns (display, [column])
			VALUES
				('PLAYER', 'rank.0.player'),
				('SCORE', 'score'), --('HOLE', 'hole'),
				('PLAYER', 'rank.1.player')

			SELECT @results_xml = (
				SELECT 'leaderboard' AS pagetype, @event_type AS event_type,
				(
					SELECT [round], ribbon, highlights,
						(
							SELECT [match_key], [hole], [score],
								(
									SELECT
										(
											SELECT player_key, player_name, status
											  FROM @results AS r_player
											 WHERE r_round.[round] = r_player.[round] AND r_match.[match_key] = r_player.[match_key] AND r_rank.[status] = r_player.[status]
											   FOR XML RAW('player'), TYPE
										)
									  FROM @results AS r_rank
									 WHERE r_round.[round] = r_rank.[round] AND r_match.[match_key] = r_rank.[match_key]
									 GROUP BY [match_key], [status]
									 ORDER BY [status]
									   FOR XML RAW('rank'), TYPE
								)
							  FROM @results AS r_match
							 WHERE r_match.[match_key] IS NOT NULL AND r_round.[round] = r_match.[round]
							   AND r_match.[score] <> ''
							 GROUP BY [match_key], [hole], [score]
							   FOR XML RAW('match'), TYPE
						)
					  FROM @rounds AS r_round
					 ORDER BY [round] DESC
					   FOR XML RAW('round'), TYPE
				),
				(
					SELECT display, [column]
					  FROM @columns
					   FOR XML RAW('column'), TYPE
				),
				(
					SELECT '_blank' AS link_target, @link_text AS link_text, @link_href AS link_href
					   FOR XML RAW('link'), TYPE
				)
				FOR XML RAW('root'), TYPE
			)

		END
		ELSE
		BEGIN

			UPDATE r
			   SET highlights = ''
			  FROM @rounds AS r
			 INNER JOIN @stats AS s ON s.round = r.round
			 WHERE s.[column] = 'score' AND s.value NOT IN ('', '0')
		
			DELETE @rounds
			 WHERE highlights IS NULL

			-- Build the columns based on the opposing countries
			INSERT INTO @columns (display, [column])
			VALUES
				((SELECT TOP 1 name FROM @countries ORDER BY [order] ASC), 'team.0.player'),
				('SCORE', 'score'), --('HOLE', 'hole'),
				((SELECT TOP 1 name FROM @countries ORDER BY [order] DESC), 'team.1.player')

			SELECT @results_xml = (
				SELECT 'leaderboard' AS pagetype,
				(
					SELECT [round], ribbon, highlights,
						(
							SELECT [match_key], [hole], [score],
								(
									SELECT [team_key], [country],
										(
											SELECT player_key, player_name, status
											  FROM @results AS r_player
											 WHERE r_round.[round] = r_player.[round] AND r_match.[match_key] = r_player.[match_key] AND r_team.[team_key] = r_player.[team_key]
											   FOR XML RAW('player'), TYPE
										)
									  FROM @results AS r_team
									 INNER JOIN @country_order AS c ON c.name = r_team.country
									 WHERE r_round.[round] = r_team.[round] AND r_match.[match_key] = r_team.[match_key]
									 GROUP BY [team_key], [country], c.[order]
									 ORDER BY c.[order]
									   FOR XML RAW('team'), TYPE
								)
							  FROM @results AS r_match
							 WHERE r_match.[match_key] IS NOT NULL AND r_round.[round] = r_match.[round] AND r_match.[score] <> ''
							 GROUP BY [match_key], [hole], [score]
							   FOR XML RAW('match'), TYPE
						)
					  FROM @rounds AS r_round
					 ORDER BY [round] DESC
					   FOR XML RAW('round'), TYPE
				),
				(
					SELECT display, [column]
					  FROM @columns
					   FOR XML RAW('column'), TYPE
				)
				FOR XML RAW('root'), TYPE
			)

		END

	END

	
	RETURN @results_xml
END

GO
