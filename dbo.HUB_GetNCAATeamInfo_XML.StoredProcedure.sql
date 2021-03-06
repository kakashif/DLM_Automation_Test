USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetNCAATeamInfo_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[HUB_GetNCAATeamInfo_XML]
   @teamSlug VARCHAR(100)
AS
--=============================================
-- Author: John Lin
-- Create date: 07/22/2014
-- Description: get NCAA team info
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @sport TABLE
    (
        league_key  VARCHAR(100),
        league_name VARCHAR(100),
        season_key  INT
    )
    INSERT INTO @sport (league_key, league_name)
    VALUES ('l.ncaa.org.mbasket', 'ncaab'), ('l.ncaa.org.mfoot', 'ncaaf'), ('l.ncaa.org.wbasket', 'ncaaw')
    
    UPDATE s
       SET s.season_key = sdd.team_season_key 
      FROM @sport s
     INNER JOIN SMG_Default_Dates sdd
        ON sdd.league_key = s.league_name AND sdd.page = 'schedules'

    DECLARE @info TABLE
    (
        league_name VARCHAR(100),
        team_first  VARCHAR(100),
        team_last   VARCHAR(100),
        team_abbr   VARCHAR(100),
        team_slug   VARCHAR(100),
        season_key  INT
    )
    
    INSERT INTO @info (league_name, team_first, team_last, team_abbr, team_slug, season_key)
    SELECT s.league_name, st.team_first, st.team_last, st.team_abbreviation, st.team_slug, s.season_key
      FROM dbo.SMG_Teams st
     INNER JOIN @sport s
        ON s.league_key = st.league_key AND s.season_key = st.season_key
     WHERE st.team_slug = @teamSlug


    SELECT
    (
        SELECT i_o.league_name,
               (
                   SELECT i_i.team_first, i_i.team_last, i_i.team_abbr, i_i.team_slug, i_i.season_key
                     FROM @info i_i
                    WHERE i_i.league_name = i_o.league_name
                      FOR XML RAW('team'), TYPE
               )
          FROM @info i_o
         GROUP BY i_o.league_name
           FOR XML RAW('league'), TYPE
    )
    FOR XML PATH(''), ROOT('root')
            
    SET NOCOUNT OFF 
END


GO
