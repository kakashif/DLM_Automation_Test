USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[EXT_GetScores_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[EXT_GetScores_XML]
    @year INT,
    @month INT,
    @day INT
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 10/07/2014
  -- Description: get scores for date for all sports
  -- Update: 07/10/2015 - John Lin - STATS team records
  -- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @start_date DATETIME = CAST(CAST(@year AS VARCHAR) + '-' + CAST(@month AS VARCHAR) + '-' + CAST(@day AS VARCHAR) AS DATETIME)
    DECLARE @end_date DATETIME = DATEADD(SECOND, -1, DATEADD(DAY, 1, @start_date))
    
	DECLARE @events TABLE
	(
	    league_key           VARCHAR(100),
        season_key           INT,
        event_key            VARCHAR(100),
        event_status         VARCHAR(100),
        game_status          VARCHAR(100),
        start_date_time_EST  DATETIME,
        away_team_key        VARCHAR(100),
        away_team_score      INT,
        away_team_rank       VARCHAR(100),
        away_team_winner     VARCHAR(100),
        away_team_abbr       VARCHAR(100),
        away_team_first      VARCHAR(100),
        away_team_last       VARCHAR(100),
        away_team_record     VARCHAR(100),        
        home_team_key        VARCHAR(100),
        home_team_score      INT,
        home_team_rank       VARCHAR(100),
        home_team_winner     VARCHAR(100),
        home_team_abbr       VARCHAR(100),
        home_team_first      VARCHAR(100),
        home_team_last       VARCHAR(100),
        home_team_record     VARCHAR(100),
	    -- extra
        ribbon               VARCHAR(100),
	    status_order         INT
	)

    INSERT INTO @events (league_key, season_key, event_key, event_status, game_status, start_date_time_EST,
                         away_team_key, away_team_score, home_team_key, home_team_score)
    SELECT league_key, season_key, event_key, event_status, game_status, start_date_time_EST,
           away_team_key, away_team_score,  home_team_key, home_team_score
      FROM dbo.SMG_Schedules
     WHERE league_key = league_key AND start_date_time_EST BETWEEN @start_date AND @end_date AND event_status <> 'smg-not-played'        

    UPDATE e
       SET e.away_team_abbr = st.team_abbreviation, e.away_team_first = st.team_first, e.away_team_last = st.team_last
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = e.season_key AND st.team_key = e.away_team_key AND st.league_key = e.league_key

    UPDATE e
       SET e.home_team_abbr = st.team_abbreviation, e.home_team_first = st.team_first, e.home_team_last = st.team_last
      FROM @events e
     INNER JOIN dbo.SMG_Teams st
        ON st.season_key = e.season_key AND st.team_key = e.home_team_key AND st.league_key = e.league_key
	    
    UPDATE @events
       SET away_team_winner = '1', home_team_winner = '0'
     WHERE event_status = 'post-event' AND away_team_score > home_team_score

    UPDATE @events
       SET home_team_winner = '1', away_team_winner = '0'
     WHERE event_status = 'post-event' AND home_team_score > away_team_score

    UPDATE @events
       SET away_team_record = '(' + dbo.SMG_fn_Team_Records(league_key, season_key, away_team_key, event_key) + ')'
     WHERE away_team_last <> 'All-Stars'
     
    UPDATE @events
       SET home_team_record = '(' + dbo.SMG_fn_Team_Records(league_key, season_key, home_team_key, event_key) + ')'
     WHERE home_team_last <> 'All-Stars'


    -- RIBBON
    -- POST SEASON
    UPDATE e
       SET e.ribbon = tag.score
      FROM @events AS e
     INNER JOIN dbo.SMG_Event_Tags tag
        ON tag.event_key = e.event_key    

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
       	


	;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT
	(
        SELECT 'true' AS 'json:Array',
               l.league_key,
               (
                   SELECT 'true' AS 'json:Array',
                          g.event_key, g.event_status, g.ribbon, g.start_date_time_EST, g.game_status,
			              (
			                  SELECT a_e.away_team_key AS team_key,
			                         a_e.away_team_abbr AS team_abbr,
			                         a_e.away_team_first AS team_first,
           			                 a_e.away_team_last AS team_last,
                                     a_e.away_team_rank AS team_rank,
                                     a_e.away_team_score AS team_score,
                                     a_e.away_team_winner AS team_winner,
                                     a_e.away_team_record AS team_record
                                FROM @events a_e
                               WHERE a_e.event_key = g.event_key
                                 FOR XML RAW('away_team'), TYPE                   
			              ),
			              ( 
			                  SELECT h_e.home_team_key AS team_key,
			                         h_e.home_team_abbr AS team_abbr,
			                         h_e.home_team_first AS team_first,
			                         h_e.home_team_last AS team_last,
                                     h_e.home_team_rank AS team_rank,
                                     h_e.home_team_score AS team_score,
                                     h_e.home_team_winner AS team_winner,
                                     h_e.home_team_record AS team_record
                                FROM @events h_e
                               WHERE h_e.event_key = g.event_key
                                 FOR XML RAW('home_team'), TYPE
                          )
                     FROM @events g
                    WHERE g.league_key = l.league_key
                    ORDER BY g.status_order ASC
                      FOR XML RAW('event'), TYPE
               )
          FROM @events l
         GROUP BY l.league_key
           FOR XML RAW('league'), TYPE
    )
    FOR XML PATH(''), ROOT('root')
    
    SET NOCOUNT OFF;
END

GO
