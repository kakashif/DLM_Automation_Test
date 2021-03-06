USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetStandings_MLS_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[MOB_GetStandings_MLS_XML]
    @seasonKey INT,
    @affiliation VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 01/07/2014
  -- Description: get MSL standings for mobile
  -- Update: 07/25/2014 - John Lin - lower case for team key
  --         10/14/2014 - John Lin - remove league key from SMG_Standings
  --         12/19/2014 - John Lin - whitebg
  --         05/20/2015 - John Lin - mls under soccer
  --         07/10/2015 - John Lin - STATS migration
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @standings TABLE
    (
        conference_key VARCHAR(100),
        conference_display VARCHAR(100),
        team_key VARCHAR(100),
        -- render
        team_abbreviation VARCHAR(100),
        long_name VARCHAR(100),
        wins INT,
        losses INT,
        ties VARCHAR(100),
        standing_points VARCHAR(100), -- extra
        team_page VARCHAR(100),
        result_effect VARCHAR(100),
        logo VARCHAR(100)
    )

    DECLARE @stats TABLE
    (       
        team_key   VARCHAR(100),
        [column]   VARCHAR(100), 
        value      VARCHAR(100)
    )
        
    INSERT INTO @stats (team_key, [column], value)
    SELECT ss.team_key, ss.[column], ss.value
      FROM SportsEditDB.dbo.SMG_Standings ss
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = 'mls' AND ss.season_key = st.season_key AND ss.team_key = st.team_key
     WHERE ss.season_key = @seasonKey AND ss.[column] IN ('wins', 'losses', 'ties', 'points', 'result-effect')

            
    INSERT INTO @standings (team_key, wins, losses, ties, standing_points, result_effect)
    SELECT p.team_key, [wins], [losses], [ties], [points], [result-effect]
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([wins], [losses], [ties], [points], [result-effect])) AS p
     
    
    UPDATE s
       SET s.conference_key = sl.conference_key,
           s.conference_display =  sl.conference_display,
           s.long_name = st.team_first + ' ' + st.team_last,
           s.team_abbreviation = st.team_abbreviation,
           s.team_page = 'http://www.usatoday.com/sports/soccer/mls/' + st.team_slug
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = 'mls' AND st.season_key = @seasonKey AND st.team_key = s.team_key
     INNER JOIN dbo.SMG_Leagues sl
        On sl.league_key = st.league_key AND sl.season_key = st.season_key AND sl.conference_key = st.conference_key


    -- render
    UPDATE @standings
       SET result_effect = ''
     WHERE result_effect IS NULL OR result_effect = 'x'

    UPDATE @standings
       SET logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/mls-whitebg/22/' + team_abbreviation + '.png'

    
    IF (@affiliation = 'league')
    BEGIN
        SELECT
	    (
	        SELECT 'MLS' AS ribbon,
	        (
                SELECT s.team_abbreviation AS short_name, s.long_name, s.wins, s.losses, s.ties, s.standing_points,
                       s.team_page, s.result_effect AS legend_key, logo
                  FROM @standings s
                 ORDER BY CAST(s.standing_points AS INT) DESC
                   FOR XML RAW('teams'), TYPE
            )
            FOR XML RAW('standings'), TYPE
        ),
        (
            SELECT @seasonKey AS [year], @affiliation AS affiliation
               FOR XML RAW('defaults'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE -- conference
    BEGIN
        SELECT
	    (
            SELECT conf_s.conference_display AS ribbon,
            (
                SELECT s.team_abbreviation AS short_name, s.long_name, s.wins, s.losses, s.ties, s.standing_points,
                       s.team_page, s.result_effect AS legend_key, logo
                  FROM @standings s
                 WHERE s.conference_key = conf_s.conference_key
                 ORDER BY CAST(s.standing_points AS INT) DESC
                   FOR XML RAW('teams'), TYPE
            )
            FROM @standings conf_s
           GROUP BY conf_s.conference_key, conf_s.conference_display
           ORDER BY CAST(conf_s.conference_key AS INT) ASC
             FOR XML RAW('standings'), TYPE
        ),
        (
            SELECT @seasonKey AS [year], @affiliation AS affiliation
               FOR XML RAW('defaults'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    
    SET NOCOUNT OFF
END 

GO
