USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNCAAFiltersByWeek_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetNCAAFiltersByWeek_XML]
    @sport VARCHAR(100),
    @week  VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 08/06/2014
  -- Description: get filter for ncaa conference by week
  -- Update: 11/05/2014 - John Lin - men -> mens
  --         12/16/2014 - John Lin - add playoffs
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100)
    DECLARE @season_key INT
    DECLARE @default_week VARCHAR(100)
    DECLARE @today DATE = CAST(GETDATE() AS DATE)

    IF (@sport = 'mens-basketball')
    BEGIN
        SELECT TOP 1 @league_key = league_key, @season_key = season_key, @default_week = [week]
          FROM dbo.SMG_Schedules
         WHERE league_key = 'l.ncaa.org.mbasket' AND start_date_time_EST > @today
         ORDER BY start_date_time_EST ASC
    END
    ELSE IF (@sport = 'football')
    BEGIN
        SELECT @league_key = 'l.ncaa.org.mfoot', @season_key = season_key, @default_week = [week]
          FROM dbo.SMG_Default_Dates
         WHERE league_key = 'ncaaf' AND page = 'schedules'
    END
    ELSE IF (@sport = 'womens-basketball')
    BEGIN
        SELECT TOP 1 @league_key = league_key, @season_key = season_key, @default_week = [week]
          FROM dbo.SMG_Schedules
         WHERE league_key = 'l.ncaa.org.wbasket' AND start_date_time_EST > @today
         ORDER BY start_date_time_EST ASC
    END

    IF (@week IS NULL)
    BEGIN
        SET @week = @default_week
    END

	
    DECLARE @weeks TABLE
	(
	    id VARCHAR(100),
	    display VARCHAR(100)
	)
	
    INSERT INTO @weeks (id, display)
	SELECT [week], 'Week ' + [week]
	  FROM dbo.SMG_Schedules
	 WHERE league_key = @league_key AND season_key = @season_key AND [week] NOT IN ('playoffs', 'bowls', 'ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi')
	 GROUP BY [week]
	 ORDER BY CAST([week] AS INT)

    IF (@sport = 'mens-basketball')
    BEGIN
        INSERT INTO @weeks (id, display)
	    SELECT TOP 1 'ncaa', 'NCAA'
	      FROM dbo.SMG_Schedules
	     WHERE league_key = 'l.ncaa.org.mbasket' AND season_key = @season_key AND [week] = 'ncaa'

        INSERT INTO @weeks (id, display)
	    SELECT TOP 1 'nit', 'NIT'
	      FROM dbo.SMG_Schedules
	     WHERE league_key = 'l.ncaa.org.mbasket' AND season_key = @season_key AND [week] = 'nit'

        INSERT INTO @weeks (id, display)
	    SELECT TOP 1 'cbi', 'CBI'
	      FROM dbo.SMG_Schedules
	     WHERE league_key = 'l.ncaa.org.mbasket' AND season_key = @season_key AND [week] = 'cbi'

        INSERT INTO @weeks (id, display)
	    SELECT TOP 1 'cit', 'CIT'
	      FROM dbo.SMG_Schedules
	     WHERE league_key = 'l.ncaa.org.mbasket' AND season_key = @season_key AND [week] = 'cit'
    END
    ELSE IF (@sport = 'football')
    BEGIN
        INSERT INTO @weeks (id, display)
	    SELECT TOP 1 'bowls', 'Bowls'
	      FROM dbo.SMG_Schedules
	     WHERE league_key = 'l.ncaa.org.mfoot' AND season_key = @season_key AND [week] = 'bowls'
    END
    ELSE IF (@sport = 'womens-basketball')
    BEGIN
        INSERT INTO @weeks (id, display)
	    SELECT TOP 1 'ncaa', 'NCAA'
	      FROM dbo.SMG_Schedules
	     WHERE league_key = 'l.ncaa.org.wbasket' AND season_key = @season_key AND [week] = 'ncaa'

        INSERT INTO @weeks (id, display)
	    SELECT TOP 1 'nit', 'NIT'
	      FROM dbo.SMG_Schedules
	     WHERE league_key = 'l.ncaa.org.wbasket' AND season_key = @season_key AND [week] = 'wnit'

        INSERT INTO @weeks (id, display)
	    SELECT TOP 1 'cbi', 'CBI'
	      FROM dbo.SMG_Schedules
	     WHERE league_key = 'l.ncaa.org.wbasket' AND season_key = @season_key AND [week] = 'wbi'
    END

    IF NOT EXISTS (SELECT 1 FROM @weeks WHERE id = @week)
    BEGIN
        SELECT TOP 1 @week = id
          FROM @weeks
         ORDER BY id DESC
    END
     

    SELECT @week AS default_week, CAST(@season_key AS VARCHAR) + '-' + CAST((@season_key + 1) % 100 AS VARCHAR) AS default_year_span,
           (
               SELECT id, display
                 FROM @weeks
                  FOR XML RAW('week'), TYPE
           )
       FOR XML RAW('root'), TYPE

END

GO
