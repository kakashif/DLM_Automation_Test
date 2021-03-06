USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_Statistics_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[DES_Statistics_XML]
   @leagueName    VARCHAR(100),
   @seasonKey     INT,
   @subSeasonType VARCHAR(100),
   @affiliation   VARCHAR(100),
   @level         VARCHAR(100),
   @category      VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 06/12/2015
  -- Description: get statistics for desktop
  -- Update: 09/18/2015 - John Lin - refactor
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    IF (@leagueName = 'mlb')
    BEGIN
        IF (@level = 'team')
        BEGIN
		    EXEC dbo.SMG_GetStatistics_MLB_team_XML @seasonKey, @subSeasonType, @affiliation, @category
        END
        ELSE
        BEGIN
            EXEC dbo.SMG_GetStatistics_MLB_player_XML @seasonKey, @subSeasonType, @affiliation, @category
        END
    END
    ELSE IF (@leagueName IN ('nba', 'ncaab', 'ncaaw', 'wnba'))
    BEGIN
        IF (@level = 'team')
        BEGIN
		    EXEC dbo.DES_Statistics_basketball_team_XML @leagueName, @seasonKey, @subSeasonType, @affiliation, @category
        END
        ELSE
        BEGIN
            EXEC dbo.DES_Statistics_basketball_player_XML @leagueName, @seasonKey, @subSeasonType, @affiliation, @category
        END
    END
    ELSE IF (@leagueName IN ('nfl', 'ncaaf'))
    BEGIN
        IF (@level = 'team')
        BEGIN
		    EXEC dbo.DES_Statistics_football_team_XML @leagueName, @seasonKey, @subSeasonType, @affiliation, @category
        END
        ELSE
        BEGIN
		    EXEC dbo.DES_Statistics_football_player_XML @leagueName, @seasonKey, @subSeasonType, @affiliation, @category
        END
    END
    ELSE IF (@leagueName = 'nhl')
    BEGIN
        IF (@level = 'team')
        BEGIN
		    EXEC dbo.SMG_GetStatistics_NHL_team_XML @seasonKey, @subSeasonType, @affiliation, @category
        END
        ELSE
        BEGIN
            EXEC dbo.SMG_GetStatistics_NHL_player_XML @seasonKey, @subSeasonType, @affiliation, @category
        END
    END
END


GO
