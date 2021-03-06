USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[LOC_Scores_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[LOC_Scores_XML]
   @leagueName VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 04/20/2015
  -- Description: get team schedule for USCP
  -- Update: 05/21/2015 - John Lin - add game_status
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    IF (@leagueName NOT IN ('mlb', 'mls', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba'))
    BEGIN
        RETURN
    END

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
   	DECLARE @season_key INT
    DECLARE @sub_season_type VARCHAR(100)
    DECLARE @week VARCHAR(100)
    DECLARE @start_date DATETIME
    DECLARE @team_key VARCHAR(100)
       	
    SELECT @season_key = season_key, @sub_season_type = sub_season_type, @week = [week], @start_date = [start_date]
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'scores'

	DECLARE @events TABLE
	(
	    date_time     VARCHAR(100),
	    dt            DATETIME,
	    event_status  VARCHAR(100),
	    game_status   VARCHAR(100),	    
	    away_key      VARCHAR(100),
	    away_score    VARCHAR(100),
	    home_key      VARCHAR(100),
	    home_score    VARCHAR(100),
	    ribbon        VARCHAR(100),
	    [date]        DATE,
	    [time]        TIME
	)	

    IF (@leagueName IN ('ncaaf', 'nfl'))
    BEGIN
        IF (@leagueName = 'ncaaf')
        BEGIN
            SET @sub_season_type = 'season-regular'
        END
        
        INSERT INTO @events (dt, event_status, game_status, away_key, away_score, home_key, home_score)
        SELECT start_date_time_EST, event_status, game_status, away_team_key, away_team_score, home_team_key, home_team_score
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = @sub_season_type AND [week] = @week AND event_status <> 'smg-not-played'
    END
    ELSE
    BEGIN
        DECLARE @end_date DATETIME = DATEADD(SECOND, -1, DATEADD(DAY, 1, @start_date))
        SET @start_date = DATEADD(DAY, -2, @end_date)

        INSERT INTO @events (dt, event_status, game_status, away_key, away_score, home_key, home_score)
        SELECT start_date_time_EST, event_status, game_status, away_team_key, away_team_score, home_team_key, home_team_score
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND start_date_time_EST BETWEEN @start_date AND @end_date AND event_status <> 'smg-not-played'

    END
    
    -- date time
    UPDATE @events
       SET [date] = CAST(dt AS DATE),
           [time] = CAST(dt AS time),
           date_time = CAST(DATEPART(MONTH, dt) AS VARCHAR) + '/' +
                       CAST(DATEPART(DAY, dt) AS VARCHAR) + '/' +
                       CAST(DATEPART(YEAR, dt) AS VARCHAR) + ' ' +
                       CASE WHEN DATEPART(HOUR, dt) > 12 THEN CAST(DATEPART(HOUR, dt) - 12 AS VARCHAR) ELSE CAST(DATEPART(HOUR, dt) AS VARCHAR) END + ':' +
                       CASE WHEN DATEPART(MINUTE, dt) < 10 THEN  '0' ELSE '' END + CAST(DATEPART(MINUTE, dt) AS VARCHAR) + ' ' +
                       CASE WHEN DATEPART(HOUR, dt) < 12 THEN 'AM' ELSE 'PM' END



    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT
	(
        SELECT 'true' AS 'json:Array',
               date_time, game_status, away_key, ISNULL(away_score, '') AS away_score, home_key, ISNULL(home_score, '') AS home_score
          FROM @events
         ORDER BY [date] ASC, [time] ASC
           FOR XML RAW('schedule'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

	
END

GO
