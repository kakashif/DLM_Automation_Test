USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamSchedulesFilters_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_GetTeamSchedulesFilters_XML]
    @leagueKey VARCHAR(100),
    @teamKey VARCHAR(100),
    @seasonKey INT
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 07/22/2013
  -- Description: get team schedules filters
  -- Update: 09/20/2013 - John Lin - MLB season does not cross years
  --         02/20/2015 - ikenticus - replacing Events_Warehouse with SMG_Schedules
  --         07/07/2015 - John Lin - update MLS
  --         07/23/2015 - John Lin - update WNBA
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_name VARCHAR(100)
    
    SELECT @league_name = value_to
	  FROM dbo.SMG_Mappings
	 WHERE value_type = 'league' AND value_from = @leagueKey

    DECLARE @seasonKeys TABLE
	(
	    seasonKey INT
	)
	INSERT INTO @seasonKeys (seasonKey)
	SELECT season_key
	  FROM dbo.SMG_Schedules
	 WHERE league_key = @leagueKey AND @teamKey IN (away_team_key, home_team_key)
	 GROUP BY season_key  

    -- verify season-key
   	IF NOT EXISTS (SELECT 1 FROM @seasonKeys WHERE seasonKey = @seasonKey)
	BEGIN
	    SELECT TOP 1 @seasonKey = seasonKey
	      FROM @seasonKeys
	     ORDER BY seasonKey DESC 
	END

    SELECT
    (
        SELECT (CASE
                   WHEN @league_name IN ('mlb', 'mls', 'wnba') THEN CAST(seasonKey AS VARCHAR)
                   ELSE CAST(seasonKey AS VARCHAR) + '-' + RIGHT(CAST(seasonKey + 1 AS VARCHAR), 2) 
               END) + ' Season' AS display,
               seasonKey AS id
          FROM @seasonKeys
         ORDER BY seasonKey DESC
           FOR XML RAW('year'), TYPE
    ),
    (
        SELECT @seasonKey AS [year]
           FOR XML RAW('default'), TYPE
    )    
    FOR XML RAW('root'), TYPE
   
END

GO
