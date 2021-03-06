USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNCAAScheduleBySlug_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[HUB_GetNCAAScheduleBySlug_XML]
   @teamSlug VARCHAR(100)
AS
--=============================================
-- Author: John Lin
-- Create date: 07/23/2014
-- Description: get NCAA team schedule
-- Update: 08/25/2014 - thlam - change from 110 to 220 logo
--         09/15/2014 - thlam - event_link default to plays when mid-event and recaps when post-event
--         11/19/2014 - John Lin - men -> mens
--         12/02/2014 - John Lin - return list
--         12/11/2014 - John Lin - order by sport, return next game
--         12/16/2014 - John Lin - add playoffs and refactor rank
--         01/07/2015 - John Lin - add home and away link
--		   07/01/2015 - ikenticus - adjusting to SMG_Polls* conversion
--         07/10/2015 - John Lin - STATS team records
--         07/29/2015 - John Lin - SDI migration
--         08/03/2015 - John Lin - retrieve event_id and logo using functions
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @events TABLE
    (
        league_key           VARCHAR(100),
        league_name          VARCHAR(100),
        sport                VARCHAR(100),
        conference           VARCHAR(100),        
        event_key            VARCHAR(100),
        season_key           INT,
        event_status         VARCHAR(100),
        game_status          VARCHAR(100),
        tv_coverage          VARCHAR(100),
        start_date_time_EST  DATETIME,
        [week]               VARCHAR(100),
        away_key             VARCHAR(100),
        away_score           VARCHAR(100),
        home_key             VARCHAR(100),
        home_score           VARCHAR(100),
	    -- extra
	    event_id             VARCHAR(100),
        max_week             INT,
        away_rank            VARCHAR(100) DEFAULT '',
        away_winner          VARCHAR(100) DEFAULT '',
        away_abbr            VARCHAR(100),
        away_first           VARCHAR(100),
        away_last            VARCHAR(100),
        away_slug            VARCHAR(100),
        away_record          VARCHAR(100),
        away_link            VARCHAR(100),
        away_logo            VARCHAR(100),
        home_rank            VARCHAR(100) DEFAULT '',
        home_winner          VARCHAR(100) DEFAULT '',
        home_abbr            VARCHAR(100),
        home_first           VARCHAR(100),
        home_last            VARCHAR(100),
        home_slug            VARCHAR(100),
        home_record          VARCHAR(100),
        home_link            VARCHAR(100),
        home_logo            VARCHAR(100),
	    event_link           VARCHAR(100),
        ribbon               VARCHAR(100)
    )
    DECLARE @today DATE = CAST(GETDATE() AS DATE)
    DECLARE @team_key VARCHAR(100)
    DECLARE @season_key INT

    -- men basketball
	DECLARE @ncaab_league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('ncaab')

    SELECT @season_key = team_season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = 'ncaab' AND page = 'schedules'

    SELECT @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = @ncaab_league_key AND season_key = @season_key AND team_slug = @teamSlug

    INSERT INTO @events (league_key, league_name, sport, season_key, event_key, event_status, game_status,
                         tv_coverage, start_date_time_EST, [week], away_key, away_score, home_key, home_score)
    SELECT TOP 1 @ncaab_league_key, 'ncaab', 'mens-basketball', season_key, event_key, event_status, game_status,
           tv_coverage, start_date_time_EST, [week], away_team_key, away_team_score, home_team_key, home_team_score
      FROM dbo.SMG_Schedules
     WHERE league_key = @ncaab_league_key AND @team_key IN (away_team_key, home_team_key) AND start_date_time_EST > @today
     ORDER BY start_date_time_EST ASC

    -- football
	DECLARE @ncaaf_league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('ncaaf')

    SELECT @season_key = season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = 'ncaaf' AND page = 'schedules'

    SELECT @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = @ncaaf_league_key AND season_key = @season_key AND team_slug = @teamSlug

    INSERT INTO @events (league_key, league_name, sport, season_key, event_key, event_status, game_status,
                         tv_coverage, start_date_time_EST, [week], away_key, away_score, home_key, home_score)
    SELECT TOP 1 @ncaaf_league_key, 'ncaaf', 'football', season_key, event_key, event_status, game_status,
           tv_coverage, start_date_time_EST, [week], away_team_key, away_team_score, home_team_key, home_team_score
      FROM dbo.SMG_Schedules
     WHERE league_key = @ncaaf_league_key AND @team_key IN (away_team_key, home_team_key) AND start_date_time_EST > @today
     ORDER BY start_date_time_EST ASC

    -- women basketball
	DECLARE @ncaaw_league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('ncaaw')

    SELECT @season_key = team_season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = 'ncaaw' AND page = 'schedules'

    SELECT @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = @ncaaw_league_key AND season_key = @season_key AND team_slug = @teamSlug

    INSERT INTO @events (league_key, league_name, sport, season_key, event_key, event_status, game_status,
                         tv_coverage, start_date_time_EST, [week], away_key, away_score, home_key, home_score)
    SELECT TOP 1 @ncaaw_league_key, 'ncaaw', 'womens-basketball', season_key, event_key, event_status, game_status,
           tv_coverage, start_date_time_EST, [week], away_team_key, away_team_score, home_team_key, home_team_score
      FROM dbo.SMG_Schedules
     WHERE league_key = @ncaaw_league_key AND @team_key IN (away_team_key, home_team_key) AND start_date_time_EST > @today
     ORDER BY start_date_time_EST ASC


    UPDATE e
       SET e.away_first = st.team_first, e.away_last = st.team_last, e.away_abbr = st.team_abbreviation, e.away_slug = st.team_slug,
           e.away_link = CASE
                             WHEN st.team_slug IS NULL OR st.team_slug = '' THEN ''
                             WHEN st.conference_key = '/sport/football/conference:12' THEN '/ncaa/sec/' + st.team_slug + '/' + e.sport + '/'                             
                             WHEN e.league_name = 'ncaaf' THEN 'http://www.usatoday.com/sports/ncaaf/' + st.team_slug + '/' 
                             ELSE ''
                         END

      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = e.season_key AND st.team_key = e.away_key

    UPDATE e
       SET e.home_first = st.team_first, e.home_last = st.team_last, e.home_abbr = st.team_abbreviation, e.home_slug = st.team_slug,
           e.home_link = CASE
                             WHEN st.team_slug IS NULL OR st.team_slug = '' THEN ''
                             WHEN st.conference_key = '/sport/football/conference:12' THEN '/ncaa/sec/' + st.team_slug + '/' + e.sport + '/'
                             WHEN e.league_name = 'ncaaf' THEN 'http://www.usatoday.com/sports/ncaaf/' + st.team_slug + '/'
                             ELSE ''
                         END

      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = e.season_key AND st.team_key = e.home_key

    UPDATE @events
       SET away_slug = ''
     WHERE away_slug IS NULL

    UPDATE @events
       SET  home_slug = ''
     WHERE home_slug IS NULL
   
    UPDATE e
       SET e.conference = sl.conference_display
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = e.season_key AND st.team_slug = @teamSlug
     INNER JOIN dbo.SMG_Leagues sl
        ON sl.season_key = st.season_key AND sl.conference_key = st.conference_key

    -- event id
    UPDATE @events
       SET event_id = dbo.SMG_fnEventId(event_key)

    -- logo
	UPDATE @events
	   SET away_logo = dbo.SMG_fnTeamLogo(league_name, away_abbr, '220'),
		   home_logo = dbo.SMG_fnTeamLogo(league_name, home_abbr, '220')

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
	 
    UPDATE e   
       SET e.event_link = '/ncaa/' +
                          CASE
                              WHEN league_name = 'ncaab' THEN 'mens-basketball/'
                              WHEN league_name = 'ncaaf' THEN 'football/'
                              WHEN league_name = 'ncaaw' THEN 'womens-basketball/'
                              ELSE ''
                          END + 'event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/' +
                          CASE
                              WHEN e.event_status = 'pre-event' AND c.column_type = 'pre-event-coverage' THEN 'preview/'
                              WHEN e.event_status = 'post-event' AND c.column_type = 'post-event-coverage' THEN 'recap/'
                          END
      FROM @events e
     INNER JOIN @coverage c
        ON c.event_key = e.event_key


    UPDATE @events
       SET event_link = '/ncaa/' +
                        CASE
                            WHEN league_name = 'ncaab' THEN 'mens-basketball/'
                            WHEN league_name = 'ncaaf' THEN 'football/'
                            WHEN league_name = 'ncaaw' THEN 'womens-basketball/'
                            ELSE ''
                        END + 'event/' + CAST(season_key AS VARCHAR) + '/' + event_id +
                        CASE
                            WHEN event_status IN ('mid-event') THEN '/plays/'
                            WHEN event_status IN ('post-event') THEN '/recap/'
                            ELSE '/preview/'
                        END
      WHERE event_link IS NULL


    -- RANK    
    -- assume no poll
    UPDATE e
       SET e.max_week = (SELECT MAX(sp.[week])
                           FROM SportsEditDB.dbo.SMG_Polls sp
                          WHERE sp.league_key = e.league_name AND sp.season_key = e.season_key AND sp.fixture_key = 'smg-usat')
      FROM @events e
        
    -- set to max week
    UPDATE e
       SET e.away_rank = sp.ranking
      FROM @events e
     INNER JOIN SportsEditDB.dbo.SMG_Polls sp
        ON sp.league_key = e.league_name AND sp.season_key = e.season_key AND sp.team_key = e.away_abbr AND 
           sp.[week] = CAST(e.[week] AS INT) AND sp.fixture_key = 'smg-usat'
     WHERE e.[week] NOT IN ('playoffs', 'bowls', 'ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi')
               
    UPDATE e
       SET e.home_rank = sp.ranking
      FROM @events e
     INNER JOIN SportsEditDB.dbo.SMG_Polls sp
        ON sp.league_key = e.league_name AND sp.season_key = e.season_key AND sp.team_key = e.home_abbr AND 
           sp.[week] = CAST(e.[week] AS INT) AND sp.fixture_key = 'smg-usat'
     WHERE e.[week] NOT IN ('playoffs', 'bowls', 'ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi')

    -- set to correct week 
    UPDATE e
       SET e.away_rank = sp.ranking
      FROM @events e
     INNER JOIN SportsEditDB.dbo.SMG_Polls sp
        ON sp.league_key = e.league_name AND sp.season_key = e.season_key AND sp.team_key = e.away_abbr AND 
           sp.[week] = e.max_week AND sp.fixture_key = 'smg-usat'
     WHERE e.[week] IN ('playoffs', 'bowls', 'ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi')
               
    UPDATE e
       SET e.home_rank = sp.ranking
      FROM @events e
     INNER JOIN SportsEditDB.dbo.SMG_Polls sp
        ON sp.league_key = e.league_name AND sp.season_key = e.season_key AND sp.team_key = e.home_abbr AND 
           sp.[week] = e.max_week AND sp.fixture_key = 'smg-usat'
     WHERE e.[week] IN ('playoffs', 'bowls', 'ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi')


    UPDATE e
       SET e.away_rank = enbt.seed
      FROM @events e
     INNER JOIN SportsEditDB.dbo.Edit_NCAA_Bracket_Teams enbt
        ON enbt.league_key = e.league_key AND enbt.season_key = e.season_key AND enbt.team_key = e.away_key
     WHERE e.league_key IN (@ncaab_league_key, @ncaaw_league_key) AND e.[week] IS NOT NULL AND e.[week] = 'ncaa'

    UPDATE e
       SET e.home_rank = enbt.seed
      FROM @events e
     INNER JOIN SportsEditDB.dbo.Edit_NCAA_Bracket_Teams enbt
        ON enbt.league_key = e.league_key AND enbt.season_key = e.season_key AND enbt.team_key = e.home_key
     WHERE e.league_key IN (@ncaab_league_key, @ncaaw_league_key) AND e.[week] IS NOT NULL AND e.[week] = 'ncaa'
        
    -- RIBBON
    -- POST SEASON
    UPDATE @events
       SET ribbon = 'WEEK ' + [week]
     WHERE league_key = @ncaaf_league_key AND [week] IN ('bowls', 'playoffs')
       
    UPDATE e
       SET e.ribbon = tag.schedule
      FROM @events AS e
     INNER JOIN dbo.SMG_Event_Tags tag
        ON tag.event_key = e.event_key


    -- RENDER
    UPDATE @events
       SET away_record = dbo.SMG_fn_Team_Records(league_name, season_key, away_key, event_key)
     
    UPDATE @events
       SET home_record = dbo.SMG_fn_Team_Records(league_name, season_key, home_key, event_key)

    UPDATE @events
       SET away_winner = '1', home_winner = '0'
     WHERE event_status = 'post-event' AND CAST(away_score AS INT) > CAST(home_score AS INT)

    UPDATE @events
       SET home_winner = '1', away_winner = '0'
     WHERE event_status = 'post-event' AND CAST(home_score AS INT) > CAST(away_score AS INT)

    UPDATE @events
       SET away_score = ''
     WHERE away_score IS NULL

    UPDATE @events
       SET home_score = ''
     WHERE home_score IS NULL


                
	;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT
	(
	    SELECT 'true' AS 'json:Array',
	           e.league_name AS league, e.conference,
	           (
                   SELECT 'true' AS 'json:Array',
                          e_r.event_key, e_r.event_status, e_r.game_status, e_r.tv_coverage, e_r.start_date_time_EST, e_r.ribbon, e_r.event_link,
			              (
			                  SELECT a_e.away_first AS [first], a_e.away_last AS [last], a_e.away_rank AS [rank], a_e.away_score AS score,
			                         a_e.away_winner AS winner, a_e.away_record AS record, a_e.away_logo AS logo,
			                         a_e.away_link AS link
                                FROM @events a_e
                               WHERE a_e.league_key = e.league_key AND a_e.event_key = e_r.event_key
                                 FOR XML RAW('away'), TYPE
			              ),
			              (
			                  SELECT h_e.home_first AS [first], h_e.home_last AS [last], h_e.home_rank AS [rank], h_e.home_score AS score,
			                         h_e.home_winner AS winner, h_e.home_record AS record, h_e.home_logo AS logo,
			                         h_e.home_link AS link
                                FROM @events h_e
                               WHERE h_e.league_key = e.league_key AND h_e.event_key = e_r.event_key
                                 FOR XML RAW('home'), TYPE
                          )
                     FROM @events e_r
                    WHERE e_r.league_key = e.league_key
                    ORDER BY e_r.start_date_time_EST ASC
                      FOR XML RAW('schedule'), TYPE
               )
          FROM @events e
         ORDER BY e.league_key ASC
           FOR XML RAW('league'), TYPE
    )
    FOR XML PATH(''), ROOT('root')       

            
    SET NOCOUNT OFF 
END


GO
