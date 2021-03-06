USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[LOC_Player_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[LOC_Player_XML]
    @leagueName VARCHAR(100),
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

    IF (@leagueName = 'mlb')
    BEGIN
        EXEC dbo.LOC_Player_baseball_XML @playerId
    END
    ELSE IF (@leagueName IN ('nba', 'ncaab', 'ncaaw', 'wnba'))
    BEGIN
        EXEC dbo.LOC_Player_basketball_XML @leagueName, @playerId
    END
    ELSE IF (@leagueName IN ('ncaaf', 'nfl'))
    BEGIN
        EXEC dbo.LOC_Player_football_XML @leagueName, @playerId
    END
    ELSE IF (@leagueName = 'nhl')
    BEGIN
        EXEC dbo.LOC_Player_hockey_XML @playerId
    END
      
    SET NOCOUNT OFF
END 

GO
