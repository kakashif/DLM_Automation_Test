USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetSchedules_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DES_GetSchedules_XML]
   @leagueName VARCHAR(30),
   @seasonKey INT = NULL,
   @subSeasonType VARCHAR(100) = NULL,
   @week VARCHAR(100) = NULL,
   @startDate DATETIME = NULL,
   @filter VARCHAR(50) = NULL
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 03/17/2014
  -- Description: get schedules by date for desktop
  -- Update: 03/31/2014 - John Lin - add parentheses to team record
  --         04/17/2014 - John Lin - backward compatible
  --         04/25/2014 - thlam - updating the matchup link for mlb
  --                    - pkamat - add home team and away team names for ticketcity
  --                    - John Lin - exclude smg-not-played
  --         05/14/2014 - thlam - remove wnba, mls and nhl team links
  --         05/15/2014 - thlam - update the mls, wnba boxscore, preview, and recap link
  --         05/30/2014 - John Lin - lower case for team class
  --         08/06/2014 - John Lin - refactor NFL
  --         08/13/2014 - John Lin - add filter to NCAA
  --         10/10/2014 - John Lin - nhl refactor
  --         12/18/2014 - John Lin - add playoffs
  --         01/29/2015 - John Lin - rename championship to conference
  --         03/18/2015 - John Lin - modify event link
  --         05/20/2015 - ikenticus - adding odds and euro soccer (exclude from padding)
  --         05/27/2015 - John Lin - swap out sprite
  --         06/02/2015 - ikenticus - hard-coding soccer league_display for now
  --         06/03/2015 - ikenticus - update coverage_link to link_coverage to match team schedule refactor
  --         06/30/2015 - John Lin - fix issues
  --	     07/01/2015 - ikenticus - adjusting to SMG_Polls* conversion
  --         07/09/2015 - John Lin - STATS team records
  --         07/28/2015 - John Lin - MLS All Stars
  --         07/29/2015 - John Lin - SDI migration
  --	     08/03/2015 - John Lin - retrieve event_id and logo using functions
  --         09/02/2015 - ikenticus - refactor euro soccer to accept both weekly and daily API calls
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    IF (@leagueName NOT IN ('mlb', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba',
							'champions', 'natl', 'wwc', 'epl', 'mls'))
    BEGIN
        RETURN
    END
    

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @sport VARCHAR(100) = 'mens-basketball'

	DECLARE @events TABLE
	(
        season_key           INT,
        event_key            VARCHAR(100),
        event_id             VARCHAR(100),
        event_status         VARCHAR(100),
        game_status          VARCHAR(100),
        tv_coverage          VARCHAR(100),
        away_team_key        VARCHAR(100),
        away_team_score      INT,
        away_team_rank       VARCHAR(100),
        away_team_winner     VARCHAR(100),
        away_team_abbr       VARCHAR(100),
        away_team_name       VARCHAR(100),
        away_team_short      VARCHAR(100),
        away_team_logo       VARCHAR(100),
        away_team_slug       VARCHAR(100),        
        away_team_link       VARCHAR(100),
        away_team_record     VARCHAR(100),        
        home_team_key        VARCHAR(100),
        home_team_score      INT,
        home_team_rank       VARCHAR(100),
        home_team_winner     VARCHAR(100),
        home_team_abbr       VARCHAR(100),
        home_team_name       VARCHAR(100),
        home_team_logo       VARCHAR(100),
        home_team_slug       VARCHAR(100),        
        home_team_link       VARCHAR(100),
        home_team_record     VARCHAR(100),
        odds                 VARCHAR(100),
        start_date_time_EST  DATETIME,
        [week]               VARCHAR(100),
        level_name           VARCHAR(100),
	    -- info
        away_team_conference VARCHAR(100),
        home_team_conference VARCHAR(100),
	    -- extra
        ribbon               VARCHAR(100),
        link_preview         VARCHAR(100),
        link_boxscore        VARCHAR(MAX),
        link_recap           VARCHAR(100),
        ribbon_order         INT
	)

    IF (@leagueName = 'nfl')
    BEGIN
        IF (@seasonKey IS NULL OR @subSeasonType IS NULL OR @week IS NULL)
        BEGIN
            RETURN
        END

        IF (@week = 'all')
        BEGIN
            INSERT INTO @events (season_key, event_key, event_status, game_status, tv_coverage, start_date_time_EST, [week],
                                 away_team_key, away_team_score, home_team_key, home_team_score, odds)
            SELECT season_key, event_key, event_status, game_status, tv_coverage, start_date_time_EST, [week],
                   away_team_key, away_team_score, home_team_key, home_team_score, odds
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType
        END
        ELSE
        BEGIN
            INSERT INTO @events (season_key, event_key, event_status, game_status, tv_coverage, start_date_time_EST, [week],
                                 away_team_key, away_team_score, home_team_key, home_team_score, odds)
            SELECT season_key, event_key, event_status, game_status, tv_coverage, start_date_time_EST, [week],
                   away_team_key, away_team_score, home_team_key, home_team_score, odds
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND [week] = @week
        END 
    END
    ELSE IF (@leagueName = 'ncaaf')
    BEGIN
        IF (@seasonKey IS NULL OR @week IS NULL)
        BEGIN
            RETURN
        END

        SET @sport = 'football'
        
        IF (@week = 'all')
        BEGIN
            INSERT INTO @events (season_key, event_key, event_status, game_status, tv_coverage, start_date_time_EST, [week],
                                 away_team_key, away_team_score, home_team_key, home_team_score, odds)
            SELECT season_key, event_key, event_status, game_status, tv_coverage, start_date_time_EST, [week],
                   away_team_key, away_team_score, home_team_key, home_team_score, odds
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @seasonKey AND [week] NOT IN ('bowls', 'playoffs')
        END
        ELSE
        BEGIN
            IF (@week = 'bowls')
            BEGIN
                INSERT INTO @events (season_key, event_key, event_status, game_status, tv_coverage, start_date_time_EST, [week],
                                     away_team_key, away_team_score, home_team_key, home_team_score, odds)
                SELECT season_key, event_key, event_status, game_status, tv_coverage, start_date_time_EST, [week],
                       away_team_key, away_team_score, home_team_key, home_team_score, odds
                  FROM dbo.SMG_Schedules
                 WHERE league_key = @league_key AND season_key = @seasonKey AND [week] = 'playoffs'
            END
            
            INSERT INTO @events (season_key, event_key, event_status, game_status, tv_coverage, start_date_time_EST, [week],
                                 away_team_key, away_team_score, home_team_key, home_team_score, odds)
            SELECT season_key, event_key, event_status, game_status, tv_coverage, start_date_time_EST, [week],
                   away_team_key, away_team_score, home_team_key, home_team_score, odds
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @seasonKey AND [week] = @week
        END         
    END
    ELSE IF (@leagueName IN ('epl', 'champions', 'natl', 'wwc') AND @week IS NOT NULL)
    BEGIN
        IF (@seasonKey IS NULL OR @week IS NULL)
        BEGIN
            RETURN
        END

        SET @sport = 'soccer'
                      
		INSERT INTO @events (season_key, event_key, event_status, game_status, tv_coverage, start_date_time_EST, [week],
							 away_team_key, away_team_score, home_team_key, home_team_score, odds)
		SELECT season_key, event_key, event_status, game_status, tv_coverage, start_date_time_EST, [week],
			   away_team_key, away_team_score, home_team_key, home_team_score, odds
		  FROM dbo.SMG_Schedules
		 WHERE league_key = @league_key AND season_key = @seasonKey AND [week] = @week     
    END
    ELSE
    BEGIN
        IF (@startDate IS NULL)
        BEGIN
            RETURN
        END
        
        DECLARE @end_date DATETIME = DATEADD(SECOND, -1, DATEADD(WEEK, 1, @startDate))

        INSERT INTO @events (season_key, event_key, event_status, game_status, tv_coverage, start_date_time_EST, [week],
                             away_team_key, away_team_score, home_team_key, home_team_score, odds, level_name)
        SELECT season_key, event_key, event_status, game_status, tv_coverage, start_date_time_EST, [week],
               away_team_key, away_team_score, home_team_key, home_team_score, odds, level_name
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND start_date_time_EST BETWEEN @startDate AND @end_date AND event_status <> 'smg-not-played'        
    END

    UPDATE e
       SET e.away_team_abbr = st.team_abbreviation, e.away_team_conference = st.conference_key,
     	   e.away_team_name = st.team_first + ' ' + st.team_last, e.away_team_slug = st.team_slug
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = e.season_key AND st.team_key = e.away_team_key
     
    UPDATE e
       SET e.home_team_abbr = st.team_abbreviation, e.home_team_conference = st.conference_key,
           e.home_team_name = st.team_first + ' ' + st.team_last, e.home_team_slug = st.team_slug
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = e.season_key AND st.team_key = e.home_team_key
    
    -- link
    IF (@leagueName IN ('mlb', 'nba', 'ncaaf', 'nfl'))
    BEGIN
        UPDATE @events
           SET away_team_link = '/sports/' + @leagueName + '/' + away_team_slug + '/',
               home_team_link = '/sports/' + @leagueName + '/' + home_team_slug + '/'     
    END

    UPDATE @events
       SET away_team_winner = '1', home_team_winner = '0'
     WHERE event_status = 'post-event' AND away_team_score > home_team_score

    UPDATE @events
       SET home_team_winner = '1', away_team_winner = '0'
     WHERE event_status = 'post-event' AND home_team_score > away_team_score

    UPDATE @events
       SET away_team_record = '(' + dbo.SMG_fn_Team_Records(@leagueName, season_key, away_team_key, event_key) + ')'

    UPDATE @events
       SET home_team_record = '(' + dbo.SMG_fn_Team_Records(@leagueName, season_key, home_team_key, event_key) + ')'
	
    -- logo
	UPDATE @events
	   SET away_team_logo = dbo.SMG_fnTeamLogo(@leagueName, away_team_abbr, '30'),
		   home_team_logo = dbo.SMG_fnTeamLogo(@leagueName, home_team_abbr, '30')

    IF (@leagueName = 'mls')
    BEGIN
        UPDATE @events
           SET away_team_logo = dbo.SMG_fnTeamLogo('champions', away_team_abbr, '30')
         WHERE level_name = 'exhibition'
    END


    -- LINKS
	DECLARE @coverage TABLE (
		event_key VARCHAR(100),
		column_type VARCHAR(100)
	)
	
	INSERT INTO @coverage (event_key, column_type)
	SELECT ss.event_key, ss.column_type
	  FROM dbo.SMG_Scores ss
	 INNER JOIN @events e
	    ON e.event_key = ss.event_key
	 WHERE ss.column_type IN ('pre-event-coverage', 'post-event-coverage')

    -- event id
    UPDATE @events
       SET event_id = dbo.SMG_fnEventId(event_key)
     
    IF (@leagueName IN ('champions', 'epl', 'mls', 'natl', 'wwc'))
    BEGIN
        UPDATE @events
           SET link_boxscore = '/sports/soccer/' + @leagueName + '/event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/boxscore/'

        UPDATE e
           SET link_preview = '/sports/soccer/' + @leagueName + '/event/' + CAST(e.season_key AS VARCHAR) + '/' + e.event_id + '/preview/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'pre-event-coverage'

        UPDATE e
           SET link_recap = '/sports/soccer/' + @leagueName + '/event/' + CAST(e.season_key AS VARCHAR) + '/' + e.event_id + '/recap/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'post-event-coverage'
    END
    ELSE IF (@leagueName <> 'ncaaw')
    BEGIN
        UPDATE @events
           SET link_boxscore = '/sports/' + @leagueName + '/event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/boxscore/'

        UPDATE e
           SET link_preview = '/sports/' + @leagueName + '/event/' + CAST(e.season_key AS VARCHAR) + '/' + e.event_id + '/preview/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'pre-event-coverage'

        UPDATE e
           SET link_recap = '/sports/' + @leagueName + '/event/' + CAST(e.season_key AS VARCHAR) + '/' + e.event_id + '/recap/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'post-event-coverage'
    END
    
    -- SEC HACK
    IF (@leagueName IN ('ncaab', 'ncaaf'))
    BEGIN
         UPDATE @events
           SET link_boxscore = link_boxscore + 'top25/',
               link_preview = link_preview + 'top25/',
               link_recap = link_recap + 'top25/'
         WHERE [week] IS NULL OR [week] <> 'ncaa'

        UPDATE @events
           SET link_boxscore = 'http://sports.usatoday.com/ncaa/' + @sport + '/event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/boxscore/'
         WHERE 'c.southeastern' IN (away_team_conference, home_team_conference)

        UPDATE e
           SET link_preview = 'http://sports.usatoday.com/ncaa/' + @sport + '/event/' + CAST(e.season_key AS VARCHAR) + '/' + e.event_id + '/preview/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'pre-event-coverage'
         WHERE 'c.southeastern' IN (e.away_team_conference, e.home_team_conference)

        UPDATE e
           SET link_recap = 'http://sports.usatoday.com/ncaa/' + @sport + '/event/' + CAST(e.season_key AS VARCHAR) + '/' + e.event_id + '/recap/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'post-event-coverage'
         WHERE 'c.southeastern' IN (e.away_team_conference, e.home_team_conference)
    END

    -- NCAA HACK
    IF (@leagueName = 'ncaab')
    BEGIN
        UPDATE @events
           SET link_boxscore = 'http://sports.usatoday.com/ncaa/mens-basketball/event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/boxscore/'
         WHERE [week] = 'ncaa'

        UPDATE @events
           SET link_preview = 'http://sports.usatoday.com/ncaa/mens-basketball/event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/preview/'
         WHERE [week] = 'ncaa'

        UPDATE e
           SET link_recap = 'http://sports.usatoday.com/ncaa/mens-basketball/event/' + CAST(e.season_key AS VARCHAR) + '/' + e.event_id + '/recap/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'post-event-coverage'
         WHERE [week] = 'ncaa'
    END


    -- FILTER
    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        IF (@leagueName IN ('ncaab', 'ncaaw'))
        BEGIN
            SELECT TOP 1 @seasonKey = season_key
              FROM @events
             ORDER BY season_key DESC
        END

        -- assume no poll
        DECLARE @max_week INT
             
        SELECT TOP 1 @max_week = [week]
          FROM SportsEditDB.dbo.SMG_Polls
         WHERE league_key = @leagueName AND season_key = @seasonKey AND fixture_key = 'smg-usat'
         ORDER BY [week] DESC
        
        -- set to max week
        UPDATE e
           SET e.away_team_rank = sp.ranking
          FROM @events e
         INNER JOIN SportsEditDB.dbo.SMG_Polls sp
            ON sp.league_key = @leagueName AND sp.season_key = @seasonKey AND sp.fixture_key = 'smg-usat' AND
               sp.team_key = e.away_team_abbr AND e.[week] NOT IN ('playoffs', 'bowls', 'ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi') AND
               sp.[week] = @max_week
               
        UPDATE e
           SET e.home_team_rank = sp.ranking
          FROM @events e
         INNER JOIN SportsEditDB.dbo.SMG_Polls sp
            ON sp.league_key = @leagueName AND sp.season_key = @seasonKey AND sp.fixture_key = 'smg-usat' AND
               sp.team_key = e.home_team_abbr AND e.[week] NOT IN ('playoffs', 'bowls', 'ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi') AND
               sp.[week] = @max_week

        -- set to correct week 
        UPDATE e
           SET e.away_team_rank = sp.ranking
          FROM @events e
         INNER JOIN SportsEditDB.dbo.SMG_Polls sp
            ON sp.league_key = @leagueName AND sp.season_key = @seasonKey AND sp.fixture_key = 'smg-usat' AND
               sp.team_key = e.away_team_abbr AND e.[week] NOT IN ('playoffs', 'bowls', 'ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi') AND
               sp.[week] =  CAST(e.[week] AS INT)
               
        UPDATE e
           SET e.home_team_rank = sp.ranking
          FROM @events e
         INNER JOIN SportsEditDB.dbo.SMG_Polls sp
            ON sp.league_key = @leagueName AND sp.season_key = @seasonKey AND sp.fixture_key = 'smg-usat' AND
               sp.team_key = e.home_team_abbr AND e.[week] NOT IN ('playoffs', 'bowls', 'ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi') AND
               sp.[week] =  CAST(e.[week] AS INT)
        
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
        
        IF (@filter NOT IN ('div1.a', 'div1'))
        BEGIN
            UPDATE @events
               SET ribbon_order = 0

            IF (@filter = 'tourney')
            BEGIN
                UPDATE @events
                   SET ribbon_order = 1
                 WHERE [week] IN ('ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi')
            END
            ELSE IF (@filter IN ('ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi'))
            BEGIN
                UPDATE @events
                   SET ribbon_order = 1
                 WHERE [week] = @filter
            END
            ELSE
            BEGIN
                IF (@filter = 'top25')
                BEGIN
                    UPDATE @events
                       SET ribbon_order = 1
                     WHERE (CAST (ISNULL(NULLIF(home_team_rank, ''), '0') AS INT) + CONVERT(INT, ISNULL(NULLIF(away_team_rank, ''), '0'))) > 0
                END
                ELSE
    	        BEGIN
	                UPDATE e
        	           SET e.ribbon_order = 1
	                  FROM @events e
	                 INNER JOIN dbo.SMG_Leagues l
	                    ON l.league_key = @league_key AND l.season_key = @seasonKey AND SportsEditDB.dbo.SMG_fnSlugifyName(l.conference_display) = @filter AND
	                       l.conference_key IN (e.home_team_conference, e.away_team_conference)
                END

                UPDATE @events
                   SET ribbon_order = 0
                 WHERE [week] IN ('ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi')                
            END
        
            DELETE @events
             WHERE ribbon_order = 0
        END
    END

    -- RIBBON
    -- POST SEASON
    UPDATE @events
       SET ribbon_order = 0

    IF (@leagueName IN ('nfl', 'ncaaf'))
    BEGIN
        UPDATE @events
           SET ribbon = 'WEEK ' + [week], ribbon_order = CAST([week] AS INT)
         WHERE [week] NOT IN ('hall-of-fame', 'wild-card', 'divisional', 'conference', 'pro-bowl', 'super-bowl', 'bowls', 'playoffs')
    END
       
    UPDATE e
       SET e.ribbon = tag.schedule, e.ribbon_order = CASE
                                                         WHEN e.[week] = 'hall-of-fame' THEN 0
	                                                     WHEN e.[week] = 'wild-card' THEN 1
	                                                     WHEN e.[week] = 'divisional' THEN 2
   	                                                     WHEN e.[week] = 'conference' THEN 3
	                                                     WHEN e.[week] = 'pro-bowl' THEN 4
	                                                     WHEN e.[week] = 'super-bowl' THEN 4
                                                         WHEN e.[week] = 'ncaa' THEN 1
                                                         WHEN e.[week] = 'nit' THEN 2
                                                         WHEN e.[week] = 'wnit' THEN 2
                                                         WHEN e.[week] = 'cbi' THEN 3
                                                         WHEN e.[week] = 'wbi' THEN 3
                                                         WHEN e.[week] = 'cit' THEN 4
	                                                     WHEN CHARINDEX('1st Round', tag.schedule) > 0 THEN 1
	                                                     WHEN CHARINDEX('Conference Quarterfinals', tag.schedule) > 0 THEN 1
	                                                     WHEN CHARINDEX('Division Series', tag.schedule) > 0 THEN 2
	                                                     WHEN CHARINDEX('Conference Semifinals', tag.schedule) > 0 THEN 2	                                                    
	                                                     WHEN CHARINDEX('League Championship Series', tag.schedule) > 0 THEN 3
	                                                     WHEN CHARINDEX('Conference Finals', tag.schedule) > 0 THEN 3
	                                                     WHEN tag.schedule = 'World Series' THEN 4
	                                                     WHEN tag.schedule = 'NBA Finals' THEN 4
	                                                     WHEN tag.schedule = 'NHL Stanley Cup Finals' THEN 4
	                                                     WHEN tag.schedule = 'MLS Cup' THEN 4
	                                                     WHEN tag.schedule = 'WNBA Finals' THEN 4
                                                         ELSE 0
                                                     END
      FROM @events AS e
     INNER JOIN dbo.SMG_Event_Tags tag
        ON tag.league_key = @league_key AND tag.event_key = e.event_key


    -- PADDING
    IF (@leagueName NOT IN ('nfl', 'ncaaf', 'natl', 'wwc', 'epl', 'champions'))
    BEGIN
        DECLARE @pad_max INT = 7
        DECLARE @pad_num INT = 0
      
        DECLARE @dates TABLE
        (
            event_date DATETIME,
            pad_num INT,
            ribbon VARCHAR(100),
            ribbon_order INT
        )
        
        WHILE (@pad_num < @pad_max)
        BEGIN
            INSERT INTO @dates(event_date, pad_num, ribbon, ribbon_order)
            VALUES(DATEADD(DAY, @pad_num, @startDate), @pad_num, '', 0)
            
            SET @pad_num = @pad_num + 1
        END
        
        UPDATE d
           SET d.pad_num = 99, d.ribbon = e.ribbon, d.ribbon_order = e.ribbon_order
          FROM @dates d
         INNER JOIN @events e
            ON CONVERT(DATE, e.start_date_time_EST) = CONVERT(DATE, d.event_date)
        
        IF EXISTS (SELECT 1 FROM @dates WHERE ribbon <> '')
        BEGIN    
            UPDATE d_new
               SET d_new.ribbon = (SELECT TOP 1 d_old.ribbon
                                     FROM @dates d_old
                                    WHERE d_old.ribbon <> '' AND d_old.event_date = d_new.event_date
                                    ORDER BY d_old.event_date DESC)
              FROM @dates d_new
             WHERE d_new.pad_num < 99 AND d_new.ribbon = ''
             
            UPDATE d
               SET d.ribbon_order = e.ribbon_order
              FROM @dates d
             INNER JOIN @events e
                ON e.ribbon = d.ribbon
        END

  	    INSERT INTO @events (start_date_time_EST, event_key, event_status, ribbon, ribbon_order)
        SELECT event_date, CONVERT(VARCHAR(100), pad_num), 'padding', ribbon, ribbon_order
          FROM @dates
         WHERE pad_num < 99
    END


	DECLARE @league_display VARCHAR(100)

	SET @league_display = CASE
								WHEN @leagueName = 'champions' THEN 'Champions League'
								WHEN @leagueName = 'wwc' THEN 'Women''s World Cup'
								WHEN @leagueName = 'natl' THEN 'World Cup'
								WHEN @leagueName IN ('epl', 'mls') THEN UPPER(@leagueName)
						  END

    SELECT @league_display AS league_display,
	(
        SELECT e.event_key, e.event_status, e.ribbon, e.start_date_time_EST, e.game_status,
               e.link_preview, e.link_boxscore, e.link_recap, e.tv_coverage, e.odds,
			   (
			       SELECT a_e.away_team_key AS team_key,
			              a_e.away_team_abbr AS team_abbr,
			              a_e.away_team_name AS team_name,
			              a_e.away_team_short AS short_name,
                          a_e.away_team_logo AS team_logo,
                          a_e.away_team_rank AS team_rank,
                          a_e.away_team_score AS team_score,
                          a_e.away_team_winner AS team_winner,
                          a_e.away_team_record AS team_record,                          
                          a_e.away_team_link AS team_link
                     FROM @events a_e
                    WHERE a_e.event_key = e.event_key
                      FOR XML RAW('away_team'), TYPE                   
			   ),
			   ( 
			       SELECT h_e.home_team_key AS team_key,
			              h_e.home_team_abbr AS team_abbr,
			              h_e.home_team_name AS team_name,
                          h_e.home_team_logo AS team_logo,
                          h_e.home_team_rank AS team_rank,
                          h_e.home_team_score AS team_score,
                          h_e.home_team_winner AS team_winner,
                          h_e.home_team_record AS team_record,                          
                          h_e.home_team_link AS team_link
                     FROM @events h_e
                    WHERE h_e.event_key = e.event_key
                      FOR XML RAW('home_team'), TYPE
               )
          FROM @events e
         ORDER BY e.ribbon_order ASC, e.start_date_time_EST ASC
           FOR XML RAW('schedule'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

END

GO
