USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetEventMoreFilter_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DES_GetEventMoreFilter_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT,
    @filter VARCHAR(100) = NULL
AS
-- =============================================
-- Author:		John Lin
-- Create date: 03/10/2014
-- Description:	get more event with filter for desktop
-- Update: 03/27/2014 - John Lin - fix order
--         04/24/2014 - John Lin - use suspender for ribbon
--         05/02/2014 - John Lin - exclude smg-not-played
--         06/09/2014 - thlam - sorting the 2nd start_date_time_EST column
--         06/10/2014 - John Lin - set pre event score to null
--		   08/14/2014 - ikenticus - appending @filter to boxscore_link
--		   08/20/2014 - ikenticus - correcting NCAAF conf filtering issue due to NULL conf
--		   09/09/2014 - ikenticus - per JIRA SCI-491, only append @filter to NCAAF when NOT NULL
--		   06/03/2015 - ikenticus - adding CDN logos and fixing league_key logic
--         06/24/2015 - ikenticus - adding failover event_key logic for source transitions
--		   07/01/2015 - ikenticus - adjusting to SMG_Polls* conversion
--         07/29/2015 - John Lin - SDI migration
--	       08/03/2015 - John Lin - retrieve event_id and logo using functions
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @event_key VARCHAR(100)
    DECLARE @sub_season_type VARCHAR(100)
    DECLARE @week VARCHAR(100)
    DECLARE @start_date DATETIME
    DECLARE @end_date DATETIME

    SELECT TOP 1 @event_key = event_key, @sub_season_type = sub_season_type, @week = [week], @start_date = CAST(start_date_time_EST AS DATE)
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key,
			   @event_key = event_key, @sub_season_type = sub_season_type, @week = [week], @start_date = CAST(start_date_time_EST AS DATE)
		  FROM SportsDB.dbo.SMG_Schedules AS s
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = s.league_key AND m.value_to = @leagueName AND m.value_type = 'league'
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		 ORDER BY league_key DESC
	END

	DECLARE @events TABLE
	(
        event_key           VARCHAR(100),        
        event_status        VARCHAR(100),
        start_date_time_EST DATETIME,
        away_team_key       VARCHAR(100),
        away_team_abbr      VARCHAR(100),
        away_team_logo      VARCHAR(100),
        away_team_score     VARCHAR(100),
        away_team_rank      VARCHAR(100),
        away_team_class     VARCHAR(100),
        away_team_winner    VARCHAR(100),
        away_team_conf      VARCHAR(100),
        home_team_key       VARCHAR(100),
        home_team_abbr      VARCHAR(100),
        home_team_logo      VARCHAR(100),
        home_team_score     VARCHAR(100),
        home_team_rank      VARCHAR(100),
        home_team_class     VARCHAR(100),
        home_team_winner    VARCHAR(100),
        home_team_conf      VARCHAR(100),
        game_status         VARCHAR(100),
        [week]              VARCHAR(100),
        ribbon              VARCHAR(100),
        event_id            VARCHAR(100),
        preview_link        VARCHAR(100),
        boxscore_link       VARCHAR(100),
        recap_link          VARCHAR(100),
        status_order        INT
    )
    
    IF (@leagueName IN ('nfl', 'ncaaf'))
    BEGIN
        INSERT INTO @events (event_key, event_status, start_date_time_EST, away_team_key, away_team_score,
                             home_team_key, home_team_score, game_status, [week])
        SELECT event_key, event_status, start_date_time_EST, away_team_key, away_team_score,
               home_team_key, home_team_score, game_status, [week]
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @sub_season_type AND [week] = @week
    END
    ELSE
    BEGIN    
        SET @end_date = DATEADD(SECOND, -1, DATEADD(DAY, 1, @start_date)) 
        
        INSERT INTO @events (event_key, event_status, start_date_time_EST, away_team_key, away_team_score,
                             home_team_key, home_team_score, game_status, [week])
        SELECT event_key, event_status, start_date_time_EST, away_team_key, away_team_score,
               home_team_key, home_team_score, game_status, [week]
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND start_date_time_EST BETWEEN @start_date AND @end_date AND event_status <> 'smg-not-played'
    END    

    -- remove self
    DELETE @events
     WHERE event_key = @event_key

    -- set scores to null for pre event
    UPDATE @events
       SET away_team_score = NULL, home_team_score = NULL
     WHERE event_status = 'pre-event'

    UPDATE e
       SET e.away_team_abbr = st.team_abbreviation, e.away_team_conf = st.conference_key
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND st.season_key = @seasonKey AND st.team_key = e.away_team_key

    UPDATE e
       SET e.home_team_abbr = st.team_abbreviation, e.home_team_conf = st.conference_key
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND st.season_key = @seasonKey AND st.team_key = e.home_team_key
     
    -- FILTER
    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        UPDATE @events
           SET away_team_class = away_team_abbr, home_team_class = home_team_abbr


        IF (@leagueName = 'ncaaf')
        BEGIN
            SELECT TOP 1 @start_date = start_date_time_EST
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @seasonKey AND [week] = @week
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

        IF (@filter IN ('div1.a', 'div1'))
        BEGIN
            SET @filter = 'top25'
        END
        
        IF (@filter = 'top25')
        BEGIN
            DELETE @events
             WHERE (CAST(ISNULL(home_team_rank, '') AS INT) + CAST(ISNULL(away_team_rank, '') AS INT)) = 0
        END            
        ELSE IF (@filter IN ('tourney', 'ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi'))
        BEGIN
            IF (@leagueName IN ('ncaab', 'ncaaw'))
            BEGIN
                UPDATE e
                   SET e.away_team_rank = enbt.seed
                  FROM @events e
                 INNER JOIN SportsEditDB.dbo.Edit_NCAA_Bracket_Teams enbt
                    ON enbt.league_key = @league_key AND enbt.season_key = @seasonKey AND enbt.team_key = e.away_team_key
                 WHERE e.[week] = 'ncaa'

                UPDATE e
                   SET e.home_team_rank = enbt.seed
                  FROM @events e
                 INNER JOIN SportsEditDB.dbo.Edit_NCAA_Bracket_Teams enbt
                    ON enbt.league_key = @league_key AND enbt.season_key = @seasonKey AND enbt.team_key = e.home_team_key
                 WHERE e.[week] = 'ncaa'
            END

            IF (@filter = 'tourney')
            BEGIN
                DELETE @events
                 WHERE [week] NOT IN ('ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi')
            END
            ELSE
            BEGIN
                DELETE @events
                 WHERE [week] <> @filter
            END
        END
        ELSE
        BEGIN
			-- UPDATE conf to empty if NULL before DELETE
			UPDATE @events
               SET away_team_conf = ''
             WHERE away_team_conf IS NULL

			UPDATE @events
               SET home_team_conf = ''
             WHERE home_team_conf IS NULL

            DELETE @events
             WHERE away_team_conf <> @filter AND home_team_conf <> @filter
        END
    END        
    ELSE
    BEGIN
        UPDATE @events
           SET away_team_class = @leagueName + REPLACE(away_team_key, @league_key + '-t.', ''),
               home_team_class = @leagueName + REPLACE(home_team_key, @league_key + '-t.', '')
    END


    UPDATE @events
       SET away_team_winner = '1', home_team_winner = '0'
     WHERE event_status = 'post-event' AND CAST(away_team_score AS INT) > CAST(home_team_score AS INT)

    UPDATE @events
       SET home_team_winner = '1', away_team_winner = '0'
     WHERE event_status = 'post-event' AND CAST(home_team_score AS INT) > CAST(away_team_score AS INT)

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

	UPDATE @events
	   SET boxscore_link = '/sports/' + @leagueName + '/event/' + CAST(@seasonKey AS VARCHAR) + '/' + event_id + '/boxscore/'

    UPDATE e
       SET e.preview_link = '/sports/' + @leagueName + '/event/' + CAST(@seasonKey AS VARCHAR) + '/' + e.event_id + '/preview/'
      FROM @events e
     INNER JOIN @coverage c
        ON c.event_key = e.event_key AND c.column_type = 'pre-event-coverage'

    UPDATE e
       SET e.recap_link = '/sports/' + @leagueName + '/event/' + CAST(@seasonKey AS VARCHAR) + '/' + e.event_id + '/recap/'
      FROM @events e
     INNER JOIN @coverage c
        ON c.event_key = e.event_key AND c.column_type = 'post-event-coverage'


    IF (@leagueName = 'ncaaf' AND @filter IS NOT NULL)
	BEGIN
		UPDATE @events
		   SET boxscore_link = boxscore_link + @filter + '/'
	END

    IF (@leagueName = 'ncaab')
    BEGIN
       UPDATE @events
          SET boxscore_link = REPLACE(boxscore_link, 'event', 'bracket'),
              preview_link = REPLACE(preview_link, 'event', 'bracket'),
              recap_link = REPLACE(recap_link, 'event', 'bracket')
        WHERE [week] = 'ncaa'

       UPDATE @events
          SET boxscore_link = boxscore_link + @filter + '/',
              preview_link = preview_link + @filter + '/',
              recap_link = recap_link + @filter + '/'
        WHERE [week] IS NULL OR [week] <> 'ncaa'
	END

    -- RIBBON
    -- POST SEASON
    UPDATE e
       SET e.ribbon = tag.suspender
      FROM @events AS e
     INNER JOIN dbo.SMG_Event_Tags tag
        ON tag.event_key = e.event_key

    -- ORDER
    UPDATE @events
       SET status_order = (CASE
	                          WHEN event_status = 'mid-event' THEN 1
                              WHEN event_status = 'intermission' THEN 2
               	              WHEN event_status = 'weather-delay' THEN 3
	                          WHEN event_status = 'post-event' THEN 4
	                          WHEN event_status = 'suspended' THEN 5
	                          WHEN event_status = 'postponed' THEN 6
	                          WHEN event_status = 'pre-event' THEN 7
	                      END)
    
    -- logo
	UPDATE @events
	   SET away_team_logo = dbo.SMG_fnTeamLogo(@leagueName, away_team_abbr, '30'),
		   home_team_logo = dbo.SMG_fnTeamLogo(@leagueName, home_team_abbr, '30')


    SELECT
	(
        SELECT e.event_key, e.game_status, e.event_status, e.preview_link, e.boxscore_link, e.recap_link, e.ribbon,
               CONVERT(VARCHAR(100), CAST(e.start_date_time_EST AS TIME), 100) AS start_time,
			   (
			       SELECT a_e.away_team_score AS score,
                          a_e.away_team_rank AS [rank],
                          a_e.away_team_key AS team_key,
                          a_e.away_team_abbr AS abbr,
                          a_e.away_team_logo AS team_logo,
                          a_e.away_team_class AS team_class,
                          a_e.away_team_winner AS winner
                     FROM @events a_e
                    WHERE a_e.event_key = e.event_key
                      FOR XML RAW('away_team'), TYPE                   
			   ),
			   ( 
			       SELECT h_e.home_team_score AS score,
                          h_e.home_team_rank AS [rank],
                          h_e.home_team_key AS team_key,
                          h_e.home_team_abbr AS abbr,
                          h_e.home_team_logo AS team_logo,
                          h_e.home_team_class AS team_class,
                          h_e.home_team_winner AS winner
                     FROM @events h_e
                    WHERE h_e.event_key = e.event_key
                      FOR XML RAW('home_team'), TYPE
               )
          FROM @events e
         ORDER BY e.status_order ASC, e.start_date_time_EST ASC
           FOR XML RAW('score'), TYPE
    )
    FOR XML PATH(''), ROOT('root')
        	    
    SET NOCOUNT OFF;
END

GO
