USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetScoresFilterByDateFilter_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[DES_GetScoresFilterByDateFilter_XML]
   @leagueName VARCHAR(100),
   @year       INT,
   @month      INT,
   @day        INT,
   @filter     VARCHAR(100) = NULL,
   @page       VARCHAR(100) = 'scores'
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 02/28/2014
  -- Description: get scores filter for daily sport for desktop
  -- Update: 03/31/2014 -- cchiu -- put the subseason dates into a subseason_dates section
  --         04/25/2014 - John Lin - exclude smg-not-played
  --         05/02/2014 - John Lin - pre/regular/post use argument year
  --         05/08/2014 - John Lin - add display_odd
  --         06/15/2015 - John Lin - STATS migration
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @season_key INT
    DECLARE @start_date DATETIME = CAST(CAST(@year AS VARCHAR) + '-' + CAST(@month AS VARCHAR) + '-' + CAST(@day AS VARCHAR) AS DATETIME)
    DECLARE @event_start_date DATETIME = DATEADD(MONTH, DATEDIFF(MONTH, 0, @start_date), 0)
    DECLARE @event_end_date DATETIME = DATEADD(SECOND, -1, DATEADD(MONTH, 1, @event_start_date))

	
    DECLARE @days TABLE
	(
	    [day] INT,
	    season_key INT
	)
	INSERT INTO @days ([day], season_key)
	SELECT DAY(start_date_time_EST), season_key
	  FROM dbo.SMG_Schedules
	 WHERE league_key = @league_key AND start_date_time_EST BETWEEN @event_start_date AND @event_end_date AND event_status <> 'smg-not-played'

    DECLARE @concat VARCHAR(MAX)
	DECLARE @pre DATE
	DECLARE @regular DATE
	DECLARE @post DATE
	     
	SELECT @concat = COALESCE(@concat + ',' + CONVERT(VARCHAR(100), [day]), CONVERT(VARCHAR(100), [day]))
	  FROM @days
	 GROUP BY [day]

    SELECT TOP 1 @season_key = season_key
	  FROM @days
     ORDER BY season_key DESC

     SELECT TOP 1 @pre = start_date_time_EST
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = 'pre-season'
     ORDER BY start_date_time_EST ASC

    SELECT TOP 1 @regular = start_date_time_EST
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = 'season-regular'
     ORDER BY start_date_time_EST ASC

    SELECT TOP 1 @post = start_date_time_EST
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = 'post-season'
     ORDER BY start_date_time_EST ASC


    IF (@season_key IS NULL)
    BEGIN
        SELECT @season_key = team_season_key
          FROM dbo.SMG_Default_Dates
         WHERE league_key = @leagueName AND page = 'scores'
    END
    	    	    

	
    DECLARE @filters TABLE
	(
	    id VARCHAR(100),
	    display VARCHAR(100)
	)	
	IF (@leagueName IN ('ncaab', 'ncaaw'))
	BEGIN
        INSERT INTO @filters (id, display)
        SELECT id, display
          FROM dbo.SMG_fnGetNCAABFilter(@league_key, @start_date, @filter, @page)
    
        IF NOT EXISTS (SELECT 1 FROM @filters WHERE id = @filter)
        BEGIN
            SET @filter = 'div1'
        
            IF EXISTS (SELECT 1 FROM @filters WHERE id = 'tourney')
            BEGIN
                SET @filter = 'tourney'
            END
            ELSE
            BEGIN
                IF EXISTS (SELECT 1 FROM @filters WHERE id = 'top25')
                BEGIN
                    SET @filter = 'top25'
                END
            END
        END
    END

    DECLARE @display_odds INT = 0
    
    IF EXISTS (SELECT 1
                 FROM dbo.SMG_Default_Dates
                WHERE league_key = @leagueName AND [start_date] = @start_date)
    BEGIN
        SET @display_odds = 1
    END

    
    SELECT @concat AS [days],
    (
        SELECT id, display
          FROM @filters
           FOR XML RAW('filter'), TYPE
    ),
    (
        SELECT CONVERT(VARCHAR(100), @start_date, 126) AS [date], @filter AS filter, @display_odds AS display_odds
           FOR XML RAW('default'), TYPE
    ),
	(
		SELECT @pre AS pre, @regular AS regular, @post AS post
			FOR XML RAW('sub_season'), TYPE
	)
    FOR XML RAW('root'), TYPE

END

GO
