USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetScores_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DES_GetScores_XML]
   @leagueName VARCHAR(30),
   @seasonKey INT = NULL,
   @subSeasonType VARCHAR(100) = NULL,
   @week VARCHAR(100) = NULL,
   @startDate DATETIME = NULL,
   @filter	VARCHAR(50) = NULL
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 02/21/2014
  -- Description: get scores by date for desktop
  -- Update: 03/18/2014 - John Lin - use charindex
  --         03/31/2014 - John Lin - add parentheses to team record
  --         04/17/2014 - John Lin - backward compatible
  --         04/25/2014 - John Lin - exclude smg-not-played
  --         05/02/2014 - John Lin - double hitter issue
  --         05/09/2014 - John Lin - use SMG_Periods
  --         05/14/2014 - thlam - remove wnba, mls and nhl team links
  --         05/15/2014 - thlam - update the mls and wnba boxscore, preview, and recap link
  --         05/30/2014 - John Lin - lower case for team class
  --         06/17/2014 - John Lin - move SMG_Events_Leaders
  --         06/17/2014 - John Lin - no team link if no conference and division key
  --         06/23/2014 - John Lin - adjustments for All Stars
  --         06/30/2014 - thlam - add stats_link for mls and wnba
  --         08/06/2014 - John Lin - refactor NFL
  --         08/13/2014 - John Lin - add filter to NCAA
  --         08/20/2014 - ikenticus - removing suspicious max week Top 25 poll JOIN
  --         09/09/2014 - John Lin - rewrite suspicious max week logic
  --         09/12/2014 - John Lin - update display order
  --         09/24/2014 - John Lin - fix bowls week  
  --         10/10/2014 - John Lin - set ncaab week
  --         10/10/2014 - John Lin - nhl refactor
  --         12/18/2014 - John Lin - add playoffs
  --         03/03/2015 - ikenticus - SCI-584: NCAA @ Majors
  --         03/18/2015 - John Lin - modify event link
  --         05/19/2015 - ikenticus - adding euro soccer
  --         05/21/2015 - ikenticus - utilize winner_team_key if available
  --         05/27/2015 - John Lin - swap out sprite
  --         06/02/2015 - ikenticus - adding soccer to the date_order logic, hard-coding soccer league_display for now
  --         06/08/2015 - ikenticus - setting correct date_order when "week" is actually more than 7 days
  --	     07/01/2015 - ikenticus - adjusting to SMG_Polls* conversion
  --         07/09/2015 - John Lin - STATS team records
  --         07/28/2015 - John Lin - MLS All Stars
  --	     08/03/2015 - ikenticus - retrieve event_id and logo using functions
  --         09/02/2015 - ikenticus - refactor euro soccer to accept both weekly and daily API calls
  --         09/23/2015 - ikenticus - team_score set to zero when null and mid-event
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
    DECLARE @default_week VARCHAR(100)

	DECLARE @events TABLE
	(
        season_key           INT,
        sub_season_type      VARCHAR(100),
        event_key            VARCHAR(100),
        event_id             VARCHAR(100),
        event_status         VARCHAR(100),
        game_status          VARCHAR(100),
        winner_team_key      VARCHAR(100),
        away_team_key        VARCHAR(100),
        away_team_score      INT,
        away_team_rank       VARCHAR(100),
        away_team_winner     VARCHAR(100),
        away_team_abbr       VARCHAR(100),
        away_team_short      VARCHAR(100),
        away_team_first      VARCHAR(100),
        away_team_last       VARCHAR(100),
        away_team_logo       VARCHAR(100),
        away_team_slug       VARCHAR(100),
        away_team_link       VARCHAR(100),
        away_stat_link       VARCHAR(200),
        away_roster_link     VARCHAR(100),
        away_team_record     VARCHAR(100),        
        home_team_key        VARCHAR(100),
        home_team_score      INT,
        home_team_rank       VARCHAR(100),
        home_team_winner     VARCHAR(100),
        home_team_abbr       VARCHAR(100),
        home_team_short      VARCHAR(100),
        home_team_first      VARCHAR(100),
        home_team_last       VARCHAR(100),
        home_team_logo       VARCHAR(100),
        home_team_slug       VARCHAR(100),
        home_team_link       VARCHAR(100),
        home_stat_link       VARCHAR(200),
        home_roster_link     VARCHAR(100),
        home_team_record     VARCHAR(100),
        start_date_time_EST  DATETIME,
        [week]               VARCHAR(100),
        level_name           VARCHAR(100),
	    -- info
        away_team_conference VARCHAR(100),
        home_team_conference VARCHAR(100),
	    -- extra
        ribbon               VARCHAR(100),
        preview_link         VARCHAR(100),
        boxscore_link        VARCHAR(MAX),
        recap_link           VARCHAR(100),
	    date_order           INT,
	    status_order         INT,
	    time_order           INT
	)

    IF (@leagueName = 'nfl')
    BEGIN
        IF (@seasonKey IS NULL OR @subSeasonType IS NULL OR @week IS NULL)
        BEGIN
            RETURN
        END

        SELECT @default_week = [week]
          FROM dbo.SMG_Default_Dates
         WHERE league_key = 'nfl' AND page = 'scores'

        INSERT INTO @events (season_key, sub_season_type, event_key, event_status, game_status,
                             away_team_key, away_team_score, away_team_rank, away_team_winner,
                             home_team_key, home_team_score, home_team_rank, home_team_winner,
                             winner_team_key, start_date_time_EST, [week], ribbon)
        SELECT season_key, sub_season_type, event_key, event_status, game_status, away_team_key, away_team_score, '', '',
               home_team_key, home_team_score, '', '', winner_team_key, start_date_time_EST, [week], ''
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND [week] = @week        
    END
    ELSE IF (@leagueName = 'ncaaf')
    BEGIN
        IF (@seasonKey IS NULL OR @week IS NULL)
        BEGIN
            RETURN
        END

        SET @sport = 'football'
        
        SELECT @default_week = [week]
          FROM dbo.SMG_Default_Dates
         WHERE league_key = 'ncaaf' AND page = 'scores'

        IF (@week = 'bowls')
        BEGIN
            INSERT INTO @events (season_key, sub_season_type, event_key, event_status, game_status,
                                 away_team_key, away_team_score, away_team_rank, away_team_winner,
                                 home_team_key, home_team_score, home_team_rank, home_team_winner,
                                 winner_team_key, start_date_time_EST, [week], ribbon)
            SELECT season_key, sub_season_type, event_key, event_status, game_status, away_team_key, away_team_score, '', '',
                   home_team_key, home_team_score, '', '', winner_team_key, start_date_time_EST, [week], ''
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @seasonKey AND [week] = 'playoffs'
        END
        
        INSERT INTO @events (season_key, sub_season_type, event_key, event_status, game_status,
                             away_team_key, away_team_score, away_team_rank, away_team_winner,
                             home_team_key, home_team_score, home_team_rank, home_team_winner,
                             winner_team_key, start_date_time_EST, [week], ribbon)
        SELECT season_key, sub_season_type, event_key, event_status, game_status, away_team_key, away_team_score, '', '',
               home_team_key, home_team_score, '', '', winner_team_key, start_date_time_EST, [week], ''
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @seasonKey AND [week] = @week
    END
    ELSE IF (@leagueName IN ('epl', 'champions', 'natl', 'wwc') AND @week IS NOT NULL)
    BEGIN
        IF (@seasonKey IS NULL OR @week IS NULL)
        BEGIN
            RETURN
        END

        SET @sport = 'soccer'
        
        SELECT @default_week = [week]
          FROM dbo.SMG_Default_Dates
         WHERE league_key = @leagueName AND page = 'scores'
        
        INSERT INTO @events (season_key, sub_season_type, event_key, event_status, game_status,
                             away_team_key, away_team_score, away_team_rank, away_team_winner,
                             home_team_key, home_team_score, home_team_rank, home_team_winner,
                             winner_team_key, start_date_time_EST, [week], ribbon)
        SELECT season_key, sub_season_type, event_key, event_status, game_status, away_team_key, away_team_score, '', '',
               home_team_key, home_team_score, '', '', winner_team_key, start_date_time_EST, [week], ''
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

        INSERT INTO @events (season_key, sub_season_type, event_key, event_status, game_status,
                             away_team_key, away_team_score, away_team_rank, away_team_winner,
                             home_team_key, home_team_score, home_team_rank, home_team_winner,
                             winner_team_key, start_date_time_EST, [week], ribbon, level_name)
        SELECT season_key, sub_season_type, event_key, event_status, game_status, away_team_key, away_team_score, '', '',
               home_team_key, home_team_score, '', '', winner_team_key, start_date_time_EST, [week], '', level_name
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND start_date_time_EST BETWEEN @startDate AND @end_date AND event_status <> 'smg-not-played'        
    END

    UPDATE e
       SET e.away_team_abbr = st.team_abbreviation, e.away_team_first = st.team_first, e.away_team_last = st.team_last,
           e.away_team_conference = st.conference_key, e.away_team_slug = st.team_slug
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = e.season_key AND st.team_key = e.away_team_key
     
    UPDATE e
       SET e.home_team_abbr = st.team_abbreviation, e.home_team_first = st.team_first, e.home_team_last = st.team_last,
           e.home_team_conference = st.conference_key, e.home_team_slug = st.team_slug
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

    IF (@leagueName IN ('mlb', 'nba', 'nfl', 'nhl'))
    BEGIN
        UPDATE @events
           SET away_stat_link = '/sports/' + @leagueName + '/' + away_team_slug + '/statistics/',
               home_stat_link = '/sports/' + @leagueName + '/' + home_team_slug + '/statistics/'
    END

    IF (@leagueName IN ('mlb', 'nba', 'nfl', 'nhl', 'wnba'))
    BEGIN
        UPDATE @events
           SET away_roster_link = '/sports/' + @leagueName + '/' + away_team_slug + '/roster/',
               home_roster_link = '/sports/' + @leagueName + '/' + home_team_slug + '/roster/'
    END

    IF (@leagueName IN ('champions', 'natl', 'wwc', 'epl', 'mls'))
    BEGIN
        UPDATE @events
           SET away_roster_link = '/sports/soccer/' + @leagueName + '/' + away_team_slug + '/roster/',
               home_roster_link = '/sports/soccer/' + @leagueName + '/' + home_team_slug + '/roster/'
         WHERE level_name IS NULL
    END

    -- short	
    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw', 'natl', 'wwc'))
    BEGIN
        UPDATE @events
           SET away_team_short = away_team_first, home_team_short = home_team_first
    END
    ELSE
    BEGIN
        UPDATE @events
           SET away_team_short = away_team_last, home_team_short = home_team_last
    END
    
    UPDATE @events
       SET away_team_winner = '1', home_team_winner = '0'
     WHERE event_status = 'post-event' AND away_team_score > home_team_score

    UPDATE @events
       SET home_team_winner = '1', away_team_winner = '0'
     WHERE event_status = 'post-event' AND home_team_score > away_team_score

    UPDATE @events
       SET away_team_winner = '1', home_team_winner = '0'
     WHERE away_team_key = winner_team_key AND away_team_winner = ''

    UPDATE @events
       SET home_team_winner = '1', away_team_winner = '0'
     WHERE home_team_key = winner_team_key AND home_team_winner = ''

    UPDATE @events
       SET away_team_record = '(' + dbo.SMG_fn_Team_Records(@leagueName, season_key, away_team_key, event_key) + ')'
     WHERE away_team_last <> 'All-Stars'
     
    UPDATE @events
       SET home_team_record = '(' + dbo.SMG_fn_Team_Records(@leagueName, season_key, home_team_key, event_key) + ')'
     WHERE home_team_last <> 'All-Stars'

    -- logo
	UPDATE @events
	   SET away_team_logo = dbo.SMG_fnTeamLogo(@leagueName, away_team_abbr, '30'),
		   home_team_logo = dbo.SMG_fnTeamLogo(@leagueName, home_team_abbr, '30')

	IF (@leagueName = 'mls')
	BEGIN
		UPDATE @events
		   SET away_team_logo = dbo.SMG_fnTeamLogo('euro', away_team_abbr, '30')
		 WHERE level_name = 'exhibition'
    END


    IF (@leagueName = 'mlb')
    BEGIN
	-- HACK: pre-season NCAA at Majors (apparently, pre-season is not passed for daily)
    IF EXISTS(SELECT 1 FROM @events WHERE away_team_abbr IS NULL) --AND @subSeasonType = 'pre-season'
	BEGIN
		UPDATE e
		   SET away_team_short = t.team_first
		  FROM @events AS e
		 INNER JOIN dbo.SMG_Teams AS t ON t.team_key = e.away_team_key

		UPDATE @events
		   SET e.away_team_abbr = t.team_abbreviation, e.away_team_short = t.team_abbreviation
		  FROM @events AS e
		 INNER JOIN dbo.SMG_Teams t ON t.team_abbreviation IS NOT NULL AND t.team_abbreviation <> ''
		 WHERE t.team_abbreviation = away_team_first OR t.team_key LIKE '%' + RIGHT(away_team_key, CHARINDEX('.t-', REVERSE(away_team_key)))

        UPDATE @events
           SET away_team_abbr = away_team_short
    END
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
           SET boxscore_link = '/sports/soccer/' + @leagueName + '/event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/boxscore/'

        UPDATE e
           SET e.preview_link = '/sports/soccer/' + @leagueName + '/event/' + CAST(e.season_key AS VARCHAR) + '/' + e.event_id + '/preview/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'pre-event-coverage'

        UPDATE e
           SET e.recap_link = '/sports/soccer/' + @leagueName + '/event/' + CAST(e.season_key AS VARCHAR) + '/' + e.event_id + '/recap/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'post-event-coverage'
    END
    ELSE IF (@leagueName <> 'ncaaw')
    BEGIN
        UPDATE @events
           SET boxscore_link = '/sports/' + @leagueName + '/event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/boxscore/'

        UPDATE e
           SET e.preview_link = '/sports/' + @leagueName + '/event/' + CAST(e.season_key AS VARCHAR) + '/' + e.event_id + '/preview/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'pre-event-coverage'

        UPDATE e
           SET e.recap_link = '/sports/' + @leagueName + '/event/' + CAST(e.season_key AS VARCHAR) + '/' + e.event_id + '/recap/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'post-event-coverage'
    END
   
    -- SEC HACK
    IF (@leagueName IN ('ncaab', 'ncaaf'))
    BEGIN
         UPDATE @events
           SET boxscore_link = boxscore_link + 'top25/',
               preview_link = preview_link + 'top25/',
               recap_link = recap_link + 'top25/'
         WHERE [week] IS NULL OR [week] <> 'ncaa'

        UPDATE @events
           SET boxscore_link = 'http://sports.usatoday.com/ncaa/' + @sport + '/event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/boxscore/'
         WHERE 'c.southeastern' IN (away_team_conference, home_team_conference)

        UPDATE e
           SET e.preview_link = 'http://sports.usatoday.com/ncaa/' + @sport + '/event/' + CAST(e.season_key AS VARCHAR) + '/' + e.event_id + '/preview/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'pre-event-coverage'
         WHERE 'c.southeastern' IN (e.away_team_conference, e.home_team_conference)

        UPDATE e
           SET e.recap_link = 'http://sports.usatoday.com/ncaa/' + @sport + '/event/' + CAST(e.season_key AS VARCHAR) + '/' + e.event_id + '/recap/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'post-event-coverage'
         WHERE 'c.southeastern' IN (e.away_team_conference, e.home_team_conference)
    END

    -- NCAA HACK
    IF (@leagueName = 'ncaab')
    BEGIN
        UPDATE @events
           SET boxscore_link = 'http://sports.usatoday.com/ncaa/mens-basketball/event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/boxscore/'
         WHERE [week] = 'ncaa'

        UPDATE @events
           SET preview_link = 'http://sports.usatoday.com/ncaa/mens-basketball/event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/preview/'
         WHERE [week] = 'ncaa'

        UPDATE e
           SET e.recap_link = 'http://sports.usatoday.com/ncaa/mens-basketball/event/' + CAST(e.season_key AS VARCHAR) + '/' + e.event_id + '/recap/'
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
               sp.team_key = e.away_team_abbr AND e.[week] NOT IN ('playoffs', 'bowls', 'ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi') AND
               sp.[week] = @poll_week
               
        UPDATE e
           SET e.home_team_rank = sp.ranking
          FROM @events e
         INNER JOIN SportsEditDB.dbo.SMG_Polls sp
            ON sp.league_key = @leagueName AND sp.season_key = @seasonKey AND sp.fixture_key = 'smg-usat' AND
               sp.team_key = e.home_team_abbr AND e.[week] NOT IN ('playoffs', 'bowls', 'ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi') AND
               sp.[week] = @poll_week

        
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
	                UPDATE e
        	           SET e.status_order = 1
	                  FROM @events e
	                 INNER JOIN dbo.SMG_Leagues l
	                    ON l.league_key = @league_key AND l.season_key = @seasonKey AND SportsEditDB.dbo.SMG_fnSlugifyName(l.conference_display) = @filter AND
                           l.conference_key IN (e.home_team_conference, e.away_team_conference)
                END
            END
        
            DELETE @events
             WHERE status_order = 0
        END
    END

    -- RIBBON
    -- POST SEASON
    UPDATE e
       SET e.ribbon = tag.score
      FROM @events AS e
     INNER JOIN dbo.SMG_Event_Tags tag
        ON tag.league_key = @league_key AND tag.event_key = e.event_key

    -- LINESCORE
    DECLARE @linescore TABLE
    (
        event_key VARCHAR(100),
        period INT,
        period_value VARCHAR(100),
        away_value VARCHAR(100),
        home_value VARCHAR(100)
    )
    INSERT INTO @linescore (event_key, period, period_value, away_value, home_value)
    SELECT sp.event_key, sp.period, sp.period_value, sp.away_value, sp.home_value
      FROM dbo.SMG_Periods sp
     INNER JOIN @events e
        ON e.event_key = sp.event_key


	-- SCOREBOARD (zero instead of null)
	UPDATE @events
	   SET away_team_score = 0
	 WHERE event_status = 'mid-event' AND home_team_score IS NULL

	UPDATE @events
	   SET home_team_score = 0
	 WHERE event_status = 'mid-event' AND home_team_score IS NULL


    -- LEADERS
    DECLARE @leaders TABLE
    (
        team_key       VARCHAR(100),
        category       VARCHAR(100),
        category_order INT,
        player_value   VARCHAR(100),
        stat_value     VARCHAR(100),
        stat_order     INT,
        event_key      VARCHAR(100)
    )
    
    INSERT INTO @leaders (team_key, category, category_order, player_value, stat_value, stat_order, event_key)
    SELECT sel.team_key, sel.category, sel.category_order, sel.player_value, sel.stat_value, sel.stat_order, e.event_key
      FROM @events e
     INNER JOIN dbo.SMG_Events_Leaders sel
        ON sel.event_key = e.event_key AND sel.team_key IN (e.away_team_key, e.home_team_key)
     WHERE e.event_status <> 'pre-event'
    

    -- ORDER
    IF (@leagueName IN ('nfl', 'ncaaf', 'wwc', 'natl', 'epl', 'champions'))
    BEGIN
        DECLARE @today DATETIME = CONVERT(DATE, GETDATE())
		DECLARE @max_order INT

        IF (CAST(GETDATE() AS TIME) < '11:00:00')
        BEGIN
            SELECT @today = DATEADD(DAY, -1, @today)
        END
        
        UPDATE @events
           SET date_order = DATEDIFF(DAY, @today, CAST(start_date_time_EST AS DATE))

		SELECT @max_order = MAX(date_order)
		  FROM @events

        IF (@default_week = @week)
        BEGIN        
            UPDATE @events
               SET date_order = (date_order * -@max_order + 1)
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
	                      END)

    UPDATE @events
       SET time_order = DATEPART(HOUR, start_date_time_EST) * 100 + DATEPART(MINUTE, start_date_time_EST)
       
    IF (@leagueName IN ('nfl', 'ncaaf') AND @default_week = @week)
    BEGIN
        UPDATE @events
           SET time_order = (time_order * -1)
         WHERE event_status = 'post-event'
    END
	

	-- Football possession
	DECLARE @possession TABLE
	(
		event_key VARCHAR(100),
		team_key VARCHAR(100),
		team_value VARCHAR(100),
		stat_value VARCHAR(100)
	)

	IF (@leagueName IN ('nfl', 'ncaaf')) 
	BEGIN
		INSERT INTO @possession (event_key, team_key, team_value, stat_value)
		SELECT e.event_key, et.target_key, et.target_value, et.stat_value
		  FROM @events e
		 INNER JOIN SportsEditDB.dbo.SMG_Events_Transient et
			ON et.event_key = e.event_key AND category = 'possession'
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
               e.preview_link, e.boxscore_link, e.recap_link,
               (
                   SELECT ls.period_value AS periods
                     FROM @linescore ls
                    WHERE ls.event_key = e.event_key
                    ORDER BY period ASC
                      FOR XML PATH(''), TYPE
               ),
               (
	               SELECT l.category, 
	                      (
	                          SELECT a_l.player_value, a_l.stat_value
	                            FROM @leaders a_l
	                           WHERE a_l.category_order = l.category_order AND a_l.event_key = e.event_key AND a_l.team_key = e.away_team_key
	                           ORDER BY a_l.stat_order ASC
	                             FOR XML PATH('away_team'), TYPE
	                      ),
	                      (
	                          SELECT h_l.player_value, h_l.stat_value
	                            FROM @leaders h_l
	                           WHERE h_l.category_order = l.category_order AND h_l.event_key = e.event_key AND h_l.team_key = e.home_team_key
	                           ORDER BY h_l.stat_order ASC
	                             FOR XML PATH('home_team'), TYPE
	                      )
                     FROM @leaders l
                    WHERE l.event_key = e.event_key
                    GROUP BY l.category, l.category_order
                    ORDER BY l.category_order ASC
                      FOR XML RAW('leaders'), TYPE
               ),
			   (
			       SELECT a_e.away_team_key AS team_key,
			              a_e.away_team_abbr AS team_abbr,
			              a_e.away_team_short AS short_name,
			              a_e.away_team_first AS team_first,
			              a_e.away_team_last AS team_last,
                          a_e.away_team_logo AS team_logo,
                          a_e.away_team_rank AS team_rank,
                          a_e.away_team_score AS team_score,
                          a_e.away_team_winner AS team_winner,
                          a_e.away_team_record AS team_record,                          
                          a_e.away_team_link AS team_link,
                          a_e.away_stat_link AS stat_link,
                          a_e.away_roster_link AS roster_link,
                          (
                              SELECT a_ls.away_value AS sub_score
                                FROM @linescore a_ls
                               WHERE a_ls.event_key = e.event_key
                               ORDER BY a_ls.period ASC
                                 FOR XML PATH(''), TYPE
                          ),
						  (
							  SELECT '1' AS possession
								FROM @possession AS p
							   WHERE p.event_key = e.event_key AND p.team_key = e.away_team_key
								 FOR XML PATH(''), TYPE
						  )
                     FROM @events a_e
                    WHERE a_e.event_key = e.event_key
                      FOR XML RAW('away_team'), TYPE                   
			   ),
			   ( 
			       SELECT h_e.home_team_key AS team_key,
			              h_e.home_team_abbr AS team_abbr,
			              h_e.home_team_short AS short_name,
			              h_e.home_team_first AS team_first,
			              h_e.home_team_last AS team_last,
                          h_e.home_team_logo AS team_logo,
                          h_e.home_team_rank AS team_rank,
                          h_e.home_team_score AS team_score,
                          h_e.home_team_winner AS team_winner,
                          h_e.home_team_record AS team_record,                          
                          h_e.home_team_link AS team_link,
                          h_e.home_stat_link AS stat_link,
                          h_e.home_roster_link AS roster_link,
                          (
                              SELECT h_ls.home_value AS sub_score
                                FROM @linescore h_ls
                               WHERE h_ls.event_key = e.event_key
                               ORDER BY h_ls.period ASC
                                 FOR XML PATH(''), TYPE
                          ),
						  (
							  SELECT '1' AS possession
								FROM @possession AS p
							   WHERE p.event_key = e.event_key AND p.team_key = e.home_team_key
								 FOR XML PATH(''), TYPE
                          )
                     FROM @events h_e
                    WHERE h_e.event_key = e.event_key
                      FOR XML RAW('home_team'), TYPE
               )
          FROM @events e
         ORDER BY e.date_order ASC, e.status_order ASC, e.time_order ASC
           FOR XML RAW('score'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

END


GO
