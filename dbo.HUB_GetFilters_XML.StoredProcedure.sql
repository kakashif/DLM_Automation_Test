USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetFilters_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[HUB_GetFilters_XML]
   @leagueName VARCHAR(100),
   @page VARCHAR(100)
AS
--=============================================
-- Author:	  ikenticus
-- Create date: 06/13/2014
-- Description: get default filters, clone of SMG_GetFilters
--				uncomment/alter as other flowin, currently only Polls
--				modified to follow naming conventions
-- Update:		10/14/2014 - pkamat: Enable Filters for nfl 
--				06/03/2015 - pkamat: Changed call for nfl filter 
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
    
    DECLARE @season_key INT = 0
    DECLARE @sub_season_type VARCHAR(100) = ''
    DECLARE @week VARCHAR(100) = ''
    DECLARE @start_date DATETIME = NULL
    DECLARE @filter VARCHAR(100) = ''
   
    SELECT @season_key 		= season_key,
           @sub_season_type	= sub_season_type,
           @week 			= [week],
           @start_date 		= [start_date],
           @filter 			= filter
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = @page

    IF (@page = 'polls')
    BEGIN
		EXEC dbo.HUB_GetPollsFilters_XML @leagueName, NULL, NULL, NULL
	END
/*
    ELSE IF (@page = 'ballots')
    BEGIN
		EXEC dbo.SMG_GetBallotsFilters_XML @leagueKey, NULL, NULL, NULL
	END
    ELSE IF (@page = 'salaries')
    BEGIN
		EXEC SportsEditDB.dbo.SMG_GetSalariesFilters_XML @leagueKey, NULL, NULL, NULL
	END
    ELSE IF (@page = 'standings')
    BEGIN
        IF (@leagueKey IN ('l.mlb.com', 'l.nfl.com'))
        BEGIN
		    EXEC dbo.SMG_GetStandingsFilters_XML @leagueKey, @seasonKey, 'division'
		END
		ELSE 
		BEGIN
		    EXEC dbo.SMG_GetStandingsFilters_XML @leagueKey, @seasonKey, 'conference'
		END
	END
    ELSE IF (@page = 'statistics')
    BEGIN
        IF (@leagueKey = 'l.mlb.com')
        BEGIN
		    EXEC dbo.SMG_GetStatisticsFilters_XML 'l.mlb.com', @seasonKey, @subSeasonType, 'all', 'player', 'batting'
        END
        ELSE IF (@leagueKey IN ('l.nba.com', 'l.nfl.com', 'l.ncaa.org.mbasket', 'l.ncaa.org.mfoot', 'l.nhl.com'))
        BEGIN
		    EXEC dbo.SMG_GetStatisticsFilters_XML @leagueKey, @seasonKey, @subSeasonType, 'all', 'player', 'offense'
        END
    END
*/
    ELSE
    BEGIN
        IF (@leagueName = 'nfl')
        BEGIN
			EXEC dbo.DES_GetSchedulesFilterByYearSubSeasonTypeWeek_XML @season_key, @sub_season_type, @week
        END
/*
        ELSE IF (@leagueKey = 'l.ncaa.org.mfoot')
        BEGIN
            EXEC dbo.SMG_GetFiltersByYearWeek_XML @page, @seasonKey, @week, @filter
        END
        ELSE
        BEGIN
            EXEC dbo.SMG_GetFiltersByStartDate_XML @leagueKey, @page, @startDate, @filter
        END
*/
    END
END


GO
