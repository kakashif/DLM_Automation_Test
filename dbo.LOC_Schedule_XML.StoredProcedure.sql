USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[LOC_Schedule_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[LOC_Schedule_XML]
   @leagueName VARCHAR(100),
   @teamSlug VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 04/20/2015
  -- Description: get team schedule for USCP
  -- Update: 07/29/2015 - John Lin - SDI migration
  --	     08/03/2015 - John Lin - retrieve event_id using function
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    IF (@leagueName NOT IN ('mlb', 'mls', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba'))
    BEGIN
        RETURN
    END


    IF (@leagueName IN ('nfl', 'ncaaf'))
    BEGIN
        EXEC dbo.LOC_Schedule_new_XML @leagueName, @teamSlug
        RETURN
    END


    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
   	DECLARE @season_key INT
    DECLARE @team_key VARCHAR(100)
    DECLARE @logo_league VARCHAR(100) = @leagueName
    DECLARE @sub_season VARCHAR(100)

    SELECT @season_key = team_season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'schedules'

    SELECT @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @season_key AND team_slug = @teamSlug    

     
	DECLARE @events TABLE
	(
	    season_key    INT,
	    sub_season    VARCHAR(100),
	    date_time     VARCHAR(100),
	    dt            DATETIME,
	    event_status  VARCHAR(100),	    
	    away_key      VARCHAR(100),
	    away_score    VARCHAR(100),
	    home_key      VARCHAR(100),
	    home_score    VARCHAR(100),
	    game_status   VARCHAR(100),
	    event_key     VARCHAR(100),
	    event_id      VARCHAR(100)
	)	
    INSERT INTO @events (season_key, sub_season, dt, event_status, away_key, away_score, home_key, home_score, game_status, event_key)
    SELECT season_key, sub_season_type, start_date_time_EST, event_status, away_team_key, away_team_score, home_team_key, home_team_score, game_status, event_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @season_key AND @team_key IN (away_team_key, home_team_key) AND event_status <> 'smg-not-played'

    -- All-Stars
    IF (@leagueName = 'mlb')
    BEGIN     
        INSERT INTO @events (season_key, sub_season, dt, event_status, away_key, away_score, home_key, home_score, game_status, event_key)
        SELECT season_key, sub_season_type, start_date_time_EST, event_status, away_team_key, away_team_score, home_team_key, home_team_score, game_status, event_key
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @season_key AND away_team_key IN ('321', '322') AND event_status <> 'smg-not-played'
    END

    -- sub season
    SELECT TOP 1 @sub_season = sub_season
      FROM @events
     WHERE event_status = 'pre-event'
     ORDER BY date_time ASC

    IF (@sub_season = 'season-regular')
    BEGIN
        DELETE @events
         WHERE sub_season = 'pre-season'
    END

    -- date time
    UPDATE @events
       SET date_time = CAST(DATEPART(MONTH, dt) AS VARCHAR) + '/' +
                       CAST(DATEPART(DAY, dt) AS VARCHAR) + '/' +
                       CAST(DATEPART(YEAR, dt) AS VARCHAR) + ' ' +
                       CASE WHEN DATEPART(HOUR, dt) > 12 THEN CAST(DATEPART(HOUR, dt) - 12 AS VARCHAR) ELSE CAST(DATEPART(HOUR, dt) AS VARCHAR) END + ':' +
                       CASE WHEN DATEPART(MINUTE, dt) < 10 THEN  '0' ELSE '' END + CAST(DATEPART(MINUTE, dt) AS VARCHAR) + ' ' +
                       CASE WHEN DATEPART(HOUR, dt) < 12 THEN 'AM' ELSE 'PM' END

    -- event id
    UPDATE @events
       SET event_id = dbo.SMG_fnEventId(event_key)
       


    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT
	(
        SELECT 'true' AS 'json:Array',
               date_time, away_key, ISNULL(away_score, '') AS away_score, home_key, ISNULL(home_score, '') AS home_score, game_status, event_id
          FROM @events
         ORDER BY dt ASC
           FOR XML RAW('schedule'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

	
END

GO
