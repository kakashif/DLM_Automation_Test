USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamSchedules_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetTeamSchedules_XML]
   @leagueKey     VARCHAR(100),
   @teamKey       VARCHAR(100),
   @seasonKey     INT
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 07/22/2013
  -- Description: get team schedules
  -- Update: 11/18/2013 - John Lin - add NCAAB HACK
  --         12/10/2013 - John Lin - hall of fame
  --         08/11/2014 - John Lin - add link to preview, boxscore, recap
  --         08/15/2014 - Prashant Kamat - add full_name for ticketcity links
  --         09/15/2014 - John Lin - switch to SMG_Schedules
  --         10/10/2014 - John Lin - nhl refactor
  --         12/18/2014 - John Lin - add playoffs
  --         03/18/2015 - John Lin - modify event link
  --         07/01/2015 - ikenticus - adjusting to STATS migration and SMG_Polls* conversion
  --         07/29/2015 - John Lin - SDI migration
  --	     08/03/2015 - John Lin - retrieve event_id using function
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
    
	DECLARE @today DATETIME = CAST(GETDATE() AS DATE)
    DECLARE @startDate DATETIME
    DECLARE @endDate DATETIME
    DECLARE @team_id INT
    DECLARE @league_name VARCHAR(100)
    DECLARE @sport VARCHAR(100) = 'mens-basketball'    
    
	SELECT TOP 1 @league_name = value_to
	  FROM SportsDB.dbo.SMG_Mappings
	 WHERE value_from = @leagueKey

    IF (@league_name NOT IN ('mlb', 'mls', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba'))
    BEGIN
        RETURN
    END


	DECLARE @events TABLE
	(
	    sub_season_type      VARCHAR(100),
	    event_key            VARCHAR(100),
	    event_status         VARCHAR(50),
	    game_status          VARCHAR(100),
	    start_date_time_EST  DATETIME,
	    [week]               VARCHAR(100),
	    away_team_key        VARCHAR(50),
	    away_team_score      INT,
	    home_team_key        VARCHAR(50),
	    home_team_score      INT,
	    tv_coverage          VARCHAR(255),
	    -- extra
   	    away_team_abbr       VARCHAR(50),
	    away_team_first      VARCHAR(50),
	    away_team_last       VARCHAR(50),
	    away_team_rank       INT,
	    away_team_conference VARCHAR(100),
	    home_team_abbr       VARCHAR(50),
	    home_team_first      VARCHAR(50),
	    home_team_last       VARCHAR(50),
	    home_team_rank       INT,
	    home_team_conference VARCHAR(100),
	    event_id             INT,
	    ribbon               VARCHAR(100) DEFAULT 'REGULAR SEASON',
        preview_link         VARCHAR(100),
        boxscore_link        VARCHAR(MAX),
        recap_link           VARCHAR(100),
	    ribbon_order         INT DEFAULT 1
	)
    INSERT INTO @events (sub_season_type, event_key, event_status, game_status, start_date_time_EST, [week], away_team_key, away_team_score,
                         home_team_key, home_team_score, tv_coverage)
    SELECT sub_season_type, event_key, event_status, game_status, start_date_time_EST, [week], away_team_key, away_team_score,
           home_team_key, home_team_score, tv_coverage
      FROM dbo.SMG_Schedules
     WHERE league_key = @leagueKey AND season_key = @seasonKey AND @teamKey IN (away_team_key, home_team_key) AND event_status <> 'smg-not-played'

        
    IF (@league_name IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        -- coaches' ranking
        UPDATE e
           SET e.away_team_rank = sp.ranking
          FROM @events e
         INNER JOIN SportsEditDB.dbo.SMG_Polls sp
            ON sp.league_key = @league_name AND sp.season_key = @seasonKey AND sp.fixture_key = 'smg-usat' AND
               sp.team_key = e.away_team_abbr AND e.[week] NOT IN ('playoffs', 'bowls', 'ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi') AND
               sp.[week] = CAST(e.[week] AS INT)
           
        UPDATE e
           SET e.home_team_rank = sp.ranking
          FROM @events e
         INNER JOIN SportsEditDB.dbo.SMG_Polls sp
            ON sp.league_key = @league_name AND sp.season_key = @seasonKey AND sp.fixture_key = 'smg-usat' AND
               sp.team_key = e.home_team_abbr AND e.[week] NOT IN ('playoffs', 'bowls', 'ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi') AND
               sp.[week] = CAST(e.[week] AS INT)

        -- post season
        IF (@league_name = 'ncaaf')
        BEGIN
           SET @sport = 'football'
           
           UPDATE e
              SET e.ribbon = ups.schedule, e.ribbon_order = 0
             FROM @events e
            INNER JOIN dbo.USAT_Post_Seasons ups
               ON ups.event_key = e.event_key
        END
        ELSE
        BEGIN
            UPDATE e
               SET e.away_team_rank = enbt.seed
              FROM @events e
             INNER JOIN SportsEditDB.dbo.Edit_NCAA_Bracket_Teams enbt
                ON enbt.league_key = @leagueKey AND enbt.season_key = @seasonKey AND enbt.team_key = e.away_team_key
             WHERE e.[week] IS NOT NULL AND e.[week] = 'ncaa'

            UPDATE e
               SET e.home_team_rank = enbt.seed
              FROM @events e
             INNER JOIN SportsEditDB.dbo.Edit_NCAA_Bracket_Teams enbt
                ON enbt.league_key = @leagueKey AND enbt.season_key = @seasonKey AND enbt.team_key = e.home_team_key
             WHERE e.[week] IS NOT NULL AND e.[week] = 'ncaa'

            UPDATE e
               SET e.ribbon = ups.dropdown + ' Tournament', e.ribbon_order = 0
              FROM @events e
             INNER JOIN dbo.USAT_Post_Seasons ups
                ON ups.event_key = e.event_key
        END
    END
    ELSE
    BEGIN
        -- pre season
        UPDATE @events
           SET ribbon = 'PRESEASON'
         WHERE sub_season_type = 'pre-season'

        SELECT TOP 1 @endDate = CAST(start_date_time_EST AS DATE)
          FROM @events
         WHERE ribbon = 'PRESEASON'
         ORDER BY start_date_time_EST DESC

        IF (@today > @endDate)
        BEGIN
            UPDATE @events
               SET ribbon_order = 2
             WHERE ribbon = 'PRESEASON'

            UPDATE @events
               SET ribbon = 'POSTSEASON', ribbon_order = 0
             WHERE sub_season_type = 'post-season'
        END
        ELSE
        BEGIN
            UPDATE @events
               SET ribbon_order = 0
             WHERE ribbon = 'PRESEASON'
        END

        IF (@league_name = 'nfl')
        BEGIN
           UPDATE e
              SET e.[week] = ups.dropdown
             FROM @events e
            INNER JOIN dbo.USAT_Post_Seasons ups
               ON ups.event_key = e.event_key

            -- PADDING
            DECLARE @missings TABLE
            (
                [week]          INT,
                missing         INT,
                start_date_time DATETIME
            )
            INSERT INTO @missings ([week], missing)
            VALUES (1, 1), (2, 1), (3, 1), (4, 1), (5, 1), (6, 1), (7, 1), (8, 1), (9, 1), (10, 1), (11, 1), (12, 1), (13, 1), (14, 1), (15, 1), (16, 1), (17, 1)
            
            UPDATE m
               SET m.missing = 0
              FROM @missings m
             INNER JOIN @events e
                ON e.[week] = m.[week] AND e.ribbon = 'REGULAR SEASON'

            UPDATE m
               SET m.start_date_time = DATEADD(WEEK, 1, e.start_date_time_EST)
              FROM @missings m
             INNER JOIN @events e
                ON e.[week] = (m.[week] - 1) AND e.ribbon = 'REGULAR SEASON'
                
            INSERT INTO @events (start_date_time_EST, [week], ribbon, ribbon_order)
            SELECT start_date_time, [week], 'REGULAR SEASON', 1
              FROM @missings
             WHERE missing = 1
        END
    END

    UPDATE e
       SET e.away_team_first = st.team_first,
           e.away_team_last = st.team_last,
           e.away_team_abbr = st.team_abbreviation,
           e.away_team_conference = st.conference_key
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = @seasonKey AND st.team_key = e.away_team_key


    UPDATE e
       SET e.home_team_first = st.team_first,
           e.home_team_last = st.team_last,
           e.home_team_abbr = st.team_abbreviation,
           e.home_team_conference = st.conference_key
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = @seasonKey AND st.team_key = e.home_team_key

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

    IF (@league_name = 'mls')
    BEGIN
        UPDATE @events
           SET boxscore_link = 'http://www.sportsnetwork.com/merge/tsnform.aspx?c=usatoday&page=soc-mls/scores/final/boxscore.aspx?gameid=' + CAST(event_id AS VARCHAR) 

        UPDATE e
           SET e.preview_link = 'http://www.sportsnetwork.com/merge/tsnform.aspx?c=usatoday&page=soc-mls/scores/live/pv' + CAST(e.event_id AS VARCHAR) + '.htm'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'pre-event-coverage'

        UPDATE e
           SET e.recap_link = 'http://www.sportsnetwork.com/merge/tsnform.aspx?c=usatoday&page=soc-mls/scores/final/w' + CAST(e.event_id AS VARCHAR) + '.htm'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'post-event-coverage'
    END
    ELSE
    BEGIN
        UPDATE @events
           SET boxscore_link = '/sports/' + @league_name + '/event/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(event_id AS VARCHAR) + '/boxscore/'

        UPDATE e
           SET e.preview_link = '/sports/' + @league_name + '/event/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(e.event_id AS VARCHAR) + '/preview/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'pre-event-coverage'

        UPDATE e
           SET e.recap_link = '/sports/' + @league_name + '/event/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(e.event_id AS VARCHAR) + '/recap/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'post-event-coverage'
    END
    
    -- SEC HACK
    IF (@league_name IN ('ncaab', 'ncaaf'))
    BEGIN
         UPDATE @events
           SET boxscore_link = boxscore_link + 'top25/',
               preview_link = preview_link + 'top25/',
               recap_link = recap_link + 'top25/'
         WHERE [week] IS NULL OR [week] <> 'ncaa'

        UPDATE @events
           SET boxscore_link = 'http://sports.usatoday.com/ncaa/' + @sport + '/event/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(event_id AS VARCHAR) + '/boxscore/'
         WHERE 'c.southeastern' IN (away_team_conference, home_team_conference)

        UPDATE e
           SET e.preview_link = 'http://sports.usatoday.com/ncaa/' + @sport + '/event/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(e.event_id AS VARCHAR) + '/preview/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'pre-event-coverage'
         WHERE 'c.southeastern' IN (e.away_team_conference, e.home_team_conference)

        UPDATE e
           SET e.recap_link = 'http://sports.usatoday.com/ncaa/' + @sport + '/event/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(e.event_id AS VARCHAR) + '/recap/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'post-event-coverage'
         WHERE 'c.southeastern' IN (e.away_team_conference, e.home_team_conference)
    END

    -- NCAA HACK
    IF (@league_name = 'ncaab')
    BEGIN
        UPDATE @events
           SET boxscore_link = 'http://sports.usatoday.com/ncaa/mens-basketball/event/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(event_id AS VARCHAR) + '/boxscore/'
         WHERE [week] = 'ncaa'

        UPDATE @events
           SET preview_link = 'http://sports.usatoday.com/ncaa/mens-basketball/event/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(event_id AS VARCHAR) + '/preview/'
         WHERE [week] = 'ncaa'

        UPDATE e
           SET e.recap_link = 'http://sports.usatoday.com/ncaa/mens-basketball/event/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(e.event_id AS VARCHAR) + '/recap/'
          FROM @events e
         INNER JOIN @coverage c
            ON c.event_key = e.event_key AND c.column_type = 'post-event-coverage'
         WHERE [week] = 'ncaa'
    END

    IF (@league_name <> 'nfl')
    BEGIN
        UPDATE @events
           SET [week] = NULL
    END

        
    SELECT
	(
        SELECT g.boxscore_link AS boxScore,
               g.event_key,
               g.event_status,
               g.game_status,
               '' AS game2,
               '' AS line,
               g.ribbon,
			   g.preview_link AS preview,
               g.start_date_time_EST AS start_date_time,
			   g.recap_link AS summary,
               g.tv_coverage AS tv,
               g.[week],
               g.boxscore_link,
               g.preview_link,
               g.recap_link,
			   (
			       SELECT away_team_first AS first_name,
                          away_team_last AS last_name,
						  away_team_first + ' ' + away_team_last AS full_name,
                          ISNULL(away_team_score, 0) AS score,
                          away_team_rank AS [rank],
                          away_team_key AS team_key,
                          away_team_abbr AS abbr
                     FROM @events AS a_g
                    WHERE a_g.event_key = g.event_key
                   FOR XML RAW('away_team'), TYPE                   
			   ),
			   ( 
                   SELECT home_team_first AS first_name,
                          home_team_last AS last_name,
						  home_team_first + ' ' + home_team_last AS full_name,
                          ISNULL(home_team_score, 0) AS score,
                          home_team_rank AS [rank],
                          home_team_key AS team_key,
                          home_team_abbr AS abbr
                     FROM @events AS h_g
                    WHERE h_g.event_key = g.event_key
                      FOR XML RAW('home_team'), TYPE
               )				   
          FROM @events AS g
         ORDER BY g.ribbon_order ASC, g.start_date_time_EST ASC
           FOR XML RAW('schedule'), TYPE
    )
    FOR XML PATH(''), ROOT('root')
 
 END


GO
