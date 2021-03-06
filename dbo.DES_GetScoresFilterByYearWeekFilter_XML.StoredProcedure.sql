USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetScoresFilterByYearWeekFilter_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DES_GetScoresFilterByYearWeekFilter_XML]
   @year    INT,
   @week    VARCHAR(100),
   @filter	VARCHAR(100),
   @page    VARCHAR(100) = 'scores'
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 02/28/2014
  -- Description: get scores filter for ncaaf for desktop
  -- Update: 05/08/2014 - John Lin - add display_odd
  --         12/18/2014 - John Lin - add playoffs
  --         08/18/2015 - John Lin - SDI migration
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    -- HACK
    SET @filter = REPLACE(@filter, 'c.', '')


    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('ncaaf')

    DECLARE @season_keys TABLE
	(
	    season_key INT
	)
    INSERT INTO @season_keys (season_key)
	SELECT season_key
	  FROM dbo.SMG_Schedules
	 WHERE league_key = @league_key
	 GROUP BY season_key

    IF NOT EXISTS (SELECT 1 FROM @season_keys WHERE season_key = @year)
    BEGIN
        SELECT TOP 1 @year = season_key
          FROM @season_keys
         ORDER BY season_key DESC
    END

		
    DECLARE @weeks TABLE
	(
	    id VARCHAR(100),
	    display VARCHAR(100)
	)
	
	IF (@page = 'schedules')
	BEGIN
        INSERT INTO @weeks (id, display)
        VALUES ('all', 'All Weeks')
	END
	
    INSERT INTO @weeks (id, display)
	SELECT [week], 'Week ' + [week]
	  FROM dbo.SMG_Schedules
	 WHERE league_key = @league_key AND season_key = @year AND [week] NOT IN ('bowls', 'playoffs')
	 GROUP BY [week]
	 ORDER BY CAST([week] AS INT)

    INSERT INTO @weeks (id, display)
	SELECT TOP 1 'bowls', 'Bowls'
	  FROM dbo.SMG_Schedules
	 WHERE league_key = @league_key AND season_key = @year AND [week] IN ('bowls', 'playoffs')

    IF NOT EXISTS (SELECT 1 FROM @weeks WHERE id = @week)
    BEGIN
        SELECT TOP 1 @week = id
          FROM @weeks
         ORDER BY id DESC
    END

	
    DECLARE @filters TABLE
	(
	    id VARCHAR(100),
	    display VARCHAR(100)
	)
    INSERT INTO @filters(id, display)
    SELECT id, display
      FROM dbo.SMG_fnGetNCAAFFilter(@year, @week, @filter, @page)

    IF NOT EXISTS (SELECT 1 FROM @filters WHERE id = @filter)
    BEGIN
        SET @filter = 'div1.a'

        IF EXISTS (SELECT 1 FROM @filters WHERE id = 'top25')
        BEGIN
            SET @filter = 'top25'
        END
    END

    DECLARE @display_odds INT = 0
    
    IF EXISTS (SELECT 1
                 FROM dbo.SMG_Default_Dates
                WHERE league_key = 'ncaaf' AND season_key = @year AND [week] = @week)
    BEGIN
        SET @display_odds = 1
    END
      

    SELECT
    (
        SELECT season_key AS id, CONVERT(VARCHAR(100), season_key) + '-' + RIGHT(CONVERT(VARCHAR(100), season_key + 1), 2) AS display
          FROM @season_keys
         ORDER BY season_key DESC
           FOR XML RAW('year'), TYPE
    ),
    (
        SELECT id, display
          FROM @weeks
           FOR XML RAW('week'), TYPE
    ),
    (
        SELECT id, display
          FROM @filters
           FOR XML RAW('filter'), TYPE
    ),
    (
        SELECT @year AS [year], @week AS [week], @filter AS filter, @display_odds AS display_odds
           FOR XML RAW('default'), TYPE
    )    
    FOR XML RAW('root'), TYPE

END

GO
