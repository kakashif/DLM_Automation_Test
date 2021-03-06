USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[GDP_Standings_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[GDP_Standings_XML]
    @leagueName VARCHAR(100),
    @teamSlug VARCHAR(100)
AS
  -- =============================================
  -- Author: John Lin
  -- Create date: 06/24/2015
  -- Description: get standings for GDP
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

/* DEPRECATED

    IF (@leagueName NOT IN ('mlb', 'mls', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba'))
    BEGIN
        RETURN
    END


    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @season_key INT
    DECLARE @conference_key VARCHAR(100)
    DECLARE @division_key VARCHAR(100)
    DECLARE @team_key VARCHAR(100)

    SELECT @season_key = team_season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'standings'

    DECLARE @standings TABLE
    (
        conference_key VARCHAR(100),
        conference VARCHAR(100),
        division_key VARCHAR(100),
        division VARCHAR(100),
        team_key VARCHAR(100),
        -- render
        [wins] INT, -- MLB
        [losses] INT, -- MLB
        [winning-percentage] VARCHAR(100), -- MLB
        [games-back] VARCHAR(100), -- MLB
        [away-wins] INT, -- MLB
        [away-losses] INT, -- MLB
        [home-wins] INT, -- MLB
        [home-losses] INT, -- MLB
        [last-ten-games-losses] INT, -- MLB
        [last-ten-games-wins] INT, -- MLB
        [streak-total] INT, -- MLB
        [streak-type] VARCHAR(100), -- MLB
        [result-effect] VARCHAR(100), -- MLB
        -- extra
        selected VARCHAR(100),
        order_by FLOAT
    )
    DECLARE @stats TABLE
    (       
        team_key   VARCHAR(100),
        [column]   VARCHAR(100), 
        value      VARCHAR(100)
    )
    INSERT INTO @stats (team_key, [column], value)
    SELECT team_key, [column], value
      FROM SportsEditDB.dbo.SMG_Standings
     WHERE league_key = @league_key AND season_key = @season_key

    IF (@leagueName = 'mlb')
    BEGIN
        INSERT INTO @standings (team_key, [wins], [losses], [winning-percentage], [games-back], [away-wins], [away-losses], [home-wins], [home-losses],
                                [last-ten-games-losses], [last-ten-games-wins], [streak-total], [streak-type], [result-effect])
        SELECT p.team_key, [wins], [losses], [winning-percentage], [games-back], [away-wins], [away-losses], [home-wins], [home-losses],
               [last-ten-games-losses], [last-ten-games-wins], [streak-total], [streak-type], [result-effect]
          FROM (SELECT team_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([wins], [losses], [winning-percentage], [games-back], [away-wins], [away-losses], [home-wins], [home-losses],
                                                [last-ten-games-losses], [last-ten-games-wins], [streak-total], [streak-type], [result-effect])) AS p

        UPDATE @standings
           SET order_by = CAST([games-back] AS FLOAT) 

        UPDATE @standings
           SET [games-back] = '-'
         WHERE [games-back] = '0'
    END
/*    
    ELSE IF (@leagueName IN ('nba', 'wnba'))
    BEGIN
        INSERT INTO @standings (team_key, overall_W, overall_L, overall_Pct, division_W, division_L, division_GB)
        SELECT p.team_key, [wins], [losses], [winning-percentage], [conference-wins], [conference-losses], [games-back]
          FROM (SELECT team_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([wins], [losses], [winning-percentage], [conference-wins], [conference-losses], [games-back])) AS p
    END
    ELSE IF (@leagueName = 'nfl')
    BEGIN
        INSERT INTO @standings (team_key, overall_W, overall_L, overall_Pct, division_W, division_L)
        SELECT p.team_key, [wins], [losses], [winning-percentage], [division-wins], [division-losses]
          FROM (SELECT team_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([wins], [losses], [winning-percentage], [division-wins], [division-losses])) AS p
    END
    ELSE IF (@leagueName = 'nhl')
    BEGIN
        INSERT INTO @standings (team_key, overall_W, overall_L, overall_OTL, division_Rnk, division_W, division_L, division_OTL)
        SELECT p.team_key, [wins], [losses], [overtime-losses], [conference-rank], [division-wins], [division-losses], [division-overtime-losses]
          FROM (SELECT team_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([wins], [losses], [overtime-losses], [conference-rank], [division-wins], [division-losses], [division-overtime-losses])) AS p
    END
    ELSE IF (@leagueName = 'ncaaf')
    BEGIN
        INSERT INTO @standings (team_key, overall_W, overall_L, overall_Pct, division_W, division_L, division_Pct)
        SELECT p.team_key, [wins], [losses], [winning-percentage], [conference-wins], [conference-losses], [conference-winning-percentage]
          FROM (SELECT team_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([wins], [losses], [winning-percentage], [conference-wins], [conference-losses], [conference-winning-percentage])) AS p
    END
    ELSE IF (@leagueName IN ('ncaab', 'ncaaw'))
    BEGIN
        INSERT INTO @standings (team_key, overall_W, overall_L, overall_Pct, division_W, division_L)
        SELECT p.team_key, [wins], [losses], [winning-percentage], [conference-wins], [conference-losses]
          FROM (SELECT team_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([wins], [losses], [winning-percentage], [conference-wins], [conference-losses])) AS p
    END
*/    

    UPDATE s
       SET s.conference_key = st.conference_key, s.division_key =  st.division_key
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND st.season_key = @season_key AND st.team_key = s.team_key 

    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        UPDATE s
           SET s.conference = sl.conference_display, s.division = sl.division_display
          FROM @standings s
         INNER JOIN dbo.SMG_Leagues sl
            ON sl.league_key = @league_key AND sl.season_key = @season_key AND sl.conference_key = s.conference_key AND sl.division_key = s.division_key
    END
    ELSE
    BEGIN
        UPDATE s
           SET s.conference = sl.conference_name, s.division = sl.division_name
          FROM @standings s
         INNER JOIN dbo.SMG_Leagues sl
            ON sl.league_key = @league_key AND sl.season_key = @season_key AND sl.conference_key = s.conference_key AND sl.division_key = s.division_key
    END

    IF (@teamSlug <> 'all')
    BEGIN
        SELECT @conference_key = conference_key, @division_key = division_key, @team_key = team_key
          FROM dbo.SMG_Teams
         WHERE league_key = @league_key AND season_key = @season_key AND team_slug = @teamSlug
    
        -- move selected team conference and division to top
        UPDATE @standings
           SET conference_key = 0
         WHERE conference_key = @conference_key

        UPDATE @standings
           SET division_key = 0
         WHERE division_key = @division_key

        UPDATE @standings
           SET selected = 1
         WHERE team_key = @team_key
    END
/*     
    -- render
    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        IF (@leagueName IN ('ncaab', 'ncaaw'))
        BEGIN
            UPDATE @standings
               SET division_Pct = CASE
                                      WHEN (division_L) = 0 THEN '1.00'
                                      ELSE RIGHT(ROUND(division_W / CAST((division_W + division_L) AS FLOAT), 3), 4)
                                  END
        END

        UPDATE @standings
           SET order_by = 1 - CAST(division_Pct AS FLOAT)
    END
    ELSE IF (@leagueName IN ('mlb', 'nba'))
    BEGIN
        IF (@leagueName = 'mlb')
        BEGIN
            UPDATE @standings
               SET conference = CASE
                                    WHEN conference = 'AL' THEN 'American'
                                    WHEN conference = 'NL' THEN 'National'
                                    ELSE conference
                                END

            UPDATE @standings
               SET division = CASE
                                  WHEN division IN ('AL East', 'NL East') THEN 'Eastern'
                                  WHEN division IN ('AL Central', 'NL Central') THEN 'Central'
                                  WHEN division IN ('AL West', 'NL West') THEN 'Western'
                                  ELSE division
                              END
        END

        
           
    END
    ELSE IF (@leagueName = 'nfl')
    BEGIN
        UPDATE @standings
           SET conference = CASE
                                WHEN conference = 'AFC' THEN 'American'
                                WHEN conference = 'NFC' THEN 'National'
                                ELSE conference
                            END

        UPDATE @standings
           SET division = REPLACE(REPLACE(division, 'AFC ', ''), 'NFC ', '')


        UPDATE @standings
           SET division_Pct = CASE
                                  WHEN (division_L) = 0 THEN '1.00'
                                  ELSE RIGHT(ROUND(division_W / CAST((division_W + division_L) AS FLOAT), 3), 4)
                              END

        UPDATE @standings
           SET order_by = 1 - CAST(overall_Pct AS FLOAT)
    END
    ELSE IF (@leagueName = 'nhl')
    BEGIN
        UPDATE @standings
           SET overall_Pct = CASE
                                 WHEN (overall_L + overall_OTL) = 0 THEN '1.00'
                                 ELSE RIGHT(ROUND(overall_W / CAST((overall_W + overall_L + overall_OTL) AS FLOAT), 3), 4)
                             END

        UPDATE @standings
           SET division_Pct = CASE
                                  WHEN (division_L + division_OTL) = 0 THEN '1.00'
                                  ELSE RIGHT(ROUND(division_W / CAST((division_W + division_L + division_OTL) AS FLOAT), 3), 4)
                              END
   
        UPDATE @standings
           SET order_by = CAST(division_Rnk AS FLOAT)
    END
*/


    ;WITH XMLNAMESPACES ('http://james.newtonking.com/projects/json' AS json)
    SELECT
    (
        SELECT 'true' AS 'json:Array',
               c.conference,
        (
            SELECT 'true' AS 'json:Array',
                   d.division,
            (
                SELECT 'true' AS 'json:Array',
                       t.selected, t.team_key, t.[wins], t.[losses], t.[winning-percentage], t.[away-wins],  t.[away-losses],
                       t.[home-wins], t.[home-losses], t.[last-ten-games-losses], t.[last-ten-games-wins],
                       t.[streak-total], t.[streak-type], t.[result-effect], t.[games-back]
                  FROM @standings t
                 WHERE t.conference_key = c.conference_key AND t.division_key = d.division_key
                 ORDER BY t.order_by ASC
                   FOR XML RAW('teams'), TYPE
            )
            FROM @standings d
           WHERE d.conference_key = c.conference_key
           GROUP BY d.division, d.division_key
           ORDER BY CAST(d.division_key AS INT) ASC
             FOR XML RAW('division'), TYPE
        )
        FROM @standings c
       GROUP BY c.conference, c.conference_key
       ORDER BY CAST(c.conference_key AS INT) ASC
         FOR XML RAW('conferences'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

*/
    
    SET NOCOUNT OFF
END 

GO
