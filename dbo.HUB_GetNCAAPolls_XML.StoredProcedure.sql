USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNCAAPolls_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetNCAAPolls_XML]
	@sport VARCHAR(100),
	@poll VARCHAR(100),
	@year INT,
	@week INT
AS
--=============================================
-- Author:	  ikenticus
-- Create date: 08/06/2014
-- Description: get polls filters, clone of SMG_GetPolls, transformed for SportsHub
-- Update: 10/23/2014 - ikenticus: adding CFP Poll to filter, adjusting columns
--		   10/27/2014 - ikenticus: delete info for CFP Poll
--		   07/01/2015 - ikenticus - adjusting to STATS migration and SMG_Polls* conversion
--         07/10/2015 - John Lin - STATS team records
--		   09/28/2015 - ikenticus - update team records if empty
-- =============================================
BEGIN

	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


-- Sports
	DECLARE @ncaa_sports TABLE (
	    id VARCHAR(100),
	    display VARCHAR(100),
		league_name VARCHAR(100),
		[order] INT
	)
	INSERT INTO @ncaa_sports ([order], id, display, league_name)
	VALUES
		(1, 'football',			'Football',				'ncaaf'),
		(2, 'basketball-men',	'Men''s Basketball',	'ncaab'),
		(3, 'basketball-women',	'Women''s Basketball',	'ncaaw'),
		(4, 'baseball',			'Baseball',				'cws')

	-- Determine league info from sport
	DECLARE @league_name VARCHAR(100)

	SELECT @league_name = league_name
	  FROM @ncaa_sports
	 WHERE id = @sport

	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@league_name)


