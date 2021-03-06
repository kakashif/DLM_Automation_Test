USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNCAASchedule_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[HUB_GetNCAASchedule_XML]
   @conference VARCHAR(100),
   @sport VARCHAR(100),
   @week VARCHAR(100)
AS
--=============================================
-- Author: John Lin
-- Create date: 07/30/2014
-- Description: get NCAA schedule
-- Update: 09/03/2014 - thlam - updating team_link if SEC and forward to usat presto team page if not SEC
--         09/09/2014 - John Lin - rewrite rank logic
--         09/15/2014 - thlam - event_link default to plays when mid-event and recaps when post-event
--         11/05/2014 - John Lin - men -> mens
--         11/13/2014 - John Lin - only link ncaaf back to usat
--         12/02/2014 - John Lin - return list
--         12/11/2014 - John Lin - fix post season, order by date time
--         12/16/2014 - John Lin - add playoffs
--		   07/01/2015 - ikenticus - adjusting to SMG_Polls* conversion
--         07/10/2015 - John Lin - STATS team records
--         07/29/2015 - John Lin - SDI migration
--         08/03/2015 - John Lin - retrieve event_id and logo using functions
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    -- NEED TO PUT INTO A TABLE
    DECLARE @conference_key VARCHAR(100)
    
    IF (@conference = 'sec')
    BEGIN
        SET @conference_key = '/sport/football/conference:12'
    END

	DECLARE @league_name VARCHAR(100)
    DECLARE @season_key INT

    IF (@sport = 'mens-basketball')
    BEGIN
        SELECT @league_name = league_key, @season_key = team_season_key
          FROM dbo.SMG_Default_Dates
         WHERE league_key = 'ncaab' AND page = 'schedules'        
    END
    ELSE IF (@sport = 'football')
    BEGIN
        SELECT @league_name = league_key, @season_key = team_season_key
          FROM dbo.SMG_Default_Dates
         WHERE league_key = 'ncaaf' AND page = 'schedules'
    END
    ELSE IF (@sport = 'womens-basketball')
    BEGIN
        SELECT @league_name = league_key, @season_key = team_season_key
          FROM dbo.SMG_Default_Dates
         WHERE league_key = 'ncaaw' AND page = 'schedules'
    END

	DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@league_name)

    DECLARE @events TABLE
    (
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
        event_link           VARCHAR(100),
        away_rank            VARCHAR(100) DEFAULT '',
        away_winner          VARCHAR(100) DEFAULT '',
        away_abbr            VARCHAR(100),
        away_first           VARCHAR(100),
        away_last            VARCHAR(100),
        away_slug            VARCHAR(100),
        away_link            VARCHAR(100),
        away_logo            VARCHAR(100),
        away_record          VARCHAR(100),        
        away_conference      VARCHAR(100),
        home_rank            VARCHAR(100) DEFAULT '',
        home_winner          VARCHAR(100) DEFAULT '',
        home_abbr            VARCHAR(100),
        home_first           VARCHAR(100),
        home_last            VARCHAR(100),
        home_slug            VARCHAR(100),
        home_link            VARCHAR(100),
        home_logo            VARCHAR(100),
        home_record          VARCHAR(100),
        home_conference      VARCHAR(100),
        ribbon               VARCHAR(100)
    )

    IF (@league_name = 'ncaaf' AND @week = 'bowls')
    BEGIN
        INSERT INTO @events (season_key, event_key, event_status, game_status, tv_coverage, start_date_time_EST, [week], away_key, away_score, home_key, home_score)
        SELECT season_key, event_key, event_status, game_status, tv_coverage, start_date_time_EST, [week], away_team_key, away_team_score, home_team_key, home_team_score
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @season_key AND [week] = 'playoffs'
    END

    INSERT INTO @events (season_key, event_key, event_status, game_status, tv_coverage, start_date_time_EST, [week], away_key, away_score, home_key, home_score)
    SELECT season_key, event_key, event_status, game_status, tv_coverage, start_date_time_EST, [week], away_team_key, away_team_score, home_team_key, home_team_score
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @season_key AND [week] = @week

    UPDATE e
       SET e.away_first = st.team_first, e.away_last = st.team_last, e.away_abbr = st.team_abbreviation,
           e.away_slug = st.team_slug, e.away_conference = st.conference_key,
           e.away_link = CASE
                             WHEN st.team_slug IS NULL OR st.team_slug = '' THEN ''
							 WHEN st.conference_key = '/sport/football/conference:12' THEN '/ncaa/sec/' + st.team_slug + '/' + CASE
									                                                                                WHEN @league_name = 'ncaab' THEN 'mens-basketball/'
									                                                                                WHEN @league_name = 'ncaaf' THEN 'football/'
									                                                                                WHEN @league_name = 'ncaaw' THEN 'womens-basketball/'
                                                                                                                END
                             WHEN @league_name = 'ncaaf' THEN 'http://www.usatoday.com/sports/ncaaf/' + st.team_slug + '/'
							 ELSE ''
						 END
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND st.season_key = e.season_key AND st.team_key = e.away_key

    UPDATE e
       SET e.home_first = st.team_first, e.home_last = st.team_last, e.home_abbr = st.team_abbreviation,
           e.home_slug = st.team_slug, e.home_conference = st.conference_key,
           e.home_link = CASE
                             WHEN st.team_slug IS NULL OR st.team_slug = '' THEN ''
                             WHEN st.conference_key = '/sport/football/conference:12' THEN '/ncaa/sec/' + st.team_slug + '/' + CASE
                                                                                                                    WHEN @league_name = 'ncaab' THEN 'mens-basketball/'
                                                                                                                    WHEN @league_name = 'ncaaf' THEN 'football/'
                                                                                                                    WHEN @league_name = 'ncaaw' THEN 'womens-basketball/'
                                                                                                                END
					         WHEN @league_name = 'ncaaf' THEN 'http://www.usatoday.com/sports/ncaaf/' + st.team_slug + '/'
							 ELSE ''
                         END
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND st.season_key = e.season_key AND st.team_key = e.home_key
            
    UPDATE @events
       SET away_conference = ''
     WHERE away_conference IS NULL

    UPDATE @events
       SET home_conference = ''
     WHERE home_conference IS NULL
         
    DELETE @events
     WHERE @conference_key NOT IN (away_conference, home_conference)
    
    -- event id
    UPDATE @events
       SET event_id = dbo.SMG_fnEventId(event_key)

    -- logo
	UPDATE @events
	   SET away_logo = dbo.SMG_fnTeamLogo(@league_name, away_abbr, '220'),
		   home_logo = dbo.SMG_fnTeamLogo(@league_name, home_abbr, '220')

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
       SET e.event_link = '/ncaa/' + @sport + '/event/' + CAST(season_key AS VARCHAR) + '/' + event_id + '/' +
                          CASE
                              WHEN e.event_status = 'pre-event' AND c.column_type = 'pre-event-coverage' THEN 'preview/'
                              WHEN e.event_status = 'post-event' AND c.column_type = 'post-event-coverage' THEN 'recap/'
                          END
      FROM @events e
     INNER JOIN @coverage c
        ON c.event_key = e.event_key

    UPDATE @events
       SET event_link = '/ncaa/' + @sport + '/event/' + CAST(season_key AS VARCHAR) + '/' + event_id +
                        CASE
                            WHEN event_status IN ('mid-event') THEN '/plays/'
                            WHEN event_status IN ('post-event') THEN '/recap/'
                            ELSE '/preview/'
                        END
      WHERE event_link IS NULL

    -- RANK
    DECLARE @poll_week INT
    
    IF (ISNUMERIC(@week) = 1 AND EXISTS (SELECT 1
		                                   FROM SportsEditDB.dbo.SMG_Polls
				                          WHERE league_key = @league_name AND season_key = @season_key AND fixture_key = 'smg-usat' AND [week] = @week))
    BEGIN
		SET @poll_week = CAST(@week AS INT)
	END
	ELSE
	BEGIN             
		SELECT TOP 1 @poll_week = [week]
		  FROM SportsEditDB.dbo.SMG_Polls
		 WHERE league_key = @league_name AND season_key = @season_key AND fixture_key = 'smg-usat'
		 ORDER BY [week] DESC
	END

	UPDATE e
	   SET e.away_rank = sp.ranking
	  FROM @events e
	 INNER JOIN SportsEditDB.dbo.SMG_Polls sp
		ON sp.league_key = @league_name AND sp.season_key = @season_key AND sp.fixture_key = 'smg-usat' AND
		   sp.team_key = e.away_abbr AND sp.[week] = @poll_week
              
	UPDATE e
	   SET e.home_rank = sp.ranking
	  FROM @events e
	 INNER JOIN SportsEditDB.dbo.SMG_Polls sp
		ON sp.league_key = @league_name AND sp.season_key = @season_key AND sp.fixture_key = 'smg-usat' AND
		   sp.team_key = e.home_abbr AND sp.[week] = @poll_week

    -- SEED        
    IF (@league_name IN ('ncaab', 'ncaaw'))
    BEGIN
        UPDATE e
           SET e.away_rank = enbt.seed
          FROM @events e
         INNER JOIN SportsEditDB.dbo.Edit_NCAA_Bracket_Teams enbt
            ON enbt.league_key = @league_key AND enbt.season_key = e.season_key AND enbt.team_key = e.away_key
         WHERE e.[week] IS NOT NULL AND e.[week] = 'ncaa'

        UPDATE e
           SET e.home_rank = enbt.seed
          FROM @events e
         INNER JOIN SportsEditDB.dbo.Edit_NCAA_Bracket_Teams enbt
            ON enbt.league_key = @league_key AND enbt.season_key = e.season_key AND enbt.team_key = e.home_key
         WHERE e.[week] IS NOT NULL AND e.[week] = 'ncaa'
    END
        
    -- RIBBON
    UPDATE @events
       SET ribbon = 'WEEK ' + [week]
     WHERE [week] NOT IN ('bowls', 'ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi')
       
    UPDATE e
       SET e.ribbon = tag.schedule
      FROM @events AS e
     INNER JOIN dbo.SMG_Event_Tags tag
        ON tag.event_key = e.event_key


    -- RENDER
    UPDATE @events
       SET away_record = dbo.SMG_fn_Team_Records(@league_name, season_key, away_key, event_key)
     
    UPDATE @events
       SET home_record = dbo.SMG_fn_Team_Records(@league_name, season_key, home_key, event_key)

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
               e.event_key, e.event_status, e.game_status, e.tv_coverage, e.start_date_time_EST, e.ribbon, e.event_link,
			   (
			       SELECT a_e.away_first AS [first], a_e.away_last AS [last], a_e.away_abbr AS abbr,
			              a_e.away_rank AS [rank], a_e.away_score AS score, a_e.away_winner AS winner,
			              a_e.away_record AS record, a_e.away_logo AS logo, a_e.away_link AS link
                     FROM @events a_e
                    WHERE a_e.event_key = e.event_key
                      FOR XML RAW('away'), TYPE                   
			   ),
			   ( 
			       SELECT h_e.home_first AS [first], h_e.home_last AS [last], h_e.home_abbr AS abbr,
			              h_e.home_rank AS [rank], h_e.home_score AS score, h_e.home_winner AS winner,
			              h_e.home_record AS record, h_e.home_logo AS logo, h_e.home_link AS link
                     FROM @events h_e
                    WHERE h_e.event_key = e.event_key
                      FOR XML RAW('home'), TYPE
               )
          FROM @events e
         ORDER BY e.start_date_time_EST ASC
           FOR XML RAW('schedule'), TYPE
    )
    FOR XML PATH(''), ROOT('root')       

            
    SET NOCOUNT OFF 
END


GO
