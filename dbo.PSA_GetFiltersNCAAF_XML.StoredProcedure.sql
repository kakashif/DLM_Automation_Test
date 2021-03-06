USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetFiltersNCAAF_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetFiltersNCAAF_XML]
   @seasonKey INT,
   @week VARCHAR(100)
AS
  --=============================================
  -- Author: John Lin
  -- Create date: 06/10/2014
  -- Description: get filter for jameson
  -- Update: 12/01/2014 - John Lin - update filters
  --         12/16/2014 - John Lin - filter week can not be bowls or playoffs
  --         03/10/2015 - John Lin - deprecate SMG_NCAA table
  --         03/13/2015 - John Lin - Top 25 needs to always appear
  --         08/18/2015 - John Lin - SDI migration
  --         09/03/2015 - John Lin - return only tier 1 conferences
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('ncaaf')

    -- default
    IF (@week IN ('0', 'bowls', 'playoffs'))
    BEGIN
        SELECT @seasonKey = season_key
          FROM dbo.SMG_Default_Dates
         WHERE league_key = 'ncaaf' AND page = 'scores'
        
        SELECT TOP 1 @week = [week]
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @seasonKey AND [week] NOT IN ('bowls', 'playoffs')
         ORDER BY start_date_time_EST DESC
    END

    DECLARE @endpoint VARCHAR(100) = '/Scores.svc/ncaaf/' + CAST(@seasonKey AS VARCHAR) + '/' + @week + '/'
    
    DECLARE @filters TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        display VARCHAR(100),
        [key] VARCHAR(100)        
    )

    IF EXISTS (SELECT 1
                 FROM dbo.SMG_Schedules
                WHERE league_key = @league_key AND season_key = @seasonKey AND level_id = 'playoffs')
    BEGIN    
        INSERT INTO @filters (display, [key])
        VALUES ('Playoffs', 'playoffs')
    END

    IF EXISTS (SELECT 1
                 FROM dbo.SMG_Schedules
                WHERE league_key = @league_key AND season_key = @seasonKey AND [week] = 'bowls')
    BEGIN    
        INSERT INTO @filters (display, [key])
        VALUES ('Bowls', 'bowls')
    END

    INSERT INTO @filters (display, [key])
    VALUES ('Top 25', 'top25')
        
    INSERT INTO @filters (display, [key])
    SELECT conference_display, SportsEditDB.dbo.SMG_fnSlugifyName(conference_display)
      FROM dbo.SMG_Leagues
     WHERE league_key = @league_key AND season_key = @seasonKey AND tier = 1
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
