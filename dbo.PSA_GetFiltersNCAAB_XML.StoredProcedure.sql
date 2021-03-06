USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetFiltersNCAAB_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetFiltersNCAAB_XML]
   @year INT,
   @month INT,
   @day INT
AS
  --=============================================
  -- Author: John Lin
  -- Create date: 06/10/2014
  -- Description: get filter for jameson
  -- Update: 12/01/2014 - John Lin - update filters
  --         03/10/2015 - John Lin - deprecate SMG_NCAA table
  --         03/15/2015 - John Lin - Top 25 needs to always appear
  --         10/14/2015 - John Lin - SDI migration
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('ncaab')

    -- default
    IF (@year = 0 AND @month = 0 AND @day = 0)
    BEGIN
        DECLARE @default_date DATE
        
        SELECT @default_date = [start_date]
          FROM dbo.SMG_Default_Dates
         WHERE league_key = 'ncaab' AND page = 'scores'
        
        SET @year = YEAR(@default_date)
        SET @month = MONTH(@default_date)
        SET @day = DAY(@default_date)
    END

    DECLARE @start_date DATE = CAST(CAST(@year AS VARCHAR) + '-' + CAST(@month AS VARCHAR) + '-' + CAST(@day AS VARCHAR) AS DATE)
    DECLARE @end_date DATE = DATEADD(DAY, 1, @start_date)
    DECLARE @endpoint VARCHAR(100) = '/Scores.svc/ncaab/' + CAST(@year AS VARCHAR) + '/' + CAST(@month AS VARCHAR) + '/' + CAST(@day AS VARCHAR) + '/'
    DECLARE @season_key INT

    SELECT TOP 1 @season_key = season_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND start_date_time_EST BETWEEN @start_date AND @end_date

    DECLARE @filters TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        display VARCHAR(100),
        [key] VARCHAR(100)        
    )

    IF EXISTS (SELECT 1
                 FROM dbo.SMG_Schedules
                WHERE league_key = @league_key AND season_key = @season_key AND [week] = 'ncaa')
    BEGIN    
        INSERT INTO @filters (display, [key])
        VALUES ('NCAA', 'ncaa')
    END

    IF EXISTS (SELECT 1
                 FROM dbo.SMG_Schedules
                WHERE league_key = @league_key AND season_key = @season_key AND [week] = 'ncaa')
    BEGIN    
        INSERT INTO @filters (display, [key])
        VALUES ('NIT', 'nit')
    END

    IF EXISTS (SELECT 1
                 FROM dbo.SMG_Schedules
                WHERE league_key = @league_key AND season_key = @season_key AND [week] = 'ncaa')
    BEGIN    
        INSERT INTO @filters (display, [key])
        VALUES ('CBI', 'cbi')
    END

    IF EXISTS (SELECT 1
                 FROM dbo.SMG_Schedules
                WHERE league_key = @league_key AND season_key = @season_key AND [week] = 'ncaa')
    BEGIN    
        INSERT INTO @filters (display, [key])
        VALUES ('CIT', 'cit')
    END

    INSERT INTO @filters (display, [key])
    VALUES ('Top 25', 'top25')
        
    INSERT INTO @filters (display, [key])
    SELECT conference_display, SportsEditDB.dbo.SMG_fnSlugifyName(conference_display)
      FROM dbo.SMG_Leagues
     WHERE league_key = @league_key AND season_key = @season_key AND conference_key IS NOT NULL
     GROUP BY conference_key, conference_display, conference_order
     ORDER BY conference_order ASC
    
    
   	SELECT (
               SELECT display, @endpoint + [key] AS [endpoint]
                 FROM @filters
                ORDER BY id ASC
     			  FOR XML RAW('filters'), TYPE
           )
       FOR XML PATH(''), ROOT('root')
       
END


GO
