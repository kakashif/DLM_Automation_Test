USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetStandings_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DES_GetStandings_XML]
	@leagueName VARCHAR(100),
	@seasonKey INT,
	@affiliation VARCHAR(100)
AS
-- =============================================
-- Author:		ikenticus
-- Create date:	05/26/2015
-- Description:	get standings, based on SMG_GetStandings_XML
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)   
    
    IF (@leagueName = 'mlb')
    BEGIN
        EXEC dbo.SMG_GetStandings_MLB_XML @seasonKey, @affiliation
    END
    ELSE IF (@leagueName = 'mls')
    BEGIN
        EXEC dbo.SMG_GetStandings_MLS_XML @seasonKey, @affiliation
    END
    ELSE IF (@leagueName IN ('nba', 'wnba'))
    BEGIN
        EXEC dbo.SMG_GetStandings_NBA_XML @league_key, @seasonKey, @affiliation
    END
    ELSE IF (@leagueName IN ('ncaab', 'ncaaf'))
    BEGIN
        EXEC dbo.SMG_GetStandings_NCAA_XML @league_key, @seasonKey, @affiliation
    END
    ELSE IF (@leagueName = 'nfl')
    BEGIN
        EXEC dbo.SMG_GetStandings_NFL_XML @seasonKey, @affiliation
    END
    ELSE IF (@leagueName = 'nhl')
    BEGIN
        EXEC dbo.SMG_GetStandings_NHL_XML @seasonKey, @affiliation
    END
    ELSE IF (@leagueName = 'epl')
    BEGIN
        EXEC dbo.SMG_GetStandings_EPL_XML @seasonKey
    END
    ELSE IF (@leagueName = 'champions')
    BEGIN
        EXEC dbo.SMG_GetStandings_Champions_XML @seasonKey
    END
    ELSE IF (@leagueName IN ('natl', 'wwc'))
    BEGIN
        EXEC dbo.SMG_GetStandings_WC_XML @league_key, @seasonKey
    END

    SET NOCOUNT OFF
END 

GO
