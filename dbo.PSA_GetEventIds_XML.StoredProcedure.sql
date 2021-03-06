USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventIds_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventIds_XML] 
    @leagueName VARCHAR(100),
    @year INT,
    @month INT,
    @day INT
AS
-- =============================================
-- Author:      John Lin
-- Create date: 06/03/2014
-- Description: get event ids
-- Update:		06/16/2014 - John Lin - return only events with team abbreviation
--				07/23/2014 - ikenticus - adding brief_display for CMS dropdown
--              10/10/2014 - John Lin - exclude smg-not-played events
--              01/27/2015 - John Lin - add champions and epl
--				04/13/2015 - ikenticus: preparing for STATS soccer by adding the simpler league_keys (preliminary)
--              06/06/2015 - Johh Lin - hot fix
--              07/29/2015 - John Lin - SDI migration
--              08/03/2015 - John Lin - retrieve event_id using function
--              09/02/2015 - ikenticus - use team_first for SDI soccer
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    IF (@leagueName NOT IN ('mlb','nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba',
							'champions', 'wwc', 'epl', 'chlg', 'mls'))
    BEGIN
        RETURN
    END
    
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @date DATE = CAST(CAST(@year AS VARCHAR) + '-' + CAST(@month AS VARCHAR) + '-' + CAST(@day AS VARCHAR) AS DATETIME)

    DECLARE @events TABLE
    (
        season_key INT,
        event_key VARCHAR(100),
        away_key VARCHAR(100),
        home_key VARCHAR(100),
        start_date_time_EST DATETIME,
        -- extra        
        event_id VARCHAR(100),
        brief_display VARCHAR(100),
        brief_endpoint VARCHAR(100),
        away_name VARCHAR(100),
        away_abbr VARCHAR(100),
        home_name VARCHAR(100),
        home_abbr VARCHAR(100),
        start_time VARCHAR(100)
    )    

    INSERT INTO @events (season_key, event_key, away_key, home_key, start_date_time_EST)
	SELECT season_key, event_key, away_team_key, home_team_key, start_date_time_EST
	  FROM dbo.SMG_Schedules
	 WHERE league_key = @league_key AND start_date_time_EST BETWEEN @date AND DATEADD(DAY, 1, @date) AND event_status <> 'smg-not-played'

    UPDATE @events
       SET start_time = CONVERT(VARCHAR, CAST(start_date_time_EST AS TIME), 100)
 
       
    IF (@leagueName IN ('ncaab', 'ncaaf', 'natl', 'wwc', 'epl', 'champions'))
    BEGIN
        UPDATE e
           SET e.away_name = st.team_first, e.away_abbr = st.team_abbreviation
          FROM @events e
         INNER JOIN dbo.SMG_Teams st
            ON st.season_key = e.season_key AND st.team_key = e.away_key

        UPDATE e
           SET e.home_name = st.team_first, e.home_abbr = st.team_abbreviation
          FROM @events e
         INNER JOIN dbo.SMG_Teams st
            ON st.season_key = e.season_key AND st.team_key = e.home_key
    END
    ELSE
    BEGIN
        UPDATE e
           SET e.away_name = st.team_last, e.away_abbr = st.team_abbreviation
          FROM @events e
         INNER JOIN dbo.SMG_Teams st
            ON st.season_key = e.season_key AND st.team_key = e.away_key

        UPDATE e
           SET e.home_name = st.team_last, e.home_abbr = st.team_abbreviation
          FROM @events e
         INNER JOIN dbo.SMG_Teams st
            ON st.season_key = e.season_key AND st.team_key = e.home_key
    END

    -- event id
    UPDATE @events
       SET event_id = dbo.SMG_fnEventId(event_key)

    UPDATE @events
       SET brief_endpoint = '/Event.svc/brief/' + @leagueName + '/' + CAST(season_key AS VARCHAR) + '/' + event_id

    UPDATE @events
       SET brief_display = start_time + ': ' + away_name + ' at ' + home_name

    -- remove events
    DELETE @events
     WHERE away_abbr IS NULL OR away_abbr = ''

    DELETE @events
     WHERE home_abbr IS NULL OR home_abbr = ''

     
    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT (
               SELECT 'true' AS 'json:Array',
                      start_time AS [time], away_name AS away, home_name AS home, brief_display, brief_endpoint, event_id AS id 
                 FROM @events
                ORDER BY start_date_time_EST ASC
                  FOR XML RAW('events'), TYPE
           )
       FOR XML PATH(''), ROOT('root')

        
    SET NOCOUNT OFF;
END

GO
