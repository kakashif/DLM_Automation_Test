USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetSuspender_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DES_GetSuspender_XML] 
    @leagueName VARCHAR(100)
AS
-- =============================================
-- Author:      John Lin
-- Create date: 02/19/2014
-- Description: get suspender for a given league name
-- Update:      02/21/2014 - cchiu   -  updated links for NBA, NHL
--              03/18/2014 - John Lin - ncaa post season link to bracket
--              03/31/2014 - thlam - combined the matchup link for NBA and NHL
--              04/03/2014 - John Lin - use Editorial seed for NCAA basketball
--              04/23/2014 - John Lin - add olympics
--              04/25/2014 - thlam - add matchup link for mlb
--                         - John Lin - exclude smg-not-played
--              05/08/2014 - thlam - remove the mls and wnba team link
--              05/14/2014 - thlam - remove nhl team link
--              05/15/2014 - thlam - update the mls and wnba boxscore, preview, and recap link
--              05/20/2014 - John Lin - update nhl boxscore, preview and recap
--              05/30/2014 - John Lin - lower case for team class
--              07/28/2014 - John Lin - fix some logic issues
--              08/06/2014 - John Lin - refactor NFL
--              08/13/2014 - John Lin - add filter to NCAA
--              09/15/2014 - John Lin - NCAAF SEC link off
--              10/10/2014 - John Lin - nhl refactor
--              03/18/2015 - John Lin - modify event link
--              05/27/2015 - John Lin - swap out sprite
--              06/30/2015 - John Lin - fix issue
--		   		07/01/2015 - ikenticus - adjusting to SMG_Polls* conversion
--              07/16/2015 - John Lin - override via SMG_Default_Dates
--              07/28/2015 - John Lin - MLS All Stars
--              07/29/2015 - John Lin - SDI migration
--              08/03/2015 - John Lin - retrieve event_id and logo using functions
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    DECLARE @season_key INT

	IF (@leagueName = 'golf')
	BEGIN
	    DECLARE @event_key VARCHAR(100)
	    
	    SELECT @season_key = season_key, @event_key = [week]
	      FROM dbo.SMG_Default_Dates
	     WHERE league_key = 'pga-tour' AND page = 'source'	     

        IF (@season_key IS NOT NULL AND @event_key IS NOT NULL)
        BEGIN
            EXEC dbo.DES_Suspender_Golf_XML @season_key, @event_key
        END
        ELSE
        BEGIN
            EXEC dbo.SMG_GetSuspenderGolf_XML 'R'
		END
		
		RETURN
	END

	DECLARE @link_head VARCHAR(100)
	DECLARE @link_text VARCHAR(100)
	DECLARE @link_href VARCHAR(100)

	SET @link_head = UPPER(@leagueName)
	SET @link_text = 'All Scores'
	
	IF (@leagueName = 'olympics')
	BEGIN
		SET @link_head = 'MEDAL COUNT'
		SET @link_text = 'View All'
		SET @link_href = '/sports/olympics/2014/medals/'
	
	    SELECT
	    (
		    SELECT '_self' AS link_target, @link_head AS link_head, @link_text AS link_text, @link_href AS link_href
		       FOR XML RAW('link'), TYPE
		)
        FOR XML PATH(''), ROOT('root')

        RETURN
    END


    IF (@leagueName NOT IN ('mlb', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba',
                            'champions', 'epl', 'mls', 'natl', 'wwc'))
    BEGIN
        RETURN
    END
    

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
   	DECLARE @sport VARCHAR(100) = 'mens-basketball'
   	
    SET @season_key = 0
    DECLARE @sub_season_type VARCHAR(100) = ''
    DECLARE @week VARCHAR(100) = ''
    DECLARE @start_date DATETIME = NULL
    DECLARE @filter VARCHAR(100) = ''
    DECLARE @end_date DATETIME
    DECLARE @week_int INT
    
    SELECT @season_key = season_key, @sub_season_type = sub_season_type, @week = [week],
           @start_date = [start_date], @filter = filter
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'suspender'
         
	DECLARE @events TABLE
	(
        season_key           INT,
        event_key            VARCHAR(100),	    
        event_status         VARCHAR(100),
        game_status          VARCHAR(100),
        away_team_key        VARCHAR(100),
        away_team_score      INT,
        away_team_rank       VARCHAR(100),
        away_team_winner     VARCHAR(100),
        home_team_key        VARCHAR(100),
        home_team_score      INT,
        home_team_rank       VARCHAR(100),
        home_team_winner     VARCHAR(100),
        start_date_time_EST  DATETIME,
        [week]               VARCHAR(100),
        level_name           VARCHAR(100),
	    -- info
        away_team_abbr       VARCHAR(100),
        away_team_slug       VARCHAR(100),
        away_team_link       VARCHAR(100),
        away_team_logo       VARCHAR(100),
        away_team_conference VARCHAR(100),
        home_team_abbr       VARCHAR(100),
        home_team_slug       VARCHAR(100),
        home_team_link       VARCHAR(100),
        home_team_logo       VARCHAR(100),
        home_team_conference VARCHAR(100),
	    -- extra
	    ribbon               VARCHAR(100),
	    preview_link         VARCHAR(100),
	    boxscore_link        VARCHAR(MAX),
	    recap_link           VARCHAR(100),
	    event_id             VARCHAR(100),
	    date_order           INT,
	    status_order         INT,
	    time_order           INT
	)

    IF (@leagueName = 'nfl')
    BEGIN
        IF (@season_key IS NULL OR @sub_season_type IS NULL OR @week IS NULL)
        BEGIN
            RETURN
        END

        INSERT INTO @events (season_key, event_key, event_status, game_status, away_team_key, away_team_score, away_team_rank, away_team_winner,
                             home_team_key, home_team_score, home_team_rank, home_team_winner, start_date_time_EST, [week], ribbon)
        SELECT season_key, event_key, event_status, game_status, away_team_key, away_team_score, '', '',
               home_team_key, home_team_score, '', '', start_date_time_EST, [week], ''
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = @sub_season_type AND [week] = @week        
    END
    ELSE IF (@leagueName IN ('ncaaf', 'epl', 'champions'))
    BEGIN
        IF (@season_key IS NULL OR @week IS NULL)
        BEGIN
            RETURN
        END

        SET @sport = 'soccer'
        
        IF (@leagueName = 'ncaaf')
        BEGIN
            SET @sport = 'football'
        END
        
        IF (@start_date IS NOT NULL)
        BEGIN
            SET @end_date = DATEADD(SECOND, -1, DATEADD(DAY, 1, @start_date))
            
            INSERT INTO @events (season_key, event_key, event_status, game_status, away_team_key, away_team_score, away_team_rank, away_team_winner,
                                 home_team_key, home_team_score, home_team_rank, home_team_winner, start_date_time_EST, [week], ribbon)
            SELECT season_key, event_key, event_status, game_status, away_team_key, away_team_score, '', '',
                   home_team_key, home_team_score, '', '', start_date_time_EST, [week], ''
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND start_date_time_EST BETWEEN @start_date AND @end_date  
        END
        ELSE
        BEGIN
            INSERT INTO @events (season_key, event_key, event_status, game_status, away_team_key, away_team_score, away_team_rank, away_team_winner,
                                 home_team_key, home_team_score, home_team_rank, home_team_winner, start_date_time_EST, [week], ribbon)
            SELECT season_key, event_key, event_status, game_status, away_team_key, away_team_score, '', '',
                   home_team_key, home_team_score, '', '', start_date_time_EST, [week], ''
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @season_key AND [week] = @week
        END
    END
    ELSE
    BEGIN
        IF (@start_date IS NULL)
        BEGIN
            IF (@leagueName <> 'olympics')
            BEGIN
                RETURN
            END
        END
        
        
        IF (@leagueName IN ('natl', 'wwc'))
        BEGIN
            SET @sport = 'soccer'
        END
  
        SET @end_date = DATEADD(SECOND, -1, DATEADD(DAY, 1, @start_date))

        INSERT INTO @events (season_key, event_key, event_status, game_status, away_team_key, away_team_score, away_team_rank, away_team_winner,
                             home_team_key, home_team_score, home_team_rank, home_team_winner, start_date_time_EST, [week], ribbon, level_name)
        SELECT season_key, event_key, event_status, game_status, away_team_key, away_team_score, '', '',
               home_team_key, home_team_score, '', '', start_date_time_EST, [week], '', level_name
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND start_date_time_EST BETWEEN @start_date AND @end_date AND event_status <> 'smg-not-played'
    END

    -- event id
    UPDATE @events
       SET event_id = dbo.SMG_fnEventId(event_key)
          
    UPDATE e
       SET e.away_team_abbr = st.team_abbreviation, e.away_team_conference = st.conference_key, e.away_team_slug = st.team_slug
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = e.season_key AND st.team_key = e.away_team_key
     
    UPDATE e
       SET e.home_team_abbr = st.team_abbreviation, e.home_team_conference = st.conference_key, e.home_team_slug = st.team_slug
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = e.season_key AND st.team_key = e.home_team_key
    
    UPDATE @events
       SET away_team_winner = '1', home_team_winner = '0'
     WHERE event_status = 'post-event' AND away_team_score > home_team_score

    UPDATE @events
       SET home_team_winner = '1', away_team_winner = '0'
     WHERE event_status = 'post-event' AND home_team_score > away_team_score
              

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

    -- HACK BEGIN
    IF (@leagueName IN ('mlb', 'nba', 'ncaaf', 'nfl'))
    BEGIN
        UPDATE @events
           SET away_team_link = '/sports/' + @leagueName + '/' + away_team_slug + '/',
               home_team_link = '/sports/' + @leagueName + '/' + home_team_slug + '/'
    END
    -- HACK END

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
        IF (@leagueName = 'ncaaf')
        BEGIN
            SELECT TOP 1 @start_date = start_date_time_EST
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @season_key AND [week] = @week
             ORDER BY start_date_time_EST ASC
        END
               
        DECLARE @poll_date DATE
                   
        SELECT TOP 1 @poll_date = poll_date
          FROM SportsEditDB.dbo.SMG_Polls
          WHERE league_key = @leagueName AND fixture_key = 'smg-usat' AND poll_date < @start_date
          ORDER BY poll_date DESC
                
        UPDATE e
           SET e.away_team_rank = sp.ranking
          FROM @events e
         INNER JOIN SportsEditDB.dbo.SMG_Polls sp
            ON sp.league_key = @leagueName AND sp.poll_date = @poll_date AND sp.fixture_key = 'smg-usat' AND sp.team_key = e.away_team_abbr
               
        UPDATE e
           SET e.home_team_rank = sp.ranking
          FROM @events e
         INNER JOIN SportsEditDB.dbo.SMG_Polls sp
            ON sp.league_key = @leagueName AND sp.poll_date = @poll_date AND sp.fixture_key = 'smg-usat' AND sp.team_key = e.home_team_abbr

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
               SET status_order = 0

            IF (@filter IN ('ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi'))
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

    -- RIBBON
    -- POST SEASON
    UPDATE e
       SET e.ribbon = tag.score
      FROM @events AS e
     INNER JOIN dbo.SMG_Event_Tags tag
        ON tag.event_key = e.event_key


    -- ORDER
    IF (@leagueName IN ('nfl', 'ncaaf'))
    BEGIN
        DECLARE @today DATETIME = CONVERT(DATE, GETDATE())

        IF (CAST(GETDATE() AS TIME) < '11:00:00')
        BEGIN
            SELECT @today = DATEADD(DAY, -1, @today)
        END
        
        UPDATE @events
           SET date_order = DATEDIFF(DAY, @today, CAST(start_date_time_EST AS DATE))
        
        UPDATE @events
           SET date_order = (date_order * -7)
         WHERE date_order < 0
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
       
    IF (@leagueName IN ('nfl', 'ncaaf'))
    BEGIN
        UPDATE @events
           SET time_order = (time_order * -1)
         WHERE event_status = 'post-event'
    END

	IF (@filter = 'ncaa' AND @leagueName IN ('ncaab', 'ncaaw'))
	BEGIN
	    SET @link_href = '/sports/' + @leagueName + '/bracket/' + CAST(YEAR(GETDATE()) AS VARCHAR) + '/'
	END
	ELSE IF (@leagueName IN ('mls', 'natl', 'wwc', 'epl', 'champions'))
	BEGIN
	    SET @link_href = '/sports/soccer/' + @leagueName + '/scores/'
	END
	ELSE
	BEGIN
	    SET @link_href = '/sports/' + @leagueName + '/scores/'
	END



    SELECT
	(
        SELECT e.preview_link, e.boxscore_link, e.recap_link,
               e.event_key, e.event_status, e.game_status, e.ribbon, e.start_date_time_EST,               
			   (
			       SELECT e_a.away_team_link AS team_link,
                          e_a.away_team_score AS score,
                          e_a.away_team_rank AS [rank],
                          e_a.away_team_key AS team_key,
                          e_a.away_team_abbr AS abbr,
                          e_a.away_team_logo AS team_logo,
                          e_a.away_team_winner AS winner
                     FROM @events AS e_a
                    WHERE e_a.event_key = e.event_key
                   FOR XML RAW('away_team'), TYPE                   
			   ),
			   ( 
                   SELECT e_h.home_team_link AS team_link,
                          e_h.home_team_score AS score,
                          e_h.home_team_rank AS [rank],
                          e_h.home_team_key AS team_key,
                          e_h.home_team_abbr AS abbr,
                          e_h.home_team_logo AS team_logo,
                          e_h.home_team_winner AS winner
                     FROM @events AS e_h
                    WHERE e_h.event_key = e.event_key
                      FOR XML RAW('home_team'), TYPE
               )  
          FROM @events AS e
         ORDER BY e.date_order ASC, e.status_order ASC, e.time_order ASC
           FOR XML RAW('schedule'), TYPE
    ),
	(
		SELECT '_self' AS link_target, @link_head AS link_head, @link_text AS link_text, @link_href AS link_href
		   FOR XML RAW('link'), TYPE
	)
    FOR XML PATH(''), ROOT('root')

        
    SET NOCOUNT OFF;
END

GO
