USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetPolls_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetPolls_XML]
	@leagueName VARCHAR(100),
	@fixtureKey VARCHAR(100) = NULL,
	@seasonKey INT = NULL,
	@week INT = NULL
AS
--=============================================
-- Author:	  ikenticus
-- Create date: 09/19/2013
-- Description: get polls
-- Update:		09/23/2013 - ikenticus: adding additional info, fixing BCS
--				10/02/2013 - ikenticus: adding team_first and team_last, published sub_ribbon
--              10/18/2013 - John Lin - replace space with dash for team name
--				10/20/2013 - ikenticus - replace NULL ranking_previous with NR
--				10/22/2013 - ikenticus - forgot to include additional info for BCS
--				11/03/2013 - ikenticus - adding asterisk for Hi/Low, inserting disclaimer before voters
--				11/05/2013 - ikenticus - adding embargo based on publish_date_time
--				11/17/2013 - ikenticus - switched to leagueName, enhanced smg-usat header, all ribbons should be singular
--				11/22/2013 - ikenticus - prepended USA TODAY to Coaches Poll ribbon
--				02/11/2014 - ikenticus - changing USA TODAY to @sponsor
--				02/18/2014 - ikenticus - retrieve header from data_front_attrs with fallback to feeds_credit
--				02/24/2014 - ikenticus - adding NCAAB/CWS leagueName, adding ties to record
--				03/27/2014 - ikenticus - adding team first/last to biggest movers for video design
--				03/31/2014 - ikenticus - using team_abbreviation for biggest movers when team_first is too long
--				05/20/2014 - ikenticus - adding fixture_key for Fan Poll
--				07/08/2014 - ikenticus - adding end_date_time for Fan Poll
-- 				07/10/2014 - ikenticus - removing publish_date embargo from Fan Poll
--				07/01/2015 - ikenticus - adjusting to STATS migration and SMG_Polls* conversion
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


    -- Unsupported league
    IF (@leagueName NOT IN (
		SELECT league_key
		  FROM SportsEditDB.dbo.SMG_Polls
		 GROUP BY league_key
	))
    BEGIN
        RETURN
    END

	-- Determine leagueKey from leagueName
	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)

	-- Obtain header
	DECLARE @header VARCHAR(MAX)

	SELECT @header = [value]
	FROM SportsEditDB.dbo.SMG_Data_Front_Attrs
	WHERE LOWER(league_name) = LOWER(@leagueName)
	AND page_id = @fixtureKey
	AND name = 'header'

	IF (@header IS NULL)
	BEGIN
		SELECT @header = credits
		FROM SportsEditDB.dbo.Feeds_Credits
		WHERE type = 'polls-' + @leagueName + '-' + @fixtureKey
	END


	-- Create the Polls table, appended with the additional BCS columns
	DECLARE @polls TABLE (
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
	IF (@fixtureKey = 'ranking-bcs')
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
		 WHERE p.league_key = @leagueName AND p.season_key = @seasonKey AND p.week = @week
		   AND p.fixture_key IN (@fixtureKey, 'poll-harris', 'smg-usat', 'smg-usatfan')
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

		IF (@fixtureKey = 'smg-usatfan')
		BEGIN
			INSERT INTO @polls (team_class, team_name, team_first, team_last, poll_name, poll_date, ranking, ranking_previous,
								 ranking_mover, first_place_votes, points, ranking_diff, ranking_hilo, record)
			SELECT team_abbreviation, team_slug, team_first, team_last, poll_name, poll_date, ranking, ISNULL(p.ranking_previous, 'NR'),
				   ranking_mover, first_place_votes, points, -1 * ranking_diff,
				   (CAST(p.ranking_hi AS VARCHAR(100)) + '/' + CAST(p.ranking_lo AS VARCHAR(100))),
				   (CAST(p.wins AS VARCHAR(100)) + '-' + CAST(p.losses AS VARCHAR(100))) + '-' + CAST(ISNULL(p.ties, 0) AS VARCHAR(100))
			  FROM SportsEditDB.dbo.SMG_Polls AS p
			 INNER JOIN SportsDB.dbo.SMG_Teams AS t ON t.league_key = @league_key
			   AND t.team_abbreviation = p.team_key AND t.season_key = p.season_key
			 WHERE p.league_key = @leagueName AND p.season_key = @seasonKey AND p.week = @week AND p.fixture_key = @fixtureKey
		END
		ELSE
		BEGIN
			INSERT INTO @polls (team_class, team_name, team_first, team_last, poll_name, poll_date, ranking, ranking_previous,
								 ranking_mover, first_place_votes, points, ranking_diff, ranking_hilo, record)
			SELECT team_abbreviation, team_slug, team_first, team_last, poll_name, poll_date, ranking, ISNULL(p.ranking_previous, 'NR'),
				   ranking_mover, first_place_votes, points, -1 * ranking_diff,
				   (CAST(p.ranking_hi AS VARCHAR(100)) + '/' + CAST(p.ranking_lo AS VARCHAR(100))),
				   (CAST(p.wins AS VARCHAR(100)) + '-' + CAST(p.losses AS VARCHAR(100))) + '-' + CAST(ISNULL(p.ties, 0) AS VARCHAR(100))
			  FROM SportsEditDB.dbo.SMG_Polls AS p
			 INNER JOIN SportsDB.dbo.SMG_Teams AS t ON t.league_key = @league_key
			   AND t.team_abbreviation = p.team_key AND t.season_key = p.season_key
			 WHERE p.league_key = @leagueName AND p.season_key = @seasonKey AND p.week = @week AND p.fixture_key = @fixtureKey
			   AND (publish_date_time IS NULL OR publish_date_time < GETDATE())
		END

		UPDATE @polls
		SET record = LEFT(record, LEN(record) - 2)
		WHERE CHARINDEX('-0', record, LEN(record) - 2) > 0

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
	 WHERE league_key = @leagueName AND fixture_key = @fixtureKey AND poll_date = (SELECT TOP 1 poll_date FROM @polls)

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


	-- Check for sponsors
	DECLARE @sponsor VARCHAR(100)

	SELECT @sponsor = [value]
	FROM SportsEditDB.dbo.SMG_Data_Front_Attrs
	WHERE LOWER(league_name) = LOWER(@leagueName)
	AND page_id = @fixtureKey
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
			WHEN @fixtureKey = 'ranking-bcs' THEN 'BCS Ranking'
			WHEN @fixtureKey = 'smg-usat' THEN @sponsor + ' Coaches Poll'
			WHEN @fixtureKey = 'smg-usatfan' THEN @sponsor + ' Fan Poll'
			ELSE poll_name + ' Poll' END
		) AS ribbon,
		'(Published On: ' + CAST(poll_date AS VARCHAR(100)) + ')' AS sub_ribbon
	FROM @polls


	DECLARE @end_date_time DATETIME
	IF (@fixtureKey = 'smg-usatfan')
	BEGIN
		SELECT @end_date_time = publish_date_time
		  FROM SportsEditDB.dbo.SMG_Polls
		 WHERE league_key = @league_key AND fixture_key = @fixtureKey AND season_key = @seasonKey AND week = @week
	END
		

	-- Separate the BCS output from all other Polls
	IF (@fixtureKey = 'ranking-bcs')
	BEGIN

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
			SELECT [title], ribbon, display, [order]
			FROM @titles
			ORDER BY [order]
			FOR XML RAW('info_title'), TYPE
		),
		(
			SELECT polls_hilo, dropped_out, votes_other, voters, notes
			FROM @info
			FOR XML RAW('info'), TYPE
		)
		FOR XML RAW('root'), TYPE

	END
	ELSE
	BEGIN

		SELECT @end_date_time AS end_date_time,
		(
			SELECT
				team_class, team_name,
				team_first, team_last,
				ranking, record, points,
				first_place_votes, ranking_previous,
				ranking_diff, ranking_hilo
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
				SELECT
					(CASE WHEN LEN(team_first) > 20 THEN team_class ELSE team_first END) AS team_first,
					team_last,
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
					(CASE WHEN LEN(team_first) > 20 THEN team_class ELSE team_first END) AS team_first,
					team_last,
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
			SELECT [title], ribbon, display, [order]
			FROM @titles
			ORDER BY [order]
			FOR XML RAW('info_title'), TYPE
		),
		(
			SELECT polls_hilo, dropped_out, votes_other, voters, notes
			FROM @info
			FOR XML RAW('info'), TYPE
		)
		FOR XML RAW('root'), TYPE

	END

END


GO
