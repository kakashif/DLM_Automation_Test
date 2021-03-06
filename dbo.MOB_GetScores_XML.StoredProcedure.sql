USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetScores_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[MOB_GetScores_XML]
   @leagueName VARCHAR(100),
   @seasonKey INT = NULL,
   @subSeasonType VARCHAR(100) = NULL,
   @week VARCHAR(100) = NULL,
   @startDate DATETIME = NULL,
   @filter	VARCHAR(100) = NULL
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 12/02/2013
  -- Description: get scores by date for mobile
  -- Updated:     02/27/2014 - ikenticus: cloning from DES_GetScoes_XML and reshaping data to PDF specs
  --              03/04/2014 - ikenticus: additional modifications discussed in Jira SMW-1, bullets 1-6
  --              03/07/2014 - ikenticus: additional modifications discussed in Jira SMW-1, bullets 7-11
  --              03/25/2014 - John Lin - remove unused fields
  --              03/31/2014 - John Lin - add parentheses to team record
  --              04/21/2014 - John Lin - change NCAAF previous/next
  --              04/25/2014 - John Lin - exclude smg-not-played
  --              05/06/2014 - John Lin - set boxscore link to production
  --              05/28/2014 - John Lin - add Preseason for pre-season
  --              05/30/2014 - John Lin - fix weekly next/previous link
  --              06/20/2014 - John Lin - add odds
  --              06/23/2014 - John Lin - adjustments for All Stars
  --              07/15/2014 - John Lin - always show pre event
  --              07/25/2014 - John Lin - lower case for team key
  --              08/21/2014 - ikenticus - removing NFL pre-season team records
  --              09/03/2014 - ikenticus - updating NCAA logos to whitebg per JIRA SMW-91
  --              09/09/2014 - John Lin - update rank logic
  --              09/12/2014 - John Lin - update display order
  --              09/24/2014 - John Lin - fix bowls week and team TBA
  --              10/10/2014 - John Lin - set ncaab week
  --              11/21/2014 - John Lin - remove ET from game status and second team odds
  --              12/03/2014 - John Lin - whitebg
  --              12/15/2014 - John Lin - add playoffs to ncaaf
  --              12/19/2014 - John Lin - add next and previous display
  --              01/29/2015 - John Lin - rename championship to conference
  --              03/18/2015 - John Lin - modify event link
  --              04/06/2015 - John Lin - add team link
  --              04/22/2015 - John Lin - use mobile ribbon
  --              05/18/2015 - John Lin - add Women's World Cup
  --              06/10/2015 - John Lin - revert modified event link
  --              06/19/2015 - John Lin - add round of 16
  --		 	  07/01/2015 - ikenticus - adjusting to SMG_Polls* conversion
  --              07/10/2015 - John Lin - STATS team records
  --              07/28/2015 - John Lin - MLS All Stars
  --              07/29/2015 - John Lin - SDI migration
  --              08/03/2015 - John Lin - retrieve event_id and logo using functions
  --              09/09/2015 - John Lin - use conference display for NCAA filter
  --              10/14/2015 - John Lin - refactor ncaa
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    IF (@leagueName NOT IN ('mlb', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba',
                            'mls', 'wwc'))
    BEGIN
        SELECT 'invalid league name' AS [message], '400' AS [status]
           FOR XML PATH(''), ROOT('root')

        RETURN
    END

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @sport VARCHAR(100) = 'mens-basketball'
    DECLARE @web_host VARCHAR(100) = 'http://www.usatoday.com/sports/'
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
        away_team_page       VARCHAR(100),
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
        home_team_page       VARCHAR(100),
        level_name           VARCHAR(100),
	    -- info
        away_team_last       VARCHAR(100) DEFAULT '',
        away_team_conference VARCHAR(100),
        home_team_last       VARCHAR(100) DEFAULT '',
        home_team_conference VARCHAR(100),
	    -- extra
        ribbon               VARCHAR(100),
        event_id             VARCHAR(100),
        event_link           VARCHAR(100),
        event_date           DATE,
	    date_order           INT,
	    status_order         INT,
	    time_order           INT
	)
    DECLARE @current VARCHAR(100)
    DECLARE @min_start_date_EST DATETIME
    DECLARE @max_start_date_EST DATETIME
    DECLARE @today DATE = CONVERT(DATE, GETDATE())

    IF (@leagueName = 'nfl')
    BEGIN
        IF (@seasonKey IS NULL OR @subSeasonType IS NULL OR @week IS NULL)
        BEGIN
            RETURN
        END

        SET @current = '/sports/' + @leagueName + '/scores/' + CAST(@seasonKey AS VARCHAR) + '/' + @subSeasonType + '/' + @week + '/'

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

        SELECT @default_week = [week]
          FROM dbo.SMG_Default_Dates
         WHERE league_key = @leagueName AND page = 'scores'
        
        SET @current = '/sports/' + @leagueName + '/scores/' + CAST(@seasonKey AS VARCHAR) + '/' + @week + '/'

        IF (@leagueName = 'wwc')
        BEGIN
            SET @current = '/sports/soccer/' + @leagueName + '/scores/' + CAST(@seasonKey AS VARCHAR) + '/' + @week + '/'
        END

        IF (@leagueName = 'ncaaf')
        BEGIN
            SET @sport = 'football'

            IF (@week = 'bowls')
            BEGIN
                INSERT INTO @events (season_key, event_key, event_status, game_status, odds, start_date_time_EST, [week],
                                     away_team_key, away_team_score, home_team_key, home_team_score)
                SELECT season_key, event_key, event_status, game_status, odds, start_date_time_EST, [week],
                       away_team_key, away_team_score, home_team_key, home_team_score
                  FROM dbo.SMG_Schedules
                 WHERE league_key = @league_key AND season_key = @seasonKey AND [week] = 'playoffs'
            END
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
        SET @current =  '/sports/' + @leagueName + '/scores/' + REPLACE(CAST(CAST(@startDate AS DATE) AS VARCHAR), '-', '/') + '/'
        
        IF (@leagueName = 'mls')
        BEGIN
            SET @current =  '/sports/soccer/' + @leagueName + '/scores/' + REPLACE(CAST(CAST(@startDate AS DATE) AS VARCHAR), '-', '/') + '/'
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
       
    IF (@leagueName IN ('mls', 'wwc'))
    BEGIN
        SET @web_host = 'http://www.usatoday.com/sports/soccer/'
    END

    UPDATE e
       SET e.away_team_abbr = st.team_abbreviation, e.away_team_last = st.team_last, e.away_team_conference = st.conference_key,
           e.away_team_page = @web_host + @leagueName + '/' + st.team_slug
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = e.season_key AND st.team_key = e.away_team_key
     
    UPDATE e
       SET e.home_team_abbr = st.team_abbreviation, e.home_team_last = st.team_last, e.home_team_conference = st.conference_key,
           e.home_team_page = @web_host + @leagueName + '/' + st.team_slug
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = e.season_key AND st.team_key = e.home_team_key

    -- links
    UPDATE e
       SET e.event_link = @web_host + @leagueName + '/event/' + CAST(e.season_key AS VARCHAR) + '/' + e.event_id + '/preview/'
      FROM @events e
      INNER JOIN @coverage c
        ON c.event_key = e.event_key AND c.column_type = 'pre-event-coverage'

    UPDATE @events
       SET event_link = @web_host + @leagueName + '/event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/boxscore/'
     WHERE event_status <> 'pre-event'

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


    -- SEC HACK
    IF (@leagueName IN ('ncaab', 'ncaaw'))
    BEGIN
        SELECT TOP 1 @seasonKey = season_key, @week = [week]
          FROM @events
         ORDER BY start_date_time_EST DESC
    END

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
           SET event_link = 'http://sports.usatoday.com/ncaa/' + @sport + '/event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/boxscore/'
         WHERE '/sport/football/conference:12' IN (away_team_conference, home_team_conference)
    END
    
    -- NCAA HACK    
    IF (@leagueName = 'ncaab')
    BEGIN
        UPDATE e
           SET e.event_link = 'http://sports.usatoday.com/ncaa/mens-basketball/event/' + CAST(e.season_key AS VARCHAR) + '/' + e.event_id + '/preview/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'pre-event-coverage'
         WHERE [week] = 'ncaa' AND [week] = 'ncaa'

        UPDATE @events
           SET event_link = 'http://sports.usatoday.com/ncaa/mens-basketball/event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/boxscore/'
         WHERE event_status <> 'pre-event'
    END

    -- FILTER
    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN        
        DECLARE @poll_week INT
    
        IF (ISNUMERIC(@week) = 1 AND EXISTS (SELECT 1
		                                       FROM SportsEditDB.dbo.SMG_Polls
				                              WHERE league_key = @leagueName AND season_key = @seasonKey AND fixture_key = 'smg-usat' AND [week] = @week))
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
	     	ON sp.league_key = @leagueName AND sp.season_key = e.season_key AND sp.fixture_key = 'smg-usat' AND
		       sp.team_key = e.away_team_abbr AND sp.[week] = @poll_week
              
    	UPDATE e
	       SET e.home_team_rank = sp.ranking
    	  FROM @events e
	     INNER JOIN SportsEditDB.dbo.SMG_Polls sp
		    ON sp.league_key = @leagueName AND sp.season_key = e.season_key AND sp.fixture_key = 'smg-usat' AND
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
       
	DECLARE @type VARCHAR(100) = 'daily'
	DECLARE @previous VARCHAR(100) = NULL
	DECLARE @previous_display VARCHAR(100) = NULL
	DECLARE @next VARCHAR(100) = NULL
	DECLARE @next_display VARCHAR(100) = NULL
	DECLARE @pn_date DATE
	DECLARE @display VARCHAR(100)

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
		                            WHEN @leagueName = 'nfl' AND @subSeasonType = 'pre-season' THEN 'Pre Week ' + @week
		                            ELSE 'Week ' + @week
		                        END)
		               END

	    DECLARE @sub_season_type VARCHAR(100)
	    DECLARE @pn_week VARCHAR(100)
        
        SET @sub_season_type = NULL
        SELECT TOP 1 @sub_season_type = sub_season_type, @pn_week = [week]
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @seasonKey AND start_date_time_EST < @min_start_date_EST
         ORDER BY start_date_time_EST DESC

        IF (@sub_season_type IS NOT NULL)
        BEGIN
            SET @previous = '/sports/' + @leagueName + '/scores/' + CAST(@seasonKey AS VARCHAR) + '/' + @sub_season_type + '/' + @pn_week + '/'
            
            IF (@leagueName = 'ncaaf')
            BEGIN
                SET @previous = '/sports/' + @leagueName + '/scores/' + CAST(@seasonKey AS VARCHAR) + '/' + @pn_week + '/'               
            END

            IF (@leagueName = 'wwc')
            BEGIN
                SET @previous = '/sports/soccer/' + @leagueName + '/scores/' + CAST(@seasonKey AS VARCHAR) + '/' + @pn_week + '/'               
            END

    		SET @previous_display = CASE
	    	                            WHEN @pn_week = 'bowls' THEN 'Bowls'
             		                    WHEN @pn_week = 'playoffs' THEN 'Playoff'
		                                WHEN @pn_week = 'hall-of-fame' THEN 'Hall Of Fame'
		                                WHEN @pn_week = 'wild-card' THEN 'Wild Card'
		                                WHEN @pn_week = 'divisional' THEN 'Divisional'
         		                        WHEN @pn_week = 'conference' THEN 'Conference'
		                                WHEN @pn_week = 'pro-bowl' THEN 'Pro Bowl'
		                                WHEN @pn_week = 'super-bowl' THEN 'Super Bowl'
                                        WHEN @pn_week = 'quarterfinal' THEN 'Quarterfinal'
                                        WHEN @pn_week = 'semifinal' THEN 'Semifinal'
                                        WHEN @pn_week = 'third-place-game' THEN 'Third Place Game'
                                        WHEN @pn_week = 'final' THEN 'Final'
                                        WHEN @pn_week = 'group-stage' THEN 'Group Stage'
		                                WHEN @pn_week = 'round-of-16' THEN 'Round of 16'
		                                ELSE (CASE
		                                         WHEN @leagueName = 'nfl' AND @sub_season_type = 'pre-season' THEN 'Pre Week ' + @pn_week
		                                         ELSE 'Week ' + @pn_week
    		                                 END)
	    	                        END
        END

        SET @sub_season_type = NULL
        SELECT TOP 1 @sub_season_type = sub_season_type, @pn_week = [week]
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @seasonKey AND start_date_time_EST > @max_start_date_EST
         ORDER BY start_date_time_EST ASC

        IF (@sub_season_type IS NULL OR @week = 'playoffs')
        BEGIN
            IF (@week = 'bowls')
            BEGIN
                SET @next = '/sports/' + @leagueName + '/scores/' + CAST(@seasonKey AS VARCHAR) + '/playoffs/'
                SET @next_display = 'Playoff'
            END
        END
        ELSE
        BEGIN
            SET @next = '/sports/' + @leagueName + '/scores/' + CAST(@seasonKey AS VARCHAR) + '/' + @sub_season_type + '/' + @pn_week + '/'
            
            IF (@leagueName = 'ncaaf')
            BEGIN
                SET @next = '/sports/' + @leagueName + '/scores/' + CAST(@seasonKey AS VARCHAR) + '/' + @pn_week + '/'            
            END

            IF (@leagueName = 'wwc')
            BEGIN
                SET @next = '/sports/soccer/' + @leagueName + '/scores/' + CAST(@seasonKey AS VARCHAR) + '/' + @pn_week + '/'            
            END

    		SET @next_display = CASE
	    	                        WHEN @pn_week = 'bowls' THEN 'Bowls'
             		                WHEN @pn_week = 'playoffs' THEN 'Playoff'
		                            WHEN @pn_week = 'hall-of-fame' THEN 'Hall Of Fame'
		                            WHEN @pn_week = 'wild-card' THEN 'Wild Card'
		                            WHEN @pn_week = 'divisional' THEN 'Divisional'
         		                    WHEN @pn_week = 'conference' THEN 'Conference'
		                            WHEN @pn_week = 'pro-bowl' THEN 'Pro Bowl'
		                            WHEN @pn_week = 'super-bowl' THEN 'Super Bowl'
                                    WHEN @pn_week = 'quarterfinal' THEN 'Quarterfinal'
                                    WHEN @pn_week = 'semifinal' THEN 'Semifinal'
                                    WHEN @pn_week = 'third-place-game' THEN 'Third Place Game'
                                    WHEN @pn_week = 'final' THEN 'Final'
		                            WHEN @pn_week = 'group-stage' THEN 'Group Stage'
          		                    WHEN @pn_week = 'round-of-16' THEN 'Round of 16'
		                            ELSE (CASE
		                                     WHEN @leagueName = 'nfl' AND @sub_season_type = 'pre-season' THEN 'Pre Week ' + @pn_week
		                                     ELSE 'Week ' + @pn_week
    		                             END)
	    	                    END
        END
	END
	ELSE
	BEGIN
	    SET @type = 'daily'
        SET @display = CAST(CAST(@startDate AS DATE) AS VARCHAR)

	    SELECT TOP 1 @seasonKey = season_key
	      FROM @events

        IF EXISTS (SELECT 1 start_date_time_EST
                     FROM dbo.SMG_Schedules
                    WHERE league_key = @league_key AND season_key = @seasonKey AND start_date_time_EST < @startDate AND event_status <> 'smg-not-played')
        BEGIN
            SELECT TOP 1 @pn_date = CAST(start_date_time_EST AS DATE)
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @seasonKey AND start_date_time_EST < @startDate AND event_status <> 'smg-not-played'
             ORDER BY start_date_time_EST DESC
        
            SET @previous = '/sports/' + @leagueName + '/scores/' + REPLACE(@pn_date, '-', '/') + '/'
            SET @previous_display = CAST(@pn_date AS VARCHAR)
            
            IF (@leagueName = 'mls')
            BEGIN
                SET @previous = '/sports/soccer/' + @leagueName + '/scores/' + REPLACE(@pn_date, '-', '/') + '/'
            END
        END

        IF EXISTS (SELECT 1 start_date_time_EST
                     FROM dbo.SMG_Schedules
                    WHERE league_key = @league_key AND season_key = @seasonKey AND start_date_time_EST > DATEADD(DAY, 1, @startDate) AND event_status <> 'smg-not-played')
        BEGIN        
            SELECT TOP 1 @pn_date = CAST(start_date_time_EST AS DATE)
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @seasonKey AND start_date_time_EST > DATEADD(DAY, 1, @startDate) AND event_status <> 'smg-not-played'
             ORDER BY start_date_time_EST ASC

            SET @next = '/sports/' + @leagueName + '/scores/' + REPLACE(@pn_date, '-', '/') + '/'
            SET @next_display = CAST(@pn_date AS VARCHAR)

            IF (@leagueName = 'mls')
            BEGIN
                SET @next = '/sports/soccer/' + @leagueName + '/scores/' + REPLACE(@pn_date, '-', '/') + '/'
            END
        END
	END

    -- team records (remove records for NFL pre-season since they are all 0-0)
	IF (NOT(@leagueName = 'nfl' AND @subSeasonType = 'pre-season'))
	BEGIN
		UPDATE @events
		   SET away_team_record = '(' + dbo.SMG_fn_Team_Records(@leagueName, season_key, away_team_key, event_key) + ')'
		 WHERE away_team_last <> 'All-Stars'

		UPDATE @events
		   SET home_team_record = '(' + dbo.SMG_fn_Team_Records(@leagueName, season_key, home_team_key, event_key) + ')'
		 WHERE home_team_last <> 'All-Stars'
	END
	
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
       
    IF (@leagueName IN ('nfl', 'ncaaf') AND @default_week = @week)
    BEGIN
        UPDATE @events
           SET time_order = (time_order * -1)
         WHERE event_status = 'post-event'
    END

    -- game status
    UPDATE @events
       SET game_status = REPLACE(game_status, ' ET', '')
 
    -- odds
    UPDATE @events
       SET odds = SUBSTRING(odds, 1, CHARINDEX(' / ', odds))
     WHERE CHARINDEX(' / ', odds) <> 0
      

	SELECT @type AS [type], @display AS display, @previous AS previous, @previous_display AS previous_display, @next AS [next], @next_display AS next_display,
	       (
	           SELECT @current AS [current], @filter AS [default],
	                  (
	                      SELECT id, display
	                        FROM @filters
	                         FOR XML RAW('filter'), TYPE
	                  )
	              FOR XML RAW('filters'), TYPE
	       ),
	       (
		   SELECT g.event_date,
	              (
		          SELECT e.event_key, e.ribbon, e.game_status, e.event_status, e.odds, e.event_link,
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
								a_e.away_team_record AS record,
								a_e.away_team_page AS team_page
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
				                h_e.home_team_record AS record,
								h_e.home_team_page AS team_page
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
