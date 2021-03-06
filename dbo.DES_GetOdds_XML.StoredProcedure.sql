USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetOdds_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DES_GetOdds_XML]
	@leagueName VARCHAR(100)
AS
--=============================================
-- Author:		ikenticus
-- Create date:	06/03/2015
-- Description: get odds by league for desktop
-- Update:		07/06/2015 - ikenticus - additions for SportsOdds (STATS vendor)
-- 				07/14/2015 - ikenticus - failover for starting pitcher to transient
--              08/17/2015 - John Lin - cherry pick books
--              09/03/2015 - ikenticus - refactor team logo/display, fixing over-under, starting-pitcher
--              09/08/2015 - ikenticus - adjusting books and odds display by league
--              09/11/2015 - ikenticus - correcting favorite being the team with the negative points spread (not positive)
--				09/15/2015 - ikenticus - using over-under total for NFL instead of away/home
--				09/16/2015 - ikenticus - using spread prediction instead of over-under total for non-football
--				09/17/2015 - ikenticus - adding in NASCAR odds
--				09/18/2015 - ikenticus - adding in PGA Tour odds
--				09/24/2015 - ikenticus - fixing runline/moneyline for MLB odds
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    IF (@leagueName NOT IN ('mlb', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba', 'mls', 'nascar', 'golf'))
    BEGIN
        RETURN
    END
    
    DECLARE @league_key VARCHAR(100)
    DECLARE @team_key VARCHAR(100)
	DECLARE @ribbon VARCHAR(100)


	DECLARE @columns TABLE (
		id VARCHAR(100),
		display VARCHAR(100)
	)

	IF (@leagueName = 'golf')
	BEGIN
		SET @league_key = dbo.SMG_fnGetLeagueKey('pga-tour')

		INSERT INTO @columns (id, display)
		VALUES ('team_key', 'PLAYER'), ('value', 'ODDS')
	END
	ELSE IF (@leagueName = 'nascar')
	BEGIN
		SET @league_key = dbo.SMG_fnGetLeagueKey('cup-series')

		INSERT INTO @columns (id, display)
		VALUES ('team_key', 'DRIVER'), ('value', 'ODDS')
	END
	ELSE
	BEGIN
		SET @league_key = dbo.SMG_fnGetLeagueKey(@leagueName)
	END

	DECLARE @odds TABLE (
        event_key       VARCHAR(100),
        team_key        VARCHAR(100),
		season_key		INT,
        player_key  	VARCHAR(100),
		book			VARCHAR(100),
		betting			VARCHAR(100),
		prediction		VARCHAR(100),
		value			VARCHAR(100)
	)

	INSERT INTO @odds (event_key, team_key, season_key, player_key, book, betting, prediction, value)
	SELECT event_key, team_key, season_key, player_key, book, betting, prediction, value
	  FROM dbo.SMG_Odds
	 WHERE league_key = @league_key AND date_time >= CONVERT(DATE, GETDATE(), 111)
	 ORDER BY date_time ASC


	DECLARE @events TABLE (
		start_date_time DATETIME,
		start_date 		VARCHAR(100),
		away_key		VARCHAR(100),
		home_key		VARCHAR(100),
		event_key		VARCHAR(100),
		event_name		VARCHAR(200)
	)

	IF (@leagueName IN ('golf', 'nascar'))
	BEGIN	-- SOLO

		INSERT INTO @events (event_key)
		SELECT event_key
		  FROM @odds
		 GROUP BY event_key
		
		UPDATE e
		   SET event_name = s.event_name, start_date_time = s.start_date_time
		  FROM @events AS e
		 INNER JOIN dbo.SMG_Solo_Events AS s ON s.event_key = e.event_key

		UPDATE @odds
		   SET value = CASE WHEN CAST(prediction AS INT) > 0 THEN '+' + prediction ELSE prediction END
		 WHERE value = '/' AND ISNUMERIC(prediction) = 1

        SELECT
			(
				SELECT event_name AS ribbon,
					(
						SELECT display, id
						  FROM @columns
						   FOR XML RAW('columns'), TYPE
					),
					(
						SELECT team_key, value, prediction
						  FROM @odds AS o
						 WHERE o.event_key = e.event_key
						 ORDER BY CAST(prediction AS INT) ASC, team_key ASC
						   FOR XML RAW('rows'), TYPE
					)
				  FROM @events AS e
				 ORDER BY start_date_time
				   FOR XML RAW('events'), TYPE
			)
		   FOR XML PATH(''), ROOT('root')

	END
	ELSE	-- TEAM
	BEGIN
		
		UPDATE @odds
		   SET value = '+' + value
		 WHERE betting = 'moneyline' AND LEFT(value, 1) NOT IN ('-', '+')

		INSERT INTO @events (event_key)
		SELECT event_key
		  FROM @odds
		 GROUP BY event_key

		UPDATE e
		   SET start_date_time = s.start_date_time_EST, away_key = s.away_team_key, home_key = s.home_team_key
		  FROM @events AS e
		 INNER JOIN dbo.SMG_Schedules AS s ON s.event_key = e.event_key

		UPDATE @events
		   SET start_date = CONVERT(DATE, start_date_time, 110)

		DELETE @events
		 WHERE start_date < CONVERT(DATE, GETDATE(), 111)

		DECLARE @books TABLE (
			book VARCHAR(100),
			season_key INT,
			event_key VARCHAR(100),
			player_key VARCHAR(100),
			team_key VARCHAR(100),
			team_abbr VARCHAR(100),
			team_logo VARCHAR(100),
			team_display VARCHAR(100),
			odds_display VARCHAR(100),
			over_under VARCHAR(100)
		)

		-- Limit odds to 6 sportsbooks (per Tim Gardner) for all leagues
		IF (@leagueName = 'wnba')
		BEGIN
			INSERT INTO @books (book, season_key, event_key, team_key, player_key)
			SELECT book, season_key, event_key, team_key, player_key
			  FROM @odds
			 WHERE team_key <> 'over-under'
			   AND book IN ('5dimes', 'bet365', 'betus', 'heritage', 'sportsbook', 'superbook')
			 GROUP BY book, season_key, event_key, team_key, player_key
		END
		ELSE
		BEGIN
			INSERT INTO @books (book, season_key, event_key, team_key, player_key)
			SELECT book, season_key, event_key, team_key, player_key
			  FROM @odds
			 WHERE team_key <> 'over-under'
			   AND book IN ('5dimes', 'hilton', 'ladbrokes', 'mirage', 'williamhill', 'wynn')
			 GROUP BY book, season_key, event_key, team_key, player_key
		END
		
		-- Retrieve starting pitchers from current/opening
		UPDATE b
		   SET player_key = p.player_key
		  FROM @books AS b
		 INNER JOIN @books AS p ON p.event_key = b.event_key AND p.team_key = b.team_key
		 WHERE b.player_key = '' AND p.player_key <> ''

		-- Retrieve starting pitchers from transient if still emmpty
		UPDATE b
		   SET player_key = t.player_key
		  FROM @books AS b
		 INNER JOIN dbo.SMG_Transient AS t
			ON t.team_key = b.team_key AND t.event_key = b.event_key
		 WHERE b.player_key IS NULL AND t.player_key IS NOT NULL

		UPDATE b
		   SET player_key = + '(' + UPPER(LEFT(p.throwing_hand, 1)) + ') ' + p.first_name + ' ' + p.last_name
		  FROM @books AS b
		 INNER JOIN dbo.SMG_Players AS p ON p.player_key = b.player_key
		
		UPDATE b
		   SET team_abbr = t.team_abbreviation
		  FROM @books AS b
		 INNER JOIN dbo.SMG_Teams AS t ON t.team_key = b.team_key AND t.season_key = b.season_key

		UPDATE b
		   SET team_display = t.team_display
		  FROM @books AS b
		 INNER JOIN dbo.SMG_Teams AS t ON t.team_key = b.team_key 

		UPDATE @books
		   SET team_display = team_abbr + ' ' + player_key
		 WHERE player_key IS NOT NULL


		DECLARE @over_under TABLE (
			book VARCHAR(100),
			event_key VARCHAR(100),
			[over] INT,
			[under] INT,
			[total-score] VARCHAR(100)
		)

		INSERT INTO @over_under (event_key, book, [over], [under], [total-score])
		SELECT p.event_key, p.book, [over], [under], [total-score]
		  FROM (SELECT event_key, [book], [betting], value FROM @odds WHERE team_key = 'over-under') AS s
		 PIVOT (MAX(s.value) FOR s.[betting] IN ([over], [under], [total-score])) AS p

		IF (@leagueName IN ('nfl', 'ncaaf', 'nba', 'wnba', 'ncaab', 'ncaaw'))
		BEGIN
			DELETE @over_under
			 WHERE [over] <> [under]

			UPDATE b
			   SET over_under = CAST(s.prediction AS VARCHAR) + ' -- ' + CAST(u.[total-score] AS VARCHAR)
			  FROM @books AS b
			 INNER JOIN @odds AS s ON s.team_key = b.team_key AND s.event_key = b.event_key AND s.book = b.book
			 INNER JOIN @over_under AS u ON u.event_key = b.event_key AND u.book = b.book
			 WHERE s.betting = 'spread'

			UPDATE b1
			   SET odds_display = b1.over_under
			  FROM @books AS b1
			 INNER JOIN @books AS b2 ON b2.team_key <> b1.team_key AND b2.event_key = b1.event_key AND b2.book = b1.book
			 WHERE LEFT(b1.over_under, 1) = '-'

			UPDATE b1
			   SET odds_display = '-' + b2.over_under
			  FROM @books AS b1
			 INNER JOIN @books AS b2 ON b2.team_key <> b1.team_key AND b2.event_key = b1.event_key AND b2.book = b1.book
			 WHERE LEFT(b2.over_under, 1) BETWEEN '0' AND '9'

			UPDATE @books
			   SET odds_display = REPLACE(odds_display, '-0.0', 'PK')
			 WHERE LEFT(odds_display, 4) = '-0.0'

			-- This block will set the underdog to '- -'
			UPDATE @books 
			   SET odds_display = '- -'
			 WHERE odds_display IS NULL AND over_under IS NOT NULL

			-- This block will set the underdog to +spread
			UPDATE b1
			   SET odds_display = '+' + RIGHT(b2.odds_display, LEN(b2.odds_display) - 1)
			  FROM @books AS b1
			 INNER JOIN @books AS b2 ON b2.team_key <> b1.team_key AND b2.event_key = b1.event_key AND b2.book = b1.book
			 WHERE LEFT(b2.odds_display, 1) = '-' AND b1.odds_display = '- -'

			-- This block will set the empty PK
			UPDATE b1
			   SET odds_display = b2.odds_display
			  FROM @books AS b1
			 INNER JOIN @books AS b2 ON b2.team_key <> b1.team_key AND b2.event_key = b1.event_key AND b2.book = b1.book
			 WHERE LEFT(b2.odds_display, 2) = 'PK' AND b1.odds_display = '- -'
		END
		ELSE
		BEGIN
			-- Moneyline: http://www.covers.com/odds/baseball/mlb-odds.aspx
			UPDATE b
			   SET odds_display = CAST(u.[total-score] AS VARCHAR) + ' ' + s.value
			  FROM @books AS b
			 INNER JOIN @odds AS s ON s.team_key = b.team_key AND s.event_key = b.event_key AND s.book = b.book
			 INNER JOIN @over_under AS u ON u.event_key = b.event_key AND u.book = b.book
			 WHERE s.betting = 'moneyline'

			/*
			-- Runline: http://www.covers.com/odds/baseball/mlb-runline-odds.aspx
			UPDATE b
			   SET odds_display = CAST(s.[prediction] AS VARCHAR) + ' ' + CAST(s.[value] AS VARCHAR), over_under = s.[prediction]
			  FROM @books AS b
			 INNER JOIN @odds AS s ON s.team_key = b.team_key AND s.event_key = b.event_key AND s.book = b.book
			 WHERE s.betting = 'spread'

			UPDATE b1
			   SET odds_display = CASE
									WHEN LEFT(b2.over_under, 1) = '-' THEN '+' + RIGHT(b2.over_under, LEN(b2.over_under) - 1)
									ELSE '-' + b2.over_under
									END + ' ' + b1.odds_display
			  FROM @books AS b1
			 INNER JOIN @books AS b2 ON b2.team_key <> b1.team_key AND b2.event_key = b1.event_key AND b2.book = b1.book
			 WHERE LEFT(b1.odds_display, 1) = ' ' AND b1.over_under = ''
			*/
		END

		DELETE @books
		 WHERE odds_display IS NULL

		-- Do not show STATS current/opening if additional sportsbooks available from SportsOdds
		IF EXISTS (SELECT 1 FROM @books WHERE book NOT IN ('current', 'opening') GROUP BY book)
		BEGIN
			DELETE @books
			 WHERE book IN ('current', 'opening')
		END

		-- Remove events with no odds
		DELETE e
		  FROM @events AS e
		  LEFT OUTER JOIN @books AS b ON b.event_key = e.event_key
		 WHERE book IS NULL


		-- logo
		UPDATE @books
		   SET team_logo = dbo.SMG_fnTeamLogo(@leagueName, team_abbr, 30)


		SELECT
		(
			SELECT start_date,
				(
					SELECT start_date_time,
						(
							SELECT team_display, team_logo,
								(
									SELECT book, odds_display
									  FROM @books AS b
									 WHERE b.event_key = m.event_key AND b.team_key = m.away_key
									   FOR XML RAW('odds'), TYPE
								)
							  FROM @books AS t
							 WHERE t.event_key = m.event_key AND t.team_key = m.away_key
							 GROUP BY team_display, team_logo
							   FOR XML RAW('away'), TYPE
						),
						(
							SELECT team_display, team_logo,
								(
									SELECT book, odds_display
									  FROM @books AS b
									 WHERE b.event_key = m.event_key AND b.team_key = m.home_key
									   FOR XML RAW('odds'), TYPE
								)
							  FROM @books AS t
							 WHERE t.event_key = m.event_key AND t.team_key = m.home_key
							 GROUP BY team_display, team_logo
							   FOR XML RAW('home'), TYPE
						)
					  FROM @events AS m
					 WHERE m.start_date = e.start_date
					 ORDER BY m.start_date_time ASC
					   FOR XML RAW('matchup'), TYPE
				)
			  FROM @events AS e
			 GROUP BY start_date
			   FOR XML RAW('schedule'), TYPE
		),
		(
			SELECT book AS book
			  FROM @books
			 GROUP BY book
			   FOR XML PATH(''), TYPE
		)
		FOR XML PATH(''), ROOT('root')

	END

END

GO
