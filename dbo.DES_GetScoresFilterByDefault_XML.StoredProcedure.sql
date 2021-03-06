USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetScoresFilterByDefault_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DES_GetScoresFilterByDefault_XML]
   @leagueName VARCHAR(30)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 02/28/2014
  -- Description: get default scores filter for desktop
  -- Upddate:     05/19/2015 - ikenticus - adding euro soccer
  --              09/02/2015 - ikenticus - SDI does not provide soccer Weeks so adding to Date
  --              09/11/2015 - ikenticus - somehow WNBA was missing from all conditions
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @season_key INT
    DECLARE @sub_season_type VARCHAR(100)
    DECLARE @week VARCHAR(100)
    DECLARE @start_date DATETIME
    DECLARE @filter VARCHAR(100)
    DECLARE @year INT
    DECLARE @month INT
    DECLARE @day INT
    
	
    SELECT @season_key = sdd.season_key,
           @sub_season_type = sdd.sub_season_type,
           @week = sdd.[week],
           @start_date = sdd.[start_date],
           @filter = sdd.filter
      FROM dbo.SMG_Default_Dates sdd
     WHERE sdd.league_key = @leagueName AND sdd.page = 'scores'

    IF (@leagueName IN ('mlb', 'mls', 'nba', 'nhl', 'wnba'))
    BEGIN
        SET @year = YEAR(@start_date)
        SET @month = MONTH(@start_date)
        SET @day = DAY(@start_date)
        
        EXEC dbo.DES_GetScoresFilterByDate_XML @leagueName, @year, @month, @day
    END
    ELSE IF (@leagueName IN ('ncaab', 'ncaaw'))
    BEGIN
        SET @year = YEAR(@start_date)
        SET @month = MONTH(@start_date)
        SET @day = DAY(@start_date)
        
        EXEC dbo.DES_GetScoresFilterByDateFilter_XML @leagueName, @year, @month, @day, @filter
    END
    ELSE IF (@leagueName IN ('epl', 'champions', 'natl', 'wwc'))
    BEGIN
		IF (@start_date IS NOT NULL)
		BEGIN
			SET @year = YEAR(@start_date)
			SET @month = MONTH(@start_date)
			SET @day = DAY(@start_date)
			-- SDI does NOT provide soccer Weeks, so using Date
			EXEC dbo.DES_GetScoresFilterByDate_XML @leagueName, @year, @month, @day
		END
		ELSE
		BEGIN
			-- STATS provides soccer Weeks
			EXEC dbo.DES_GetScoresFilterByYearWeek_XML @leagueName, @season_key, @week
		END
    END
    ELSE IF (@leagueName = 'ncaaf')
    BEGIN
        EXEC dbo.DES_GetScoresFilterByYearWeekFilter_XML @season_key, @week, @filter
    END
    ELSE IF (@leagueName = 'nfl')
    BEGIN
        EXEC dbo.DES_GetScoresFilterByYearSubSeasonTypeWeek_XML @season_key, @sub_season_type, @week
    END 
END

GO
