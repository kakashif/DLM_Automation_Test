USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetScoresFilterByYearSubSeasonTypeWeek_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[DES_GetScoresFilterByYearSubSeasonTypeWeek_XML]
   @year          INT,
   @subSeasonType VARCHAR(100),
   @week          VARCHAR(100),
   @page          VARCHAR(100) = 'scores'
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 02/28/2014
  -- Description: get scores filter for nfl for desktop
  -- Update: 04/15/2014 - John Lin - seperate sub season type
  --         05/08/2014 - John Lin - add display_odd
  --         05/19/2014 - John Lin - add default week
  --         01/29/2015 - John Lin - rename championship to conference
  --         07/13/2015 - John Lin - STATS migration
  --         08/05/2015 - John Lin - SDI migration
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('nfl')
    
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


    DECLARE @year_subSeason_types TABLE
	(
	    season_key INT,
	    sub_season_type VARCHAR(100),
	    type_order INT
	)	
    INSERT INTO @year_subSeason_types (season_key, sub_season_type, type_order)
	SELECT season_key, sub_season_type, 1
     FROM dbo.SMG_Schedules
	WHERE league_key = @league_key
    GROUP BY season_key, sub_season_type

    UPDATE @year_subSeason_types
       SET type_order = 2
     WHERE sub_season_type = 'season-regular'

    UPDATE @year_subSeason_types
       SET type_order = 3
     WHERE sub_season_type = 'post-season'

    IF NOT EXISTS (SELECT 1 FROM @year_subSeason_types WHERE season_key = @year AND sub_season_type = @subSeasonType)
    BEGIN
        SELECT TOP 1 @year = season_key, @subSeasonType = sub_season_type
          FROM @year_subSeason_types
         ORDER BY season_key DESC, type_order DESC
    END

		
    DECLARE @weeks TABLE
	(
	    id VARCHAR(100),
	    display VARCHAR(100),
	    week_order INT
	)

	IF (@page = 'schedules')
	BEGIN
        INSERT INTO @weeks (id, display, week_order)
        VALUES ('all', 'All Weeks', -1)
	END

    IF (@subSeasonType = 'post-season')
    BEGIN
        INSERT INTO @weeks (id, display, week_order)
        SELECT TOP 1 'wild-card', 'Wild Card', 1
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @year AND sub_season_type = @subSeasonType AND [week] = 'wild-card'

        INSERT INTO @weeks (id, display, week_order)
        SELECT TOP 1 'divisional', 'Divisional', 2
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @year AND sub_season_type = @subSeasonType AND [week] = 'divisional'

        INSERT INTO @weeks (id, display, week_order)
        SELECT TOP 1 'conference', 'Conference', 3
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @year AND sub_season_type = @subSeasonType AND [week] = 'conference'

        INSERT INTO @weeks (id, display, week_order)
        SELECT TOP 1 'pro-bowl', 'Pro Bowl', 4
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @year AND sub_season_type = @subSeasonType AND [week] = 'pro-bowl'

        INSERT INTO @weeks (id, display, week_order)
        SELECT TOP 1 'super-bowl', 'Super Bowl', 5
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @year AND sub_season_type = @subSeasonType AND [week] = 'super-bowl'
    END
    ELSE
    BEGIN
        INSERT INTO @weeks (id, display, week_order)
        SELECT 'hall-of-fame', 'Hall of Fame', 0
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @year AND sub_season_type = @subSeasonType AND [week] = 'hall-of-fame'

        INSERT INTO @weeks (id, display, week_order)
        SELECT [week], 'Week ' + [week], CAST([week] AS INT)
          FROM dbo.SMG_Schedules
         WHERE league_key = @league_key AND season_key = @year AND sub_season_type = @subSeasonType AND [week] <> 'hall-of-fame'
         GROUP BY [week]
         ORDER BY CAST([week] AS INT) ASC
    END

    IF NOT EXISTS (SELECT 1 FROM @weeks WHERE id = @week)
    BEGIN
        SELECT TOP 1 @week = id
          FROM @weeks
         ORDER BY week_order ASC
    END
    
    
    DECLARE @display_odds INT = 0
    
    IF EXISTS (SELECT 1
                 FROM dbo.SMG_Default_Dates
                WHERE league_key = @league_key AND season_key = @year AND sub_season_type = @subSeasonType AND [week] = @week)
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
        SELECT CONVERT(VARCHAR(100), season_key) + '/' + sub_season_type AS id,
               CONVERT(VARCHAR(100), season_key) + '-' +
               RIGHT(CONVERT(VARCHAR(100), season_key + 1), 2) + ' ' + (CASE
                                                                           WHEN sub_season_type = 'pre-season' THEN 'Preseason'
                                                                           WHEN sub_season_type = 'season-regular' THEN 'Regular Season'
                                                                           WHEN sub_season_type = 'post-season' THEN 'Postseason'
                                                                        END) AS display               
          FROM @year_subSeason_types
         ORDER BY season_key DESC, type_order DESC
           FOR XML RAW('year_sub_season'), TYPE
    ),
    (
        SELECT id, display
          FROM @weeks
         ORDER BY week_order ASC
           FOR XML RAW('week'), TYPE
    ),
    (
        SELECT @year AS [year], CONVERT(VARCHAR(100), @year) + '/' + @subSeasonType AS year_sub_season,
               @week AS [week], @display_odds AS display_odds
           FOR XML RAW('default'), TYPE
    )    
    FOR XML RAW('root'), TYPE
        
END

GO
