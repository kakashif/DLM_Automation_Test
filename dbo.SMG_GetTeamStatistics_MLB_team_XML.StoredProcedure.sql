USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamStatistics_MLB_team_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetTeamStatistics_MLB_team_XML]
   @teamKey       VARCHAR(100),
   @seasonKey     INT,
   @subSeasonType VARCHAR(100),
   @category      VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 08/23/2013
  -- Description: get MLB team statistics
  -- Update: 01/08/2015 - John Lin - change team_key from league-average to @league_key
  --         02/20/2015 - ikenticus - migrating SMG_Player/Team_Season_Statistics to SMG_Statistics
  --         06/16/2015 - John Lin - STATS migration
  --         08/31/2015 - ikenticus - SDI migration
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('mlb')

    DECLARE @stats TABLE
    (
        ribbon   VARCHAR(100),
        category VARCHAR(100),
        [column] VARCHAR(100), 
        value    VARCHAR(100)
    )
    -- name
    DECLARE @name VARCHAR(100)
    DECLARE @rgb VARCHAR(100)
        
    SELECT @name = team_last, @rgb = rgb
	  FROM dbo.SMG_Teams
	 WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @teamKey

    DECLARE @leaders TABLE
    (
        ribbon          VARCHAR(100), 
        [rank]          VARCHAR(100),
        value           VARCHAR(100),
        reference_ribbon  VARCHAR(100),
        reference_column  VARCHAR(100),
        reference_sort    VARCHAR(100)
    )
    DECLARE @players TABLE
    (
        sub_ribbon VARCHAR(100), 
        player_key VARCHAR(100),
        name       VARCHAR(100)
    )
    DECLARE @reference TABLE
    (
        ribbon      VARCHAR(100),
        ribbon_node VARCHAR(100)
    )    
    IF (@category = 'pitching')
    BEGIN
        DECLARE @pitchings TABLE
        (
            ribbon VARCHAR(100),
            category VARCHAR(100),
            [events-played] VARCHAR(100),
            [innings-pitched] VARCHAR(100),
            [pitching-hits] VARCHAR(100),
            [runs-allowed] VARCHAR(100),
            [earned-runs] VARCHAR(100),
            [pitching-bases-on-balls] VARCHAR(100),            
            [pitching-strikeouts] VARCHAR(100),
            [wins] VARCHAR(100),
            [losses] VARCHAR(100),
            [saves] VARCHAR(100),
            [games-complete] VARCHAR(100),
            [shutouts] VARCHAR(100),            
            [whip] VARCHAR(100),
            [era] VARCHAR(100)
        )
        INSERT INTO @stats (ribbon, category, [column], value)
        SELECT scd.ribbon, stss.category, scd.[column], stss.value 
          FROM SportsEditDB.dbo.SMG_Column_Details scd
         INNER JOIN SportsEditDB.dbo.SMG_Statistics stss
            ON stss.league_key = scd.league_key AND stss.[column] = scd.[column] AND stss.season_key = @seasonKey AND
               stss.sub_season_type = @subSeasonType AND (stss.team_key = @teamKey OR stss.team_key = @league_key) AND
               stss.category IN ('feed', 'league-average', 'rank') AND stss.player_key = 'team'
         WHERE scd.league_key = @league_key AND scd.page = 'team' AND scd.[level] = 'team' AND scd.ribbon = 'PITCHING'
              
        INSERT INTO @pitchings                 
        SELECT p.ribbon, p.category, [events-played], [innings-pitched], [pitching-hits], [runs-allowed], [earned-runs],
               [pitching-bases-on-balls], [pitching-strikeouts], [wins], [losses], [saves], [games-complete], [shutouts], [whip], [era]
          FROM (SELECT ribbon, category, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([events-played], [innings-pitched], [pitching-hits], [runs-allowed], [earned-runs],
                                                [pitching-bases-on-balls], [pitching-strikeouts], [wins], [losses], [saves], [games-complete],
                                                [shutouts], [whip], [era])) AS p

        -- leaders
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT 'EARNED RUN AVERAGE', [era] + ' ERA', ribbon, 'era'
          FROM @pitchings
         WHERE ribbon = 'PITCHING' AND category = 'feed'
         
        UPDATE @leaders
           SET [rank] = (SELECT [era] FROM @pitchings WHERE ribbon = 'PITCHING' AND category = 'rank')
         WHERE ribbon = 'EARNED RUN AVERAGE'
         
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT 'RUNS ALLOWED', [runs-allowed] + ' R', ribbon, 'runs-allowed'
          FROM @pitchings
         WHERE ribbon = 'PITCHING' AND category = 'feed'
         
        UPDATE @leaders
           SET [rank] = (SELECT [runs-allowed] FROM @pitchings WHERE ribbon = 'PITCHING' AND category = 'rank')
         WHERE ribbon = 'RUNS ALLOWED'
         
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT 'STRIKEOUTS', [pitching-strikeouts] + ' SO', ribbon, 'pitching-strikeouts'
          FROM @pitchings
         WHERE ribbon = 'PITCHING' AND category = 'feed'
         
        UPDATE @leaders
           SET [rank] = (SELECT [pitching-strikeouts] FROM @pitchings WHERE ribbon = 'PITCHING' AND category = 'rank')
         WHERE ribbon = 'STRIKEOUTS'

        UPDATE l
           SET l.reference_sort = stn.sort
          FROM @leaders l
         INNER JOIN SportsEditDB.dbo.SMG_TSN_Nodes stn
            ON stn.sport = 'baseball' AND stn.[level] = 'team' AND stn.attribute = l.reference_column

        -- players
        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'EARNED RUN AVERAGE' , player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'era' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) ASC

        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'RUNS ALLOWED' , player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'runs-allowed' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) ASC

        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'STRIKEOUTS' , player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'pitching-strikeouts' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC


        UPDATE p
	       SET p.name = LEFT(sp.first_name, 1) + '. ' + sp.last_name
	      FROM @players p
	     INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = p.player_key            
         
        -- reference
        INSERT INTO @reference (ribbon, ribbon_node)
        VALUES ('PITCHING', 'pitching')

		-- SDI formatting (may want to move to UX for better datatables sort capabilities in future
		UPDATE @pitchings
		   SET whip = REPLACE(CAST(CAST(whip AS DECIMAL(5,2)) AS VARCHAR), '.00', ''),
			   era = REPLACE(CAST(CAST(era AS DECIMAL(5,2)) AS VARCHAR), '.00', '')

        SELECT
        (
            SELECT 'PITCHING TEAM RANKINGS' AS super_ribbon, @teamKey AS team_key, ribbon, @rgb AS rgb,
                   (CASE
                       WHEN RIGHT([rank], 1) = '1' AND RIGHT([rank], 2) <> '11' THEN [rank] + 'ST'
                       WHEN RIGHT([rank], 1) = '2' AND RIGHT([rank], 2) <> '12' THEN [rank] + 'ND'
                       WHEN RIGHT([rank], 1) = '3' AND RIGHT([rank], 2) <> '13' THEN [rank] + 'RD'
                       ELSE [rank] + 'TH'
                   END) AS [rank], value, reference_ribbon, reference_sort, reference_column,
                   (
                       SELECT name
                        FROM @players
                       WHERE sub_ribbon = l.ribbon
                         FOR XML RAW('player'), TYPE
                   )
              FROM @leaders l
               FOR XML RAW('leader'), TYPE
        ),
        (
            SELECT scd.ribbon, scd.sub_ribbon, scd.[column], scd.display, scd.tooltip, stn.[type], stn.[sort], scd.[order]
              FROM SportsEditDB.dbo.SMG_Column_Details scd
             INNER JOIN SportsEditDB.dbo.SMG_TSN_Nodes stn
                ON stn.sport = 'baseball' AND stn.[level] = scd.[level] AND stn.attribute = scd.[column]                
             WHERE scd.league_key = @league_key AND scd.page = 'team' AND scd.[level] = 'team' AND scd.ribbon = 'PITCHING'
             ORDER BY scd.[order] ASC
               FOR XML RAW('pitching_column'), TYPE
        ),
        (
            SELECT (CASE
                        WHEN category = 'league-average' THEN 'League Avg'
                        WHEN category = 'rank' THEN 'Team Rank'
                        ELSE @name
                   END) AS name,
                   [events-played], [innings-pitched], [pitching-hits], [runs-allowed], [earned-runs], [pitching-bases-on-balls],
                   [pitching-strikeouts], [wins], [losses], [saves], [games-complete], [shutouts], [whip], [era]
              FROM @pitchings WHERE ribbon = 'PITCHING'
             ORDER BY category ASC
               FOR XML RAW('pitching'), TYPE
        ),
        (
            SELECT ribbon, ribbon_node
              FROM @reference
               FOR XML RAW('reference'), TYPE
        )
        FOR XML RAW('root'), TYPE        
    END
    ELSE
    BEGIN
        DECLARE @battings TABLE
        (
            ribbon VARCHAR(100),
            category VARCHAR(100),
            [events-played] VARCHAR(100),
            [at-bats] VARCHAR(100),
            [runs-scored] VARCHAR(100),
            [hits] VARCHAR(100),
            [doubles] VARCHAR(100),
            [triples] VARCHAR(100),
            [home-runs] VARCHAR(100),
            [rbi] VARCHAR(100),
            [bases-on-balls] VARCHAR(100),
            [strikeouts] VARCHAR(100),
            [stolen-bases] VARCHAR(100),
            [stolen-bases-caught] VARCHAR(100),
            [average] VARCHAR(100),
            [on-base-percentage] VARCHAR(100),
            [slugging-percentage] VARCHAR(100),
            [on-base-plus-slugging-percentage] VARCHAR(100)            
        )
        INSERT INTO @stats (ribbon, category, [column], value)
        SELECT scd.ribbon, stss.category, scd.[column], stss.value 
          FROM SportsEditDB.dbo.SMG_Column_Details scd
         INNER JOIN SportsEditDB.dbo.SMG_Statistics stss
            ON stss.league_key = scd.league_key AND stss.[column] = scd.[column] AND stss.season_key = @seasonKey AND
               stss.sub_season_type = @subSeasonType AND (stss.team_key = @teamKey OR stss.team_key = @league_key) AND
               stss.category IN ('feed', 'league-average', 'rank') AND stss.player_key = 'team'
         WHERE scd.league_key = @league_key AND scd.page = 'team' AND scd.[level] = 'team' AND scd.ribbon = 'BATTING'
              
        INSERT INTO @battings
        SELECT p.ribbon, p.category, [events-played], [at-bats], [runs-scored], [hits], [doubles], [triples], [home-runs], [rbi],
               [bases-on-balls], [strikeouts], [stolen-bases], [stolen-bases-caught], [average], [on-base-percentage], [slugging-percentage],
               [on-base-plus-slugging-percentage]
          FROM (SELECT ribbon, category, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([events-played], [at-bats], [runs-scored], [hits], [doubles], [triples], [home-runs], [rbi],
                                                [bases-on-balls], [strikeouts], [stolen-bases], [stolen-bases-caught], [average],
                                                [on-base-percentage], [slugging-percentage], [on-base-plus-slugging-percentage])) AS p

        -- leaders
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT 'BATTING AVERAGE', [average] + ' AVG', ribbon, 'average'
          FROM @battings
         WHERE ribbon = 'BATTING' AND category = 'feed'
         
        UPDATE @leaders
           SET [rank] = (SELECT [average] FROM @battings WHERE ribbon = 'BATTING' AND category = 'rank')
         WHERE ribbon = 'BATTING AVERAGE'
         
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT 'RUNS SCORED', [runs-scored] + ' R', ribbon, 'runs-scored'
          FROM @battings
         WHERE ribbon = 'BATTING' AND category = 'feed'
         
        UPDATE @leaders
           SET [rank] = (SELECT [runs-scored] FROM @battings WHERE ribbon = 'BATTING' AND category = 'rank')
         WHERE ribbon = 'RUNS SCORED'
         
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT 'HOME RUNS', [home-runs] + ' HR', ribbon, 'home-runs'
          FROM @battings
         WHERE ribbon = 'BATTING' AND category = 'feed'
         
        UPDATE @leaders
           SET [rank] = (SELECT [home-runs] FROM @battings WHERE ribbon = 'BATTING' AND category = 'rank')
         WHERE ribbon = 'HOME RUNS'

        UPDATE l
           SET l.reference_sort = stn.sort
          FROM @leaders l
         INNER JOIN SportsEditDB.dbo.SMG_TSN_Nodes stn
            ON stn.sport = 'baseball' AND stn.[level] = 'team' AND stn.attribute = l.reference_column

        -- players
        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'BATTING AVERAGE' , player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'average' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC

        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'RUNS SCORED' , player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'runs-scored' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC

        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'HOME RUNS' , player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'home-runs' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC

            
        UPDATE p
	       SET p.name = LEFT(sp.first_name, 1) + '. ' + sp.last_name
	      FROM @players p
	     INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = p.player_key            
         
        -- reference
        INSERT INTO @reference (ribbon, ribbon_node)
        VALUES ('BATTING', 'batting')

		-- SDI formatting (may want to move to UX for better datatables sort capabilities in future
		UPDATE @battings
		   SET [average] = REPLACE(REPLACE(CAST(CAST([average] AS DECIMAL(6,3)) AS VARCHAR), '0.', '.'), '.000', ''),
			   [on-base-percentage] = REPLACE(REPLACE(CAST(CAST([on-base-percentage] AS DECIMAL(6,3)) AS VARCHAR), '0.', '.'), '.000', ''),
			   [slugging-percentage] = REPLACE(REPLACE(CAST(CAST([slugging-percentage] AS DECIMAL(6,3)) AS VARCHAR), '0.', '.'), '.000', ''),
			   [on-base-plus-slugging-percentage] = REPLACE(REPLACE(CAST(CAST([on-base-plus-slugging-percentage] AS DECIMAL(6,3)) AS VARCHAR), '0.', '.'), '.000', '')

        SELECT
        (
            SELECT 'BATTING TEAM RANKINGS' AS super_ribbon, @teamKey AS team_key, ribbon, @rgb AS rgb,
                   (CASE
                       WHEN RIGHT([rank], 1) = '1' AND RIGHT([rank], 2) <> '11' THEN [rank] + 'ST'
                       WHEN RIGHT([rank], 1) = '2' AND RIGHT([rank], 2) <> '12' THEN [rank] + 'ND'
                       WHEN RIGHT([rank], 1) = '3' AND RIGHT([rank], 2) <> '13' THEN [rank] + 'RD'
                       ELSE [rank] + 'TH'
                   END) AS [rank], value, reference_ribbon, reference_sort, reference_column,
                   (
                       SELECT name
                        FROM @players
                       WHERE sub_ribbon = l.ribbon
                         FOR XML RAW('player'), TYPE
                   )
              FROM @leaders l
               FOR XML RAW('leader'), TYPE
        ),
        (
            SELECT scd.ribbon, scd.sub_ribbon, scd.[column], scd.display, scd.tooltip, stn.[type], stn.[sort], scd.[order]
              FROM SportsEditDB.dbo.SMG_Column_Details scd
             INNER JOIN SportsEditDB.dbo.SMG_TSN_Nodes stn
                ON stn.sport = 'baseball' AND stn.[level] = scd.[level] AND stn.attribute = scd.[column]                
             WHERE scd.league_key = @league_key AND scd.page = 'team' AND scd.[level] = 'team' AND scd.ribbon = 'BATTING'
             ORDER BY scd.[order] ASC
               FOR XML RAW('batting_column'), TYPE
        ),
        (
            SELECT (CASE
                        WHEN category = 'league-average' THEN 'League Avg'
                        WHEN category = 'rank' THEN 'Team Rank'
                        ELSE @name
                   END) AS name,
                   [events-played], [at-bats], [runs-scored], [hits], [doubles], [triples], [home-runs], [rbi], [bases-on-balls], [strikeouts],
                   [stolen-bases], [stolen-bases-caught], [average], [on-base-percentage], [slugging-percentage], [on-base-plus-slugging-percentage]
              FROM @battings WHERE ribbon = 'BATTING'
             ORDER BY category ASC
               FOR XML RAW('batting'), TYPE
        ),
        (
            SELECT ribbon, ribbon_node
              FROM @reference
               FOR XML RAW('reference'), TYPE
        )
        FOR XML RAW('root'), TYPE        
    END
END

GO
