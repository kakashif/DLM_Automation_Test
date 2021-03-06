USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetStandings_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetStandings_XML]
    @leagueKey VARCHAR(100),
    @seasonKey INT,
    @affiliation VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 09/27/2013
  -- Description: get standings
  -- Update: 01/14/2014 - John Lin - add MLS
  --         05/26/2015 - John Lin - add EPL, NATL, WWC, Champions
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

/* DEPRECATED   
    
    IF (@leagueKey = 'l.mlb.com')
    BEGIN
        EXEC dbo.SMG_GetStandings_MLB_XML @seasonKey, @affiliation
    END
    ELSE IF (@leagueKey = 'l.mlsnet.com')
    BEGIN
        EXEC dbo.SMG_GetStandings_MLS_XML @seasonKey, @affiliation
    END
    ELSE IF (@leagueKey IN ('l.nba.com', 'l.wnba.com'))
    BEGIN
        EXEC dbo.SMG_GetStandings_NBA_XML @leagueKey, @seasonKey, @affiliation
    END
    ELSE IF (@leagueKey IN ('l.ncaa.org.mbasket', 'l.ncaa.org.mfoot'))
    BEGIN
        EXEC dbo.SMG_GetStandings_NCAA_XML @leagueKey, @seasonKey, @affiliation
    END
    ELSE IF (@leagueKey = 'l.nfl.com')
    BEGIN
        EXEC dbo.SMG_GetStandings_NFL_XML @seasonKey, @affiliation
    END
    ELSE IF (@leagueKey = 'l.nhl.com')
    BEGIN
        EXEC dbo.SMG_GetStandings_NHL_XML @seasonKey, @affiliation
    END
    ELSE IF (@leagueKey = 'epl')
    BEGIN
        EXEC dbo.SMG_GetStandings_EPL_XML @seasonKey
    END
    ELSE IF (@leagueKey = 'champions')
    BEGIN
        EXEC dbo.SMG_GetStandings_Champions_XML @seasonKey
    END
    ELSE IF (@leagueKey IN ('natl', 'wwc'))
    BEGIN
        EXEC dbo.SMG_GetStandings_WC_XML @leagueKey, @seasonKey
    END

*/

    SET NOCOUNT OFF
END 

GO
