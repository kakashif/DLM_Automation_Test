USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetStatistics_MLB_player_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetStatistics_MLB_player_XML]
   @seasonKey     INT,
   @subSeasonType VARCHAR(100),
   @affiliation   VARCHAR(100),
   @category      VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 08/21/2013
  -- Description: get MLB player statistics
  -- Update: 10/21/2013 - John Lin - use team slug
  --         02/20/2015 - ikenticus - migrating SMG_Player_Season_Statistics to SMG_Statistics
  --         04/08/2015 - John Lin - new head shot logic
  --         06/05/2015 - ikenticus - replacing hard-coded league_key with function for non-xmlteam results
  --         06/16/2015 - John Lin - STATS migration
  --         07/27/2015 - ikenticus - adding roster phase_status to remove traded players from results
  --         08/21/2015 - John Lin - slugging and on base percentage qualify
  --         08/28/2015 - ikenticus - SDI migration
  --         08/31/2015 - ikenticus - SDI migration formatting
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('mlb')

    DECLARE @stats TABLE
    (       
        team_key   VARCHAR(100),
        player_key VARCHAR(100),
        ribbon     VARCHAR(100),
        [column]   VARCHAR(100), 
        value      VARCHAR(100)
    )
    DECLARE @players TABLE
    (
        team_key VARCHAR(100),
        player_key VARCHAR(100),
        ribbon VARCHAR(100)
    )
    DECLARE @leaders TABLE
    (
        team_key          VARCHAR(100),
        team_rgb          VARCHAR(100),
        player_key        VARCHAR(100),
        name              VARCHAR(100),
        uniform_number    VARCHAR(100),
        position_regular  VARCHAR(100),
        ribbon            VARCHAR(100),
        value             VARCHAR(100),
        reference_ribbon  VARCHAR(100),
        reference_column  VARCHAR(100),
        reference_sort    VARCHAR(100),
        abbr              VARCHAR(100),
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
    DECLARE @conferences TABLE
    (
        conference_key VARCHAR(100)
    )
    
    IF (@affiliation = 'all')
    BEGIN
        INSERT INTO @conferences (conference_key)
        SELECT conference_key
          FROM dbo.SMG_Leagues
         WHERE league_key = @league_key AND season_key = @seasonKey
         GROUP BY conference_key
    END
    ELSE
    BEGIN
        INSERT INTO @conferences (conference_key)
        SELECT conference_key
          FROM dbo.SMG_Leagues
         WHERE league_key = @league_key AND season_key = @seasonKey AND conference_key IS NOT NULL
		   AND SportsEditDb.dbo.SMG_fnSlugifyName(conference_display) = @affiliation
		 GROUP BY conference_key, conference_display
    END

    IF (@category = 'pitching')
    BEGIN
        DECLARE @pitchings TABLE
        (
            team_key VARCHAR(100),
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
            name VARCHAR(100),
            team VARCHAR(100)
        )

        -- PITCHING
        INSERT INTO @players (team_key, player_key, ribbon)
        SELECT spss.team_key, spss.player_key, 'PITCHING'
          FROM SportsEditDB.dbo.SMG_Statistics spss
         INNER JOIN dbo.SMG_Teams st
            ON st.team_key = spss.team_key AND st.season_key = spss.season_key
         INNER JOIN @conferences c
            ON c.conference_key = st.conference_key
         WHERE spss.league_key = @league_key AND spss.season_key = @seasonKey AND spss.player_key <> 'team' AND
               spss.sub_season_type = @subSeasonType AND spss.[column] = 'innings-pitched' AND spss.value <> '0'
               
        INSERT INTO @stats (team_key, player_key, ribbon, [column], value)
        SELECT p.team_key, p.player_key, p.ribbon, scd.[column], spss.value 
          FROM @players p
         INNER JOIN SportsEditDB.dbo.SMG_Column_Details scd
            ON scd.ribbon = p.ribbon AND scd.page = 'league' AND scd.[level] = 'player'
         INNER JOIN SportsEditDB.dbo.SMG_Statistics spss
            ON spss.league_key = scd.league_key AND spss.[column] = scd.[column] AND spss.player_key = p.player_key AND
               spss.team_key = p.team_key AND spss.season_key = @seasonKey AND spss.sub_season_type = @subSeasonType

        INSERT INTO @stats (team_key, player_key, ribbon, [column], value)
        SELECT p.team_key, p.player_key, p.ribbon, 'era-qualify', spss.value 
          FROM @players p
         INNER JOIN SportsEditDB.dbo.SMG_Statistics spss
            ON spss.league_key = @league_key AND spss.[column] = 'era-qualify' AND spss.player_key = p.player_key AND
               spss.team_key = p.team_key AND spss.season_key = @seasonKey AND spss.sub_season_type = @subSeasonType

        INSERT INTO @pitchings (team_key, player_key, ribbon, [events-played], [events-started], [innings-pitched], [pitching-hits],
               [runs-allowed], [earned-runs], [pitching-bases-on-balls], [pitching-strikeouts], [strikeouts-per-9-innings], [wins],
               [losses], [saves], [saves-blown], [whip], [era], [era-qualify], [pitcher_games_played])
        SELECT p.team_key, p.player_key, p.ribbon, [events-played], ISNULL([events-started], 0), [innings-pitched], ISNULL([pitching-hits], 0),
               ISNULL([runs-allowed], 0), ISNULL([earned-runs], 0), ISNULL([pitching-bases-on-balls], 0), ISNULL([pitching-strikeouts], 0), ISNULL([strikeouts-per-9-innings], 0), ISNULL([wins], 0),
               ISNULL([losses], 0), ISNULL([saves], 0), ISNULL([saves-blown], 0), [whip], ISNULL([era], '0.00'), [era-qualify], [pitcher_games_played]
          FROM (SELECT team_key, player_key, ribbon, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([events-played], [events-started], [innings-pitched], [pitching-hits], [runs-allowed],
                                                [earned-runs], [pitching-bases-on-balls], [pitching-strikeouts], [strikeouts-per-9-innings],
                                                [wins], [losses], [saves], [saves-blown], [whip], [era], [era-qualify], [pitcher_games_played])) AS p

		UPDATE @pitchings
		   SET [events-played] = pitcher_games_played
		 WHERE pitcher_games_played IS NOT NULL

        DELETE @pitchings
         WHERE [events-played] IS NULL OR [events-played] = '' OR [events-played] = '0'

        -- position_regular, name, team
	    UPDATE p
	       SET p.position_regular = sr.position_regular, phase_status = sr.phase_status
	      FROM @pitchings p
	     INNER JOIN dbo.SMG_Rosters sr
            ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.team_key = p.team_key AND sr.player_key = p.player_key

		DELETE @pitchings
		 WHERE phase_status <> 'active'
      
	    UPDATE p
	       SET p.name = sp.first_name + ' ' + sp.last_name
	      FROM @pitchings p
	     INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = p.player_key

	    UPDATE p
	       SET p.team = st.team_abbreviation + '|' + st.team_slug
	      FROM @pitchings p
	     INNER JOIN dbo.SMG_Teams st
            ON st.team_key = p.team_key AND st.season_key = @seasonKey


        -- leaders
        INSERT INTO @leaders (ribbon, team_key, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'WINS', team_key, player_key, name, position_regular, [wins] + ' W', ribbon, 'wins'
          FROM @pitchings
         ORDER BY CONVERT(FLOAT, [wins]) DESC

        INSERT INTO @leaders (ribbon, team_key, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'EARNED RUN AVERAGE', team_key, player_key, name, position_regular, CAST(CAST(era AS DECIMAL(5,2)) AS VARCHAR) + ' ERA', ribbon, 'era'
          FROM @pitchings
         WHERE [era-qualify] = '1'
         ORDER BY CONVERT(FLOAT, [era]) ASC

        INSERT INTO @leaders (ribbon, team_key, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'SAVES', team_key, player_key, name, position_regular, [saves] + ' SV', ribbon, 'saves'
          FROM @pitchings
         ORDER BY CONVERT(FLOAT, [saves]) DESC

        UPDATE l
           SET l.abbr = st.team_abbreviation, l.team_rgb = st.rgb
          FROM @leaders l
         INNER JOIN dbo.SMG_Teams st
            ON st.league_key = @league_key AND st.season_key = @seasonKey AND st.team_key = l.team_key

        UPDATE l
           SET l.uniform_number = sr.uniform_number
          FROM @leaders l
         INNER JOIN dbo.SMG_Rosters sr
            ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.team_key = l.team_key AND sr.player_key = l.player_key

        UPDATE l
           SET l.head_shot = sr.head_shot + '120x120/' + sr.[filename]
          FROM @leaders l
         INNER JOIN dbo.SMG_Rosters sr
            ON sr.team_key = l.team_key AND sr.player_key = l.player_key AND sr.league_key = @league_key AND sr.season_key = @seasonKey AND
               sr.head_shot IS NOT NULL AND sr.[filename] IS NOT NULL

        UPDATE l
           SET l.reference_sort = stn.sort
          FROM @leaders l
         INNER JOIN SportsEditDB.dbo.SMG_TSN_Nodes stn
            ON stn.sport = 'baseball' AND stn.[level] = 'player' AND stn.attribute = l.reference_column

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
               scd.league_key = @league_key AND scd.page = 'league' AND scd.[level] = 'player' AND scd.ribbon = r.ribbon

		-- SDI formatting (may want to move to UX for better datatables sort capabilities in future
		UPDATE @pitchings
		   SET whip = CAST(CAST(whip AS DECIMAL(5,2)) AS VARCHAR),
			   era = CAST(CAST(era AS DECIMAL(5,2)) AS VARCHAR)

        SELECT
        (
            SELECT 'PITCHING LEAGUE LEADERS' AS super_ribbon, team_key, team_rgb, abbr, ribbon, name, uniform_number,
                   position_regular, value, head_shot, reference_ribbon, reference_sort, reference_column
              FROM @leaders
               FOR XML RAW('leader'), TYPE
        ),
        (
            SELECT scd.ribbon, scd.sub_ribbon, scd.[column], scd.display, scd.tooltip, stn.[type], stn.[sort], scd.[order],
                   (CASE
                       WHEN scd.[column] = 'era' THEN 1
                       ELSE 0
                   END) AS qualify
              FROM SportsEditDB.dbo.SMG_Column_Details scd
             INNER JOIN SportsEditDB.dbo.SMG_TSN_Nodes stn
                ON stn.sport = 'baseball' AND stn.[level] = scd.[level] AND stn.attribute = scd.[column]                
             WHERE scd.league_key = @league_key AND scd.page = 'league' AND scd.[level] = 'player' AND scd.ribbon = 'PITCHING'
             ORDER BY scd.[order] ASC
               FOR XML RAW('pitching_column'), TYPE
        ),
        (
            SELECT (CASE 
                       WHEN position_regular IS NULL THEN name
                       ELSE name + ', ' + position_regular
                   END) AS name,
                   team, [events-played], [events-started], [innings-pitched], [pitching-hits], [runs-allowed], [earned-runs],
                   [pitching-bases-on-balls], [pitching-strikeouts], [strikeouts-per-9-innings], [wins], [losses], [saves], [saves-blown], [whip],
                   [era] + '|' + [era-qualify] AS era
              FROM @pitchings WHERE ribbon = 'PITCHING'
             ORDER BY CONVERT(FLOAT, [era]) DESC
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
            team_key VARCHAR(100),
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
            [on-base-plus-slugging-percentage-qualify] VARCHAR(100),           
            -- reference NULL
            phase_status VARCHAR(100),
            position_regular VARCHAR(100),
            name VARCHAR(100),
            team VARCHAR(100)
        )

        -- BATTING
        INSERT INTO @players (team_key, player_key, ribbon)
        SELECT spss.team_key, spss.player_key, 'BATTING'
          FROM SportsEditDB.dbo.SMG_Statistics spss
         INNER JOIN dbo.SMG_Teams st
            ON st.team_key = spss.team_key AND st.season_key = spss.season_key
         INNER JOIN @conferences c
            ON c.conference_key = st.conference_key
         WHERE spss.league_key = @league_key AND spss.season_key = @seasonKey AND spss.player_key <> 'team' AND
               spss.sub_season_type = @subSeasonType AND spss.[column] = 'at-bats' AND spss.value <> '' AND spss.value <> '0'

        INSERT INTO @stats (team_key, player_key, ribbon, [column], value)
        SELECT p.team_key, p.player_key, p.ribbon, scd.[column], spss.value 
          FROM @players p
         INNER JOIN SportsEditDB.dbo.SMG_Column_Details scd
            ON scd.ribbon = p.ribbon AND scd.page = 'league' AND scd.[level] = 'player'
         INNER JOIN SportsEditDB.dbo.SMG_Statistics spss
            ON spss.league_key = scd.league_key AND spss.[column] = scd.[column] AND spss.player_key = p.player_key AND
               spss.team_key = p.team_key AND spss.season_key = @seasonKey AND spss.sub_season_type = @subSeasonType

        INSERT INTO @stats (team_key, player_key, ribbon, [column], value)
        SELECT p.team_key, p.player_key, p.ribbon, 'average-qualify', spss.value 
          FROM @players p
         INNER JOIN SportsEditDB.dbo.SMG_Statistics spss
            ON spss.league_key = @league_key AND spss.[column] = 'average-qualify' AND spss.player_key = p.player_key AND
               spss.team_key = p.team_key AND spss.season_key = @seasonKey AND spss.sub_season_type = @subSeasonType

        INSERT INTO @stats (team_key, player_key, ribbon, [column], value)
        SELECT p.team_key, p.player_key, p.ribbon, 'on-base-percentage-qualify', spss.value 
          FROM @players p
         INNER JOIN SportsEditDB.dbo.SMG_Statistics spss
            ON spss.league_key = @league_key AND spss.[column] = 'on-base-percentage-qualify' AND spss.player_key = p.player_key AND
               spss.team_key = p.team_key AND spss.season_key = @seasonKey AND spss.sub_season_type = @subSeasonType

        INSERT INTO @stats (team_key, player_key, ribbon, [column], value)
        SELECT p.team_key, p.player_key, p.ribbon, 'slugging-percentage-qualify', spss.value 
          FROM @players p
         INNER JOIN SportsEditDB.dbo.SMG_Statistics spss
            ON spss.league_key = @league_key AND spss.[column] = 'slugging-percentage-qualify' AND spss.player_key = p.player_key AND
               spss.team_key = p.team_key AND spss.season_key = @seasonKey AND spss.sub_season_type = @subSeasonType

        INSERT INTO @stats (team_key, player_key, ribbon, [column], value)
        SELECT p.team_key, p.player_key, p.ribbon, 'on-base-plus-slugging-percentage-qualify', spss.value 
          FROM @players p
         INNER JOIN SportsEditDB.dbo.SMG_Statistics spss
            ON spss.league_key = @league_key AND spss.[column] = 'on-base-plus-slugging-percentage-qualify' AND spss.player_key = p.player_key AND
               spss.team_key = p.team_key AND spss.season_key = @seasonKey AND spss.sub_season_type = @subSeasonType
              
        INSERT INTO @battings (team_key, player_key, ribbon, [events-played], [at-bats], [runs-scored], [hits], [doubles], [triples], [home-runs],
               [rbi], [total-bases], [bases-on-balls], [strikeouts], [stolen-bases], [stolen-bases-caught], [average], [average-qualify],
               [on-base-percentage], [on-base-percentage-qualify], [slugging-percentage], [slugging-percentage-qualify], [on-base-plus-slugging-percentage], [on-base-plus-slugging-percentage-qualify])
        SELECT p.team_key, p.player_key, p.ribbon, [events-played], ISNULL([at-bats], 0), ISNULL([runs-scored], 0), ISNULL([hits], 0), ISNULL([doubles], 0), ISNULL([triples], 0), ISNULL([home-runs], 0),
               ISNULL([rbi], 0), ISNULL([total-bases], 0), ISNULL([bases-on-balls], 0), ISNULL([strikeouts], 0), ISNULL([stolen-bases], 0), ISNULL([stolen-bases-caught], 0), ISNULL([average], '.000'), [average-qualify],
               [on-base-percentage], [on-base-percentage-qualify], [slugging-percentage],[slugging-percentage-qualify], [on-base-plus-slugging-percentage], [on-base-plus-slugging-percentage-qualify]
          FROM (SELECT team_key, player_key, ribbon, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([events-played], [at-bats], [runs-scored], [hits], [doubles], [triples], [home-runs],
                                                [rbi], [total-bases], [bases-on-balls], [strikeouts], [stolen-bases], [stolen-bases-caught], [average], [average-qualify],
                                                [on-base-percentage], [on-base-percentage-qualify], [slugging-percentage], [slugging-percentage-qualify], [on-base-plus-slugging-percentage], [on-base-plus-slugging-percentage-qualify])) AS p

        DELETE @battings
         WHERE [events-played] IS NULL OR [events-played] = '' OR [events-played] = '0'

        -- position_regular, name, team
	    UPDATE b
	       SET b.position_regular = sr.position_regular, phase_status = sr.phase_status
	      FROM @battings b
	     INNER JOIN dbo.SMG_Rosters sr
            ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.team_key = b.team_key AND sr.player_key = b.player_key

		DELETE @battings
		 WHERE phase_status <> 'active'

	    UPDATE b
	       SET b.name = sp.first_name + ' ' + sp.last_name
	      FROM @battings b
	     INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = b.player_key

	    UPDATE b
	       SET b.team = st.team_abbreviation + '|' + st.team_slug
	      FROM @battings b
	     INNER JOIN dbo.SMG_Teams st
            ON st.team_key = b.team_key AND st.season_key = @seasonKey


        -- leaders
        INSERT INTO @leaders (ribbon, team_key, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'BATTING AVERAGE', team_key, player_key, name, position_regular, REPLACE(CAST(CAST([average] AS DECIMAL(6,3)) AS VARCHAR), '0.', '.') + ' AVG', ribbon, 'average'
          FROM @battings
         WHERE [average-qualify] = '1'
         ORDER BY CONVERT(FLOAT, [average]) DESC

        INSERT INTO @leaders (ribbon, team_key, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'HOME RUNS', team_key, player_key, name, position_regular, [home-runs] + ' HR', ribbon, 'home-runs'
          FROM @battings
         ORDER BY CONVERT(FLOAT, [home-runs]) DESC

        INSERT INTO @leaders (ribbon, team_key, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'RUNS BATTED IN', team_key, player_key, name, position_regular, [rbi] + ' RBI', ribbon, 'rbi'
          FROM @battings
         ORDER BY CONVERT(FLOAT, [rbi]) DESC

        UPDATE l
           SET l.abbr = st.team_abbreviation, l.team_rgb = st.rgb
          FROM @leaders l
         INNER JOIN dbo.SMG_Teams st
            ON st.league_key = @league_key AND st.season_key = @seasonKey AND st.team_key = l.team_key

        UPDATE l
           SET l.uniform_number = sr.uniform_number
          FROM @leaders l
         INNER JOIN dbo.SMG_Rosters sr
            ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.player_key = l.player_key

        UPDATE l
           SET l.head_shot = sr.head_shot + '120x120/' + sr.[filename]
          FROM @leaders l
         INNER JOIN dbo.SMG_Rosters sr
            ON sr.team_key = l.team_key AND sr.player_key = l.player_key AND sr.league_key = @league_key AND sr.season_key = @seasonKey AND
               sr.head_shot IS NOT NULL AND sr.[filename] IS NOT NULL

        UPDATE l
           SET l.reference_sort = stn.sort
          FROM @leaders l
         INNER JOIN SportsEditDB.dbo.SMG_TSN_Nodes stn
            ON stn.sport = 'baseball' AND stn.[level] = 'player' AND stn.attribute = l.reference_column

        -- reference
        INSERT INTO @reference (ribbon, ribbon_node, [column])
        VALUES ('BATTING', 'batting', 'average')

        UPDATE r
           SET r.display = scd.display, r.[sort] = stn.[sort]
          FROM @reference r
         INNER JOIN SportsEditDB.dbo.SMG_Column_Details scd
            ON scd.[column] = r.[column]
         INNER JOIN SportsEditDB.dbo.SMG_TSN_Nodes stn
            ON stn.sport = 'baseball' AND stn.[level] = scd.[level] AND stn.attribute = scd.[column] AND 
               scd.league_key = @league_key AND scd.page = 'league' AND scd.[level] = 'player' AND scd.ribbon = r.ribbon

		-- SDI formatting (may want to move to UX for better datatables sort capabilities in future
		UPDATE @battings
		   SET [average] = REPLACE(CAST(CAST([average] AS DECIMAL(6,3)) AS VARCHAR), '0.', '.'),
			   [on-base-percentage] = REPLACE(CAST(CAST([on-base-percentage] AS DECIMAL(6,3)) AS VARCHAR), '0.', '.'),
			   [slugging-percentage] = REPLACE(CAST(CAST([slugging-percentage] AS DECIMAL(6,3)) AS VARCHAR), '0.', '.'),
			   [on-base-plus-slugging-percentage] = REPLACE(CAST(CAST([on-base-plus-slugging-percentage] AS DECIMAL(6,3)) AS VARCHAR), '0.', '.')

        SELECT
        (
            SELECT 'BATTING LEAGUE LEADERS' AS super_ribbon, team_key, team_rgb, abbr, ribbon, name, uniform_number,
                   position_regular, value, head_shot, reference_ribbon, reference_sort, reference_column
              FROM @leaders
               FOR XML RAW('leader'), TYPE
        ),
        (
            SELECT scd.ribbon, scd.sub_ribbon, scd.[column], scd.display, scd.tooltip, stn.[type], stn.[sort], scd.[order],
                   (CASE
                       WHEN scd.[column] IN ('average', 'on-base-percentage', 'slugging-percentage', 'on-base-plus-slugging-percentage') THEN 1
                       ELSE 0
                   END) AS qualify
              FROM SportsEditDB.dbo.SMG_Column_Details scd
             INNER JOIN SportsEditDB.dbo.SMG_TSN_Nodes stn
                ON stn.sport = 'baseball' AND stn.[level] = scd.[level] AND stn.attribute = scd.[column]                
             WHERE scd.league_key = @league_key AND scd.page = 'league' AND scd.[level] = 'player' AND scd.ribbon = 'BATTING'
             ORDER BY scd.[order] ASC
               FOR XML RAW('batting_column'), TYPE
        ),
        (
            SELECT (CASE 
                       WHEN position_regular IS NULL THEN name
                       ELSE name + ', ' + position_regular
                   END) AS name,
                   team, [events-played], [at-bats], [runs-scored], [hits], [doubles], [triples], [home-runs], [rbi],
                   [total-bases], [bases-on-balls], [strikeouts], [stolen-bases], [stolen-bases-caught],
                   [average] + '|' + [average-qualify] AS average, [on-base-percentage]+ '|' + [on-base-percentage-qualify] AS [on-base-percentage],
                   [slugging-percentage] + '|' + [slugging-percentage-qualify] AS [slugging-percentage],
                   [on-base-plus-slugging-percentage] + '|' + [on-base-plus-slugging-percentage-qualify] AS [on-base-plus-slugging-percentage]
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
