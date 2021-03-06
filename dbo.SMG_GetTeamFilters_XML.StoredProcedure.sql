USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamFilters_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetTeamFilters_XML]
   @leagueKey VARCHAR(100),
   @teamKey VARCHAR(100),
   @page VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 06/03/2013
  -- Description: get default team filters
  -- Update: 07/22/2013 - John Lin - add schedules
  --         09/13/2013 - John Lin - fix MLB default
  --		 09/30/2013 - ikenticus - add roster, leaders/graphs (subset of statistics)
  --         09/30/2013 - John Lin - refactor
  --		 09/30/2013 - ikenticus - removing leaders/graphs
  --         06/17/2014 - John Lin - use league name for SMG_Default_Dates
  --         08/04/2015 - ikenticus - isolating deprecation to non-roster
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


    DECLARE @league_name VARCHAR(100)
    DECLARE @seasonKey INT = 0
    DECLARE @subSeasonType VARCHAR(100) = ''
    DECLARE @teamSeasonKey INT

    SELECT @league_name = league_name
      FROM dbo.USAT_leagues
     WHERE league_display_name = @leagueKey
   
    SELECT @seasonKey = sdd.season_key,
           @subSeasonType = sdd.sub_season_type,
           @teamSeasonKey = sdd.team_season_key
      FROM dbo.SMG_Default_Dates sdd
     WHERE sdd.league_key = @league_name AND sdd.page = @page

	IF (@page = 'roster')
    BEGIN
        EXEC SMG_GetTeamRosterFilters_XML @leagueKey, @teamKey, @teamSeasonKey, 'active'
    END

/* DEPRECATED

    ELSE IF (@page = 'schedules')
    BEGIN
        EXEC SMG_GetTeamSchedulesFilters_XML @leagueKey, @teamKey, @teamSeasonKey
    END
    ELSE IF (@page = 'statistics')
    BEGIN
        IF (@leagueKey = 'l.mlb.com')
        BEGIN
            EXEC SMG_GetTeamStatisticsFilters_XML 'l.mlb.com', @teamKey, @seasonKey, @subSeasonType, 'player', 'batting'
        END
        ELSE
        BEGIN
            EXEC SMG_GetTeamStatisticsFilters_XML @leagueKey, @teamKey, @seasonKey, @subSeasonType, 'player', 'offense'
        END
    END
*/

END


GO
