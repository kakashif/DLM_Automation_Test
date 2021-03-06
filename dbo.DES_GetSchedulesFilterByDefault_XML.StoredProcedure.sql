USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetSchedulesFilterByDefault_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DES_GetSchedulesFilterByDefault_XML]
   @leagueName VARCHAR(30)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 03/18/2014
  -- Description: get default schedules filter for desktop
  -- Update:      05/20/2015 - ikenticus - adding euro soccer
  --              09/02/2015 - ikenticus - SDI does not provide soccer Weeks so adding to Date
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
    
	
    SELECT @season_key = season_key,
           @sub_season_type = sub_season_type,
           @week = [week],
           @start_date = [start_date],
           @filter = filter
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'schedules'

    IF (@leagueName IN ('mlb', 'mls', 'nba', 'nhl', 'wnba'))
    BEGIN
        SET @year = YEAR(@start_date)
        SET @month = MONTH(@start_date)
        SET @day = DAY(@start_date)
        
        EXEC dbo.DES_GetSchedulesFilterByDate_XML @leagueName, @year, @month, @day
    END
    ELSE IF (@leagueName IN ('ncaab', 'ncaaw'))
    BEGIN
        SET @year = YEAR(@start_date)
        SET @month = MONTH(@start_date)
        SET @day = DAY(@start_date)
        
        EXEC dbo.DES_GetSchedulesFilterByDateFilter_XML @leagueName, @year, @month, @day, @filter
    END
    ELSE IF (@leagueName IN ('epl', 'champions', 'natl', 'wwc'))
    BEGIN
		IF (@start_date IS NOT NULL)
		BEGIN
			SET @year = YEAR(@start_date)
			SET @month = MONTH(@start_date)
			SET @day = DAY(@start_date)
			-- SDI does NOT provide soccer Weeks, so using Date
			EXEC dbo.DES_GetSchedulesFilterByDate_XML @leagueName, @year, @month, @day
		END
		ELSE
		BEGIN
			-- STATS provides soccer Weeks
			EXEC dbo.DES_GetSchedulesFilterByYearWeek_XML @leagueName, @season_key, @week
		END
    END
    ELSE IF (@leagueName = 'ncaaf')
    BEGIN
        EXEC dbo.DES_GetSchedulesFilterByYearWeekFilter_XML @season_key, @week, @filter
    END
    ELSE IF (@leagueName = 'nfl')
    BEGIN
        EXEC dbo.DES_GetSchedulesFilterByYearSubSeasonTypeWeek_XML @season_key, @sub_season_type, @week
    END 
END

GO
