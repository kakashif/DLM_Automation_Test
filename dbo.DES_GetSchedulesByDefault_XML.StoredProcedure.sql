USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetSchedulesByDefault_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DES_GetSchedulesByDefault_XML]
   @leagueName VARCHAR(30)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 02/21/2014
  -- Description: get default schedules for desktop
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @season_key INT
    DECLARE @sub_season_type VARCHAR(100)
    DECLARE @week VARCHAR(100)
    DECLARE @start_date DATETIME
    DECLARE @filter VARCHAR(100)
	
    SELECT @season_key = season_key,
           @sub_season_type = sub_season_type,
           @week = [week],
           @start_date = [start_date],
           @filter = filter
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'schedules'

    IF (@leagueName IN ('mlb', 'mls', 'nba', 'nhl'))
    BEGIN
        EXEC dbo.DES_GetSchedules_XML @leagueName, NULL, NULL, NULL, @start_date, NULL
    END
    ELSE IF (@leagueName IN ('ncaab', 'ncaaw'))
    BEGIN
        EXEC dbo.DES_GetSchedules_XML @leagueName, NULL, NULL, NULL, @start_date, @filter
    END
    ELSE IF (@leagueName = 'ncaaf')
    BEGIN
        EXEC dbo.DES_GetSchedules_XML 'ncaaf', @season_key, NULL, @week, NULL, @filter
    END
    ELSE IF (@leagueName = 'nfl')
    BEGIN
        EXEC dbo.DES_GetSchedules_XML 'nfl', @season_key, @sub_season_type, @week, NULL, NULL
    END 
END

GO
