USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[LOC_Standings_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[LOC_Standings_XML]
    @leagueName VARCHAR(100),
    @teamSlug VARCHAR(100)
AS
  -- =============================================
  -- Author: John Lin
  -- Create date: 04/21/2015
  -- Description: get standings for USCP
  -- Update: 04/30/2015 - John Lin - add division percentage for nfl
  --         06/10/2015 - John Lin - add all conferences for ncaa
  --         06/24/2015 - John Lin - update basketball
  --         07/13/2015 - John Lin - STATS migration - MLB
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    IF (@leagueName NOT IN ('mlb', 'mls', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba'))
    BEGIN
        RETURN
    END


    IF (@leagueName IN ('nfl', 'ncaaf'))
    BEGIN
        EXEC dbo.LOC_Standings_new_XML @leagueName, @teamSlug
        RETURN
    END


    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @season_key INT

    SELECT @season_key = team_season_key
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'standings'

    DECLARE @conference_key VARCHAR(100)
    DECLARE @division_key VARCHAR(100)
    DECLARE @team_key VARCHAR(100)

    SELECT TOP 1 @conference_key = conference_key, @division_key = division_key, @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @season_key AND team_slug = @teamSlug


    DECLARE @standings TABLE
    (
        conference_key VARCHAR(100),
        conference VARCHAR(100),
        conference_order INT,
        division_key VARCHAR(100),
        division VARCHAR(100),
        division_order INT,
        team_key VARCHAR(100),
        team_id VARCHAR(100),
        -- render
        overall_W INT,
        overall_L INT,
        overall_Pct VARCHAR(100),
        division_W INT,
        division_L INT,
        division_GB VARCHAR(100),
        division_Pct VARCHAR(100),
        division_Rnk INT,
        -- extra
        overall_OTL INT,
        division_OTL INT,
        selected VARCHAR(100),
        order_by FLOAT
    )   
    DECLARE @stats TABLE
    (       
        team_key   VARCHAR(100),
        [column]   VARCHAR(100), 
        value      VARCHAR(100)
    )
    DECLARE @columns TABLE
    (
        [column] VARCHAR(100)
    )

    IF (@leagueName = 'mlb')
    BEGIN
        INSERT INTO @columns([column])
        VALUES ('wins'), ('losses'), ('winning-percentage'), ('division-wins'), ('division-losses'), ('division-games-back')
    END
    ELSE IF (@leagueName IN ('nba', 'wnba'))
    BEGIN
        INSERT INTO @columns([column])
        VALUES ('wins'), ('losses'), ('winning-percentage'), ('conference-wins'), ('conference-losses'), ('games-back')
    END
    ELSE IF (@leagueName = 'nfl')
    BEGIN
        INSERT INTO @columns([column])
        VALUES ('wins'), ('losses'), ('winning-percentage'), ('division-wins'), ('division-losses')
    END
    ELSE IF (@leagueName = 'nhl')
    BEGIN
        INSERT INTO @columns([column])
        VALUES ('wins'), ('losses'), ('overtime-losses'), ('division-wins'), ('division-losses'), ('division-overtime-losses'), ('conference-rank')
    END
    ELSE IF (@leagueName = 'ncaaf')
    BEGIN
        INSERT INTO @columns([column])
        VALUES ('wins'), ('losses'), ('winning-percentage'), ('conference-wins'), ('conference-losses'), ('conference-winning-percentage')
    END
    ELSE IF (@leagueName IN ('ncaab', 'ncaaw'))
    BEGIN
        INSERT INTO @columns([column])
        VALUES ('wins'), ('losses'), ('winning-percentage'), ('conference-wins'), ('conference-losses')
    END

    INSERT INTO @stats (team_key, [column], value)
    SELECT ss.team_key, ss.[column], ss.value
      FROM SportsEditDB.dbo.SMG_Standings ss
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND st.season_key = ss.season_key AND st.team_key = ss.team_key
     INNER JOIN @columns c
        ON c.[column] = ss.[column]
     WHERE ss.season_key = @season_key
    
    IF (@leagueName = 'mlb')
    BEGIN
        INSERT INTO @standings (team_key, overall_W, overall_L, overall_Pct, division_W, division_L, division_GB)
        SELECT p.team_key, [wins], [losses], [winning-percentage], [division-wins], [division-losses], [division-games-back]
          FROM (SELECT team_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([wins], [losses], [winning-percentage], [division-wins], [division-losses], [division-games-back])) AS p
    END
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
    
    UPDATE s
       SET s.conference_key = st.conference_key, s.division_key =  st.division_key
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND st.season_key = @season_key AND st.team_key = s.team_key 

    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        UPDATE s
           SET s.conference =  sl.conference_display, s.conference_order =  sl.conference_order, s.division =  sl.division_display, s.division_order =  sl.division_order
          FROM @standings s
         INNER JOIN dbo.SMG_Leagues sl
            ON sl.league_key = @league_key AND sl.season_key = @season_key AND sl.conference_key = s.conference_key AND sl.division_key = s.division_key
    END
    ELSE
    BEGIN
        UPDATE s
           SET s.conference = sl.conference_display, s.conference_order = sl.conference_order, s.division = sl.division_display, s.division_order = sl.division_order
          FROM @standings s
         INNER JOIN dbo.SMG_Leagues sl
            ON sl.league_key = @league_key AND sl.season_key = @season_key AND sl.conference_key = s.conference_key AND sl.division_key = s.division_key
    END
    
    -- move selected team conference and division to top
    UPDATE @standings
       SET conference_order = 0
     WHERE conference_key = @conference_key

    UPDATE @standings
       SET division_order = 0
     WHERE division_key = @division_key

    UPDATE @standings
       SET selected = 1
     WHERE team_key = @team_key
     

    DECLARE @leaders TABLE
    (
        conference_key VARCHAR(100),
        division_key VARCHAR(100),
        team_key VARCHAR(100),
        wins INT,
        losses INT
    )
    DECLARE @leader_wins INT
    DECLARE @leader_losses INT

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
         UPDATE @standings
           SET overall_Pct = CASE
                                 WHEN overall_W + overall_L = overall_W THEN '1.00'
                                 ELSE REPLACE(CAST((CAST(overall_W AS FLOAT)/ (overall_W + overall_L)) AS DECIMAL(4, 3)), '0.', '.')
                             END

        INSERT INTO @leaders (conference_key, division_key)
        SELECT conference_key, division_key
          FROM @standings
         GROUP BY conference_key, division_key
        
        UPDATE l
           SET l.team_key = (SELECT TOP 1 s.team_key
                               FROM @standings s
                              WHERE s.conference_key = l.conference_key AND s.division_key = l.division_key
                            ORDER BY CAST(s.overall_Pct AS FLOAT) DESC)
          FROM @leaders l                            

        UPDATE l
           SET l.wins = s.overall_W, l.losses = s.overall_L
          FROM @leaders l
         INNER JOIN @standings s
            ON s.conference_key = l.conference_key AND s.division_key = l.division_key AND s.team_key = l.team_key

        UPDATE s
           SET s.division_GB = CAST((CAST((l.wins - s.overall_W) - (l.losses - s.overall_L) AS FLOAT) / 2.0) AS DECIMAL(6, 1))
          FROM @standings s
         INNER JOIN @leaders l
            ON l.conference_key = s.conference_key AND l.division_key = s.division_key

        UPDATE @standings
           SET division_GB = REPLACE(division_GB, '.0', '')

        IF (@leagueName = 'mlb')
        BEGIN
            UPDATE @standings
               SET conference = CASE
                                    WHEN conference = 'AL' THEN 'American League'
                                    WHEN conference = 'NL' THEN 'National League'
                                    ELSE conference
                                END

            UPDATE @standings
               SET division = CASE
                                  WHEN division IN ('AL East', 'NL East') THEN 'Eastern Division'
                                  WHEN division IN ('AL Central', 'NL Central') THEN 'Central Division'
                                  WHEN division IN ('AL West', 'NL West') THEN 'Western Division'
                                  ELSE division
                              END
        END
        
        UPDATE @standings
           SET team_id = dbo.SMG_fnEventId(team_key),
               order_by = CAST(division_GB AS FLOAT)            
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
                       t.selected, t.team_key, t.team_id, t.overall_W, t.overall_L, t.overall_Pct, t.division_W, t.division_L, t.division_Pct, t.division_Rnk,
                       (CASE
                           WHEN t.division_GB = '0' THEN '-'
                           ELSE t.division_GB
                       END) AS division_GB                       
                  FROM @standings t
                 WHERE t.conference_key = c.conference_key AND t.division_key = d.division_key
                 ORDER BY t.order_by ASC
                   FOR XML RAW('teams'), TYPE
            )
            FROM @standings d
           WHERE d.conference_key = c.conference_key
           GROUP BY d.division, d.division_key, d.division_order
           ORDER BY d.division_order ASC
             FOR XML RAW('division'), TYPE
        )
        FROM @standings c
       GROUP BY c.conference, c.conference_key, c.conference_order
       ORDER BY c.conference_order ASC
         FOR XML RAW('conferences'), TYPE
    )
    FOR XML PATH(''), ROOT('root')
    
    SET NOCOUNT OFF
END 

GO
