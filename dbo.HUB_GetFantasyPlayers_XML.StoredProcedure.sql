USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetFantasyPlayers_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetFantasyPlayers_XML]
	@leagueName VARCHAR(100) = 'nfl',
	@seasonKey VARCHAR(10) = '2014'
AS
--=============================================
-- Author:      Prashant Kamat
-- Create date: 10/15/2014
-- Description: Get Fantasy Players for a league and season
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DECLARE @league_key VARCHAR(100)

	SELECT @league_key = league_display_name
	  FROM dbo.USAT_leagues
     WHERE league_name = LOWER(@leagueName)   

    IF (@league_key = 'l.nfl.com')
    BEGIN
        EXEC HUB_GetNFLFantasyPlayers_XML @league_key, @seasonKey
    END
    ELSE IF (@league_key = 'l.nba.com')
    BEGIN
        RETURN
    END
    ELSE IF (@league_key = 'l.nhl.com')
    BEGIN
        RETURN
    END
    ELSE IF (@league_key = 'l.mlb.com')
    BEGIN
        RETURN
    END
    ELSE 
    BEGIN
        RETURN
    END


END


GO
