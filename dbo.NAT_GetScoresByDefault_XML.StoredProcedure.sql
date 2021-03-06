USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[NAT_GetScoresByDefault_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[NAT_GetScoresByDefault_XML]
   @host VARCHAR(100),
   @leagueName VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 07/08/2014
  -- Description: get default schedule for native
  -- Update: 08/05/2014 - Johh Lin - add domain
  --         05/21/2015 - John Lin - add Women's World Cup
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
        EXEC dbo.NAT_GetScores_XML @host, @leagueName, NULL, NULL, NULL, @start_date, NULL
    END
    ELSE IF (@leagueName IN ('ncaab', 'ncaaw'))
    BEGIN
        EXEC dbo.NAT_GetScores_XML @host, @leagueName, NULL, NULL, NULL, @start_date, @filter
    END
    ELSE IF (@leagueName = 'ncaaf')
    BEGIN
        EXEC dbo.NAT_GetScores_XML @host, 'ncaaf', @season_key, NULL, @week, NULL, @filter
    END
    ELSE IF (@leagueName = 'nfl')
    BEGIN
        EXEC dbo.NAT_GetScores_XML @host, 'nfl', @season_key, @sub_season_type, @week, NULL, NULL
    END
    ELSE IF (@leagueName = 'wwc')
    BEGIN
        EXEC dbo.NAT_GetScores_XML @host, 'wwc', @season_key, NULL, @week, NULL, NULL
    END
END

GO
