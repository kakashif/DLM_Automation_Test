USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[LOC_Standings_new_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[LOC_Standings_new_XML]
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
  --         08/07/2015 - John Lin - SDI migration
  --         09/01/2015 - John Lin - USCP football default year
  --         09/14/2015 - John Lin - default null to zero
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    IF (@leagueName NOT IN ('mlb', 'mls', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba'))
    BEGIN
        RETURN
    END


    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @season_key INT = YEAR(GETDATE())
    DECLARE @today DATE = CAST(GETDATE() AS DATE)

    IF (@leagueName IN ('mlb'))
    BEGIN      
        IF (DATEDIFF(DAY, @today, CAST(@season_key AS VARCHAR) + '-02-01') > 0)
        BEGIN
            -- use last year's
            SET @season_key = @season_key - 1
        END
    END
    ELSE IF (@leagueName IN ('nba', 'ncaab'))
    BEGIN      
        IF (DATEDIFF(DAY, @today, CAST(@season_key AS VARCHAR) + '-10-01') > 0)
        BEGIN
            -- use last year's
            SET @season_key = @season_key - 1
        END
    END
    ELSE IF (@leagueName IN ('nfl', 'ncaaf'))
    BEGIN      
        IF (DATEDIFF(DAY, @today, CAST(@season_key AS VARCHAR) + '-08-01') > 0)
        BEGIN
            -- use last year's
            SET @season_key = @season_key - 1
        END
    END
    ELSE
    BEGIN
        SELECT @season_key = team_season_key
          FROM dbo.SMG_Default_Dates
         WHERE league_key = @leagueName AND page = 'standings'
    END
    
    DECLARE @conference_key VARCHAR(100)
    DECLARE @division_key VARCHAR(100)
    DECLARE @team_key VARCHAR(100)

    SELECT @conference_key = conference_key, @division_key = division_key, @team_key = team_key
      FROM dbo.SMG_Teams
     WHERE league_key = @league_key AND season_key = @season_key AND team_slug = @teamSlug

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

    DECLARE @standings TABLE
    (
        conference_key VARCHAR(100),
        conference VARCHAR(100),
        conference_order INT,
        division_key VARCHAR(100),
        division VARCHAR(100),
        division_order INT,
        team_key VARCHAR(100),
        team_id INT,
        -- render
        wins INT,
        losses INT,
        ties INT,
        [wins-percentage] VARCHAR(100),
        [division-wins] INT,
        [division-losses] INT,
        [division-ties] INT,
        division_GB VARCHAR(100),
        [division-wins-percentage] VARCHAR(100),
        [division-rank] INT,
        -- extra
        [away-wins] INT,
        [away-losses] INT,
        [away-ties] INT,
        [home-wins] INT,
        [home-losses] INT,
        [home-ties] INT,
        [conference-wins] INT,
        [conference-losses] INT,
        [conference-ties] INT,
        overall_OTL INT,
        division_OTL INT,
        selected VARCHAR(100),
        order_by FLOAT
    )
    IF (@leagueName = 'mlb')
    BEGIN
        INSERT INTO @standings (team_key, wins, losses, [wins-percentage], [division-wins], [division-losses], division_GB)
        SELECT p.team_key, [wins], [losses], [wins-percentage], [division-wins], [division-losses], [division-games-back]
          FROM (SELECT team_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([wins], [losses], [wins-percentage], [division-wins], [division-losses], [division-games-back])) AS p
    END
    ELSE IF (@leagueName IN ('nba', 'wnba'))
    BEGIN
        INSERT INTO @standings (team_key, wins, losses, [wins-percentage], [division-wins], [division-losses], division_GB)
        SELECT p.team_key, [wins], [losses], [wins-percentage], [conference-wins], [conference-losses], [games-back]
          FROM (SELECT team_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([wins], [losses], [wins-percentage], [conference-wins], [conference-losses], [games-back])) AS p
    END
    ELSE IF (@leagueName IN ('nfl', 'ncaaf'))
    BEGIN
        INSERT INTO @standings (team_key, [division-rank],
                                [away-wins], [away-losses], [away-ties], [home-wins], [home-losses], [home-ties],
                                [division-wins], [division-losses], [division-ties], [conference-wins], [conference-losses], [conference-ties])
        SELECT p.team_key, ISNULL([division-rank], 0),
               ISNULL([away-wins], 0), ISNULL([away-losses], 0), ISNULL([away-ties], 0), ISNULL([home-wins], 0), ISNULL([home-losses], 0), ISNULL([home-ties], 0),
               [division-wins], [division-losses], [division-ties], ISNULL([conference-wins], 0), ISNULL([conference-losses], 0), ISNULL([conference-ties], 0)
          FROM (SELECT team_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([division-rank], [away-wins], [away-losses], [away-ties], [home-wins], [home-losses], [home-ties],
                                                [division-wins], [division-losses], [division-ties], [conference-wins], [conference-losses], [conference-ties])) AS p
        UPDATE @standings
           SET wins = [away-wins] + [home-wins],
               losses = [away-losses] + [home-losses],
               ties = [away-ties] + [home-ties]

        UPDATE @standings
           SET [division-wins] = [conference-wins], [division-losses] = [conference-losses], [division-ties] = [conference-ties]
         WHERE [division-wins] IS NULL
                    
        UPDATE @standings
           SET [wins-percentage] = CASE
                                       WHEN wins + losses + ties = 0 THEN '.000'
                                       WHEN wins + losses + ties = wins THEN '1.00'
                                       ELSE CAST((CAST(wins + (ties * 0.5) AS FLOAT) / (wins + losses + ties)) AS DECIMAL(4, 3))
                                   END
        UPDATE @standings
           SET [division-wins-percentage] = CASE
                                                WHEN [division-wins] + [division-losses] + [division-ties] = 0 THEN '.000'
                                                WHEN [division-wins] + [division-losses] + [division-ties] = [division-wins] THEN '1.00'
                                                ELSE CAST((CAST([division-wins] AS FLOAT) / ([division-wins] + [division-losses] + [division-ties])) AS DECIMAL(4, 3))
                                            END

        UPDATE @standings
           SET order_by = [division-rank],
               [wins-percentage] = REPLACE([wins-percentage], '0.', '.'),
               [division-wins-percentage] = REPLACE([division-wins-percentage], '0.', '.')
    END
    ELSE IF (@leagueName = 'nhl')
    BEGIN
        INSERT INTO @standings (team_key, wins, losses, overall_OTL, [division-rank], [division-wins], [division-losses], division_OTL)
        SELECT p.team_key, [wins], [losses], [overtime-losses], [conference-rank], [division-wins], [division-losses], [division-overtime-losses]
          FROM (SELECT team_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([wins], [losses], [overtime-losses], [conference-rank], [division-wins], [division-losses], [division-overtime-losses])) AS p
    END
    ELSE IF (@leagueName IN ('ncaab', 'ncaaw'))
    BEGIN
        INSERT INTO @standings (team_key, wins, losses, [wins-percentage], [division-wins], [division-losses])
        SELECT p.team_key, [wins], [losses], [wins-percentage], [conference-wins], [conference-losses]
          FROM (SELECT team_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([wins], [losses], [wins-percentage], [conference-wins], [conference-losses])) AS p
    END

    UPDATE s
       SET s.conference_key = st.conference_key, s.division_key = st.division_key
      FROM @standings s
     INNER JOIN dbo.SMG_Teams st
        ON st.league_key = @league_key AND st.season_key = @season_key AND st.team_key = s.team_key

    IF (@leagueName IN ('ncaaf'))
    BEGIN
        UPDATE s
           SET s.conference = sl.conference_display, s.conference_order = sl.conference_order
          FROM @standings s
         INNER JOIN dbo.SMG_Leagues sl
            ON sl.league_key = @league_key AND sl.season_key = @season_key AND sl.conference_key = s.conference_key
    END
    ELSE
    BEGIN
        UPDATE s
           SET s.conference = sl.conference_display, s.conference_order = sl.conference_order, s.division = sl.division_display, s.division_order = sl.division_order
          FROM @standings s
         INNER JOIN dbo.SMG_Leagues sl
            ON sl.league_key = @league_key AND sl.season_key = @season_key AND sl.conference_key = s.conference_key AND sl.division_key = s.division_key
    END

    -- HACK begin
    IF (@leagueName IN ('mls', 'mlb', 'wnba'))
    BEGIN
        -- STATS
        UPDATE @standings
           SET conference_order = CAST(conference_key AS INT),
               division_order = CAST(division_key AS INT)
    END
    -- HACK end
    
    -- move selected team conference and division to top
    UPDATE @standings
       SET conference_order = 0
     WHERE conference_key = @conference_key

    IF (@division_key IS NOT NULL)
    BEGIN
        UPDATE @standings
           SET division_order = 0
         WHERE division_key = @division_key
    END

    UPDATE @standings
       SET selected = 1
     WHERE team_key = @team_key
     
    -- render
    IF (@leagueName IN ('ncaab', 'ncaaw'))
    BEGIN
        UPDATE @standings
           SET [division-wins-percentage] = CASE
                                                WHEN ([division-losses]) = 0 THEN '1.00'
                                                ELSE RIGHT(ROUND([division-wins] / CAST(([division-wins] + [division-losses]) AS FLOAT), 3), 4)
                                            END
    END
    ELSE IF (@leagueName IN ('mlb', 'nba'))
    BEGIN
/*    
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
*/
        UPDATE @standings
           SET division_GB = REPLACE(REPLACE(REPLACE(division_GB, '1/2', '.5'), '.0', ''), ' ', '')
        
        UPDATE @standings
           SET order_by = CAST(division_GB AS FLOAT)            
    END
    ELSE IF (@leagueName = 'nhl')
    BEGIN
        UPDATE @standings
           SET [wins-percentage] = CASE
                                 WHEN (losses + overall_OTL) = 0 THEN '1.00'
                                 ELSE RIGHT(ROUND(wins / CAST((wins + losses + overall_OTL) AS FLOAT), 3), 4)
                             END

        UPDATE @standings
           SET [division-wins-percentage] = CASE
                                  WHEN ([division-losses] + division_OTL) = 0 THEN '1.00'
                                  ELSE RIGHT(ROUND([division-wins] / CAST(([division-wins] + [division-losses] + division_OTL) AS FLOAT), 3), 4)
                              END

        UPDATE @standings
           SET order_by = [division-rank]
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
                       t.selected, t.team_key, t.team_id, t.wins, t.losses,
                       t.[wins-percentage], t.[division-wins], t.[division-losses], t.[division-wins-percentage], t.[division-rank],
                       (CASE
                           WHEN t.division_GB = '0' THEN '-'
                           ELSE t.division_GB
                       END) AS division_GB                       
                  FROM @standings t
                 WHERE t.conference_key = c.conference_key AND ISNULL(t.division_key, '') = ISNULL(d.division_key, '')
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
