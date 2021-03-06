USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetTickerByConference_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[HUB_GetTickerByConference_XML]
   @leagueName VARCHAR(100),
   @conference VARCHAR(100)
AS
--=============================================
-- Author:		John Lin
-- Create date:	07/28/2014
-- Description:	get ticker by conference
-- Update:		08/15/2014 - ikenticus: forcing schedule node to be array
--              12/16/2014 - John Lin - render all bowls and playoffs
--				07/01/2015 - ikenticus - adjusting to STATS migration and SMG_Polls* conversion
--              07/29/2015 - John Lin - SDI migration
--              08/03/2015 - John Lin - retrieve event_id using function
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

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @season_key INT = 0
    DECLARE @sub_season_type VARCHAR(100) = ''
    DECLARE @week VARCHAR(100) = ''
    DECLARE @start_date DATETIME = NULL
    DECLARE @end_date DATETIME
    DECLARE @week_int INT
    
    SELECT @season_key = season_key, @sub_season_type = sub_season_type, @week = [week],
           @start_date = [start_date]
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'suspender'
 
	DECLARE @events TABLE
	(
        season_key          INT,
        event_key           VARCHAR(100),	    
        event_status        VARCHAR(100),
        game_status         VARCHAR(100),
        away_key            VARCHAR(100),
        away_score          VARCHAR(100),
        away_rank           VARCHAR(100) DEFAULT '',
        away_winner         VARCHAR(100) DEFAULT '',
        home_key            VARCHAR(100),
        home_score          VARCHAR(100),
        home_rank           VARCHAR(100) DEFAULT '',
        home_winner         VARCHAR(100) DEFAULT '',
        start_date_time_EST DATETIME,
        [week]              VARCHAR(100),
	    -- info
        away_abbr           VARCHAR(100),
        home_abbr           VARCHAR(100),
	    -- extra
	    away_conference     VARCHAR(200),
	    home_conference     VARCHAR(200),
	    event_link          VARCHAR(200),
	    event_id            VARCHAR(100),
	    date_order          INT,
	    status_order        INT,
	    time_order          INT
	)
    
    IF (@leagueName = 'nfl')
    BEGIN
        IF (@season_key IS NULL OR @sub_season_type IS NULL OR @week IS NULL)
        BEGIN
            RETURN
        END

        INSERT INTO @events (season_key, event_key, event_status, game_status, away_key, away_score, home_key, home_score, start_date_time_EST, [week])
        SELECT season_key, event_key, event_status, game_status, away_team_key, away_team_score, home_team_key, home_team_score, start_date_time_EST, [week]
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = @sub_season_type AND [week] = @week
    END
    ELSE IF (@leagueName = 'ncaaf')
    BEGIN
        IF (@season_key IS NULL OR @week IS NULL)
        BEGIN
            RETURN
        END

        IF (@week = 'bowls')
        BEGIN
            INSERT INTO @events (season_key, event_key, event_status, game_status, away_key, away_score, home_key, home_score, start_date_time_EST, [week])
            SELECT season_key, event_key, event_status, game_status, away_team_key, away_team_score, home_team_key, home_team_score, start_date_time_EST, [week]
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @season_key AND [week] = 'playoffs' 
        END

        INSERT INTO @events (season_key, event_key, event_status, game_status, away_key, away_score, home_key, home_score, start_date_time_EST, [week])
        SELECT season_key, event_key, event_status, game_status, away_team_key, away_team_score, home_team_key, home_team_score, start_date_time_EST, [week]
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @season_key AND [week] = @week
    END
    ELSE
    BEGIN
        IF (@start_date IS NULL)
        BEGIN
            RETURN
        END

        IF (@conference_key IS NOT NULL)
        BEGIN
            SELECT TOP 5 @end_date = DATEADD(SECOND, -1, DATEADD(DAY, 1, start_date_time_EST))
              FROM dbo.SMG_Schedules ss
             INNER JOIN dbo.SMG_Teams st
                ON st.season_key = ss.season_key AND st.team_key IN (ss.away_team_key, ss.home_team_key) AND st.conference_key = @conference_key
             WHERE ss.league_key = @league_key AND ss.start_date_time_EST > @start_date AND ss.event_status <> 'smg-not-played'
             ORDER BY ss.start_date_time_EST ASC
        END
        ELSE
        BEGIN
            SET @end_date = DATEADD(SECOND, -1, DATEADD(DAY, 1, @start_date))
        END
        
        INSERT INTO @events (season_key, event_key, event_status, game_status, away_key, away_score, home_key, home_score, start_date_time_EST, [week])
        SELECT season_key, event_key, event_status, game_status, away_team_key, away_team_score, home_team_key, home_team_score, start_date_time_EST, [week]
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND start_date_time_EST BETWEEN @start_date AND @end_date AND event_status <> 'smg-not-played'
    END

    -- NO RECORD
    IF NOT EXISTS (SELECT 1 FROM @events)
    BEGIN
        SELECT '' AS schedule
        FOR XML PATH(''), ROOT('root')
        
        RETURN
    END

    
    
    UPDATE e
       SET e.away_abbr = st.team_abbreviation, e.away_conference = st.conference_key
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = e.season_key AND st.team_key = e.away_key

    UPDATE e
       SET e.home_abbr = st.team_abbreviation, e.home_conference = st.conference_key
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = e.season_key AND st.team_key = e.home_key

    UPDATE @events
       SET away_conference = ''
     WHERE away_conference IS NULL

    UPDATE @events
       SET home_conference = ''
     WHERE home_conference IS NULL

    IF (@conference_key IS NOT NULL)
    BEGIN
        DELETE @events
         WHERE @conference_key NOT IN (away_conference, home_conference)
    END
 
    -- LINK
    -- event id
    UPDATE @events
       SET event_id = dbo.SMG_fnEventId(event_key)

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
       SET e.event_link = '/' + CASE WHEN @leagueName IN ('ncaab', 'ncaaf', 'ncaaw') THEN 'ncaa' ELSE @leagueName END + '/' +
                          CASE
                              WHEN @leagueName = 'ncaab' THEN 'mens-basketball/'
                              WHEN @leagueName = 'ncaaf' THEN 'football/'
                              WHEN @leagueName = 'ncaaw' THEN 'womens-basketball/'
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
       SET event_link = '/' + CASE WHEN @leagueName IN ('ncaab', 'ncaaf', 'ncaaw') THEN 'ncaa' ELSE @leagueName END + '/' +
                        CASE
                            WHEN @leagueName = 'ncaab' THEN 'mens-basketball/'
                            WHEN @leagueName = 'ncaaf' THEN 'football/'
                            WHEN @leagueName = 'ncaaw' THEN 'womens-basketball/'
                            ELSE ''
                        END + 'event/' + CAST(season_key AS VARCHAR) + '/' + event_id +
                        CASE
                            WHEN event_status IN ('mid-event', 'post-event') THEN '/boxscore/'
                            ELSE '/preview/'
                        END
      WHERE event_link IS NULL


    -- RANK
    IF (@leagueName IN ('ncaab', 'ncaaw'))
    BEGIN
        SELECT TOP 1 @season_key = season_key
          FROM @events
         ORDER BY season_key DESC
    END

    DECLARE @poll_week INT
    
    IF (ISNUMERIC(@week) = 1 AND EXISTS (SELECT 1
		                                   FROM SportsEditDB.dbo.SMG_Polls
				                          WHERE league_key = @leagueName AND season_key = @season_key AND fixture_key = 'smg-usat' AND [week] = @week))
    BEGIN
		SET @poll_week = CAST(@week AS INT)
	END
	ELSE
	BEGIN             
		SELECT TOP 1 @poll_week = [week]
		  FROM SportsEditDB.dbo.SMG_Polls
		 WHERE league_key = @leagueName AND season_key = @season_key AND fixture_key = 'smg-usat'
		 ORDER BY [week] DESC
	END

	UPDATE e
	   SET e.away_rank = sp.ranking
	  FROM @events e
	 INNER JOIN SportsEditDB.dbo.SMG_Polls sp
		ON sp.league_key = @leagueName AND sp.season_key = @season_key AND sp.fixture_key = 'smg-usat' AND
		   sp.team_key = e.away_abbr AND sp.[week] = @poll_week
              
	UPDATE e
	   SET e.home_rank = sp.ranking
	  FROM @events e
	 INNER JOIN SportsEditDB.dbo.SMG_Polls sp
		ON sp.league_key = @leagueName AND sp.season_key = @season_key AND sp.fixture_key = 'smg-usat' AND
		   sp.team_key = e.home_abbr AND sp.[week] = @poll_week

        
    IF (@leagueName IN ('ncaab', 'ncaaw'))
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

    -- WINNER
    UPDATE @events
       SET away_winner = '1', home_winner = '0'
     WHERE event_status = 'post-event' AND CAST(away_score AS INT) > CAST(home_score AS INT)

    UPDATE @events
       SET home_winner = '1', away_winner = '0'
     WHERE event_status = 'post-event' AND CAST(home_score AS INT) > CAST(away_score AS INT)

    -- RENDER
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
               e.event_link, e.event_key, e.event_status, e.game_status, e.start_date_time_EST,               
			   (
			       SELECT e_a.away_score AS score,
                          e_a.away_rank AS [rank],
                          e_a.away_key AS team_key,
                          e_a.away_abbr AS abbr,
                          e_a.away_winner AS winner
                          
                     FROM @events AS e_a
                    WHERE e_a.event_key = e.event_key
                   FOR XML RAW('away_team'), TYPE                   
			   ),
			   ( 
                   SELECT e_h.home_score AS score,
                          e_h.home_rank AS [rank],
                          e_h.home_key AS team_key,
                          e_h.home_abbr AS abbr,
                          e_h.home_winner AS winner
                     FROM @events AS e_h
                    WHERE e_h.event_key = e.event_key
                      FOR XML RAW('home_team'), TYPE
               )  
          FROM @events AS e
         ORDER BY e.date_order ASC, e.status_order ASC, e.time_order ASC
           FOR XML RAW('schedule'), TYPE
	)
    FOR XML PATH(''), ROOT('root')
            
    SET NOCOUNT OFF 
END


GO
