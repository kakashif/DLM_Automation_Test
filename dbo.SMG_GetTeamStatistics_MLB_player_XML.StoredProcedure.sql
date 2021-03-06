USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetTeamStatistics_MLB_player_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetTeamStatistics_MLB_player_XML]
   @teamKey       VARCHAR(100),
   @seasonKey     INT,
   @subSeasonType VARCHAR(100),
   @category      VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 08/21/2013
  -- Description: get MLB player statistics
  -- Update: 06/23/2014 - John Lin - use SMG_Teams for abbr
  --         02/20/2015 - ikenticus - migrating SMG_Player_Season_Statistics to SMG_Statistics
  --         04/08/2015 - John Lin - new head shot logic
  --         06/16/2015 - John Lin - STATS migration
  --         07/27/2015 - John Lin - adding roster phase_status to remove traded players from results
  --         08/31/2015 - ikenticus - SDI migration
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('mlb')

    DECLARE @stats TABLE
    (
        player_key VARCHAR(100),
        ribbon     VARCHAR(100),
        [column]   VARCHAR(100), 
        value      VARCHAR(100)
    )
    DECLARE @players TABLE
    (
        player_key VARCHAR(100),
        ribbon VARCHAR(100)
    )
    DECLARE @leaders TABLE
    (
        player_key       VARCHAR(100),
        name             VARCHAR(100),
        uniform_number   VARCHAR(100),
        position_regular VARCHAR(100),
        ribbon           VARCHAR(100),
        value            VARCHAR(100),
        reference_ribbon   VARCHAR(100),
        reference_column   VARCHAR(100),
        reference_sort     VARCHAR(100),
        head_shot         VARCHAR(100)        
    )
    DECLARE @reference TABLE
    (
        ribbon      VARCHAR(100),
        ribbon_node VARCHAR(100),
        [column]    VARCHAR(100),
        display     VARCHAR(100),
        [sort]      VARCHAR(100) 
    )    
    DECLARE @abbr VARCHAR(100)
    DECLARE @rgb VARCHAR(100)
    
    SELECT @abbr = team_abbreviation, @rgb = rgb
      FROM dbo.SMG_Teams
     WHERE season_key = @seasonKey AND team_key = @teamKey

    IF (@category = 'pitching')
    BEGIN
        DECLARE @pitchings TABLE
        (
            player_key VARCHAR(100),
            ribbon VARCHAR(100),
            pitcher_games_played VARCHAR(100),
            [events-played] VARCHAR(100),
            [events-started] VARCHAR(100),
            [innings-pitched] VARCHAR(100),
            [pitching-hits] VARCHAR(100),
            [runs-allowed] VARCHAR(100),
            [earned-runs] VARCHAR(100),
            [pitching-bases-on-balls] VARCHAR(100),
            [pitching-strikeouts] VARCHAR(100),
            [strikeouts-per-9-innings] VARCHAR(100),                        
            [wins] VARCHAR(100),
            [losses] VARCHAR(100),
            [saves] VARCHAR(100),
            [saves-blown] VARCHAR(100),
            [whip] VARCHAR(100),
            [era] VARCHAR(100),
            [era-qualify] VARCHAR(100),
            -- reference NULL
            phase_status VARCHAR(100),
            position_regular VARCHAR(100),
            name VARCHAR(100)            
        )

        -- PITCHING
        INSERT INTO @players (player_key, ribbon)
        SELECT player_key, 'PITCHING'
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND season_key = @seasonKey AND player_key <> 'team' AND
               sub_season_type = @subSeasonType AND team_key = @teamKey AND [column] = 'innings-pitched' AND value <> '0'

        INSERT INTO @stats (player_key, ribbon, [column], value)
        SELECT p.player_key, p.ribbon, scd.[column], spss.value 
          FROM @players p
         INNER JOIN SportsEditDB.dbo.SMG_Column_Details scd
            ON scd.ribbon = p.ribbon AND scd.page = 'team' AND scd.[level] = 'player'
         INNER JOIN SportsEditDB.dbo.SMG_Statistics spss
            ON spss.league_key = scd.league_key AND spss.[column] = scd.[column] AND spss.player_key = p.player_key AND
               spss.season_key = @seasonKey AND spss.sub_season_type = @subSeasonType AND spss.team_key = @teamKey

        INSERT INTO @stats (player_key, ribbon, [column], value)
        SELECT p.player_key, p.ribbon, 'era-qualify', spss.value 
          FROM @players p
         INNER JOIN SportsEditDB.dbo.SMG_Statistics spss
            ON spss.league_key = @league_key AND spss.[column] = 'era-qualify' AND spss.player_key = p.player_key AND
               spss.season_key = @seasonKey AND spss.sub_season_type = @subSeasonType AND spss.team_key = @teamKey

              
        INSERT INTO @pitchings (player_key, ribbon, [events-played], [events-started], [innings-pitched], [pitching-hits], [runs-allowed],
                                [earned-runs], [pitching-bases-on-balls], [pitching-strikeouts], [strikeouts-per-9-innings], [wins], [losses], [saves],
                                [saves-blown], [whip], [era], [era-qualify], [pitcher_games_played])
        SELECT p.player_key, p.ribbon, [events-played], ISNULL([events-started], 0), [innings-pitched], ISNULL([pitching-hits], 0), ISNULL([runs-allowed], 0),
               ISNULL([earned-runs], 0), ISNULL([pitching-bases-on-balls], 0), ISNULL([pitching-strikeouts], 0), ISNULL([strikeouts-per-9-innings], 0), ISNULL([wins], 0), ISNULL([losses], 0), ISNULL([saves], 0),
               ISNULL([saves-blown], 0), [whip], ISNULL([era], '0.00'), [era-qualify], [pitcher_games_played]
          FROM (SELECT player_key, ribbon, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([events-played], [events-started], [innings-pitched], [pitching-hits], [runs-allowed],
                                                [earned-runs], [pitching-bases-on-balls], [pitching-strikeouts], [strikeouts-per-9-innings],
                                                [wins], [losses], [saves], [saves-blown], [whip], [era], [era-qualify], [pitcher_games_played])) AS p

		UPDATE @pitchings
		   SET [events-played] = pitcher_games_played
		 WHERE pitcher_games_played IS NOT NULL

        DELETE @pitchings
         WHERE [events-played] IS NULL OR [events-played] = '' OR [events-played] = '0'


        -- position_regular, name
	    UPDATE p
	       SET p.position_regular = sr.position_regular, p.phase_status = sr.phase_status
	      FROM @pitchings p
	     INNER JOIN dbo.SMG_Rosters sr
            ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.team_key = @teamKey AND sr.player_key = p.player_key

		DELETE @pitchings
		 WHERE phase_status <> 'active'

	    UPDATE b
	       SET b.name = sp.first_name + ' ' + sp.last_name
	      FROM @pitchings b
	     INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = b.player_key


        -- leaders
        INSERT INTO @leaders (ribbon, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'WINS', player_key, name, position_regular, [wins] + ' W', ribbon, 'wins'
          FROM @pitchings
         ORDER BY CONVERT(FLOAT, [wins]) DESC

        INSERT INTO @leaders (ribbon, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'EARNED RUN AVERAGE', player_key, name, position_regular, CAST(CAST(era AS DECIMAL(5,2)) AS VARCHAR) + ' ERA', ribbon, 'era'
          FROM @pitchings
         WHERE [era-qualify] = '1'
         ORDER BY CONVERT(FLOAT, [era]) ASC

        INSERT INTO @leaders (ribbon, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'SAVES', player_key, name, position_regular, [saves] + ' SV', ribbon, 'saves'
          FROM @pitchings
         ORDER BY CONVERT(FLOAT, [saves]) DESC

        UPDATE l
           SET l.uniform_number = sr.uniform_number
          FROM @leaders l
         INNER JOIN dbo.SMG_Rosters sr
            ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.team_key = @teamKey AND sr.player_key = l.player_key

        UPDATE l
           SET l.reference_sort = stn.sort
          FROM @leaders l
         INNER JOIN SportsEditDB.dbo.SMG_TSN_Nodes stn
            ON stn.sport = 'baseball' AND stn.[level] = 'player' AND stn.attribute = l.reference_column

        UPDATE l
           SET l.head_shot = sr.head_shot + '120x120/' + sr.[filename]
          FROM @leaders l
         INNER JOIN dbo.SMG_Rosters sr
            ON sr.team_key = @teamKey AND sr.player_key = l.player_key AND sr.league_key = @league_key AND sr.season_key = @seasonKey AND
               sr.head_shot IS NOT NULL AND sr.[filename] IS NOT NULL

        -- reference
        INSERT INTO @reference (ribbon, ribbon_node, [column])
        VALUES ('PITCHING', 'pitching', 'era')

        UPDATE r
           SET r.display = scd.display, r.[sort] = stn.[sort]
          FROM @reference r
         INNER JOIN SportsEditDB.dbo.SMG_Column_Details scd
            ON scd.[column] = r.[column]
         INNER JOIN SportsEditDB.dbo.SMG_TSN_Nodes stn
            ON stn.sport = 'baseball' AND stn.[level] = scd.[level] AND stn.attribute = scd.[column] AND 
               scd.league_key = @league_key AND scd.page = 'team' AND scd.[level] = 'player' AND scd.ribbon = r.ribbon

		-- SDI formatting (may want to move to UX for better datatables sort capabilities in future
		UPDATE @pitchings
		   SET whip = CAST(CAST(whip AS DECIMAL(5,2)) AS VARCHAR),
			   era = CAST(CAST(era AS DECIMAL(5,2)) AS VARCHAR)

        SELECT
        (
            SELECT 'PITCHING TEAM LEADERS' AS super_ribbon, @teamKey AS team_key, @abbr AS abbr, @rgb AS team_rgb, ribbon, name, uniform_number,
                   position_regular, value, head_shot, reference_ribbon, reference_sort, reference_column
              FROM @leaders
               FOR XML RAW('leader'), TYPE
        ),
        (
            SELECT scd.ribbon, scd.sub_ribbon, scd.[column], scd.display, scd.tooltip, stn.[type], stn.[sort], scd.[order]
              FROM SportsEditDB.dbo.SMG_Column_Details scd
             INNER JOIN SportsEditDB.dbo.SMG_TSN_Nodes stn
                ON stn.sport = 'baseball' AND stn.[level] = scd.[level] AND stn.attribute = scd.[column]                
             WHERE scd.league_key = @league_key AND scd.page = 'team' AND scd.[level] = 'player' AND scd.ribbon = 'PITCHING'
             ORDER BY scd.[order] ASC
               FOR XML RAW('pitching_column'), TYPE
        ),
        (
            SELECT (CASE 
                       WHEN position_regular IS NULL THEN name
                       ELSE name + ', ' + position_regular
                   END) AS name,
                   [events-played], [events-started], [innings-pitched], [pitching-hits], [runs-allowed], [earned-runs], [pitching-bases-on-balls],
                   [pitching-strikeouts], [strikeouts-per-9-innings], [wins], [losses], [saves], [saves-blown], [whip], [era]
              FROM @pitchings WHERE ribbon = 'PITCHING'
             ORDER BY CONVERT(FLOAT, [era]) ASC
                   FOR XML RAW('pitching'), TYPE
        ),
        (
            SELECT ribbon, ribbon_node, display, [sort]
              FROM @reference
               FOR XML RAW('reference'), TYPE
        )
        FOR XML RAW('root'), TYPE
    END
    ELSE
    BEGIN
        DECLARE @battings TABLE
        (
            player_key VARCHAR(100),
            ribbon VARCHAR(100),
            [events-played] VARCHAR(100),
            [at-bats] VARCHAR(100),
            [runs-scored] VARCHAR(100),
            [hits] VARCHAR(100),
            [doubles] VARCHAR(100),
            [triples] VARCHAR(100),
            [home-runs] VARCHAR(100),
            [rbi] VARCHAR(100),
            [total-bases] VARCHAR(100),
            [bases-on-balls] VARCHAR(100),
            [strikeouts] VARCHAR(100),            
            [stolen-bases] VARCHAR(100),
            [stolen-bases-caught] VARCHAR(100),
            [average] VARCHAR(100),
            [average-qualify] VARCHAR(100),
            [on-base-percentage] VARCHAR(100),
            [on-base-percentage-qualify] VARCHAR(100),
            [slugging-percentage] VARCHAR(100),
            [slugging-percentage-qualify] VARCHAR(100),
            [on-base-plus-slugging-percentage] VARCHAR(100),
            -- reference NULL
            phase_status VARCHAR(100),
            position_regular VARCHAR(100),
            name VARCHAR(100)
        )

        -- BATTING
        INSERT INTO @players (player_key, ribbon)
        SELECT player_key, 'BATTING'
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND season_key = @seasonKey AND player_key <> 'team' AND
               sub_season_type = @subSeasonType AND team_key = @teamKey AND [column] = 'at-bats' AND value <> '0'

        INSERT INTO @stats (player_key, ribbon, [column], value)
        SELECT p.player_key, p.ribbon, scd.[column], spss.value 
          FROM @players p
         INNER JOIN SportsEditDB.dbo.SMG_Column_Details scd
            ON scd.ribbon = p.ribbon AND scd.page = 'team' AND scd.[level] = 'player'
         INNER JOIN SportsEditDB.dbo.SMG_Statistics spss
            ON spss.league_key = scd.league_key AND spss.[column] = scd.[column] AND spss.player_key = p.player_key AND
               spss.season_key = @seasonKey AND spss.sub_season_type = @subSeasonType AND spss.team_key = @teamKey

        INSERT INTO @stats (player_key, ribbon, [column], value)
        SELECT p.player_key, p.ribbon, 'average-qualify', spss.value 
          FROM @players p
         INNER JOIN SportsEditDB.dbo.SMG_Statistics spss
            ON spss.league_key = @league_key AND spss.[column] = 'average-qualify' AND spss.player_key = p.player_key AND
               spss.season_key = @seasonKey AND spss.sub_season_type = @subSeasonType AND spss.team_key = @teamKey

        INSERT INTO @stats (player_key, ribbon, [column], value)
        SELECT p.player_key, p.ribbon, 'on-base-percentage-qualify', spss.value 
          FROM @players p
         INNER JOIN SportsEditDB.dbo.SMG_Statistics spss
            ON spss.league_key = @league_key AND spss.[column] = 'on-base-percentage-qualify' AND spss.player_key = p.player_key AND
               spss.season_key = @seasonKey AND spss.sub_season_type = @subSeasonType AND spss.team_key = @teamKey

        INSERT INTO @stats (player_key, ribbon, [column], value)
        SELECT p.player_key, p.ribbon, 'slugging-percentage-qualify', spss.value 
          FROM @players p
         INNER JOIN SportsEditDB.dbo.SMG_Statistics spss
            ON spss.league_key = @league_key AND spss.[column] = 'slugging-percentage-qualify' AND spss.player_key = p.player_key AND
               spss.season_key = @seasonKey AND spss.sub_season_type = @subSeasonType AND spss.team_key = @teamKey

              
        INSERT INTO @battings (player_key, ribbon, [events-played], [at-bats], [runs-scored], [hits], [doubles], [triples], [home-runs],
                               [rbi], [total-bases], [bases-on-balls], [strikeouts], [stolen-bases], [stolen-bases-caught], [average], [average-qualify],
                               [on-base-percentage], [on-base-percentage-qualify], [slugging-percentage], [slugging-percentage-qualify], [on-base-plus-slugging-percentage])
        SELECT p.player_key, p.ribbon, [events-played], ISNULL([at-bats], 0), ISNULL([runs-scored], 0), ISNULL([hits], 0), ISNULL([doubles], 0), ISNULL([triples], 0), ISNULL([home-runs], 0),
                               ISNULL([rbi], 0), ISNULL([total-bases], 0), ISNULL([bases-on-balls], 0), ISNULL([strikeouts], 0), ISNULL([stolen-bases], 0), ISNULL([stolen-bases-caught], 0), ISNULL([average], '.000'), [average-qualify],
               [on-base-percentage], [on-base-percentage-qualify], [slugging-percentage], [slugging-percentage-qualify], [on-base-plus-slugging-percentage]
          FROM (SELECT player_key, ribbon, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([events-played], [at-bats], [runs-scored], [hits], [doubles], [triples], [home-runs],
                                                [rbi], [total-bases], [bases-on-balls], [strikeouts], [stolen-bases], [stolen-bases-caught], [average], [average-qualify],
                                                [on-base-percentage], [on-base-percentage-qualify], [slugging-percentage], [slugging-percentage-qualify], [on-base-plus-slugging-percentage])) AS p

        DELETE @battings
         WHERE [events-played] IS NULL OR [events-played] = '' OR [events-played] = '0'


        -- position_regular, name
	    UPDATE b
	       SET b.position_regular = sr.position_regular, phase_status = sr.phase_status
	      FROM @battings b
	     INNER JOIN dbo.SMG_Rosters sr
            ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.team_key = @teamKey AND sr.player_key = b.player_key

		DELETE @battings
		 WHERE phase_status <> 'active'

	    UPDATE b
	       SET b.name = sp.first_name + ' ' + sp.last_name
	      FROM @battings b
	     INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = b.player_key


        -- leaders
        INSERT INTO @leaders (ribbon, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'BATTING AVERAGE', player_key, name, position_regular, REPLACE(CAST(CAST([average] AS DECIMAL(6,3)) AS VARCHAR), '0.', '.') + ' AVG', ribbon, 'average'
          FROM @battings
         WHERE [average-qualify] = '1'
         ORDER BY CONVERT(FLOAT, [average]) DESC

        INSERT INTO @leaders (ribbon, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'HOME RUNS', player_key, name, position_regular, [home-runs] + ' HR', ribbon, 'home-runs'
          FROM @battings
         ORDER BY CONVERT(FLOAT, [home-runs]) DESC

        INSERT INTO @leaders (ribbon, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'RUNS BATTED IN', player_key, name, position_regular, [rbi] + ' RBI', ribbon, 'rbi'
          FROM @battings
         ORDER BY CONVERT(FLOAT, [rbi]) DESC

        UPDATE l
           SET l.uniform_number = sr.uniform_number
          FROM @leaders l
         INNER JOIN dbo.SMG_Rosters sr
            ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.team_key = @teamKey AND sr.player_key = l.player_key

        UPDATE l
           SET l.reference_sort = stn.sort
          FROM @leaders l
         INNER JOIN SportsEditDB.dbo.SMG_TSN_Nodes stn
            ON stn.sport = 'baseball' AND stn.[level] = 'player' AND stn.attribute = l.reference_column

        UPDATE l
           SET l.head_shot = sr.head_shot + '120x120/' + sr.[filename]
          FROM @leaders l
         INNER JOIN dbo.SMG_Rosters sr
            ON sr.team_key = @teamKey AND sr.player_key = l.player_key AND sr.league_key = @league_key AND sr.season_key = @seasonKey AND
               sr.head_shot IS NOT NULL AND sr.[filename] IS NOT NULL

		-- SDI formatting (may want to move to UX for better datatables sort capabilities in future
		UPDATE @battings
		   SET [average] = REPLACE(CAST(CAST([average] AS DECIMAL(6,3)) AS VARCHAR), '0.', '.'),
			   [on-base-percentage] = REPLACE(CAST(CAST([on-base-percentage] AS DECIMAL(6,3)) AS VARCHAR), '0.', '.'),
			   [slugging-percentage] = REPLACE(CAST(CAST([slugging-percentage] AS DECIMAL(6,3)) AS VARCHAR), '0.', '.'),
			   [on-base-plus-slugging-percentage] = REPLACE(CAST(CAST([on-base-plus-slugging-percentage] AS DECIMAL(6,3)) AS VARCHAR), '0.', '.')

        -- reference
        INSERT INTO @reference (ribbon, ribbon_node, [column])
        VALUES ('BATTING', 'batting', 'average')

        UPDATE d
           SET d.display = scd.display, d.[sort] = stn.[sort]
          FROM @reference d
         INNER JOIN SportsEditDB.dbo.SMG_Column_Details scd
            ON scd.[column] = d.[column]
         INNER JOIN SportsEditDB.dbo.SMG_TSN_Nodes stn
            ON stn.sport = 'baseball' AND stn.[level] = scd.[level] AND stn.attribute = scd.[column] AND 
               scd.league_key = @league_key AND scd.page = 'team' AND scd.[level] = 'player' AND scd.ribbon = d.ribbon

        SELECT
        (
            SELECT 'BATTING TEAM LEADERS' AS super_ribbon, @teamKey AS team_key, @abbr AS abbr, @rgb AS team_rgb, ribbon, name, uniform_number,
                   position_regular, value, head_shot, reference_ribbon, reference_sort, reference_column
              FROM @leaders
               FOR XML RAW('leader'), TYPE
        ),
        (
            SELECT scd.ribbon, scd.sub_ribbon, scd.[column], scd.display, scd.tooltip, stn.[type], stn.[sort], scd.[order]
              FROM SportsEditDB.dbo.SMG_Column_Details scd
             INNER JOIN SportsEditDB.dbo.SMG_TSN_Nodes stn
                ON stn.sport = 'baseball' AND stn.[level] = scd.[level] AND stn.attribute = scd.[column]                
             WHERE scd.league_key = @league_key AND scd.page = 'team' AND scd.[level] = 'player' AND scd.ribbon = 'BATTING'
             ORDER BY scd.[order] ASC
               FOR XML RAW('batting_column'), TYPE
        ),
        (
            SELECT (CASE 
                       WHEN position_regular IS NULL THEN name
                       ELSE name + ', ' + position_regular
                   END) AS name,
                   [events-played], [at-bats], [runs-scored], [hits], [doubles], [triples], [home-runs], [rbi], [total-bases],
                   [bases-on-balls], [strikeouts], [stolen-bases], [stolen-bases-caught], [average], [on-base-percentage],
                   [slugging-percentage], [on-base-plus-slugging-percentage]
              FROM @battings WHERE ribbon = 'BATTING'
             ORDER BY CONVERT(FLOAT, [average]) DESC
                   FOR XML RAW('batting'), TYPE
        ),
        (
            SELECT ribbon, ribbon_node, display, [sort]
              FROM @reference
               FOR XML RAW('reference'), TYPE
        )
        FOR XML RAW('root'), TYPE
    END
END

GO
