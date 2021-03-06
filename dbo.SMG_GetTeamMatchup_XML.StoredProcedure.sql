USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamMatchup_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetTeamMatchup_XML]
	@leagueName VARCHAR(100),
	@teamSlug VARCHAR(100)
AS
--=============================================
-- Author:	    John Lin
-- Create date: 10/29/2013
-- Description: get team statistics for teams
-- Update: 06/17/2014 - John Lin - use league name for SMG_Default_Dates
--         02/20/2015 - ikenticus - replacing Events_Warehouse with SMG_Schedules
-- =============================================
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

/* HORRIBLE

	DECLARE @league_key VARCHAR(100)
    DECLARE @season_key INT
    DECLARE @sub_season_type VARCHAR(100)
    DECLARE @team_key VARCHAR(100)
    DECLARE @event_key VARCHAR(100)
    DECLARE @event_status VARCHAR(100)

	SELECT @league_key = league_display_name
	  FROM sportsDB.dbo.USAT_leagues
     WHERE league_name = LOWER(@leagueName)
     
    SELECT @season_key = team_season_key
	  FROM dbo.SMG_Default_Dates
	 WHERE league_key = @leagueName AND page = 'scores'

    SELECT @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @season_key AND team_slug = @teamSlug	 
	 
    SELECT @event_key = dbo.SMG_fnGetMatchupEventKey(@league_key, @team_key)
    
    SELECT @event_status = event_status, @sub_season_type = sub_season_type
	  FROM dbo.SMG_Schedules
     WHERE event_key = @event_key

    IF (@event_status = 'pre-event')
    BEGIN
        EXEC dbo.SMG_GetMatchupByEventKey_XML @league_key, @season_key, @sub_season_type, @event_key
    END
    ELSE
    BEGIN
        EXEC dbo.SMG_GetScoresByEventKey_XML @league_key, @season_key, @sub_season_type, @event_key
    END
*/
    
END


GO
