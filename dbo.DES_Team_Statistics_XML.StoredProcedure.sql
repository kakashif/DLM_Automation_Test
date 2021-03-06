USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_Team_Statistics_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[DES_Team_Statistics_XML]
   @leagueName    VARCHAR(100),
   @teamSlug      VARCHAR(100),
   @seasonKey     INT,
   @subSeasonType VARCHAR(100),
   @level         VARCHAR(100),
   @category      VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 06/12/2015
  -- Description: get team statistics for desktop
  -- Update: 09/18/2015 - John Lin - refactor
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @team_key VARCHAR(100)
    
    SELECT @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @seasonKey AND team_slug = @teamSlug

    IF (@leagueName = 'mlb')
    BEGIN
        IF (@level = 'team')
        BEGIN
		    EXEC dbo.SMG_GetTeamStatistics_MLB_team_XML @team_key, @seasonKey, @subSeasonType, @category
        END
        ELSE
        BEGIN
		    EXEC dbo.SMG_GetTeamStatistics_MLB_player_XML @team_key, @seasonKey, @subSeasonType, @category
        END
    END
    ELSE IF (@leagueName IN ( 'nba', 'ncaab', 'ncaaw', 'wnba'))
    BEGIN
        IF (@level = 'team')
        BEGIN
		    EXEC dbo.DES_Team_Statistics_basketball_team_XML @leagueName, @team_key, @seasonKey, @subSeasonType, @category
        END
        ELSE
        BEGIN
		    EXEC dbo.DES_Team_Statistics_basketball_player_XML @leagueName, @team_key, @seasonKey, @subSeasonType, @category
        END
    END
    ELSE IF (@leagueName IN ('ncaaf', 'nfl'))
    BEGIN
        IF (@level = 'team')
        BEGIN
		    EXEC dbo.DES_Team_Statistics_football_team_XML @leagueName, @team_key, @seasonKey, @subSeasonType, @category
        END
        ELSE
        BEGIN
		    EXEC dbo.DES_Team_Statistics_football_player_XML @leagueName, @team_key, @seasonKey, @subSeasonType, @category
        END
    END
    ELSE IF (@leagueName = 'nhl')
    BEGIN
        IF (@level = 'team')
        BEGIN
		    EXEC dbo.SMG_GetTeamStatistics_NHL_team_XML @team_key, @seasonKey, @subSeasonType, @category
        END
        ELSE
        BEGIN
		    EXEC dbo.SMG_GetTeamStatistics_NHL_player_XML @team_key, @seasonKey, @subSeasonType, @category
        END
    END
END


GO
