USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetStandingsByAffiliation_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[MOB_GetStandingsByAffiliation_XML]
    @leagueName  VARCHAR(100),
    @affiliation VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 01/07/2014
  -- Description: get standings for mobile for given affiliation
  -- Update: 01/14/2014 - John Lin - add MSL
  --         01/17/2014 - John Lin - sync
  --         05/20/2015 - John Lin - add Women's World Cup
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @season_key INT
    
    SELECT @season_key = season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'standings'

    IF (@leagueName = 'mlb')
    BEGIN
        EXEC dbo.MOB_GetStandings_MLB_XML @season_key, @affiliation
    END
    ELSE IF (@leagueName = 'mls')
    BEGIN
        EXEC dbo.MOB_GetStandings_MLS_XML @season_key, @affiliation
    END
    ELSE IF (@leagueName IN ('nba', 'wnba'))
    BEGIN
        EXEC dbo.MOB_GetStandings_NBA_XML @leagueName, @season_key, @affiliation
    END
    ELSE IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        EXEC dbo.MOB_GetStandings_NCAA_XML @leagueName, @season_key, @affiliation
    END
    ELSE IF (@leagueName = 'nfl')
    BEGIN
        EXEC dbo.MOB_GetStandings_NFL_XML @season_key, @affiliation
    END
    ELSE IF (@leagueName = 'nhl')
    BEGIN
        EXEC dbo.MOB_GetStandings_NHL_XML @season_key, @affiliation
    END    
    ELSE IF (@leagueName = 'wwc')
    BEGIN
        SELECT TOP 1 @season_key = season_key
          FROM SportsEditDB.dbo.SMG_Standings
         WHERE league_key = 'wwc'
         ORDER BY season_key DESC
    
        EXEC dbo.MOB_GetStandings_WC_XML @leagueName, @season_key
    END    

    SET NOCOUNT OFF
END 

GO
