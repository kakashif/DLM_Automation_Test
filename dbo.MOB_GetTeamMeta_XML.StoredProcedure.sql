USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetTeamMeta_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[MOB_GetTeamMeta_XML]
   @leagueName VARCHAR(100),
   @teamSlug VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 01/28/2015
  -- Description: get team metadata for mobile
  -- Update: 05/18/2015 - John Lin - return error
  --         05/20/2015 - John Lin - add Women's World Cup
  --         06/23/2015 - John Lin - STATS migration
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    IF (@leagueName NOT IN ('mlb', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba',
                            'mls', 'wwc'))
    BEGIN
        SELECT 'invalid league name' AS [message], '400' AS [status]
           FOR XML PATH(''), ROOT('root')

        RETURN
    END

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/'
    DECLARE @logo_folder VARCHAR(100) = '-whitebg/22/'
    DECLARE @flag_folder VARCHAR(100) = 'countries/flags/22/'
    DECLARE @logo_suffix VARCHAR(100) = '.png'
   	DECLARE @season_key INT

    DECLARE @team_key VARCHAR(100)
    DECLARE @team_abbr VARCHAR(100)
    DECLARE @team_short VARCHAR(100)
    DECLARE @team_long VARCHAR(100)
    DECLARE @team_rgb VARCHAR(100)
    DECLARE @team_logo VARCHAR(100)
    DECLARE @team_record VARCHAR(100)
    DECLARE @division VARCHAR(100)
    DECLARE @division_rank VARCHAR(100)
    
    DECLARE @conf_key VARCHAR(100)
    DECLARE @div_key VARCHAR(100)
   
    SELECT @season_key = team_season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'schedules'

    SELECT @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @season_key AND team_slug = @teamSlug    

    -- team
    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        -- self
        SELECT @team_abbr = team_abbreviation, @team_short = team_first, @team_long = team_first + ' ' + team_last,
               @team_rgb = rgb, @team_logo = @logo_prefix + 'ncaa' + @logo_folder + team_abbreviation + @logo_suffix,
               @conf_key = conference_key, @div_key = division_key
          FROM dbo.SMG_Teams
         WHERE season_key = @season_key AND team_key = @team_key
    END
    ELSE IF (@leagueName = 'wwc')
    BEGIN
        -- self
        SELECT @team_abbr = team_abbreviation, @team_short = team_first, @team_long = team_first,
               @team_rgb = rgb, @team_logo = @logo_prefix + @flag_folder + team_abbreviation + @logo_suffix,
               @div_key = division_key
          FROM dbo.SMG_Teams
         WHERE league_key = 'wwc' AND season_key = @season_key AND team_key = @team_key
    END
    ELSE
    BEGIN
        -- self
        SELECT @team_abbr = team_abbreviation, @team_short = team_last, @team_long = team_first + ' ' + team_last,
               @team_rgb = rgb, @team_logo = @logo_prefix + @leagueName + @logo_folder + team_abbreviation + @logo_suffix,
               @conf_key = conference_key, @div_key = division_key
          FROM dbo.SMG_Teams
         WHERE season_key = @season_key AND team_key = @team_key
    END

    -- self
    IF (@leagueName = 'wwc')
    BEGIN
        SELECT @division = division_name
          FROM dbo.SMG_Leagues
         WHERE league_key = @league_key AND season_key = @season_key AND division_key = @div_key
    END
    ELSE
    BEGIN
        SELECT @division = division_display
          FROM dbo.SMG_Leagues
         WHERE league_key = @league_key AND season_key = @season_key AND conference_key = @conf_key AND division_key = @div_key

        SELECT @division_rank = value
          FROM SportsEditDB.dbo.SMG_Standings
         WHERE season_key = @season_key AND team_key = @team_key AND [column] = 'division-rank'   
    END



    SELECT
    (
        SELECT @team_key AS team_key, @team_abbr AS team_abbr, @team_short AS team_short,
               @team_long AS team_long, @team_rgb AS team_rgb, @team_logo AS team_logo,
               @team_record AS team_record, @division AS division, @division_rank AS division_rank
           FOR XML RAW('meta'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

	
END

GO
