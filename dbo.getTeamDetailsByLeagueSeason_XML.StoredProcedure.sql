USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[getTeamDetailsByLeagueSeason_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[getTeamDetailsByLeagueSeason_XML]
    @leagueKey     VARCHAR(100),
    @seasonKey     VARCHAR(100),
    @subSeasonType VARCHAR(100),
    @date          DATETIME,
    @conferenceKey VARCHAR(100) = NULL
AS
  -- =============================================
  -- Author:		Ramya Rangarajan
  -- Create date: 18th Feb 2009
  -- Description:	SProc to get the schedules of based on league and season keys
  -- Update: 30th Nov, 2011. Added @notes_league and logic for grabbing notes path conference notes pages
  -- Updated:
  --	01/31/2013 ikenticus: Reducing the #leagueevents to be centered around 90 days to speed up this query
  --	01/31/2013 ikenticus: Adding the losses_overtime and standing_points from FnTeamWinLossRecord update
  --    04/18/2013 - John Lin - use USAT_League_Details and USAT_Team_Details
  --    04/29/2013 - John Lin - toggle to old for NCAA
  --    05/13/2013 - John Lin - NCAA use USAT_League_Details and USAT_Team_Details
  --    05/15/2013 - John Lin - category for NHL is hockey
  --	07/17/2013 - James McGovern - added optional @conferenceKey parameter to filter result set by conference
  --    08/14/2013 - John Lin - NCAA use SMG_Teams and SMG_Leagues
  --    04/15/2015 - ikenticus - /Schedules.svc/teamindex/_key depends on Transforms/Schedule/TeamIndex.xslt
  -- =============================================
BEGIN
      -- SET NOCOUNT ON added to prevent extra result sets from
      -- interfering with SELECT statements.
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	
	IF (LTRIM(RTRIM(@conferenceKey)) = '')
	BEGIN
		SET @conferenceKey = null
	END
	
    IF (@leagueKey = 'l.mlsnet.com')
    BEGIN
        SELECT
	    (
            SELECT uld_conf.conference_key, uld_conf.conference_display AS conference_name,
            (
                SELECT uld_div.division_key, uld_div.division_display AS division_name,
                (
                    SELECT utd.team_abbreviation AS abbr_name,
                           'soccer' AS Category,
                           utd.team_first AS first_name,
                           utd.team_last AS last_name,
                           utd.SDI,
                           utd.team_key,
                           utd.TSN                               
                      FROM dbo.USAT_Team_Details utd
                     WHERE utd.league_key = @leagueKey AND
                           utd.conference_key = uld_conf.conference_key AND
                           utd.division_key = uld_div.division_key AND
                           utd.team_last <> 'All-Stars'
                     ORDER BY utd.team_display ASC -- ORDER BY HACK for MLS
                       FOR XML RAW('teams'), TYPE
                )
                FROM dbo.USAT_League_Details uld_div
               WHERE uld_div.league_key = @leagueKey AND uld_div.conference_key = uld_conf.conference_key
               ORDER BY uld_div.division_order ASC
                 FOR XML RAW('divisions'), TYPE
            )
            FROM dbo.USAT_League_Details uld_conf
            WHERE uld_conf.league_key = @leagueKey
            AND (@conferenceKey IS NULL OR (uld_conf.conference_key = @conferenceKey))
            GROUP BY uld_conf.conference_key, uld_conf.conference_display, uld_conf.conference_order
            ORDER BY uld_conf.conference_order
              FOR XML RAW('conferences'), TYPE
        )
        FOR XML PATH(''), ROOT('TeamIndex')
    END
    ELSE IF (CHARINDEX('l.ncaa.org', @leagueKey) > 0)
    BEGIN
        SELECT
	    (
            SELECT sl_conf.conference_key, sl_conf.conference_display AS conference_name,
            (
                SELECT sl_div.division_key, sl_div.division_display AS division_name,
                (
                    SELECT st.team_abbreviation AS abbr_name,
                           CASE
                               WHEN @leagueKey = 'l.mlb.com' THEN 'baseball'
                               WHEN @leagueKey = 'l.nba.com' THEN 'basketball'
                               WHEN @leagueKey = 'l.nfl.com' THEN 'football'
                               WHEN @leagueKey = 'l.nhl.com' THEN 'hockey'
                               ELSE 'blank'
                           END AS Category,
                           st.team_first AS first_name,
                           st.team_last AS last_name,
                           st.team_key
                      FROM dbo.SMG_Teams st
                     WHERE st.league_key = @leagueKey AND
                           st.season_key = @seasonKey AND
                           st.conference_key = sl_conf.conference_key AND
                           st.division_key = sl_div.division_key AND
                           st.team_last <> 'All-Stars'
                     ORDER BY st.team_first ASC, st.team_last ASC
                       FOR XML RAW('teams'), TYPE
                )
                FROM dbo.SMG_Leagues sl_div
               WHERE sl_div.league_key = @leagueKey AND sl_div.season_key = @seasonKey AND sl_div.conference_key = sl_conf.conference_key
               ORDER BY sl_div.division_order ASC
                 FOR XML RAW('divisions'), TYPE
            )
            FROM dbo.SMG_Leagues sl_conf
           WHERE sl_conf.league_key = @leagueKey AND sl_conf.season_key = @seasonKey 
                 AND (@conferenceKey IS NULL OR (sl_conf.conference_key = @conferenceKey))
           GROUP BY sl_conf.conference_key, sl_conf.conference_display, sl_conf.conference_order
           ORDER BY sl_conf.conference_order
             FOR XML RAW('conferences'), TYPE
        )
        FOR XML PATH(''), ROOT('TeamIndex')
    END
    ELSE
    BEGIN
        SELECT
	    (
            SELECT uld_conf.conference_key, uld_conf.conference_display AS conference_name,
            (
                SELECT uld_div.division_key, uld_div.division_display AS division_name,
                (
                    SELECT utd.team_abbreviation AS abbr_name,
                           CASE
                               WHEN @leagueKey = 'l.mlb.com' THEN 'baseball'
                               WHEN @leagueKey = 'l.nba.com' THEN 'basketball'
                               WHEN @leagueKey = 'l.nfl.com' THEN 'football'
                               WHEN @leagueKey = 'l.nhl.com' THEN 'hockey'
                               ELSE 'blank'
                           END AS Category,
                           utd.team_first AS first_name,
                           utd.team_last AS last_name,
                           utd.SDI,
                           utd.team_key,
                           utd.TSN                               
                      FROM dbo.USAT_Team_Details utd
                     WHERE utd.league_key = @leagueKey AND
                           utd.conference_key = uld_conf.conference_key AND
                           utd.division_key = uld_div.division_key AND
                           utd.team_last <> 'All-Stars'
                     ORDER BY utd.team_first ASC, utd.team_last ASC
                       FOR XML RAW('teams'), TYPE
                )
                FROM dbo.USAT_League_Details uld_div
               WHERE uld_div.league_key = @leagueKey AND uld_div.conference_key = uld_conf.conference_key
               ORDER BY uld_div.division_order ASC
                 FOR XML RAW('divisions'), TYPE
            )
            FROM dbo.USAT_League_Details uld_conf
            WHERE uld_conf.league_key = @leagueKey
            AND (@conferenceKey IS NULL OR (uld_conf.conference_key = @conferenceKey))
            GROUP BY uld_conf.conference_key, uld_conf.conference_display, uld_conf.conference_order
            ORDER BY uld_conf.conference_order
              FOR XML RAW('conferences'), TYPE
        )
        FOR XML PATH(''), ROOT('TeamIndex')
    END

    SET NOCOUNT OFF
END 

GO
