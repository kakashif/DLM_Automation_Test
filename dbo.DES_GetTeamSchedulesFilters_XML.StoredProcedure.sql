USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetTeamSchedulesFilters_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DES_GetTeamSchedulesFilters_XML]
	@leagueName VARCHAR(100),
	@teamSlug VARCHAR(100),
	@seasonKey INT
AS
--=============================================
-- Author:	ikenticus
-- Create date:	05/20/2015
-- Description:	get team schedules filters, converted from SMG_GetTeamSchedulesFilters_XML
-- Update: 07/07/2015 - John Lin - update MLS
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
	DECLARE @team_key VARCHAR(100)

	SELECT @team_key = team_key
	  FROM dbo.SMG_Teams st
	 WHERE league_key = @league_key AND season_key = @seasonKey AND team_slug = @teamSlug

    DECLARE @season_keys TABLE
	(
	    seasonKey INT
	)

	INSERT INTO @season_keys (seasonKey)
	SELECT season_key
	  FROM dbo.SMG_Schedules
	 WHERE league_key = @league_key AND (away_team_key = @team_key OR home_team_key = @team_key)
	 GROUP BY season_key  

    -- verify season-key
   	IF NOT EXISTS (SELECT 1 FROM @season_keys WHERE seasonKey = @seasonKey)
	BEGIN
	    SELECT TOP 1 @seasonKey = seasonKey
	      FROM @season_keys
	     ORDER BY seasonKey DESC 
	END

    SELECT @team_key AS team_key,
    (
        SELECT (CASE
                   WHEN @leagueName IN ('mlb', 'mls', 'natl', 'wwc') THEN CAST(seasonKey AS VARCHAR)
                   ELSE CAST(seasonKey AS VARCHAR) + '-' + RIGHT(CAST(seasonKey + 1 AS VARCHAR), 2)
               END) + ' Season' AS display,
               seasonKey AS id
          FROM @season_keys
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
