USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[NAT_GetScores_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[NAT_GetScores_XML]
   @host VARCHAR(100),
   @leagueName VARCHAR(100),
   @seasonKey INT = NULL,
   @subSeasonType VARCHAR(100) = NULL,
   @week VARCHAR(100) = NULL,
   @startDate DATETIME = NULL,
   @filter	VARCHAR(100) = NULL
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 07/08/2014
  -- Description: get scores by date for native
  -- Update: 07/08/2014 - John Lin - previous and next list
  --         07/18/2014 - John Lin - change text for previous and next
  --         07/25/2014 - John Lin - update previous to sort for visual
  --                               - lower case for team key
  --         08/05/2014 - Johh Lin - add domain
  --         08/14/2014 - ikenticus - adding Week prefix for regular season football display
  --         09/04/2014 - ikenticus - per JIRA SMW-88, adding ncaab filter, abbr nfl display for pre,
  --									adding event_link for football, adding full subseason to weekly sports
  --         09/05/2014 - ikenticus - per JIRA SMW-88, changing full season swipe insertion
  --         09/09/2014 - John Lin - update rank logic
  --         09/12/2014 - John Lin - update display order
  --         09/15/2014 - John Lin - add more parameters for mobile link off
  --         09/24/2014 - John Lin - fix bowls week and team TBA
  --         10/07/2014 - John Lin - remove ribbon
  --         10/10/2014 - John Lin - set ncaab week
  --         11/19/2014 - John Lin - remove ET
  --         12/03/2014 - John Lin - whitebg
  --         12/16/2014 - John Lin - add playoffs, link to nhl
  --         01/29/2015 - John Lin - rename championship to conference
  --         03/18/2015 - John Lin - modify event link
  --         04/22/2015 - John Lin - use mobile ribbon
  --         05/20/2015 - John Lin - add Women's World Cup
  --         06/05/2015 - John Lin - fix typo in logic
  --         06/10/2015 - John Lin - revert modified event link
  --         06/19/2015 - John Lin - add round of 16
  --		 07/01/2015 - ikenticus - adjusting to SMG_Polls* conversion
  --         07/10/2015 - John Lin - STATS team records
  --         07/28/2015 - John Lin - MLS All Stars
  --         07/29/2015 - John Lin - SDI migration
  --	     08/03/2015 - John Lin - retrieve event_id and logo using functions
  --         09/09/2015 - John Lin - use conference display for NCAA filter
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    IF (@leagueName NOT IN ('mlb', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba',
                            'mls', 'wwc'))
    BEGIN
        RETURN
    END

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @web_host VARCHAR(100) = 'http://www.usatoday.com/sports/'
    DECLARE @sport VARCHAR(100) = 'mens-basketball'
    DECLARE @default_week VARCHAR(100)

	DECLARE @events TABLE
	(
        season_key           INT,
        event_key            VARCHAR(100),
        event_status         VARCHAR(100) DEFAULT '',
        game_status          VARCHAR(100) DEFAULT '',
        odds                 VARCHAR(100),
        start_date_time_EST  DATETIME,
        [week]               VARCHAR(100),
        away_team_key        VARCHAR(100),
        away_team_abbr       VARCHAR(100),
        away_team_logo       VARCHAR(100),
        away_team_record     VARCHAR(100),
        away_team_rank       VARCHAR(100),
        away_team_score      VARCHAR(100),
        away_team_runs       VARCHAR(100),
        away_team_hits       VARCHAR(100),
        away_team_errors     VARCHAR(100),
        away_team_winner     VARCHAR(100) DEFAULT '',
        home_team_key        VARCHAR(100),
        home_team_abbr       VARCHAR(100),
        home_team_logo       VARCHAR(100),
        home_team_record     VARCHAR(100),
        home_team_rank       VARCHAR(100),
        home_team_score      VARCHAR(100),
        home_team_runs       VARCHAR(100),
        home_team_hits       VARCHAR(100),
        home_team_errors     VARCHAR(100),
        home_team_winner     VARCHAR(100) DEFAULT '',
        level_name           VARCHAR(100),
	    -- info
        away_team_last       VARCHAR(100) DEFAULT '',
        away_team_conference VARCHAR(100),
        home_team_last       VARCHAR(100) DEFAULT '',
        home_team_conference VARCHAR(100),
	    -- extra
        ribbon               VARCHAR(100),
        event_id             VARCHAR(100),
        event_link           VARCHAR(MAX),
        event_date           DATE,
	    date_order           INT,
	    status_order         INT,
	    time_order           INT
	)
    DECLARE @current VARCHAR(200)
    DECLARE @min_start_date_EST DATETIME
    DECLARE @max_start_date_EST DATETIME
    DECLARE @today DATE = CAST(GETDATE() AS DATE)

    IF (@leagueName = 'nfl')
    BEGIN
        IF (@seasonKey IS NULL OR @subSeasonType IS NULL OR @week IS NULL)
        BEGIN
            RETURN
        END

        SET @current = @host + '/SportsNative/Scores.svc/' + @leagueName + '/' + CAST(@seasonKey AS VARCHAR) + '/' + @subSeasonType + '/' + @week
        
        SELECT @default_week = [week]
          FROM dbo.SMG_Default_Dates
         WHERE league_key = 'nfl' AND page = 'scores'

        INSERT INTO @events (season_key, event_key, event_status, game_status, odds, start_date_time_EST, [week],
                             away_team_key, away_team_score, home_team_key, home_team_score)
        SELECT season_key, event_key, event_status, game_status, odds, start_date_time_EST, [week],
               away_team_key, away_team_score, home_team_key, home_team_score
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND [week] = @week 
    END
    ELSE IF (@leagueName IN ('ncaaf', 'wwc'))
    BEGIN
        IF (@seasonKey IS NULL OR @week IS NULL)
        BEGIN
            RETURN
        END

        SET @sport = 'football'
        SET @current = @host + '/SportsNative/Scores.svc/ncaaf/' + CAST(@seasonKey AS VARCHAR) + '/' + @week

        IF (@leagueName = 'wwc')
        BEGIN
            SET @current = @host + '/SportsNative/Scores.svc/wwc/' + CAST(@seasonKey AS VARCHAR) + '/' + @week
        END

        SELECT @default_week = [week]
          FROM dbo.SMG_Default_Dates
         WHERE league_key = 'ncaaf' AND page = 'scores'

        IF (@week = 'bowls')
        BEGIN
            INSERT INTO @events (season_key, event_key, event_status, game_status, odds, start_date_time_EST, [week],
                                 away_team_key, away_team_score, home_team_key, home_team_score)
            SELECT season_key, event_key, event_status, game_status, odds, start_date_time_EST, [week],
                   away_team_key, away_team_score, home_team_key, home_team_score
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @seasonKey AND [week] = 'playoffs'
        END
        
        INSERT INTO @events (season_key, event_key, event_status, game_status, odds, start_date_time_EST, [week],
                             away_team_key, away_team_score, home_team_key, home_team_score)
        SELECT season_key, event_key, event_status, game_status, odds, start_date_time_EST, [week],
               away_team_key, away_team_score, home_team_key, home_team_score
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @seasonKey AND [week] = @week
    END
    ELSE
    BEGIN
        IF (@startDate IS NULL)
        BEGIN
            RETURN
        END
        
        DECLARE @end_date DATETIME = DATEADD(SECOND, -1, DATEADD(DAY, 1, @startDate))
        SET @current =  @host + '/SportsNative/Scores.svc/' + @leagueName + '/' + REPLACE(CAST(CAST(@startDate AS DATE) AS VARCHAR), '-', '/')

        IF (@leagueName = 'mls')
        BEGIN
            SET @current =  @host + '/SportsNative/Scores.svc/mls/' + REPLACE(CAST(CAST(@startDate AS DATE) AS VARCHAR), '-', '/')
        END

        INSERT INTO @events (season_key, event_key, event_status, game_status, odds, start_date_time_EST, [week],
                             away_team_key, away_team_score, home_team_key, home_team_score, level_name)
        SELECT season_key, event_key, event_status, game_status, odds, start_date_time_EST, [week],
               away_team_key, away_team_score, home_team_key, home_team_score, level_name
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND start_date_time_EST BETWEEN @startDate AND @end_date AND event_status <> 'smg-not-played'        
    END

    -- min/max start date
    IF (@leagueName IN ('nfl', 'ncaaf', 'wwc'))
    BEGIN
        SELECT TOP 1 @min_start_date_EST = start_date_time_EST
          FROM @events
         ORDER BY start_date_time_EST ASC

        SELECT TOP 1 @max_start_date_EST = start_date_time_EST
          FROM @events
         ORDER BY start_date_time_EST DESC
    END
    
    -- FILTER NODE
    DECLARE @filters TABLE (
        id VARCHAR(100),
        display VARCHAR(100)
    )
    
    IF (@leagueName IN ('ncaab', 'ncaaw'))
    BEGIN
       INSERT INTO @filters(id, display)
       SELECT id, display
         FROM dbo.SMG_fnGetNCAABFilter(@league_key, @startDate, @filter, 'scores')

        IF NOT EXISTS (SELECT 1 FROM @filters WHERE id = @filter)
        BEGIN
            SET @filter = 'div1'
        
            IF EXISTS (SELECT 1 FROM @filters WHERE id = 'tourney')
            BEGIN
                SET @filter = 'tourney'
            END
            ELSE
            BEGIN
                IF EXISTS (SELECT 1 FROM @filters WHERE id = 'top25')
                BEGIN
                    SET @filter = 'top25'
                END
            END
        END
    END
    ELSE IF (@leagueName = 'ncaaf')
    BEGIN
       INSERT INTO @filters(id, display)
       SELECT id, display
         FROM dbo.SMG_fnGetNCAAFFilter(@seasonKey, @week, @filter, 'scores')

        IF NOT EXISTS (SELECT 1 FROM @filters WHERE id = @filter)
        BEGIN
            SET @filter = 'div1.a'

            IF EXISTS (SELECT 1 FROM @filters WHERE id = 'top25')
            BEGIN
                SET @filter = 'top25'
            END
        END
    END

    -- abbreviaton, logo, links
	DECLARE @coverage TABLE (
		event_key VARCHAR(100),
		column_type VARCHAR(100)
	)	
	INSERT INTO @coverage (event_key, column_type)
	SELECT ss.event_key, ss.column_type
	  FROM dbo.SMG_Scores ss
	 INNER JOIN @events e
	    ON e.event_key = ss.event_key

    -- event id
    UPDATE @events
       SET event_id = dbo.SMG_fnEventId(event_key)

    UPDATE e
       SET e.away_team_abbr = st.team_abbreviation, e.away_team_last = st.team_last, e.away_team_conference = st.conference_key
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = e.season_key AND st.team_key = e.away_team_key
     
    UPDATE e
       SET e.home_team_abbr = st.team_abbreviation, e.home_team_last = st.team_last, e.home_team_conference = st.conference_key
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = e.season_key AND st.team_key = e.home_team_key
    
    IF (@leagueName IN ('mls', 'wwc'))
    BEGIN
        SET @web_host = 'http://www.usatoday.com/sports/soccer/'
    END

    UPDATE e
       SET e.event_link = @web_host + @leagueName + '/event/' + CAST(e.season_key AS VARCHAR) + '/' + e.event_id + '/preview/?chromeless=true&mobile=true'
      FROM @events e
     INNER JOIN @coverage c
        ON c.event_key = e.event_key AND c.column_type = 'pre-event-coverage'

    UPDATE @events
       SET event_link = @web_host + @leagueName + '/event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/boxscore/?chromeless=true&mobile=true'
     WHERE event_status <> 'pre-event'
        
    -- SEC HACK
    IF (@leagueName IN ('ncaab', 'ncaaf'))
    BEGIN
        UPDATE e
           SET e.away_team_conference = SportsEditDB.dbo.SMG_fnSlugifyName(l.conference_display)
          FROM @events e
         INNER JOIN dbo.SMG_Leagues l
            ON l.league_key = @league_key AND l.season_key = @seasonKey AND l.conference_key = e.away_team_conference

        UPDATE e
           SET e.home_team_conference = SportsEditDB.dbo.SMG_fnSlugifyName(l.conference_display)
          FROM @events e
         INNER JOIN dbo.SMG_Leagues l
            ON l.league_key = @league_key AND l.season_key = @seasonKey AND l.conference_key = e.home_team_conference

        UPDATE @events
           SET event_link = 'http://sports.usatoday.com/ncaa/' + @sport + '/event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/boxscore/?chromeless=true&mobile=true'
         WHERE '/sport/football/conference:12' IN (away_team_conference, home_team_conference)
    END
    
    -- NCAA HACK    
    IF (@leagueName = 'ncaab')
    BEGIN
        UPDATE e
           SET e.event_link = 'http://sports.usatoday.com/ncaa/mens-basketball/event/' + CAST(e.season_key AS VARCHAR) + '/' + e.event_id + '/preview/?chromeless=true&mobile=true'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'pre-event-coverage'
         WHERE e.[week] = 'ncaa'
          
        UPDATE @events
           SET event_link = 'http://sports.usatoday.com/ncaa/mens-basketball/event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/boxscore/?chromeless=true&mobile=true'
         WHERE event_status <> 'pre-event' AND [week] = 'ncaa'
    END

    -- logo
	UPDATE @events
	   SET away_team_logo = dbo.SMG_fnTeamLogo(@leagueName, away_team_abbr, '22'),
		   home_team_logo = dbo.SMG_fnTeamLogo(@leagueName, home_team_abbr, '22')

    IF (@leagueName = 'mls')
    BEGIN
       UPDATE @events
	      SET away_team_logo = dbo.SMG_fnTeamLogo('champions', away_team_abbr, '22')
        WHERE level_name = 'exhibition'
    END


    -- team TBA
    UPDATE @events
       SET away_team_logo = ''
     WHERE away_team_abbr = 'TBA'

    UPDATE @events
       SET home_team_logo = ''
     WHERE home_team_abbr = 'TBA'


    -- FILTER
    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        IF (@leagueName IN ('ncaab', 'ncaaw'))
        BEGIN
            SELECT TOP 1 @seasonKey = season_key, @week = [week]
              FROM @events
             ORDER BY start_date_time_EST DESC
        END

        DECLARE @poll_week INT
        
        IF (ISNUMERIC(@week) = 1 AND EXISTS (SELECT 1
                                               FROM SportsEditDB.dbo.SMG_Polls
                                              WHERE league_key = @leagueName AND season_key = @seasonKey AND fixture_key = 'smg-usat' AND [week] = CAST(@week AS INT)))
        BEGIN
                SET @poll_week = CAST(@week AS INT)
        END
        ELSE
        BEGIN
            SELECT TOP 1 @poll_week = [week]
              FROM SportsEditDB.dbo.SMG_Polls
             WHERE league_key = @leagueName AND season_key = @seasonKey AND fixture_key = 'smg-usat'
             ORDER BY [week] DESC
        END
        
        UPDATE e
           SET e.away_team_rank = sp.ranking
          FROM @events e
         INNER JOIN SportsEditDB.dbo.SMG_Polls sp
            ON sp.league_key = @leagueName AND sp.season_key = @seasonKey AND sp.fixture_key = 'smg-usat' AND
               sp.team_key = e.away_team_abbr AND sp.[week] = @poll_week
               
        UPDATE e
           SET e.home_team_rank = sp.ranking
          FROM @events e
         INNER JOIN SportsEditDB.dbo.SMG_Polls sp
            ON sp.league_key = @leagueName AND sp.season_key = @seasonKey AND sp.fixture_key = 'smg-usat' AND
               sp.team_key = e.home_team_abbr AND sp.[week] = @poll_week

        
        IF (@leagueName IN ('ncaab', 'ncaaw'))
        BEGIN
            UPDATE e
               SET e.away_team_rank = enbt.seed
              FROM @events e
             INNER JOIN SportsEditDB.dbo.Edit_NCAA_Bracket_Teams enbt
                ON enbt.league_key = @league_key AND enbt.season_key = e.season_key AND enbt.team_key = e.away_team_key
             WHERE e.[week] IS NOT NULL AND e.[week] = 'ncaa'

            UPDATE e
               SET e.home_team_rank = enbt.seed
              FROM @events e
             INNER JOIN SportsEditDB.dbo.Edit_NCAA_Bracket_Teams enbt
                ON enbt.league_key = @league_key AND enbt.season_key = e.season_key AND enbt.team_key = e.home_team_key
             WHERE e.[week] IS NOT NULL AND e.[week] = 'ncaa'
        END
        
        IF (@filter NOT IN ('div1.a', 'div1') AND @week NOT IN ('bowls', 'playoffs'))
        BEGIN
            UPDATE @events
               SET status_order = 0

            IF (@filter = 'tourney')
            BEGIN
                UPDATE @events
                   SET status_order = 1
                 WHERE [week] IN ('ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi')
            END
            ELSE IF (@filter IN ('ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi'))
            BEGIN
                UPDATE @events
                   SET status_order = 1
                 WHERE [week] = @filter
            END
            ELSE
            BEGIN
                IF (@filter = 'top25')
                BEGIN
                    UPDATE @events
                       SET status_order = 1
                     WHERE (CAST (ISNULL(NULLIF(home_team_rank, ''), '0') AS INT) + CONVERT(INT, ISNULL(NULLIF(away_team_rank, ''), '0'))) > 0
                END
                ELSE
    	        BEGIN
	                UPDATE @events
        	           SET status_order = 1
                     WHERE @filter IN (home_team_conference, away_team_conference)
                END
            END
        
            DELETE @events
             WHERE status_order = 0
        END
    END


    -- MOBILE ADDITIONS
    UPDATE @events
       SET event_date = CAST(start_date_time_EST AS DATE)
       
	DECLARE @type VARCHAR(100)
	DECLARE @display VARCHAR(100)

    DECLARE @swipe TABLE
	(
        id INT IDENTITY(1, 1) PRIMARY KEY,
        [date] DATE,
        [week] VARCHAR(100),
        sub_season_type VARCHAR(100),
        start_date_time_EST DATETIME,      
        feed_endpoint VARCHAR(200),
        display VARCHAR(100),
        swipe VARCHAR(100),
		rank INT
	)
	DECLARE @pn_date DATE
	DECLARE @pn_week VARCHAR(100)
	DECLARE @pn_start_date_time_EST DATETIME


    IF (@leagueName IN ('ncaaf', 'nfl', 'wwc'))
	BEGIN
        SET @type = 'weekly'
		SET @display = CASE
		                   WHEN @week = 'bowls' THEN 'Bowls'
		                   WHEN @week = 'playoffs' THEN 'Playoff'
		                   WHEN @week = 'hall-of-fame' THEN 'Hall Of Fame'
		                   WHEN @week = 'wild-card' THEN 'Wild Card'
		                   WHEN @week = 'divisional' THEN 'Divisional'
		                   WHEN @week = 'conference' THEN 'Conference'
		                   WHEN @week = 'pro-bowl' THEN 'Pro Bowl'
		                   WHEN @week = 'super-bowl' THEN 'Super Bowl'
		                   WHEN @week = 'quarterfinal' THEN 'Quarterfinal'
		                   WHEN @week = 'semifinal' THEN 'Semifinal'
		                   WHEN @week = 'third-place-game' THEN 'Third Place Game'
		                   WHEN @week = 'final' THEN 'Final'
		                   WHEN @week = 'group-stage' THEN 'Group Stage'
		                   WHEN @week = 'round-of-16' THEN 'Round of 16'
		                   ELSE (CASE
		                            WHEN @leagueName = 'nfl' AND @subSeasonType = 'pre-season' THEN 'Pre ' + @week
		                            ELSE 'Week ' + @week
		                        END)
		               END        

        -- previous
        IF (@leagueName IN ('ncaaf', 'wwc'))
        BEGIN
            SELECT TOP 1 @pn_week = @week, @pn_start_date_time_EST = start_date_time_EST
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @seasonKey AND [week] = @week
             ORDER BY start_date_time_EST ASC
        END
        ELSE
        BEGIN
            SELECT TOP 1 @pn_week = @week, @pn_start_date_time_EST = start_date_time_EST
              FROM dbo.SMG_Schedules
             WHERE league_key = 'l.nfl.com' AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND [week] = @week
             ORDER BY start_date_time_EST ASC
        END

/* BEGIN FULL SEASON SCHEDULE */

        INSERT INTO @swipe (swipe, [week], sub_season_type, start_date_time_EST, rank)
	    SELECT 'previous', [week], sub_season_type, CONVERT(DATE, start_date_time_EST) AS start_date,
	           RANK() OVER (PARTITION BY sub_season_type, week ORDER BY CONVERT(DATE, start_date_time_EST))
    	  FROM dbo.SMG_Schedules
	     WHERE league_key = @league_key AND season_key = @seasonKey AND event_status <> 'smg-not-played' AND [week] IS NOT NULL AND
	           start_date_time_EST < @pn_start_date_time_EST AND [week] <> @pn_week
	     GROUP BY [week], sub_season_type, CONVERT(DATE, start_date_time_EST)
	     ORDER BY CONVERT(DATE, start_date_time_EST) DESC

        INSERT INTO @swipe (swipe, [week], sub_season_type, start_date_time_EST, rank)
	    SELECT 'next', [week], sub_season_type, CONVERT(DATE, start_date_time_EST) AS start_date,
	           RANK() OVER (PARTITION BY sub_season_type, week ORDER BY CONVERT(DATE, start_date_time_EST))
	      FROM dbo.SMG_Schedules
	     WHERE league_key = @league_key AND season_key = @seasonKey AND event_status <> 'smg-not-played' AND [week] IS NOT NULL AND
	           start_date_time_EST > @pn_start_date_time_EST AND [week] <> @pn_week
	     GROUP BY [week], sub_season_type, CONVERT(DATE, start_date_time_EST)
	     ORDER BY CONVERT(DATE, start_date_time_EST) ASC

	    DELETE FROM @swipe WHERE rank > 1

        IF (@leagueName = 'ncaaf' AND @week = 'playoffs')
        BEGIN
            DELETE FROM @swipe WHERE swipe = 'next'
	    END

/* END FULL SEASON SCHEDULE */

        
        UPDATE @swipe
		   SET display = CASE
		                     WHEN [week] = 'bowls' THEN 'Bowls'
		                     WHEN [week] = 'playoffs' THEN 'Playoff'
		                     WHEN [week] = 'hall-of-fame' THEN 'HOF'
		                     WHEN [week] = 'wild-card' THEN 'Wild'
		                     WHEN [week] = 'divisional' THEN 'Div'
		                     WHEN [week] = 'conference' THEN 'Conf'
		                     WHEN [week] = 'pro-bowl' THEN 'Pro Bowl'
		                     WHEN [week] = 'super-bowl' THEN 'Super Bowl'
    		                 WHEN [week] = 'quarterfinal' THEN 'Quarterfinal'
	    	                 WHEN [week] = 'semifinal' THEN 'Semifinal'
		                     WHEN [week] = 'third-place-game' THEN 'Third Place Game'
		                     WHEN [week] = 'final' THEN 'Final'
		                     WHEN [week] = 'group-stage' THEN 'Group Stage'
     		                 WHEN [week] = 'round-of-16' THEN 'Round of 16'
		                     ELSE (CASE
		                              WHEN @leagueName = 'nfl' AND sub_season_type = 'pre-season' THEN 'Pre ' + [week]
		                              ELSE 'Week ' + [week]
		                          END)
		                 END
        
        IF (@leagueName = 'nfl')
        BEGIN
            UPDATE @swipe
               SET feed_endpoint = @host + '/SportsNative/Scores.svc/' + @leagueName + '/' + CAST(@seasonKey AS VARCHAR) + '/' + sub_season_type + '/' + [week]
        END
        ELSE IF (@leagueName = 'wwc')
        BEGIN
            UPDATE @swipe
               SET feed_endpoint = @host + '/SportsNative/Scores.svc/' + @leagueName + '/' + CAST(@seasonKey AS VARCHAR) + '/' + [week]
        END
        ELSE
        BEGIN
            UPDATE @swipe
               SET feed_endpoint = @host + '/SportsNative/Scores.svc/' + @leagueName + '/' + CAST(@seasonKey AS VARCHAR) + '/' + [week] + '/' + @filter
        END
	END
	ELSE
	BEGIN
	    SET @type = 'daily'
        SET @display = CASE
                           WHEN CAST(@startDate AS DATE) = @today THEN 'Today'
                           ELSE LEFT(DATENAME(MONTH, @startDate), 3) + ' ' + CAST(DAY(@startDate) AS VARCHAR) +
                                CASE
                                    WHEN DAY(@startDate) <> 11 AND (DAY(@startDate) % 10) = 1 THEN 'st' 
                                    WHEN DAY(@startDate) <> 12 AND (DAY(@startDate) % 10) = 2 THEN 'nd'
                                    WHEN DAY(@startDate) <> 13 AND (DAY(@startDate) % 10) = 3 THEN 'rd' 
                                    ELSE 'th'
                                END
                       END

	    SELECT TOP 1 @seasonKey = season_key
	      FROM @events

        -- previous
        SET @pn_date = CAST(@startDate AS DATE)
	    
        -- previous 1
        INSERT INTO @swipe ([date], swipe)
        SELECT TOP 1 CAST(start_date_time_EST AS DATE), 'previous'
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @seasonKey AND
               start_date_time_EST < @pn_date AND event_status <> 'smg-not-played'
         ORDER BY start_date_time_EST DESC

        IF EXISTS (SELECT 1 FROM @swipe WHERE swipe = 'previous')
        BEGIN
            SELECT TOP 1 @pn_date = [date]
              FROM @swipe
             ORDER BY [date] ASC

            -- previous 2
            INSERT INTO @swipe ([date], swipe)
            SELECT TOP 1 CAST(start_date_time_EST AS DATE), 'previous'
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @seasonKey AND
                   start_date_time_EST < @pn_date AND event_status <> 'smg-not-played'
             ORDER BY start_date_time_EST DESC

            SELECT TOP 1 @pn_date = [date]
              FROM @swipe
             ORDER BY [date] ASC

            -- previous 3
            INSERT INTO @swipe ([date], swipe)
            SELECT TOP 1 CAST(start_date_time_EST AS DATE), 'previous'
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @seasonKey AND
                   start_date_time_EST < @pn_date AND event_status <> 'smg-not-played'
             ORDER BY start_date_time_EST DESC
        END
        -- next
        SET @pn_date = DATEADD(DAY, 1, CAST(@startDate AS DATE))    

        -- next 1
        INSERT INTO @swipe ([date], swipe)
        SELECT TOP 1 CAST(start_date_time_EST AS DATE), 'next'
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @seasonKey AND
               start_date_time_EST > @pn_date AND event_status <> 'smg-not-played'
         ORDER BY start_date_time_EST ASC

        IF EXISTS (SELECT 1 FROM @swipe WHERE swipe = 'next')
        BEGIN
            SELECT TOP 1 @pn_date = DATEADD(DAY, 1, [date])
              FROM @swipe
             ORDER BY [date] DESC

            -- next 2
            INSERT INTO @swipe ([date], swipe)
            SELECT TOP 1 CAST(start_date_time_EST AS DATE), 'next'
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @seasonKey AND
                   start_date_time_EST > @pn_date AND event_status <> 'smg-not-played'
             ORDER BY start_date_time_EST ASC

            SELECT TOP 1 @pn_date = DATEADD(DAY, 1, [date])
              FROM @swipe
             ORDER BY [date] DESC

            -- next 3
            INSERT INTO @swipe ([date], swipe)
            SELECT TOP 1 CAST(start_date_time_EST AS DATE), 'next'
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @seasonKey AND
                   start_date_time_EST > @pn_date AND event_status <> 'smg-not-played'
             ORDER BY start_date_time_EST ASC
        END
        
        UPDATE @swipe
           SET feed_endpoint = @host + '/SportsNative/Scores.svc/' + @leagueName + '/' + REPLACE(CAST([date] AS VARCHAR), '-', '/'),
               display = CASE
                             WHEN [date] = @today THEN 'Today'
                             ELSE LEFT(DATENAME(MONTH, [date]), 3) + ' ' + CAST(DAY([date]) AS VARCHAR) +
                                  CASE
                                      WHEN DAY([date]) <> 11 AND (DAY([date]) % 10) = 1 THEN 'st' 
                                      WHEN DAY([date]) <> 12 AND (DAY([date]) % 10) = 2 THEN 'nd'
                                      WHEN DAY([date]) <> 13 AND (DAY([date]) % 10) = 3 THEN 'rd' 
                                      ELSE 'th'
                                  END
                         END
        IF (@leagueName = 'ncaab')
        BEGIN
            UPDATE @swipe
               SET feed_endpoint = feed_endpoint + '/' + @filter
        END
	END

    -- team records    
    UPDATE @events
       SET away_team_record = '(' + dbo.SMG_fn_Team_Records(@leagueName, season_key, away_team_key, event_key) + ')'
     WHERE away_team_last <> 'All-Stars'

    UPDATE @events
       SET home_team_record = '(' + dbo.SMG_fn_Team_Records(@leagueName, season_key, home_team_key, event_key) + ')'
     WHERE home_team_last <> 'All-Stars'
	
    IF (@leagueName = 'mlb')
    BEGIN
 	    DECLARE @stats TABLE
 	    (
		    event_key VARCHAR(100),
		    team_key  VARCHAR(100),
		    [column]  VARCHAR(100),
		    value     VARCHAR(100)
	    )
        DECLARE @rhe TABLE
        (
            event_key VARCHAR(100),
            team_key  VARCHAR(100),
            runs      VARCHAR(100),
            hits      VARCHAR(100),
            errors    VARCHAR(100)
        )	
        INSERT INTO @stats (event_key, team_key, [column], value)
	    SELECT ss.event_key, ss.team_key, ss.column_type, ss.value
	      FROM dbo.SMG_Scores ss
	     INNER JOIN @events e
	        ON e.event_key = ss.event_key
	     WHERE ss.column_type IN ('runs-scored', 'hits', 'errors')

        INSERT INTO @rhe (event_key, team_key, runs, hits, errors)
        SELECT p.event_key, p.team_key, p.[runs-scored], p.hits, p.errors
          FROM (SELECT event_key, team_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([runs-scored], [hits], [errors])) AS p
                                                
        UPDATE e
           SET e.away_team_runs = rhe.runs, e.away_team_hits = rhe.hits, e.away_team_errors = rhe.errors
          FROM @events e
         INNER JOIN @rhe rhe
            ON rhe.event_key = e.event_key AND rhe.team_key = e.away_team_key

        UPDATE e
           SET e.home_team_runs = rhe.runs, e.home_team_hits = rhe.hits, e.home_team_errors = rhe.errors
          FROM @events e
         INNER JOIN @rhe rhe
            ON rhe.event_key = e.event_key AND rhe.team_key = e.home_team_key

        UPDATE @events
           SET away_team_winner = '1', home_team_winner = '0'
         WHERE event_status = 'post-event' AND CAST(away_team_runs AS INT) > CAST(home_team_runs AS INT)

        UPDATE @events
           SET home_team_winner = '1', away_team_winner = '0'
         WHERE event_status = 'post-event' AND CAST(home_team_runs AS INT) > CAST(away_team_runs AS INT)

        UPDATE @events
           SET away_team_score = NULL, home_team_score = NULL
    END
    ELSE
    BEGIN
        UPDATE @events
           SET away_team_winner = '1', home_team_winner = '0'
         WHERE event_status = 'post-event' AND CAST(away_team_score AS INT) > CAST(home_team_score AS INT)

        UPDATE @events
           SET home_team_winner = '1', away_team_winner = '0'
         WHERE event_status = 'post-event' AND CAST(home_team_score AS INT) > CAST(away_team_score AS INT)
    END

    -- RIBBON - POST SEASON
    UPDATE e
       SET e.ribbon = tag.mobile
      FROM @events e
     INNER JOIN dbo.SMG_Event_Tags tag
        ON tag.event_key = e.event_key

    -- ORDER
    IF (@leagueName IN ('nfl', 'ncaaf'))
    BEGIN
        IF (CAST(GETDATE() AS TIME) < '11:00:00')
        BEGIN
            SELECT @today = DATEADD(DAY, -1, @today)
        END
        
        UPDATE @events
           SET date_order = DATEDIFF(DAY, @today, CAST(start_date_time_EST AS DATE))

        IF (@default_week = @week)
        BEGIN        
            UPDATE @events
               SET date_order = (date_order * -7)
             WHERE date_order < 0
        END
    END

    UPDATE @events
       SET status_order = (CASE
	                          WHEN event_status = 'mid-event' THEN 1
                              WHEN event_status = 'intermission' THEN 2
               	              WHEN event_status = 'weather-delay' THEN 3
	                          WHEN event_status = 'post-event' THEN 4
	                          WHEN event_status = 'pre-event' THEN 5
	                          WHEN event_status = 'suspended' THEN 6
	                          WHEN event_status = 'postponed' THEN 7
	                          WHEN event_status = 'canceled' THEN 8
	                      END)

    UPDATE @events
       SET time_order = DATEPART(HOUR, start_date_time_EST) * 100 + DATEPART(MINUTE, start_date_time_EST)
       
    IF (@leagueName IN ('nfl', 'ncaaf', 'wwc') AND @default_week = @week)
    BEGIN
        UPDATE @events
           SET time_order = (time_order * -1)
         WHERE event_status = 'post-event'
    END

    -- game status
    UPDATE @events
       SET game_status = REPLACE(game_status, ' ET', '')


    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
	SELECT @type AS [type], @display AS display,
	       (
	           SELECT 'true' AS 'json:Array',
	                  display, feed_endpoint
	             FROM @swipe
	            WHERE swipe = 'previous'
	            ORDER BY id DESC
	              FOR XML RAW('previous'), TYPE
	       ),
	       (
	           SELECT 'true' AS 'json:Array',
	                  display, feed_endpoint
	             FROM @swipe
	            WHERE swipe = 'next'
	            ORDER BY id ASC
	              FOR XML RAW('next'), TYPE
	       ),
	       (
	           SELECT @current AS [current], @filter AS [default],
	                  (
	                      SELECT 'true' AS 'json:Array', id, display
	                        FROM @filters
	                         FOR XML RAW('filter'), TYPE
	                  )
	              FOR XML RAW('filters'), TYPE
	       ),
	       (
		   SELECT 'true' AS 'json:Array',
		          g.event_date,
	              (
		          SELECT 'true' AS 'json:Array',
		                 e.event_key, e.ribbon, e.game_status, e.event_status, e.odds, e.event_link,
			             (
				         SELECT a_e.away_team_key AS team_key,
						        a_e.away_team_abbr AS abbr,
						        a_e.away_team_logo AS logo,
								a_e.away_team_rank AS [rank],
								a_e.away_team_score AS score,
								a_e.away_team_runs AS runs,
								a_e.away_team_hits AS hits,
								a_e.away_team_errors AS errors,
								a_e.away_team_winner AS winner,
								a_e.away_team_record AS record
						   FROM @events a_e
						  WHERE a_e.event_key = e.event_key
						    FOR XML RAW('away_team'), TYPE                   
						 ),
						 ( 
						 SELECT h_e.home_team_key AS team_key,
						        h_e.home_team_abbr AS abbr,
						        h_e.home_team_logo AS logo,
						        h_e.home_team_rank AS [rank],
						        h_e.home_team_score AS score,
						        h_e.home_team_runs AS runs,
					            h_e.home_team_hits AS hits,
						        h_e.home_team_errors AS errors,
					            h_e.home_team_winner AS winner,
				                h_e.home_team_record AS record
						   FROM @events h_e
						  WHERE h_e.event_key = e.event_key
						    FOR XML RAW('home_team'), TYPE
						 )
					  FROM @events e
					 WHERE e.event_date = g.event_date
					 ORDER BY e.status_order ASC, e.time_order ASC
					   FOR XML RAW('events'), TYPE
		          )
		     FROM @events g
	        GROUP BY g.date_order, g.event_date
	        ORDER BY g.date_order ASC, g.event_date ASC
	          FOR XML RAW('event_dates'), TYPE
	       )
	   FOR XML PATH(''), ROOT('root')
	
END

GO
