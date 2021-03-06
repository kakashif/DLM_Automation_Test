USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetBallots_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetBallots_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @week INT,
    @category VARCHAR(100)
AS
--=============================================
-- Author:		ikenticus
-- Create date: 11/22/2013
-- Description: get ballots for specified category
-- Update:		11/27/2013 - ikenticus - team_class unification
--				12/02/2013 - John Lin - change wording
--				12/03/2013 - ikenticus - adding movers
--				12/16/2013 - John Lin - add matrix
--				01/13/2014 - John Lin - add matrix credit
--				02/25/2014 - ikenticus - changing USA TODAY to @sponsor, data_front_attrs with fallback to feeds_credit
--				07/01/2015 - ikenticus - adjusting to STATS migration and SMG_Polls* conversion
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


	-- Determine leagueKey from leagueName
	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)

	-- Obtain header
	DECLARE @header VARCHAR(MAX)

	SELECT @header = [value]
	  FROM SportsEditDB.dbo.SMG_Data_Front_Attrs
	 WHERE LOWER(league_name) = LOWER(@leagueName) AND page_id = 'ballots-' + @category AND name = 'header'

	IF (@header IS NULL)
	BEGIN
		SELECT @header = credits
		  FROM SportsEditDB.dbo.Feeds_Credits
		 WHERE type = 'ballots-' + @leagueName + '-' + @category
	END


	DECLARE @columns TABLE
	(
		display VARCHAR(100),
		[column] VARCHAR(100)
	)
	DECLARE @schools TABLE
	(
		team_key		VARCHAR(100),
		team_abbr		VARCHAR(100),
		team_slug		VARCHAR(100),
		team_first	    VARCHAR(100),
		team_last	    VARCHAR(100),
		team_record		VARCHAR(100),
		team_class      VARCHAR(100),
		points			VARCHAR(100),
		ranking         INT
	)
	DECLARE @coaches TABLE
	(
		team_key		VARCHAR(100),
		team_slug		VARCHAR(100),
		team_first	    VARCHAR(100),
		team_last	    VARCHAR(100),
		player_key		VARCHAR(100),
		player_first	VARCHAR(100),
		player_last		VARCHAR(100),
		player_display	VARCHAR(100)
	)	
	DECLARE @poll_date DATETIME

    SELECT TOP 1 @poll_date = poll_date
      FROM SportsEditDB.dbo.SMG_Polls
     WHERE league_key = @leagueName AND season_key = @seasonKey AND [week] = @week AND fixture_key = 'smg-usat'

	IF (@category = 'coaches')
	BEGIN
		INSERT INTO @columns (display, [column])
		VALUES ('Coach', 'player_display'), ('Team', 'team_display')

		INSERT INTO @coaches (player_key)
		SELECT player_key
		  FROM SportsEditDB.dbo.SMG_Polls_Votes
		 WHERE league_key = @leagueName AND season_key = @seasonKey AND [week] = @week
		 GROUP BY player_key

		UPDATE c
		   SET c.team_key = st.team_key,
			   c.team_slug = st.team_slug,
			   c.team_first = st.team_first,
			   c.team_last = st.team_last,
			   c.player_first = sp.first_name,
			   c.player_last = sp.last_name,
			   c.player_display = sp.first_name + ' ' + sp.last_name
		  FROM @coaches c
		 INNER JOIN dbo.SMG_Players sp ON sp.player_key = c.player_key
		 INNER JOIN dbo.SMG_Rosters sr ON sr.player_key = c.player_key AND sr.league_key = @leagueName AND sr.season_key = @seasonKey
		 INNER JOIN dbo.SMG_Teams st ON st.team_abbreviation = sr.team_key AND st.league_key = @league_key AND st.season_key = @seasonKey


		-- Check for sponsors
		DECLARE @sponsor VARCHAR(100)

		SELECT @sponsor = [value]
		  FROM SportsEditDB.dbo.SMG_Data_Front_Attrs
		 WHERE LOWER(league_name) = LOWER(@leagueName) AND page_id = 'ballots' AND name = 'sponsor'

		IF (@sponsor IS NULL)
		BEGIN
			SET @sponsor = 'USA TODAY'
		END


		-- Build XML output
		SELECT
		(
			SELECT
			(
				SELECT team_key, team_slug, team_first, team_last, player_first, player_last, player_display, player_key AS player_slug
				FROM @coaches
			   ORDER BY player_last
				 FOR XML RAW('row'), TYPE
			)
			FOR XML RAW('table'), TYPE
		),
		(
			SELECT @header AS credits
			FOR XML RAW('header'), TYPE
		),
		(
			SELECT TOP 1 '(Published On: ' + CONVERT(CHAR(10), @poll_date, 126) + ')' AS sub_ribbon, @sponsor + ' Coaches Ballots' AS ribbon
			   FOR XML RAW('reference'), TYPE
		),
		(
			SELECT display, [column]
			  FROM @columns
			   FOR XML RAW('column'), TYPE
/*			   
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
*/
		)
		FOR XML PATH(''), ROOT('root')

	END
	ELSE IF (@category = 'schools')
	BEGIN
		INSERT INTO @columns (display, [column])
		VALUES ('Team', 'team_display'), ('Record', 'team_record'), ('Points', 'points')

		INSERT INTO @schools (team_abbr, points, team_record, ranking)
		SELECT team_key, points, (CAST(wins AS VARCHAR(100)) + '-' + CAST(losses AS VARCHAR(100))), ranking
		  FROM SportsEditDB.dbo.SMG_Polls
		 WHERE league_key = @leagueName AND season_key = @seasonKey AND [week] = @week AND fixture_key = 'smg-usat'

		UPDATE s
		   SET team_key = st.team_key, team_slug = st.team_slug, team_first = st.team_first, team_last = st.team_last, team_class = st.team_abbreviation
		  FROM @schools s
		 INNER JOIN dbo.SMG_Teams AS st ON st.league_key = @league_key AND st.team_abbreviation = s.team_abbr AND st.season_key = @seasonKey


		-- Build XML output
		SELECT
		(
			SELECT
			(
				SELECT team_key, team_slug, team_first, team_last, team_class, team_record, points, ranking
				  FROM @schools
			     ORDER BY CAST(points AS INT) DESC
				   FOR XML RAW('row'), TYPE
			)
			FOR XML RAW('table'), TYPE
		),
		(
			SELECT @header AS credits
			FOR XML RAW('header'), TYPE
		),
		(
			SELECT TOP 1 '(Published On: ' + CONVERT(CHAR(10), @poll_date, 126) + ')' AS sub_ribbon, 'USA Today Coaches Ballots' AS ribbon
			   FOR XML RAW('reference'), TYPE
		),
		(
			SELECT display, [column]
			  FROM @columns
			   FOR XML RAW('column'), TYPE
/*
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
*/			
		)
		FOR XML PATH(''), ROOT('root')
	END
	ELSE IF (@category = 'matrix')
	BEGIN
	    INSERT INTO @schools (team_abbr, ranking, points, team_record)
	    SELECT team_key, ranking, points, CAST(wins AS VARCHAR) + '-' + CAST(losses AS VARCHAR)
		  FROM SportsEditDB.dbo.SMG_Polls
		 WHERE league_key = @leagueName AND season_key = @seasonKey AND [week] = @week AND fixture_key = 'smg-usat'	        
	     
	    UPDATE s
	       SET s.team_class = st.team_abbreviation, s.team_slug = st.team_slug
	      FROM @schools s
	     INNER JOIN dbo.SMG_Teams st
	        ON st.team_abbreviation = s.team_abbr AND st.league_key = @league_key AND st.season_key = @seasonKey

	    INSERT INTO @coaches (player_key)
	    SELECT player_key
	      FROM SportsEditDB.dbo.SMG_Polls_Votes
	     WHERE league_key = @leagueName AND season_key = @seasonKey AND [week] = @week
	     GROUP BY player_key
	     
	    UPDATE c
	       SET c.player_first = sp.first_name, c.player_last = sp.last_name
	      FROM @coaches c
	     INNER JOIN dbo.SMG_Players sp
	        ON sp.player_key = c.player_key
	      
		SELECT
		(
            SELECT s.team_class, s.team_slug, s.points, s.team_record, s.ranking,
                   (
                   SELECT '.' + spv.player_key + '.' + CAST(spv.ranking AS VARCHAR) AS matrix_key
                     FROM SportsEditDB.dbo.SMG_Polls_Votes spv
                    INNER JOIN dbo.SMG_Players sp
                       ON sp.player_key = spv.player_key
                    WHERE spv.team_key = s.team_key AND spv.league_key = @league_key AND spv.season_key = @seasonKey AND spv.[week] = @week
                    ORDER By sp.player_key ASC
                      FOR XML RAW('coach'), TYPE                   
                   )
              FROM @schools s
             ORDER BY s.ranking ASC
               FOR XML RAW('school'), TYPE
		),
		(
			SELECT TOP 1 '(Published On: ' + CONVERT(CHAR(10), @poll_date, 126) + ')' AS sub_ribbon, 'USA Today Coaches Ballots' AS ribbon
			   FOR XML RAW('reference'), TYPE
		),
		(
			SELECT @header AS credits
			FOR XML RAW('header'), TYPE
		),
		(
            SELECT c.player_first + ' ' + c.player_last AS player_display, c.player_key AS player_slug,
                   (
                   SELECT st.team_slug, spv.ranking
                     FROM SportsEditDB.dbo.SMG_Polls_Votes spv
                    INNER JOIN dbo.SMG_Teams st ON st.season_key = spv.season_key AND st.team_abbreviation = spv.team_key
                    WHERE st.league_key = @league_key AND spv.league_key = @league_key AND spv.season_key = @seasonKey AND spv.[week] = @week
					  AND spv.player_key = c.player_key 
                    ORDER By spv.ranking ASC
                      FOR XML RAW('school'), TYPE                    
                   )
              FROM @coaches c
             ORDER BY c.player_last ASC, c.player_first ASC
			   FOR XML RAW('coach'), TYPE
		)
		FOR XML PATH(''), ROOT('root')
	END

END


GO
