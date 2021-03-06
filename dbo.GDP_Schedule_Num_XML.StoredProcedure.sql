USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[GDP_Schedule_Num_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[GDP_Schedule_Num_XML]
   @leagueName VARCHAR(100),
   @teamSlug VARCHAR(100),
   @numPast INT,
   @numFuture INT
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 06/08/2015
  -- Description: get team schedule for GDP
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

/* DEPRECATED

    IF (@leagueName NOT IN ('mlb', 'mls', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba'))
    BEGIN
        RETURN
    END

    DECLARE @today DATE = CAST(GETDATE() AS DATE)
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)   
    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/'
    DECLARE @logo_folder VARCHAR(100) = '-whitebg/22/'
    DECLARE @logo_suffix VARCHAR(100) = '.png'    
   	DECLARE @season_key INT
    DECLARE @team_key VARCHAR(100)

    SELECT @season_key = team_season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'schedules'

    SELECT @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @season_key AND team_slug = @teamSlug    
     
	DECLARE @events TABLE
	(
	    event_key    VARCHAR(100),
	    dt           DATETIME,
	    tv_coverage  VARCHAR(100),
	    -- render
	    event_date   VARCHAR(100),
	    event_time   VARCHAR(100),
	    home_game    INT,
	    opponent_key VARCHAR(100),
	    -- exra
	    season_key   INT,
	    away_key     VARCHAR(100),
	    home_key     VARCHAR(100),
	    event_id     VARCHAR(100)
	)
    INSERT INTO @events (season_key, event_key, dt, tv_coverage, away_key, home_key)
    SELECT TOP (@numPast) season_key, event_key, start_date_time_EST, tv_coverage, away_team_key, home_team_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @season_key AND @team_key IN (away_team_key, home_team_key) AND
           start_date_time_EST < @today AND event_status <> 'smg-not-played'
     ORDER BY start_date_time_EST DESC
           
    INSERT INTO @events (season_key, event_key, dt, tv_coverage, away_key, home_key)
    SELECT TOP (@numFuture) season_key, event_key, start_date_time_EST, tv_coverage, away_team_key, home_team_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @season_key AND @team_key IN (away_team_key, home_team_key) AND
           start_date_time_EST >= @today AND event_status <> 'smg-not-played'
     ORDER BY start_date_time_EST ASC

    UPDATE @events
       SET home_game = 0, opponent_key = home_key
     WHERE away_key = @team_key

    UPDATE @events
       SET home_game = 1, opponent_key = away_key
     WHERE home_key = @team_key

    -- date time
    UPDATE @events
       SET event_date = CAST(DATEPART(MONTH, dt) AS VARCHAR) + '/' + CAST(DATEPART(DAY, dt) AS VARCHAR) + '/' + CAST(DATEPART(YEAR, dt) AS VARCHAR),
           event_time = CASE WHEN DATEPART(HOUR, dt) > 12 THEN CAST(DATEPART(HOUR, dt) - 12 AS VARCHAR) ELSE CAST(DATEPART(HOUR, dt) AS VARCHAR) END + ':' +
                        CASE WHEN DATEPART(MINUTE, dt) < 10 THEN  '0' ELSE '' END + CAST(DATEPART(MINUTE, dt) AS VARCHAR) + ' ' +
                        CASE WHEN DATEPART(HOUR, dt) < 12 THEN 'AM' ELSE 'PM' END,
           event_id = REPLACE(event_key, @league_key + '-' + CAST(season_key AS VARCHAR) + '-e.', '')



    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT
	(
        SELECT 'true' AS 'json:Array',
               event_date, event_time, tv_coverage, home_game, opponent_key, event_id
          FROM @events
         ORDER BY dt ASC
           FOR XML RAW('schedule'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

*/
	
END

GO
