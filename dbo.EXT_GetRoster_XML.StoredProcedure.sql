USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[EXT_GetRoster_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[EXT_GetRoster_XML]
    @leagueName     VARCHAR(100)
AS
--=============================================
-- Author:		John Lin
-- Create date:	01/28/2014
-- Description:	get league roster for current year
-- Update:		02/17/2014 - ikenticus - get latest roster season_key for given league_key
--				02/18/2014 - ikenticus - omitting coaches and managers from results
--				02/25/2014 - ikenticus: exclude phase_status=delete from query
--				04/07/2015 - ikenticus: tweaking output due to new SMG_Salaries
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100)
    DECLARE @season_key INT    
    
    SELECT @league_key = league_display_name
	  FROM sportsDB.dbo.USAT_leagues
     WHERE league_name = LOWER(@leagueName)

    SELECT TOP 1 @season_key = season_key
      FROM SportsDB.dbo.SMG_Default_Dates
	 WHERE league_key = @leagueName AND page = 'standings'
	 ORDER BY season_key DESC
    
    SELECT @season_key AS season,
    (
        SELECT st.team_first AS city, st.team_last AS mascot,
               (
                   SELECT sp.first_name + ' ' + sp.last_name
                     FROM dbo.SMG_Players sp                     
                    INNER JOIN dbo.SMG_Rosters sr
                       ON sr.player_key = sp.player_key
                    WHERE sr.league_key = st.league_key AND sr.season_key = st.season_key AND sr.team_key = st.team_key
					  AND LOWER(position_regular) NOT IN ('manager', 'coach', 'head-coach', 'assistant-coach')
					  AND sr.phase_status <> 'delete'
                    ORDER BY sp.last_name ASC, sp.first_name ASC
                      FOR XML PATH('players'), TYPE
               )
          FROM dbo.SMG_Teams st
         WHERE st.league_key = @league_key AND st.season_key = @season_key AND st.team_slug IS NOT NULL
         GROUP BY st.league_key, st.season_key, st.team_key, st.team_first, st.team_last
           FOR XML PATH('teams'), TYPE
    )
    FOR XML PATH(''), ROOT('root')
    
    SET NOCOUNT OFF;
END

GO