--- Fixtures
	DECLARE @poll_order TABLE (
		id VARCHAR(100),
		display VARCHAR(100),
		fixture_key VARCHAR(100),
		[order] INT
	)
	INSERT INTO @poll_order ([order], id, fixture_key, display)
	VALUES
		(1, 'coaches-poll',	'smg-usat',		'Coaches Poll'),
		(2, 'fan-poll',		'smg-usatfan',	'Fan Poll'),
		(3, 'cfp-poll',		'poll-cfp',		'College Football Playoff Ranking'),
		(4, 'ap-poll',		'poll-ap',		'AP Poll'),
		(5, 'bcs-poll',		'ranking-bcs',	'Historical BCS Poll')
		--(6, 'harris-poll',	'poll-harris',	'Harris Poll'),

	DECLARE @fixture_key VARCHAR(100)

	SELECT @fixture_key = fixture_key
	  FROM @poll_order
	 WHERE id = @poll


	-- Obtain header
	DECLARE @header VARCHAR(MAX)

	SELECT @header = [value]
	FROM SportsEditDB.dbo.SMG_Data_Front_Attrs
	WHERE LOWER(league_name) = LOWER(@league_name)
	AND page_id = @fixture_key
	AND name = 'header'

	IF (@header IS NULL)
	BEGIN
		SELECT @header = credits
		FROM SportsEditDB.dbo.Feeds_Credits
		WHERE type = 'polls-' + @league_name + '-' + @fixture_key
	END


	-- Create the Polls table, appended with the additional BCS columns
	DECLARE @polls TABLE (
	    team_key          	VARCHAR(100),
	    team_class          VARCHAR(100),
	    team_name           VARCHAR(100),
	    team_first          VARCHAR(100),
	    team_last           VARCHAR(100),
		poll_name           VARCHAR(100),
		poll_date	        DATE,
	    ranking             VARCHAR(100),
	    ranking_previous	VARCHAR(100),
		ranking_diff		INT,
		ranking_mover		VARCHAR(100),
        first_place_votes	INT,
        points              VARCHAR(100),
		ranking_hilo		VARCHAR(100),
        record              VARCHAR(100),
		-- additional BCS columns below this line:
		harris_ranking		VARCHAR(100),
		harris_rating		VARCHAR(100),
		usat_ranking		VARCHAR(100),
		usat_rating			VARCHAR(100),
		computer_ranking	VARCHAR(100),
		computer_rating		VARCHAR(100),
        rating              VARCHAR(100)		
	)


	-- Insert the shared left-most columns
    DECLARE @columns TABLE (
		[column]	VARCHAR(100),
        ribbon		VARCHAR(100),
        sub_ribbon	VARCHAR(100),
		display		VARCHAR(100),
		[order]		INT
    )
	INSERT INTO @columns ([column], display, sub_ribbon, [order])
	VALUES ('ranking', NULL, 'RANK', 1), ('team_name', NULL, 'TEAM', 2)


	-- Inject different middle columns for BCS versus all other Polls
	IF (@fixture_key = 'ranking-bcs')
	BEGIN

		INSERT INTO @columns
			([column], display, sub_ribbon, [order])
		VALUES
			('harris_ranking', NULL, 'HARRIS POLL', 3),
			('harris_rating', NULL, 'HARRIS POLL', 4),
			('usat_ranking', NULL, 'USA TODAY POLL', 5),
			('usat_rating', NULL, 'USA TODAY POLL', 6),
			('computer_ranking',  NULL, 'COMPUTER RANK', 7),
			('computer_rating', NULL, 'COMPUTER RANK', 8),
			('points', NULL, 'BCS AVERAGE', 9)

		INSERT INTO @polls (team_class, team_name, team_first, team_last, poll_name, poll_date, ranking, ranking_previous,
							 ranking_mover, first_place_votes, points, rating, ranking_diff, ranking_hilo, record)
		SELECT team_abbreviation, team_slug, team_first, team_last, poll_name, poll_date, ranking, ISNULL(p.ranking_previous, 'NR'),
			   ranking_mover, first_place_votes, points, rating, -1 * ranking_diff,
			   (CAST(p.ranking_hi AS VARCHAR(100)) + '/' + CAST(p.ranking_lo AS VARCHAR(100))),
			   (CAST(p.wins AS VARCHAR(100)) + '-' + CAST(p.losses AS VARCHAR(100))) + '-' + CAST(ISNULL(p.ties, 0) AS VARCHAR(100))
		  FROM SportsEditDB.dbo.SMG_Polls AS p
		 INNER JOIN SportsDB.dbo.SMG_Teams AS t ON t.league_key = @league_key
		   AND t.team_abbreviation = p.team_key AND t.season_key = p.season_key
		 WHERE p.league_key = @league_name AND p.season_key = @year AND p.week = @week
		   AND p.fixture_key IN (@fixture_key, 'poll-harris', 'smg-usat', 'smg-usatfan')
		   AND (publish_date_time IS NULL OR publish_date_time < GETDATE())

		UPDATE @polls
		   SET record = LEFT(record, LEN(record) - 2)
		 WHERE CHARINDEX('-0', record, LEN(record) - 2) > 0

		;WITH bcs_computer AS (
			SELECT
				points,
				team_name,
				RANK() OVER (
					PARTITION BY poll_name
					ORDER BY poll_name, rating DESC
					) AS computer_ranking,
				REPLACE(CAST(CAST(rating AS DECIMAL(5,4)) AS VARCHAR(100)), '0.', '.') AS computer_rating
			FROM @polls
			WHERE poll_name = 'BCS'
		) UPDATE p
		SET
			p.computer_rating	= REPLACE(CAST(CAST(b.computer_rating AS DECIMAL(5,4)) AS VARCHAR(100)), '0.', '.'),
			p.computer_ranking	= b.computer_ranking,
			p.points			= REPLACE(CAST(CAST(b.points AS DECIMAL(5,4)) AS VARCHAR(100)), '0.', '.')
		FROM @polls AS p
		INNER JOIN bcs_computer AS b
			ON p.team_name = b.team_name
			AND p.poll_name = 'BCS'

		;WITH polls_other AS (
			SELECT team_name, ranking, rating, poll_name
			FROM @polls
			WHERE poll_name != 'BCS'
		) UPDATE p
		SET
			p.usat_rating		= REPLACE(CAST(CAST(u.rating AS DECIMAL(5,4)) AS VARCHAR(100)), '0.', '.'),
			p.usat_ranking		= u.ranking,
			p.harris_rating 	= REPLACE(CAST(CAST(h.rating AS DECIMAL(5,4)) AS VARCHAR(100)), '0.', '.'),
			p.harris_ranking 	= h.ranking
		FROM @polls AS p
		LEFT OUTER JOIN polls_other AS h
			ON p.team_name = h.team_name
			AND h.poll_name = 'Harris'
		LEFT OUTER JOIN polls_other AS u
			ON p.team_name = u.team_name
			AND u.poll_name = 'Coaches Poll'
		WHERE p.poll_name = 'BCS'

		DELETE FROM @polls
		WHERE poll_name != 'BCS'

		UPDATE @polls SET usat_rating = '&nbsp;' WHERE usat_rating IS NULL
		UPDATE @polls SET usat_ranking = 'NR' WHERE usat_ranking IS NULL
		UPDATE @polls SET harris_rating = '&nbsp;' WHERE harris_rating IS NULL
		UPDATE @polls SET harris_ranking = 'NR' WHERE harris_ranking IS NULL
		
	END
	ELSE
	BEGIN

		INSERT INTO @columns
			([column], display, sub_ribbon, [order])
		VALUES
			('record', NULL, 'RECORD', 3),
			('points', NULL, 'POINTS', 4),
			('first_place_votes', NULL, 'FIRST PLACE VOTES', 5)

		IF (@fixture_key = 'smg-usatfan')
		BEGIN
			INSERT INTO @polls (team_key, team_class, team_name, team_first, team_last, poll_name, poll_date, ranking, ranking_previous,
								 ranking_mover, first_place_votes, points, ranking_diff, ranking_hilo, record)
			SELECT t.team_key, team_abbreviation, team_slug, team_first, team_last, poll_name, poll_date, ranking, ISNULL(p.ranking_previous, 'NR'),
				   ranking_mover, first_place_votes, points, -1 * ranking_diff,
				   (CAST(p.ranking_hi AS VARCHAR(100)) + '/' + CAST(p.ranking_lo AS VARCHAR(100))),
				   (CAST(p.wins AS VARCHAR(100)) + '-' + CAST(p.losses AS VARCHAR(100))) + '-' + CAST(ISNULL(p.ties, 0) AS VARCHAR(100))
			  FROM SportsEditDB.dbo.SMG_Polls AS p
			 INNER JOIN SportsDB.dbo.SMG_Teams AS t ON t.league_key = @league_key
			   AND t.team_abbreviation = p.team_key AND t.season_key = p.season_key
			 WHERE p.league_key = @league_name AND p.season_key = @year AND p.week = @week AND p.fixture_key = @fixture_key
		END
		ELSE
		BEGIN
			INSERT INTO @polls (team_key, team_class, team_name, team_first, team_last, poll_name, poll_date, ranking, ranking_previous,
								 ranking_mover, first_place_votes, points, ranking_diff, ranking_hilo, record)
			SELECT t.team_key, team_abbreviation, team_slug, team_first, team_last, poll_name, poll_date, ranking, ISNULL(p.ranking_previous, 'NR'),
				   ranking_mover, first_place_votes, points, -1 * ranking_diff,
				   (CAST(p.ranking_hi AS VARCHAR(100)) + '/' + CAST(p.ranking_lo AS VARCHAR(100))),
				   (CAST(p.wins AS VARCHAR(100)) + '-' + CAST(p.losses AS VARCHAR(100))) + '-' + CAST(ISNULL(p.ties, 0) AS VARCHAR(100))
			  FROM SportsEditDB.dbo.SMG_Polls AS p
			 INNER JOIN SportsDB.dbo.SMG_Teams AS t ON t.league_key = @league_key
			   AND t.team_abbreviation = p.team_key AND t.season_key = p.season_key
			 WHERE p.league_key = @league_name AND p.season_key = @year AND p.week = @week AND p.fixture_key = @fixture_key
			   AND (publish_date_time IS NULL OR publish_date_time < GETDATE())
		END

		-- Remove ties?
		UPDATE @polls
		   SET record = LEFT(record, LEN(record) - 2)
		 WHERE CHARINDEX('-0', record, LEN(record) - 2) > 0

	END

	-- Update record if empty
	IF NOT EXISTS (SELECT 1 FROM @polls WHERE record <> '0-0')
	BEGIN
		UPDATE @polls
		   SET record = SportsDB.dbo.SMG_fn_Team_Records(@league_name, @year, team_key, poll_date)
	END

	-- Build the additional info table
	DECLARE @info TABLE (
		dropped_out			VARCHAR(MAX),
		votes_other			VARCHAR(MAX),
		voters				VARCHAR(MAX),
		notes				VARCHAR(MAX),
		polls_hilo			VARCHAR(MAX)
	)
	INSERT INTO @info (dropped_out, votes_other, voters, notes)
	SELECT dropped_out, votes_other, voters, notes
	  FROM SportsEditDB.dbo.SMG_Polls_Info
	 WHERE fixture_key = @fixture_key AND league_key = @league_name AND poll_date = (SELECT TOP 1 poll_date FROM @polls)

	UPDATE @info SET polls_hilo = (SELECT credits FROM SportsEditDB.dbo.Feeds_Credits WHERE type = 'polls-hilo')


	DECLARE @titles TABLE (
		[title]		VARCHAR(100),
		ribbon		VARCHAR(100),
		display		VARCHAR(100),
		[order]		INT
	)
	INSERT INTO @titles ([title], display, [order])
	VALUES
		('dropped_out', 'Schools Dropped Out', 1),
		('votes_other', 'Others Receiving Votes', 2),
		('polls_hilo', '', 3),
		('voters', 'List of Voters', 4),
		('notes', 'Misc Notes', 5)


	-- Append the shared right-most columns
	INSERT INTO @columns
		([column], display, sub_ribbon, [order])
	VALUES
		('ranking_previous', NULL, 'PREVIOUS RANK', 11),
		('ranking_diff', NULL, 'CHANGE', 12),
		('ranking_hilo', NULL, 'HI/LOW*', 13)


	-- Removing columns for College Football Playoffs
	IF (@poll = 'cfp-poll')
	BEGIN
		DELETE FROM @columns
		 WHERE [column] IN ('points', 'first_place_votes', 'ranking_diff', 'ranking_hilo')

		DELETE FROM @info
		DELETE FROM @titles
	END

    UPDATE @polls
       SET record = dbo.SMG_fn_Team_Records(@league_name, @year, team_key, poll_date)
	 WHERE record IS NULL


	-- Check for sponsors
	DECLARE @sponsor VARCHAR(100)

	SELECT @sponsor = [value]
	FROM SportsEditDB.dbo.SMG_Data_Front_Attrs
	WHERE LOWER(league_name) = LOWER(@league_name)
	AND page_id = @fixture_key
	AND name = 'sponsor'

	IF (@sponsor IS NULL)
	BEGIN
		SET @sponsor = 'USA TODAY'
	END


	-- Build the reference node using poll_name
    DECLARE @reference TABLE (
        ribbon		VARCHAR(100),
        sub_ribbon	VARCHAR(100),
        ribbon_node	VARCHAR(100)
    )
	INSERT INTO @reference (ribbon_node, ribbon, sub_ribbon)
	SELECT TOP 1
		'poll' AS ribbon_node,
		(CASE
			WHEN @fixture_key = 'ranking-bcs' THEN 'BCS Ranking'
			WHEN @fixture_key = 'smg-usat' THEN @sponsor + ' Coaches Poll'
			WHEN @fixture_key = 'smg-usatfan' THEN @sponsor + ' Fan Poll'
			WHEN @fixture_key = 'poll-cfp' THEN poll_name + ' Ranking'
			ELSE poll_name + ' Poll' END
		) AS ribbon,
		'(Published On: ' + CAST(poll_date AS VARCHAR(100)) + ')' AS sub_ribbon
	FROM @polls


	DECLARE @end_date_time DATETIME
	IF (@fixture_key = 'smg-usatfan')
	BEGIN
		SELECT @end_date_time = publish_date_time
		  FROM SportsEditDB.dbo.SMG_Polls
		 WHERE league_key = @league_name AND fixture_key = @fixture_key AND season_key = @year AND week = @week
	END
		

	DECLARE @published_on DATE
	SELECT @published_on = poll_date
	  FROM @polls


	-- Separate the BCS output from all other Polls
	IF (@fixture_key = 'ranking-bcs')
	BEGIN

		;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
		SELECT
		(
			SELECT
				team_class, team_name,
				team_first, team_last,
				ranking, record, points,
				first_place_votes, ranking_previous,
				ranking_diff, ranking_hilo,
				computer_ranking, computer_rating,
				harris_ranking, harris_rating,
				usat_ranking, usat_rating
			FROM @polls
			ORDER BY CAST(ranking AS INT)
			FOR XML RAW('poll'), TYPE
		),
		(
			SELECT [column], ribbon, sub_ribbon, display, [order]
			FROM @columns
			ORDER BY [order]
			FOR XML RAW('poll_column'), TYPE
		),
		(
			SELECT ribbon, ribbon_node, sub_ribbon
			FROM @reference
			FOR XML RAW('reference'), TYPE
		),
		(
			SELECT
			(
				SELECT
					team_name,
					team_class,
					ranking,
					ranking_diff,
					ranking_hilo
				FROM @polls
				WHERE ranking_mover = 'RISE'
				FOR XML RAW('rise'), TYPE
			),
			(
				SELECT
					team_name,
					team_class,
					ranking,
					ranking_diff,
					ranking_hilo
				FROM @polls
				WHERE ranking_mover = 'FALL'
				FOR XML RAW('fall'), TYPE
			)
			FOR XML RAW('movers'), TYPE
		),
		(
			SELECT 'true' AS 'json:Array', [title], ribbon, display, [order]
			FROM @titles
			ORDER BY [order]
			FOR XML RAW('info_title'), TYPE
		),
		(
			SELECT 'true' AS 'json:Array', polls_hilo, dropped_out, votes_other, voters, notes
			FROM @info
			FOR XML RAW('info'), TYPE
		)
		FOR XML RAW('root'), TYPE

	END
	ELSE
	BEGIN

		;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
		SELECT @end_date_time AS end_date_time,
		(
			SELECT team_class, team_name, team_first, team_last, ranking, record, points,
				   first_place_votes, ranking_previous, ranking_diff, ranking_hilo
			  FROM @polls
			 ORDER BY CAST(ranking AS INT)
			   FOR XML RAW('poll'), TYPE
		),
		(
			SELECT [column], ribbon, sub_ribbon, display, [order]
			  FROM @columns
			 ORDER BY [order]
			   FOR XML RAW('poll_column'), TYPE
		),
		(
			SELECT ribbon, ribbon_node, sub_ribbon
			  FROM @reference
			   FOR XML RAW('reference'), TYPE
		),
		(
			SELECT @header AS credits
			   FOR XML RAW('header'), TYPE
		),
		(
			SELECT
			(
				SELECT (CASE WHEN LEN(team_first) > 20 THEN team_class ELSE team_first END) AS team_first,
					   team_last, team_name, team_class, ranking, ranking_diff, ranking_hilo
				  FROM @polls
				 WHERE ranking_mover = 'RISE'
				   FOR XML RAW('rise'), TYPE
			),
			(
				SELECT (CASE WHEN LEN(team_first) > 20 THEN team_class ELSE team_first END) AS team_first,
					   team_last, team_name, team_class, ranking, ranking_diff, ranking_hilo
				  FROM @polls
				 WHERE ranking_mover = 'FALL'
				   FOR XML RAW('fall'), TYPE
			)
			FOR XML RAW('movers'), TYPE
		),
		(
			SELECT 'true' AS 'json:Array', [title], ribbon, display, [order]
			  FROM @titles
			 ORDER BY [order]
			   FOR XML RAW('info_title'), TYPE
		),
		(
			SELECT 'true' AS 'json:Array', polls_hilo, dropped_out, votes_other, voters, notes
			  FROM @info
			   FOR XML RAW('info'), TYPE
		),
		(
			SELECT @published_on AS published_on, @league_name AS league_name
			   FOR XML RAW('video'), TYPE
		)
		FOR XML RAW('root'), TYPE

	END

END


GO
