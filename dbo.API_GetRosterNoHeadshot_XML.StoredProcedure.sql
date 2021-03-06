USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[API_GetRosterNoHeadshot_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[API_GetRosterNoHeadshot_XML]
    @leagueName VARCHAR(100)
AS
--=============================================
-- Author:		ikenticus
-- Create date:	04/07/2015
-- Description:	get league roster for latest season without headshots
-- Update:		05/07/2015 ikenticus: removing dependence on source and standings
-- 				06/18/2015 ikenticus: using league_key function
-- 				09/16/2015 ikenticus: renaming CON to CON_ to avoid Windows conflicts while generating new headshots
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @season_key INT    
    
	SELECT TOP 1 @season_key = season_key 
	  FROM SportsDB.dbo.SMG_Rosters
	 WHERE league_key = @league_key AND phase_status = 'active'
	 ORDER BY season_key DESC
    
	;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT @season_key AS season,
    (
        SELECT @league_key AS league_key, st.team_slug, st.team_key, st.team_first, st.team_last,
			   CASE WHEN st.team_abbreviation = 'CON' THEN 'CON_' ELSE st.team_abbreviation END AS team_abbr, 
               (
                   SELECT sp.first_name, sp.last_name, sp.player_key, 'true' AS 'json:Array'
                     FROM dbo.SMG_Players sp                     
                    INNER JOIN dbo.SMG_Rosters AS sr ON sr.player_key = sp.player_key
                    WHERE sr.league_key = st.league_key AND sr.season_key = st.season_key AND sr.team_key = st.team_key
					  AND LOWER(ISNULL(position_regular, '')) NOT IN ('manager', 'coach', 'head-coach', 'assistant-coach')
					  AND sr.phase_status <> 'delete' --AND sr.filename IS NULL
                    ORDER BY sp.last_name ASC, sp.first_name ASC
                      FOR XML RAW('players'), TYPE
               )
          FROM dbo.SMG_Teams st
         WHERE st.league_key = @league_key AND st.season_key = @season_key AND st.team_slug IS NOT NULL
         GROUP BY st.league_key, st.season_key, st.team_key, st.team_first, st.team_last, st.team_abbreviation, st.team_slug
		 ORDER BY st.team_slug ASC
           FOR XML PATH('teams'), TYPE
    )
    FOR XML PATH(''), ROOT('root')
    
    SET NOCOUNT OFF;
END

GO
