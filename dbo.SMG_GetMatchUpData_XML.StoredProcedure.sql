USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetMatchUpData_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetMatchUpData_XML]
    @leagueKey VARCHAR(100),
	@teamKey   VARCHAR(100)
AS
  -- =============================================
  -- Author:      Prashant Kamat
  -- Create date: 01/20/2015
  -- Description: Get Match up Module info for team fronts
  -- Update:	  02/23/2015 - pkamat: Call NCAAF stats
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
   
    
    IF (@leagueKey = 'l.mlb.com')
    BEGIN
        EXEC dbo.SMG_GetMatchUpData_MLB_XML @teamKey
    END
    ELSE IF (@leagueKey IN ('l.nba.com'))
    BEGIN
        EXEC dbo.SMG_GetMatchUpData_NBA_XML @teamKey
    END
    ELSE IF (@leagueKey = 'l.nfl.com')
    BEGIN
        EXEC dbo.SMG_GetMatchUpData_NFL_XML @teamKey
    END
    ELSE IF (@leagueKey = 'l.nhl.com')
    BEGIN
        EXEC dbo.SMG_GetMatchUpData_NHL_XML @teamKey
    END
    ELSE IF (@leagueKey = 'l.ncaa.org.mfoot')
    BEGIN
        EXEC dbo.SMG_GetMatchUpData_NCAAF_XML @teamKey
    END


    SET NOCOUNT OFF
END 

GO
