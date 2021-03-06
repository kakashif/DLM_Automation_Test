USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetStandings_NHL_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PSA_GetStandings_NHL_XML]
    @affiliation VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 07/02/2014
  -- Description: get NHL standings
  -- Update: 10/09/2014 - John Lin - whitebg
  --         10/14/2014 - John Lin - remove league key from SMG_Standings
  --         05/14/2015 - ikenticus - obtain league_key from SMG_fnGetLeagueKey
  --         10/08/2015 - John Lin - calculate standings points
  --         10/21/2015 - John Lin - use RANK() instead of ROW_NUMBER()
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('nhl')
    DECLARE @season_key INT
    
    SELECT @season_key = season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = 'nhl' AND page = 'standings'
    
    DECLARE @columns TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        column_name    VARCHAR(100),
        column_display VARCHAR(100)
    )
    DECLARE @stats TABLE
    (       
        team_key   VARCHAR(100),
        [column]   VARCHAR(100), 
        value      VARCHAR(100)
    )

    INSERT INTO @columns (column_name, column_display)
    VALUES ('rank', 'RK'), ('name', 'TEAM'), ('wins', 'W'), ('losses', 'L'), ('overtime_losses', 'OTL'), ('standing_points', 'PTS')
        
    INSERT INTO @stats (team_key, [column], value)
    SELECT ss.team_key, ss.[column], ss.value
      FROM SportsEditDB.dbo.SMG_Standings ss
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = ss.league_key AND ss.season_key = st.season_key AND ss.team_key = st.team_key
     WHERE ss.league_key = @league_key AND ss.season_key = @season_key AND ss.[column] IN ('wins', 'losses', 'overtime-losses', 'standing-points', 'result-effect', 'streak')

    DECLARE @standings TABLE
    (
        conference_key VARCHAR(100),
        conference_name VARCHAR(100),
        conference_order INT,
        division_key VARCHAR(100),
        division_name VARCHAR(100),
        division_order INT,
        team_key VARCHAR(100),
        -- render
        name VARCHAR(100),
        wins INT,
        losses INT,
        overtime_losses INT,
        standing_points INT,
        result_effect VARCHAR(100),
        logo VARCHAR(100),
        -- extra
        team_abbreviation VARCHAR(100)
    )
            
    INSERT INTO @standings (team_key, wins, losses, overtime_losses, result_effect)
    SELECT p.team_key, ISNULL([wins], 0), ISNULL([losses], 0), ISNULL([overtime-losses], 0), [result-effect]
      FROM (SELECT team_key, [column], value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.[column] IN ([wins], [losses], [overtime-losses], [result-effect])) AS p    

    UPDATE @standings
       SET standing_points = ((wins * 2) + overtime_losses)
    
    UPDATE s
       SET s.conference_key = sl.conference_key,
           s.conference_name =  sl.conference_name,
           s.conference_order =  sl.conference_order,
           s.division_key =  sl.division_key,
           s.division_name =  sl.division_name,
           s.division_order =  sl.division_order,
           s.name = st.team_last,
           s.team_abbreviation = st.team_abbreviation
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st
        ON st.team_key = s.team_key AND st.league_key = @league_key AND st.season_key = @season_key
     INNER JOIN dbo.SMG_Leagues sl
        On sl.league_key = st.league_key AND sl.season_key = st.season_key AND sl.conference_key = st.conference_key AND sl.division_key = st.division_key

    -- render
    UPDATE @standings
       SET logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/nhl-whitebg/110/' + team_abbreviation + '.png'


    IF (@affiliation = 'division')
    BEGIN    	
        SELECT
	    (
            SELECT div_s.division_name AS ribbon,
            (
    	        SELECT column_name, column_display
		          FROM @columns
		         ORDER BY id ASC
	    	       FOR XML PATH('columns'), TYPE
    	    ),
            (
                SELECT CASE
                           WHEN RANK() OVER(ORDER BY CAST(s.standing_points AS INT) DESC) > 8 THEN NULL
                           ELSE RANK() OVER(ORDER BY CAST(s.standing_points AS INT) DESC)
                       END AS [rank],
                       s.name, s.wins, s.losses, s.overtime_losses, s.standing_points, s.logo, s.result_effect AS [key]
                  FROM @standings s
                 WHERE s.division_key = div_s.division_key
                 ORDER BY s.standing_points DESC, s.wins DESC, s.overtime_losses ASC, s.losses ASC              
                   FOR XML RAW('rows'), TYPE
            )
            FROM @standings div_s
           GROUP BY div_s.division_key, div_s.division_name, div_s.division_order
           ORDER BY div_s.division_order
             FOR XML RAW('standings'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    ELSE -- conference
    BEGIN
        SELECT
	    (
            SELECT conf_s.conference_name AS ribbon,
            (
    	        SELECT column_name, column_display
		          FROM @columns
		         ORDER BY id ASC
	    	       FOR XML PATH('columns'), TYPE
    	    ),
            (
                SELECT CASE
                           WHEN RANK() OVER(ORDER BY CAST(s.standing_points AS INT) DESC) > 8 THEN NULL
                           ELSE RANK() OVER(ORDER BY CAST(s.standing_points AS INT) DESC)
                       END AS [rank],
                       s.name, s.wins, s.losses, s.overtime_losses, s.standing_points, s.logo, s.result_effect AS [key]
                  FROM @standings s
                 WHERE s.conference_key = conf_s.conference_key
                 ORDER BY s.standing_points DESC, s.wins DESC, s.overtime_losses ASC, s.losses ASC              
                   FOR XML RAW('rows'), TYPE
            )
            FROM @standings conf_s
           GROUP BY conf_s.conference_key, conf_s.conference_name, conf_s.conference_order
           ORDER BY conf_s.conference_order
             FOR XML RAW('standings'), TYPE
        )
        FOR XML PATH(''), ROOT('root')
    END
    
    SET NOCOUNT OFF
END 

GO
