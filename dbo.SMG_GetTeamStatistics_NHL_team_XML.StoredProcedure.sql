USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamStatistics_NHL_team_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetTeamStatistics_NHL_team_XML]
   @teamKey       VARCHAR(100),
   @seasonKey     INT,
   @subSeasonType VARCHAR(100),
   @category      VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 09/12/2013
  -- Description: get NHL team team statistics
  -- Update: 01/08/2015 - John Lin - change team_key from league-average to l.nhl.com
  --         02/20/2015 - ikenticus - migrating SMG_Player/Team_Season_Statistics to SMG_Statistics
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @stats TABLE
    (
        ribbon   VARCHAR(100),
        category VARCHAR(100),
        [column] VARCHAR(100), 
        value    VARCHAR(100)
    )
    -- name
    DECLARE @name VARCHAR(100)
        
    SELECT @name = team_last
	  FROM dbo.SMG_Teams
	 WHERE league_key = 'l.nhl.com' AND season_key = @seasonKey AND team_key = @teamKey

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
    IF (@category = 'defense')
    BEGIN
        DECLARE @defenses TABLE
        (
            ribbon VARCHAR(100),
            category VARCHAR(100),
            [events-played] VARCHAR(100),
            [goals-regulation-allowed] VARCHAR(100),
            [goals-overtime-allowed] VARCHAR(100),
            [goals-shootout-allowed] VARCHAR(100),
            [goals-allowed] VARCHAR(100),
            [goals-allowed-per-game] VARCHAR(100),
            [shots-shootout-allowed] VARCHAR(100),
            [shots-allowed] VARCHAR(100),
            [shots-allowed-per-game] VARCHAR(100),
            [shutouts] VARCHAR(100),
            [hits] VARCHAR(100),
            [takeaways] VARCHAR(100),
            [turnover-ratio] VARCHAR(100)
        )
        
        INSERT INTO @stats (ribbon, category, [column], value)
        SELECT scd.ribbon, stss.category, scd.[column], stss.value 
          FROM SportsEditDB.dbo.SMG_Column_Details scd
         INNER JOIN SportsEditDB.dbo.SMG_Statistics stss
            ON stss.league_key = scd.league_key AND stss.[column] = scd.[column] AND stss.season_key = @seasonKey AND
               stss.sub_season_type = @subSeasonType AND (stss.team_key = @teamKey OR stss.team_key = 'l.nhl.com') AND
               stss.category IN ('feed', 'league-average', 'rank') AND stss.player_key = 'team'
         WHERE scd.league_key = 'l.nhl.com' AND scd.page = 'team' AND scd.[level] = 'team' AND scd.ribbon = 'DEFENSE'
              
        INSERT INTO @defenses                 
        SELECT p.ribbon, p.category, [events-played], [goals-regulation-allowed], [goals-overtime-allowed],
               [goals-shootout-allowed], [goals-allowed], [goals-allowed-per-game], [shots-shootout-allowed], [shots-allowed],
               [shots-allowed-per-game], [shutouts], [hits], [takeaways], [turnover-ratio]
          FROM (SELECT ribbon, category, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([events-played], [goals-regulation-allowed], [goals-overtime-allowed], [goals-shootout-allowed],
                                                [goals-allowed], [goals-allowed-per-game], [shots-shootout-allowed], [shots-allowed],
                                                [shots-allowed-per-game], [shutouts], [hits], [takeaways], [turnover-ratio])) AS p

        -- leaders
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT 'GOALS ALLOWED', [goals-allowed] + ' GA', ribbon, 'goals-allowed'
          FROM @defenses
         WHERE ribbon = 'DEFENSE' AND category = 'feed'
         
        UPDATE @leaders
           SET [rank] = (SELECT [goals-allowed] FROM @defenses WHERE ribbon = 'DEFENSE' AND category = 'rank')
         WHERE ribbon = 'GOALS ALLOWED'
         
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT 'SHOTS ALLOWED PER GAME', [shots-allowed-per-game] + ' SA/G', ribbon, 'shots-allowed-per-game'
          FROM @defenses
         WHERE ribbon = 'DEFENSE' AND category = 'feed'
         
        UPDATE @leaders
           SET [rank] = (SELECT [shots-allowed-per-game] FROM @defenses WHERE ribbon = 'DEFENSE' AND category = 'rank')
         WHERE ribbon = 'SHOTS ALLOWED PER GAME'
         
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT 'SHUTOUTS', [shutouts] + ' SHO', ribbon, 'shutouts'
          FROM @defenses
         WHERE ribbon = 'DEFENSE' AND category = 'feed'
         
        UPDATE @leaders
           SET [rank] = (SELECT [shutouts] FROM @defenses WHERE ribbon = 'DEFENSE' AND category = 'rank')
         WHERE ribbon = 'SHUTOUTS'

        UPDATE l
           SET l.reference_sort = stn.sort
          FROM @leaders l
         INNER JOIN SportsEditDB.dbo.SMG_TSN_Nodes stn
            ON stn.sport = 'hockey' AND stn.[level] = 'team' AND stn.attribute = l.reference_column

        -- players
        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'GOALS ALLOWED', player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = 'l.nhl.com' AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'goals-allowed' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC

        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'SHOTS ALLOWED PER GAME', player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = 'l.nhl.com' AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'shots-allowed-per-game' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC

        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'SHUTOUTS', player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = 'l.nhl.com' AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'shutouts' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC


        UPDATE p
	       SET p.name = LEFT(sp.first_name, 1) + '. ' + sp.last_name
	      FROM @players p
	     INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = p.player_key            
         
        -- reference
        INSERT INTO @reference (ribbon, ribbon_node)
        VALUES ('DEFENSE', 'defense')

        SELECT
        (
            SELECT 'DEFENSIVE TEAM RANKINGS' AS super_ribbon, @teamKey AS team_key, ribbon,
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
                ON stn.sport = 'hockey' AND stn.[level] = scd.[level] AND stn.attribute = scd.[column]                
             WHERE scd.league_key = 'l.nhl.com' AND scd.page = 'team' AND scd.[level] = 'team' AND scd.ribbon = 'DEFENSE'
             ORDER BY scd.[order] ASC
               FOR XML RAW('defense_column'), TYPE
        ),
        (
            SELECT (CASE
                        WHEN category = 'league-average' THEN 'League Avg'
                        WHEN category = 'rank' THEN 'Team Rank'
                        ELSE @name
                   END) AS name,
                   [events-played], [goals-regulation-allowed], [goals-overtime-allowed], [goals-shootout-allowed], [goals-allowed],
                   [goals-allowed-per-game], [shots-shootout-allowed], [shots-allowed], [shots-allowed-per-game], [shutouts], [hits],
                   [takeaways], [turnover-ratio]
              FROM @defenses WHERE ribbon = 'DEFENSE'
             ORDER BY category ASC
               FOR XML RAW('defense'), TYPE
        ),
        (
            SELECT ribbon, ribbon_node
              FROM @reference
               FOR XML RAW('reference'), TYPE
        )
        FOR XML RAW('root'), TYPE        
    END
    ELSE IF (@category = 'special-teams')
    BEGIN
        DECLARE @specials TABLE
        (
            ribbon VARCHAR(100),
            category VARCHAR(100),
            [events-played] VARCHAR(100),
            [goals-power-play] VARCHAR(100),
            [shots-power-play] VARCHAR(100),
            [power-play-amount] VARCHAR(100),
            [power-play-percentage] VARCHAR(100),
            [goals-short-handed-allowed] VARCHAR(100),
            [goals-power-play-allowed] VARCHAR(100),
            [penalty-killing-amount] VARCHAR(100),
            [penalty-killing-percentage] VARCHAR(100),
            [goals-short-handed] VARCHAR(100),
            [penalty-minutes] VARCHAR(100),
            [penalty-minutes-per-game] VARCHAR(100)
        )
        INSERT INTO @stats (ribbon, category, [column], value)
        SELECT scd.ribbon, stss.category, scd.[column], stss.value 
          FROM SportsEditDB.dbo.SMG_Column_Details scd
         INNER JOIN SportsEditDB.dbo.SMG_Statistics stss
            ON stss.league_key = scd.league_key AND stss.[column] = scd.[column] AND stss.season_key = @seasonKey AND
               stss.sub_season_type = @subSeasonType AND (stss.team_key = @teamKey OR stss.team_key = 'l.nhl.com') AND
               stss.category IN ('feed', 'league-average', 'rank') AND stss.player_key = 'team'
         WHERE scd.league_key = 'l.nhl.com' AND scd.page = 'team' AND scd.[level] = 'team' AND scd.ribbon = 'SPECIAL TEAMS'
              
        INSERT INTO @specials                 
        SELECT p.ribbon, p.category, [events-played], [goals-power-play], [shots-power-play], [power-play-amount],
               [power-play-percentage], [goals-short-handed-allowed], [goals-power-play-allowed], [penalty-killing-amount],
               [penalty-killing-percentage], [goals-short-handed], [penalty-minutes], [penalty-minutes-per-game]
          FROM (SELECT ribbon, category, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([events-played], [goals-power-play], [shots-power-play], [power-play-amount], [power-play-percentage],
                                                [goals-short-handed-allowed], [goals-power-play-allowed], [penalty-killing-amount],
                                                [penalty-killing-percentage], [goals-short-handed], [penalty-minutes], [penalty-minutes-per-game])) AS p

        -- leaders
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT 'POWER PLAY %', [power-play-percentage] + ' PP%', ribbon, 'power-play-percentage'
          FROM @specials
         WHERE ribbon = 'SPECIAL TEAMS' AND category = 'feed'
         
        UPDATE @leaders
           SET [rank] = (SELECT [power-play-percentage] FROM @specials WHERE ribbon = 'SPECIAL TEAMS' AND category = 'rank')
         WHERE ribbon = 'POWER PLAY %'
         
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT 'PENALTY KILL %', [penalty-killing-percentage] + ' PK%', ribbon, 'penalty-killing-percentage'
          FROM @specials
         WHERE ribbon = 'SPECIAL TEAMS' AND category = 'feed'
         
        UPDATE @leaders
           SET [rank] = (SELECT [penalty-killing-percentage] FROM @specials WHERE ribbon = 'SPECIAL TEAMS' AND category = 'rank')
         WHERE ribbon = 'PENALTY KILL %'
         
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT 'PENALTY MINUTES', [penalty-minutes] + ' PIM', ribbon, 'penalty-minutes'
          FROM @specials
         WHERE ribbon = 'SPECIAL TEAMS' AND category = 'feed'
         
        UPDATE @leaders
           SET [rank] = (SELECT [penalty-minutes] FROM @specials WHERE ribbon = 'SPECIAL TEAMS' AND category = 'rank')
         WHERE ribbon = 'PENALTY MINUTES'

        UPDATE l
           SET l.reference_sort = stn.sort
          FROM @leaders l
         INNER JOIN SportsEditDB.dbo.SMG_TSN_Nodes stn
            ON stn.sport = 'hockey' AND stn.[level] = 'team' AND stn.attribute = l.reference_column 

        -- players
        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'POWER PLAY %', player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = 'l.nhl.com' AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'goals-power-play' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC

        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'PENALTY KILL %', player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = 'l.nhl.com' AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'penalty-killing-percentage' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC

        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'PENALTY MINUTES', player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = 'l.nhl.com' AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'penalty-minutes' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC


        UPDATE p
	       SET p.name = LEFT(sp.first_name, 1) + '. ' + sp.last_name
	      FROM @players p
	     INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = p.player_key            
         
        -- reference
        INSERT INTO @reference (ribbon, ribbon_node)
        VALUES ('SPECIAL TEAMS', 'special')

        SELECT
        (
            SELECT 'SPECIAL TEAMS TEAM RANKINGS' AS super_ribbon, @teamKey AS team_key, ribbon,
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
                ON stn.sport = 'hockey' AND stn.[level] = scd.[level] AND stn.attribute = scd.[column]                
             WHERE scd.league_key = 'l.nhl.com' AND scd.page = 'team' AND scd.[level] = 'team' AND scd.ribbon = 'SPECIAL TEAMS'
             ORDER BY scd.[order] ASC
               FOR XML RAW('special_column'), TYPE
        ),
        (
            SELECT (CASE
                        WHEN category = 'league-average' THEN 'League Avg'
                        WHEN category = 'rank' THEN 'Team Rank'
                        ELSE @name
                   END) AS name,
                   [events-played], [goals-power-play], [shots-power-play], [power-play-amount], [power-play-percentage], [goals-short-handed-allowed],
                   [goals-power-play-allowed], [penalty-killing-amount], [penalty-killing-percentage], [goals-short-handed], [penalty-minutes],
                   [penalty-minutes-per-game]
              FROM @specials WHERE ribbon = 'SPECIAL TEAMS'
             ORDER BY category ASC
               FOR XML RAW('special'), TYPE
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
        DECLARE @offenses TABLE
        (
            ribbon VARCHAR(100),
            category VARCHAR(100),
            [events-played] VARCHAR(100),
            [goals] VARCHAR(100),
            [goals-overtime] VARCHAR(100),
            [goals-shootout] VARCHAR(100),
            [goals-per-game] VARCHAR(100),
            [shots] VARCHAR(100),
            [shots-per-game] VARCHAR(100),
            [faceoff-wins] VARCHAR(100),
            [faceoff-losses] VARCHAR(100),
            [faceoff-win-percentage] VARCHAR(100)
        )
        INSERT INTO @stats (ribbon, category, [column], value)
        SELECT scd.ribbon, stss.category, scd.[column], stss.value 
          FROM SportsEditDB.dbo.SMG_Column_Details scd
         INNER JOIN SportsEditDB.dbo.SMG_Statistics stss
            ON stss.league_key = scd.league_key AND stss.[column] = scd.[column] AND stss.season_key = @seasonKey AND
               stss.sub_season_type = @subSeasonType AND (stss.team_key = @teamKey OR stss.team_key = 'l.nhl.com') AND
               stss.category IN ('feed', 'league-average', 'rank') AND stss.player_key = 'team'
         WHERE scd.league_key = 'l.nhl.com' AND scd.page = 'team' AND scd.[level] = 'team' AND scd.ribbon = 'OFFENSE'
              
        INSERT INTO @offenses
        SELECT p.ribbon, p.category, [events-played], [goals], [goals-overtime], [goals-shootout], [goals-per-game], [shots],
               [shots-per-game], [faceoff-wins], [faceoff-losses], [faceoff-win-percentage]
          FROM (SELECT ribbon, category, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([events-played], [goals], [goals-overtime], [goals-shootout], [goals-per-game], [shots],
                                                [shots-per-game], [faceoff-wins], [faceoff-losses], [faceoff-win-percentage])) AS p

        -- leaders
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT 'GOALS', [goals] + ' G', ribbon, 'goals'
          FROM @offenses
         WHERE ribbon = 'OFFENSE' AND category = 'feed'
         
        UPDATE @leaders
           SET [rank] = (SELECT [goals] FROM @offenses WHERE ribbon = 'OFFENSE' AND category = 'rank')
         WHERE ribbon = 'GOALS'
         
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT 'GOALS PER GAME', [goals-per-game] + ' G/G', ribbon, 'goals-per-game'
          FROM @offenses
         WHERE ribbon = 'OFFENSE' AND category = 'feed'
         
        UPDATE @leaders
           SET [rank] = (SELECT [goals-per-game] FROM @offenses WHERE ribbon = 'OFFENSE' AND category = 'rank')
         WHERE ribbon = 'GOALS PER GAME'
         
        INSERT INTO @leaders (ribbon, value, reference_ribbon, reference_column)
        SELECT 'SHOTS PER GAME', [shots-per-game] + ' S/G', ribbon, 'shots-per-game'
          FROM @offenses
         WHERE ribbon = 'OFFENSE' AND category = 'feed'
         
        UPDATE @leaders
           SET [rank] = (SELECT [shots-per-game] FROM @offenses WHERE ribbon = 'OFFENSE' AND category = 'rank')
         WHERE ribbon = 'SHOTS PER GAME'

        UPDATE l
           SET l.reference_sort = stn.sort
          FROM @leaders l
         INNER JOIN SportsEditDB.dbo.SMG_TSN_Nodes stn
            ON stn.sport = 'hockey' AND stn.[level] = 'team' AND stn.attribute = l.reference_column

        -- players
        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'GOALS', player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = 'l.nhl.com' AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'goals' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC

        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'GOALS PER GAME', player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = 'l.nhl.com' AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'goals-per-game' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC

        INSERT INTO @players (sub_ribbon, player_key)
        SELECT TOP 4 'SHOTS PER GAME', player_key
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = 'l.nhl.com' AND season_key = @seasonKey AND sub_season_type = @subSeasonType
           AND team_key = @teamKey AND [column] = 'shots-per-game' AND player_key <> 'team'
         ORDER BY CONVERT(FLOAT, [value]) DESC

            
        UPDATE p
	       SET p.name = LEFT(sp.first_name, 1) + '. ' + sp.last_name
	      FROM @players p
	     INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = p.player_key            
         
        -- reference
        INSERT INTO @reference (ribbon, ribbon_node)
        VALUES ('OFFENSE', 'offense')

        SELECT
        (
            SELECT 'OFFENSIVE TEAM RANKINGS' AS super_ribbon, @teamKey AS team_key, ribbon,
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
                ON stn.sport = 'hockey' AND stn.[level] = scd.[level] AND stn.attribute = scd.[column]                
             WHERE scd.league_key = 'l.nhl.com' AND scd.page = 'team' AND scd.[level] = 'team' AND scd.ribbon = 'OFFENSE'
             ORDER BY scd.[order] ASC
               FOR XML RAW('offense_column'), TYPE
        ),
        (
            SELECT (CASE
                        WHEN category = 'league-average' THEN 'League Avg'
                        WHEN category = 'rank' THEN 'Team Rank'
                        ELSE @name
                   END) AS name,
                   [events-played], [goals], [goals-overtime], [goals-shootout], [goals-per-game], [shots], [shots-per-game], [faceoff-wins],
                   [faceoff-losses], [faceoff-win-percentage]
              FROM @offenses WHERE ribbon = 'OFFENSE'
             ORDER BY category ASC
               FOR XML RAW('offense'), TYPE
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
