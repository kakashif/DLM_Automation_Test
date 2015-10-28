USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetScoresByDefault_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[MOB_GetScoresByDefault_XML]
   @leagueName VARCHAR(30)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 05/01/2013
  -- Description: get default schedule for mobile
  -- Update: 05/18/2015 - John Lin - add Women's World Cup
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
     WHERE league_key = @leagueName AND page = 'scores'

    IF (@leagueName IN ('mlb', 'mls', 'nba', 'nhl', 'wnba'))
    BEGIN
        EXEC dbo.MOB_GetScores_XML @leagueName, NULL, NULL, NULL, @start_date, NULL
    END
    ELSE IF (@leagueName IN ('ncaab', 'ncaaw'))
    BEGIN
        EXEC dbo.MOB_GetScores_XML @leagueName, NULL, NULL, NULL, @start_date, @filter
    END
    ELSE IF (@leagueName = 'ncaaf')
    BEGIN
        EXEC dbo.MOB_GetScores_XML 'ncaaf', @season_key, NULL, @week, NULL, @filter
    END
    ELSE IF (@leagueName = 'nfl')
    BEGIN
        EXEC dbo.MOB_GetScores_XML 'nfl', @season_key, @sub_season_type, @week, NULL, NULL
    END
    ELSE IF (@leagueName = 'wwc')
    BEGIN
        EXEC dbo.MOB_GetScores_XML 'wwc', @season_key, NULL, @week, NULL, NULL
    END
END

GO
