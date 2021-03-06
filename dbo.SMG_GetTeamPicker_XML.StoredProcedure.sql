USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamPicker_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_GetTeamPicker_XML]
    @leagueName	VARCHAR(100),
	@seasonKey	INT	
AS
-- =============================================
-- Author:     	ikenticus
-- Create date: 10/04/2013
-- Description: get team picker info for league name and season key
-- Update: 10/21/2013 - John Lin - add team slug
--         10/30/2013 - ikenticus: fixing default date
--         05/01/2014 - John Lin - remove display order
--         06/17/2014 - John Lin - use league name for SMG_Default_Dates
--         08/04/2014 - John LIn - check All-Stars in first and last
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	
/* DEPRECATED

	-- Determine leagueKey from leagueName
	DECLARE @league_key VARCHAR(100)
	
	SELECT @league_key = league_display_name
      FROM sportsDB.dbo.USAT_leagues
     WHERE league_name = LOWER(@leagueName)


	-- Check for valid seasonKey
	IF @seasonKey NOT IN (SELECT season_key
	                        FROM dbo.SMG_Teams
	                       WHERE league_key = @league_key
	                       GROUP BY season_key)
	BEGIN
		SELECT @seasonKey = season_key
		  FROM SMG_Default_Dates
		 WHERE league_key = @leagueName AND page = 'statistics'
	END


	IF UPPER(@leagueName) IN ('NCAAF', 'NCAAB', 'NCAAW')
    BEGIN
        SELECT
	    (
            SELECT sl_conf.conference_key, sl_conf.conference_display AS conference_name,
				  (
					  SELECT	
							 st.team_first AS first_name,
							 st.team_last AS last_name,
							 st.team_key,
							 st.team_first AS team_name,
							 st.team_slug
						FROM dbo.SMG_Teams st
					   WHERE st.league_key = @league_key AND st.season_key = @seasonKey AND
							 st.conference_key = sl_conf.conference_key AND
							 'All-Stars' NOT IN (st.team_first, st.team_last)
					   ORDER BY st.team_first ASC, st.team_last ASC
						 FOR XML RAW('team'), TYPE
				  )
              FROM dbo.SMG_Leagues sl_conf
             WHERE sl_conf.league_key = @league_key AND sl_conf.season_key = @seasonkey
             GROUP BY sl_conf.conference_key, sl_conf.conference_display, sl_conf.conference_order
             ORDER BY sl_conf.conference_order
               FOR XML RAW('conference'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE
    BEGIN
        SELECT
	    (
            SELECT sl_conf.conference_key, sl_conf.conference_display AS conference_name,
                   (
                       SELECT sl_div.division_key, sl_div.division_display AS division_name,
                              (CASE WHEN UPPER(@leagueName) IN ('MLS', 'WNBA') THEN 'CONFERENCE'
                                    ELSE NULL END) AS conference_only,							
                              (
                                  SELECT
                                         (CASE
											WHEN UPPER(@leagueName) IN ('MLS') THEN NULL
											ELSE 1
											END) AS first_name_display,
                                         st.team_first AS first_name,
                                         st.team_last AS last_name,
                                         st.team_key,
                                         ISNULL(st.team_display, st.team_last) AS team_name,
                                         st.team_slug
                                    FROM dbo.SMG_Teams st
                                   WHERE st.league_key = @league_key AND st.season_key = @seasonKey AND
                                         st.conference_key = sl_conf.conference_key AND
                                         st.division_key = sl_div.division_key AND
							             'All-Stars' NOT IN (st.team_first, st.team_last)
                                   ORDER BY st.team_first ASC, st.team_last ASC
                                     FOR XML RAW('team'), TYPE
                              )
                         FROM dbo.SMG_Leagues sl_div
                        WHERE sl_div.league_key = @league_key AND sl_div.season_key = @seasonKey AND sl_div.conference_key = sl_conf.conference_key
                        ORDER BY sl_div.division_order ASC
                          FOR XML RAW('division'), TYPE
                   )
              FROM dbo.SMG_Leagues sl_conf
             WHERE sl_conf.league_key = @league_key AND sl_conf.season_key = @seasonkey
             GROUP BY sl_conf.conference_key, sl_conf.conference_display, sl_conf.conference_order
             ORDER BY sl_conf.conference_order
               FOR XML RAW('conference'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END

*/

    SET NOCOUNT OFF
END 

GO
