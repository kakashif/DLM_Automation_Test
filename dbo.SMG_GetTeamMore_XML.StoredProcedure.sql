USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamMore_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetTeamMore_XML]
    @leagueName VARCHAR(100),
    @teamSlug VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 01/22/2014
  -- Description: get conference, division and team excluding team slug
  -- Update: 06/17/2014 - John Lin - use league name for SMG_Default_Dates
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @season_key INT
    DECLARE @display VARCHAR(100)

    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/'
    DECLARE @logo_folder VARCHAR(100) = '-whitebg/80/'
    DECLARE @logo_suffix VARCHAR(100) = '.png'

    SELECT @season_key = team_season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'schedules'
     	
	IF @leagueName IN ('ncaaf', 'ncaab', 'ncaaw')
    BEGIN
        DECLARE @conference_key VARCHAR(100)
        
        SELECT @conference_key = sl.conference_key, @display = sl.conference_display
          FROM dbo.SMG_Leagues sl
         INNER JOIN dbo.SMG_Teams st
            ON st.league_key = sl.league_key AND st.season_key = sl.season_key AND sl.conference_key = st.conference_key AND
               ISNULL(sl.division_key, '') = ISNULL(st.division_key, '') AND st.team_slug = @teamSlug
         WHERE sl.league_key = @league_key AND sl.season_key = @season_key
         
        SELECT @display AS default_division,
               (
                   SELECT '/sports/' + @leagueName + '/' + team_slug + '/' AS link, rgb,
                          @logo_prefix + 'ncaa' + @logo_folder + team_abbreviation + @logo_suffix AS logo
                     FROM dbo.SMG_Teams
                    WHERE league_key = @league_key AND season_key = @season_key AND conference_key = @conference_key AND
                          team_slug <> @teamSlug
                    ORDER BY team_first ASC, team_last ASC
                      FOR XML RAW('team'), TYPE
               )
           FOR XML PATH(''), ROOT('root')
    END
    ELSE
    BEGIN
        SELECT @display = sl.division_display
          FROM dbo.SMG_Leagues sl
         INNER JOIN dbo.SMG_Teams st
            ON st.league_key = sl.league_key AND st.season_key = sl.season_key AND sl.conference_key = st.conference_key AND
               sl.division_key = st.division_key AND st.team_slug = @teamSlug
         WHERE sl.league_key = @league_key AND sl.season_key = @season_key
         
        SELECT @display AS default_division, 
	           (
                   SELECT sl.division_display AS division_name,
                          (
                              SELECT '/sports/' + @leagueName + '/' + st.team_slug + '/' AS link, st.rgb,
                                     @logo_prefix + @leagueName + @logo_folder + st.team_abbreviation + @logo_suffix AS logo
                                FROM dbo.SMG_Teams st
                               WHERE st.league_key = sl.league_key AND st.season_key = sl.season_key AND
                                     st.conference_key = sl.conference_key AND st.division_key = sl.division_key AND
                                     st.team_slug <> @teamSlug
                               ORDER BY st.team_first ASC, st.team_last ASC
                                 FOR XML RAW('team'), TYPE
                          )
                     FROM dbo.SMG_Leagues sl
                    WHERE sl.league_key = @league_key AND sl.season_key = @season_key AND sl.conference_key <> '' AND sl.division_key <> ''
                    GROUP BY sl.league_key, sl.season_key, sl.conference_key, sl.conference_order,
                             sl.division_key, sl.division_order, sl.division_display
                    ORDER BY sl.conference_order ASC, sl.division_order ASC
                      FOR XML RAW('division'), TYPE
               )
           FOR XML PATH(''), ROOT('root')
    END

    SET NOCOUNT OFF
END 

GO
