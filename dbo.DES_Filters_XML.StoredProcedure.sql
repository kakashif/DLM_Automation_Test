USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_Filters_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[DES_Filters_XML]
   @leagueName VARCHAR(100),
   @page VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 06/17/2015
  -- Description: get default filters
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
    
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @seasonKey INT = 0
    DECLARE @subSeasonType VARCHAR(100) = ''
    DECLARE @week VARCHAR(100) = ''
    DECLARE @startDate DATETIME = NULL
    DECLARE @filter VARCHAR(100) = ''
       
    SELECT @seasonKey = sdd.season_key,
           @subSeasonType = sdd.sub_season_type,
           @week = sdd.[week],
           @startDate = sdd.[start_date],
           @filter = sdd.filter
      FROM dbo.SMG_Default_Dates sdd
     WHERE sdd.league_key = @leagueName AND sdd.page = @page

    IF (@page = 'ballots')
    BEGIN
		EXEC dbo.SMG_GetBallotsFilters_XML @league_key, NULL, NULL, NULL
	END
    ELSE IF (@page = 'polls')
    BEGIN
		EXEC dbo.SMG_GetPollsFilters_XML @league_key, NULL, NULL, NULL
	END
    ELSE IF (@page = 'injuries')
    BEGIN
		EXEC dbo.SMG_GetInjuriesFilters_XML @league_key, NULL, NULL
	END
    ELSE IF (@page = 'salaries')
    BEGIN
		EXEC SportsEditDB.dbo.SMG_GetSalariesFilters_XML @league_key, NULL, NULL, NULL
	END
    ELSE IF (@page = 'standings')
    BEGIN
        IF (@leagueName IN ('mlb', 'nfl'))
        BEGIN
		    EXEC dbo.DES_GetStandingsFilter_XML @leagueName, @seasonKey, 'division'
		END
		ELSE 
		BEGIN
		    EXEC dbo.DES_GetStandingsFilter_XML @leagueName, @seasonKey, 'conference'
		END
	END
    ELSE IF (@page = 'statistics')
    BEGIN
        IF (@leagueName = 'mlb')
        BEGIN
		    EXEC dbo.DES_Statistics_Filters_XML @leagueName, @seasonKey, @subSeasonType, 'all', 'player', 'batting'
        END
        ELSE IF (@leagueName IN ('nba', 'nfl', 'ncaab', 'ncaaf', 'nhl', 'wnba'))
        BEGIN
		    EXEC dbo.DES_Statistics_Filters_XML @leagueName, @seasonKey, @subSeasonType, 'all', 'player', 'offense'
        END
    END
    ELSE
    BEGIN
        IF (@leagueName = 'nfl')
        BEGIN
            EXEC dbo.SMG_GetFiltersByYearSubSeasonTypeWeek_XML @page, @seasonKey, @subSeasonType, @week
        END
        ELSE IF (@leagueName = 'ncaaf')
        BEGIN
            EXEC dbo.SMG_GetFiltersByYearWeek_XML @page, @seasonKey, @week, @filter
        END
        ELSE
        BEGIN
            EXEC dbo.SMG_GetFiltersByStartDate_XML @league_key, @page, @startDate, @filter
        END
    END
END


GO
