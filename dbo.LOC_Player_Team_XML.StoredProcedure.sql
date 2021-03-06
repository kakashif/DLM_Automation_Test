USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[LOC_Player_Team_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[LOC_Player_Team_XML]
    @leagueName VARCHAR(100),
    @teamSlug VARCHAR(100),
    @playerId INT
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 04/29/2015
  -- Description: get player statistics for USCP
  -- Update: 08/28/2015 - John Lin - add team slug
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    IF (@leagueName NOT IN ('mlb'/*, 'mls' */, 'nba', 'ncaab', 'ncaaf'/*, 'ncaaw' */, 'nfl', 'nhl'/*, 'wnba' */))
    BEGIN
        RETURN
    END


    DECLARE @season_key INT

    SELECT @season_key = team_season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'statistics'

    IF (@leagueName = 'mlb')
    BEGIN
        EXEC dbo.LOC_Player_Team_baseball_XML @season_key, @teamSlug, @playerId
    END
    ELSE IF (@leagueName IN ('nba', 'ncaab', 'ncaaw', 'wnba'))
    BEGIN
        EXEC dbo.LOC_Player_Team_basketball_XML @leagueName, @season_key, @teamSlug, @playerId
    END
    ELSE IF (@leagueName IN ('ncaaf', 'nfl'))
    BEGIN
        EXEC dbo.LOC_Player_Team_football_XML @leagueName, @season_key, @teamSlug, @playerId
    END
    ELSE IF (@leagueName = 'nhl')
    BEGIN
        EXEC dbo.LOC_Player_Team_hockey_XML @season_key, @teamSlug, @playerId
    END
      
    SET NOCOUNT OFF
END 

GO
