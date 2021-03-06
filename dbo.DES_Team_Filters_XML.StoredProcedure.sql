USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_Team_Filters_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[DES_Team_Filters_XML]
   @leagueName VARCHAR(100),
   @teamSlug VARCHAR(100),
   @page VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 06/16/2015
  -- Description: get default team filters for desktop
  -- Update: 06/18/2015 - John Lin - STATS migration
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
    
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @season_key INT = 0
    DECLARE @sub_season_type VARCHAR(100) = ''
    DECLARE @team_key VARCHAR(100)

    SELECT @season_key = team_season_key, @sub_season_type = sub_season_type
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = @page

    SELECT @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @season_key AND team_slug = @teamSlug

	IF (@page = 'roster')
    BEGIN
        EXEC SMG_GetTeamRosterFilters_XML @league_key, @team_key, @season_key, 'active'
    END
    ELSE IF (@page = 'schedules')
    BEGIN
        EXEC SMG_GetTeamSchedulesFilters_XML @league_key, @team_key, @season_key
    END
    ELSE IF (@page = 'statistics')
    BEGIN
        IF (@leagueName = 'mlb')
        BEGIN
            EXEC DES_Team_Statistics_Filters_XML 'mlb', @teamSlug, @season_key, @sub_season_type, 'player', 'batting'
        END
        ELSE
        BEGIN
            EXEC DES_Team_Statistics_Filters_XML @leagueName, @teamSlug, @season_key, @sub_season_type, 'player', 'offense'
        END
    END

END


GO
