USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetScoresFilterByYearWeek_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DES_GetScoresFilterByYearWeek_XML]
	@leagueName VARCHAR(100),
	@year INT,
	@week VARCHAR(100),
	@page VARCHAR(100) = 'scores'
AS
--=============================================
-- Author:		ikenticus
-- Create date:	05/19/2015
-- Description:	get scores filter for euro soccer for desktop
-- Update:		06/01/2015 - John Lin - return year for world cup
--				06/02/2015 - ikenticus - adjustment for World Cup Group Stage
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)

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
		[rank] INT,
	    id VARCHAR(100),
	    display VARCHAR(100)
	)
/*	
	IF (@page = 'schedules')
	BEGIN
        INSERT INTO @weeks (id, display)
        VALUES ('all', 'All Weeks')
	END
*/
	INSERT INTO @weeks (id, display, rank)
	SELECT [week], level_name, RANK() OVER (PARTITION BY [week] ORDER BY CAST(start_date_time_EST AS DATE) ASC)
	  FROM SportsDB.dbo.SMG_Schedules
	 WHERE league_key = @league_key AND season_key = @year AND event_status <> 'smg-not-played' AND [week] IS NOT NULL AND sub_season_type = 'season-regular'
	 GROUP BY [week], level_name, CAST(start_date_time_EST AS DATE)
	 ORDER BY CAST(start_date_time_EST AS DATE) ASC

	DELETE @weeks WHERE [rank] > 1

	UPDATE @weeks
	   SET display = 'Week ' + id
	 WHERE display IN ('Group Stage', 'Regular Season')

	UPDATE @weeks
	   SET display = 'Group Stage'
	 WHERE id = 'group-stage'

	UPDATE @weeks
	   SET display = 'Week ' + id
	 WHERE display IS NULL

    IF NOT EXISTS (SELECT 1 FROM @weeks WHERE id = @week)
    BEGIN
        SELECT TOP 1 @week = id
          FROM @weeks
         ORDER BY id DESC
    END


    DECLARE @display_odds INT = 0
    
    IF EXISTS (SELECT 1
                 FROM dbo.SMG_Default_Dates
                WHERE league_key = @leagueName AND season_key = @year AND [week] = @week)
    BEGIN
        SET @display_odds = 1
    END
      

    SELECT
    (
        SELECT season_key AS id, CASE
                                     WHEN @leagueName IN ('natl', 'wwc') THEN CAST(season_key AS VARCHAR)
                                     ELSE CAST(season_key AS VARCHAR) + '-' + RIGHT(CAST(season_key + 1 AS VARCHAR), 2)
                                 END AS display
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
        SELECT @year AS [year], @week AS [week], @display_odds AS display_odds
           FOR XML RAW('default'), TYPE
    )    
    FOR XML RAW('root'), TYPE

END

GO
