USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[API_GetEventDates_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[API_GetEventDates_XML] 
    @leagueName VARCHAR(100)
AS
-- =============================================
-- Author:      John Lin
-- Create date: 06/03/2014
-- Description: get event dates
-- Update: 06/16/2014 - John Lin - return only dates with team abbreviation
--         10/10/2014 - John Lin - exclude smg-not-played events
--         01/27/2015 - John Lin - add champions and epl
--         04/13/2015 - ikenticus: preparing for STATS soccer by adding the simpler league_keys
--         06/06/2015 - John Lin - hot fix 
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    IF (@leagueName NOT IN ('champions', 'mlb', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba',
							'wwc', 'epl', 'chlg', 'mls'))
    BEGIN
        RETURN
    END
    
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @yesterday DATE = DATEADD(DAY, -1, CAST(GETDATE() AS DATE))
    DECLARE @concat VARCHAR(MAX)

    DECLARE @dates TABLE
    (
        [date] DATE,
        season_key INT,
        away_key VARCHAR(100),
        home_key VARCHAR(100),
        away_abbr VARCHAR(100),
        home_abbr VARCHAR(100)
    )
        
    INSERT INTO @dates ([date], season_key, away_key, home_key)
    SELECT CAST(start_date_time_EST AS DATE), season_key, away_team_key, home_team_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND start_date_time_EST > @yesterday AND event_status <> 'smg-not-played'

    UPDATE d
       SET d.away_abbr = st.team_abbreviation
      FROM @dates d
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND st.season_key = d.season_key AND st.team_key = d.away_key

    UPDATE d
       SET d.home_abbr = st.team_abbreviation
      FROM @dates d
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND st.season_key = d.season_key AND st.team_key = d.home_key

    -- remove events
    DELETE @dates
     WHERE away_abbr IS NULL OR away_abbr = ''

    DELETE @dates
     WHERE home_abbr IS NULL OR home_abbr = ''

	SELECT @concat = COALESCE(@concat + ',' + CAST([date] AS VARCHAR), CAST([date] AS VARCHAR))
	  FROM @dates
	 GROUP BY [date]


    SELECT
	(
        SELECT @concat AS dates
           FOR XML PATH(''), TYPE
    )
    FOR XML PATH(''), ROOT('root')
        
    SET NOCOUNT OFF;
END

GO
