USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetFilters_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetFilters_XML]
   @leagueKey VARCHAR(100),
   @page VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 05/07/2013
  -- Description: get default filters
  -- Update:      07/26/2013 - John Lin - football statistics
  --              09/09/2013 - John Lin - baseball statistics
  --              09/13/2013 - John Lin - hockey statistics
  --			  09/19/2013 - ikenticus - polls
  --              10/01/2013 - John Lin - add basketball statistics
  --              10/02/2013 - John Lin - add standings
  --              11/12/2013 - John Lin - default standings
  --              11/22/2013 - ikenticus - default ballots
  --              03/06/2014 - ikenticus - default salaries
  --              06/17/2014 - John Lin - use league name for SMG_Default_Dates
  --              01/01/2015 - ikenticus - default injuries
  --              06/05/2015 - John Lin - add wnba
  --              06/05/2015 - ikenticus - supporting leagueName in addition to leagueKey, use SMG_Mappings for league_name
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
    
    DECLARE @league_name VARCHAR(100)
    DECLARE @seasonKey INT = 0
    DECLARE @subSeasonType VARCHAR(100) = ''
    DECLARE @week VARCHAR(100) = ''
    DECLARE @startDate DATETIME = NULL
    DECLARE @filter VARCHAR(100) = ''
   
	SELECT TOP 1 @league_name = value_to
	  FROM dbo.SMG_Mappings
	 WHERE value_type = 'league' AND value_from = @leagueKey
     
    SELECT @seasonKey = sdd.season_key,
           @subSeasonType = sdd.sub_season_type,
           @week = sdd.[week],
           @startDate = sdd.[start_date],
           @filter = sdd.filter
      FROM dbo.SMG_Default_Dates sdd
     WHERE sdd.league_key = @league_name AND sdd.page = @page

    IF (@page = 'ballots')
    BEGIN
		EXEC dbo.SMG_GetBallotsFilters_XML @leagueKey, NULL, NULL, NULL
	END
    ELSE IF (@page = 'polls')
    BEGIN
		EXEC dbo.SMG_GetPollsFilters_XML @leagueKey, NULL, NULL, NULL
	END
    ELSE IF (@page = 'injuries')
    BEGIN
		EXEC dbo.SMG_GetInjuriesFilters_XML @leagueKey, NULL, NULL
	END
    ELSE IF (@page = 'salaries')
    BEGIN
		EXEC SportsEditDB.dbo.SMG_GetSalariesFilters_XML @leagueKey, NULL, NULL, NULL
	END
    ELSE IF (@page = 'standings')
    BEGIN
        IF (@league_name IN ('mlb', 'nfl'))
        BEGIN
		    EXEC dbo.DES_GetStandingsFilter_XML @league_name, @seasonKey, 'division'
		END
		ELSE 
		BEGIN
		    EXEC dbo.DES_GetStandingsFilter_XML @league_name, @seasonKey, 'conference'
		END
	END
    ELSE IF (@page = 'statistics')
    BEGIN
        IF (@league_name = 'mlb')
        BEGIN
		    EXEC dbo.SMG_GetStatisticsFilters_XML @leagueKey, @seasonKey, @subSeasonType, 'all', 'player', 'batting'
        END
        ELSE IF (@league_name IN ('nba', 'nfl', 'ncaab', 'ncaaf', 'nhl', 'wnba'))
        BEGIN
		    EXEC dbo.SMG_GetStatisticsFilters_XML @leagueKey, @seasonKey, @subSeasonType, 'all', 'player', 'offense'
        END
    END
    ELSE
    BEGIN
        IF (@league_name = 'nfl')
        BEGIN
            EXEC dbo.SMG_GetFiltersByYearSubSeasonTypeWeek_XML @page, @seasonKey, @subSeasonType, @week
        END
        ELSE IF (@league_name = 'ncaaf')
        BEGIN
            EXEC dbo.SMG_GetFiltersByYearWeek_XML @page, @seasonKey, @week, @filter
        END
        ELSE
        BEGIN
            EXEC dbo.SMG_GetFiltersByStartDate_XML @leagueKey, @page, @startDate, @filter
        END
    END
END


GO
