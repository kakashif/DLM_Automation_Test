USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetScoresByDefault_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DES_GetScoresByDefault_XML]
   @leagueName VARCHAR(30)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 02/21/2014
  -- Description: get default scores for desktop
  -- Update:      05/19/2015 - ikenticus - adding euro soccer
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @season_key INT
    DECLARE @sub_season_type VARCHAR(100)
    DECLARE @week VARCHAR(100)
    DECLARE @start_date DATETIME
    DECLARE @filter VARCHAR(100)
	
    SELECT @season_key = sdd.season_key,
           @sub_season_type = sdd.sub_season_type,
           @week = sdd.[week],
           @start_date = sdd.[start_date],
           @filter = sdd.filter
      FROM dbo.SMG_Default_Dates sdd
     WHERE sdd.league_key = @leagueName AND sdd.page = 'scores'

    IF (@leagueName IN ('mlb', 'mls', 'nba', 'nhl'))
    BEGIN
        EXEC dbo.DES_GetScores_XML @leagueName, NULL, NULL, NULL, @start_date, NULL
    END
    ELSE IF (@leagueName IN ('ncaab', 'ncaaw'))
    BEGIN
        EXEC dbo.DES_GetScores_XML @leagueName, NULL, NULL, NULL, @start_date, @filter
    END
    ELSE IF (@leagueName IN ('epl', 'champions', 'natl', 'wwc'))
    BEGIN
        EXEC dbo.DES_GetScores_XML @leagueName, @season_key, NULL, @week, NULL, NULL
    END
    ELSE IF (@leagueName = 'ncaaf')
    BEGIN
        EXEC dbo.DES_GetScores_XML 'ncaaf', @season_key, NULL, @week, NULL, @filter
    END
    ELSE IF (@leagueName = 'nfl')
    BEGIN
        EXEC dbo.DES_GetScores_XML 'nfl', @season_key, @sub_season_type, @week, NULL, NULL
    END 
END

GO
