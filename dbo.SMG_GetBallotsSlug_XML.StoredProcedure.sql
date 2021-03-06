USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetBallotsSlug_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetBallotsSlug_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @week INT,
    @category VARCHAR(100),
    @slug VARCHAR(100)
AS
--=============================================
-- Author:		ikenticus
-- Create date: 11/22/2013
-- Description: get ballots for specified category/slug
-- Update:		11/26/2013 - John Lin - modified here and there
--				11/27/2013 - ikenticus - team_class unification, adding same week logic as filters
--				12/02/2013 - ikenticus - adding points from SMG_Polls_Other
--				12/02/2013 - John Lin - change wording
--				12/03/2013 - John Lin - remove team record for week
--				12/19/2013 - John Lin - add team_class for week
--				07/01/2015 - ikenticus - adjusting to STATS migration and SMG_Polls* conversion
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


	-- Determine leagueKey from leagueName
	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)

	DECLARE @columns TABLE
	(
		display VARCHAR(100),
		[column] VARCHAR(100)
	)

    DECLARE @selected VARCHAR(100)

	IF (@category = 'coaches')
	BEGIN
        SELECT @selected = first_name + ' ' + last_name
          FROM dbo.SMG_Players
         WHERE player_key = @slug
        
		INSERT INTO @columns (display, [column])
		VALUES ('Rank', 'ranking'), ('Team', 'team_display')

		DECLARE @coaches TABLE
		(
			team_key	VARCHAR(100),
			team_class	VARCHAR(100),
			team_slug   VARCHAR(100),
			team_logo   VARCHAR(100),
			team_first	VARCHAR(100),
			team_last	VARCHAR(100),
			ranking		INT
		)
		INSERT INTO @coaches (team_key, team_class, team_slug, team_first, team_last, ranking)
		SELECT st.team_key, st.team_abbreviation, st.team_slug, st.team_first, st.team_last, spv.ranking
		  FROM SportsEditDB.dbo.SMG_Polls_Votes spv
		 INNER JOIN dbo.SMG_Players sp
			ON sp.player_key = spv.player_key AND sp.player_key = @slug
		 INNER JOIN dbo.SMG_Teams st
			ON st.team_abbreviation = spv.team_key AND st.league_key = @league_key AND st.season_key = @seasonKey
		 WHERE spv.league_key = @leagueName AND spv.season_key = @seasonKey AND spv.[week] = @week

		UPDATE @coaches
		   SET team_logo = dbo.SMG_fnTeamLogo(@leagueName, team_class, '30')

		-- Build XML output
		SELECT
		(
			SELECT @category AS category, @seasonKey AS season, @week AS week, @selected AS display
			FOR XML RAW('selected'), TYPE
		),
		(
			SELECT
			(
				SELECT team_key, team_logo, team_class, team_slug, team_first, team_last, ranking
				  FROM @coaches
				 ORDER BY ranking
				   FOR XML RAW('row'), TYPE
			)
			FOR XML RAW('table'), TYPE
		),
		(
			SELECT display, [column]
			  FROM @columns
			   FOR XML RAW('column'), TYPE
		)
		FOR XML PATH(''), ROOT('root')

	END
	ELSE IF (@category = 'schools')
	BEGIN
        SELECT @selected = team_first
          FROM dbo.SMG_Teams
         WHERE league_key = @league_key AND season_key = @seasonKey AND team_slug = @slug

		INSERT INTO @columns (display, [column])
		VALUES ('Coach', 'player_display'), ('Team', 'team_display'), ('Rank', 'ranking')

		DECLARE @schools TABLE
		(
			player_key		VARCHAR(100),
			player_first	VARCHAR(100),
			player_last		VARCHAR(100),
			player_display	VARCHAR(100),
			team_key		VARCHAR(100),
			team_class		VARCHAR(100),
			team_logo		VARCHAR(100),
			team_first	    VARCHAR(100),
			team_last 	    VARCHAR(100),
			ranking			INT
		)
		INSERT INTO @schools (team_key, team_class, team_first, team_last, ranking, player_key, player_first, player_last, player_display)
		SELECT sr_t.team_key, sr_t.team_abbreviation, sr_t.team_first, sr_t.team_last, spv.ranking, sp.player_key, sp.first_name, sp.last_name, sp.first_name + ' ' + sp.last_name
		  FROM SportsEditDB.dbo.SMG_Polls_Votes spv
		 INNER JOIN dbo.SMG_Players sp
			ON sp.player_key = spv.player_key
		 INNER JOIN dbo.SMG_Rosters sr
			ON sp.player_key = sr.player_key AND sr.league_key = @leagueName AND sr.season_key = @seasonKey
		 INNER JOIN dbo.SMG_Teams sr_t
			ON sr_t.team_abbreviation = sr.team_key AND sr_t.league_key = @league_key AND sr_t.season_key = @seasonKey
		 INNER JOIN dbo.SMG_Teams spv_t
			ON spv_t.team_abbreviation = spv.team_key AND spv_t.league_key = @league_key AND spv_t.season_key = @seasonKey AND spv_t.team_slug = @slug
		 WHERE spv.league_key = @leagueName AND spv.season_key = @seasonKey AND spv.[week] = @week

		UPDATE @schools
		   SET team_logo = dbo.SMG_fnTeamLogo(@leagueName, team_class, '30')

		-- Build XML output
		SELECT
		(
			SELECT @category AS category, @seasonKey AS season, @week AS week, @selected AS display
			FOR XML RAW('selected'), TYPE
		),
		(
			SELECT
			(
				SELECT team_key, team_logo, team_class, team_first, team_last, ranking, player_first, player_last, player_display, player_key AS player_slug
				  FROM @schools
				 ORDER BY player_last
				   FOR XML RAW('row'), TYPE
			)
			FOR XML RAW('table'), TYPE
		),
		(
			SELECT display, [column]
			  FROM @columns
			   FOR XML RAW('column'), TYPE
		)
		FOR XML PATH(''), ROOT('root')

	END
	ELSE IF (@category = 'weeks')
	BEGIN

		DECLARE @team_key VARCHAR(100)
		DECLARE @team_abbr VARCHAR(100)
		
        SELECT @selected = team_first + ' ' + team_last, @team_key = team_key, @team_abbr = team_abbreviation
          FROM dbo.SMG_Teams
         WHERE league_key = @league_key AND season_key = @seasonKey AND team_slug = @slug

        IF (@leagueName = 'ncaaf')
        BEGIN
    		INSERT INTO @columns (display, [column])
	    	VALUES ('Week', 'week'), ('Rank', 'ranking'), ('Points', 'points')
        END
        ELSE
        BEGIN
    		INSERT INTO @columns (display, [column])
	    	VALUES ('Week', 'week'), ('Rank', 'ranking'), ('Record', 'team_record'), ('Points', 'points')
		END

		DECLARE @weeks TABLE 
		(
			team_record		VARCHAR(100),
			points			VARCHAR(100),
			ranking			VARCHAR(100),
			[week]  		VARCHAR(100)
		)
		INSERT INTO @weeks ([week], ranking)
		SELECT [week], NULL
		  FROM SportsEditDB.dbo.SMG_Polls
	     WHERE league_key = @leagueName AND season_key = @seasonKey AND [week] <= @week
		 GROUP BY [week]

		UPDATE w
		   SET w.team_record = (CAST(sp.wins AS VARCHAR(100)) + '-' + CAST(sp.losses AS VARCHAR(100))),
			   w.ranking = sp.ranking,
			   w.points = sp.points
		  FROM @weeks w
		 INNER JOIN SportsEditDB.dbo.SMG_Polls AS sp
			ON w.[week] = sp.[week] AND sp.fixture_key = 'smg-usat' AND sp.league_key = @leagueName AND sp.season_key = @seasonKey
	     INNER JOIN dbo.SMG_Teams st
	        ON st.league_key = @league_key AND st.season_key = sp.season_key AND st.team_abbreviation = sp.team_key AND st.team_slug = @slug

		-- Update points from SMG_Polls_Other
		UPDATE w
		   SET w.points = spo.points --, w.ranking = spo.ranking
		  FROM @weeks w
		 INNER JOIN SportsEditDB.dbo.SMG_Polls_Other AS spo
			ON w.[week] = spo.[week] AND spo.team_key = @team_abbr
           AND spo.league_key = @leagueName AND spo.season_key = @seasonKey
			

		-- Build XML output
		SELECT
		(
			SELECT @category AS category, @seasonKey AS season, @week AS week, @selected AS display, @team_abbr AS team_class
			FOR XML RAW('selected'), TYPE
		),
		(
			SELECT
			(
				SELECT
					ISNULL(team_record, '--') AS team_record,
					ISNULL(ranking, 'NR') AS ranking,
					ISNULL(points, '--') AS points,
					(CASE
						WHEN week = 1 THEN 'Preseason'
						WHEN week >= 16 AND @league_key = 'l.ncaa.org.mfoot' THEN 'Final Ranking'
						WHEN week = 20 AND @league_key <> 'l.ncaa.org.mfoot' THEN 'Postseason'
						WHEN week >= 21 AND @league_key <> 'l.ncaa.org.mfoot' THEN 'Postseason (Final)'
						ELSE 'Week ' + CAST(week AS VARCHAR(100)) END
					) AS [week]
				  FROM @weeks
				 ORDER BY CAST([week] AS INT) ASC
				   FOR XML RAW('row'), TYPE
			)
			FOR XML RAW('table'), TYPE
		),
		(
			SELECT display, [column]
			  FROM @columns
			   FOR XML RAW('column'), TYPE
		)
		FOR XML PATH(''), ROOT('root')

	END

END


GO
