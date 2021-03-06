USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetStatistics_MLB_team_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetStatistics_MLB_team_XML]
   @seasonKey     INT,
   @subSeasonType VARCHAR(100),
   @affiliation   VARCHAR(100),
   @category      VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 08/23/2013
  -- Description: get MLB league team statistics
  -- Update: 10/21/2013 - John Lin - use team slug
  --         02/20/2015 - ikenticus - migrating SMG_Team_Season_Statistics to SMG_Statistics
  --         06/05/2015 - ikenticus - replacing hard-coded league_key with function for non-xmlteam results
  --         06/16/2015 - John Lin - STATS migration
  --         08/28/2015 - ikenticus - SDI migration
  --         08/31/2015 - ikenticus - SDI migration formatting
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('mlb')
    
    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/'
    DECLARE @logo_folder VARCHAR(100) = 'mlb-whitebg/80/'
    DECLARE @logo_suffix VARCHAR(100) = '.png'

    DECLARE @stats TABLE
    (
        team_key VARCHAR(100),
        ribbon   VARCHAR(100),
        category VARCHAR(100),
        [column] VARCHAR(100), 
        value    VARCHAR(100)
    )
    DECLARE @leaders TABLE
    (
        team_key          VARCHAR(100),
        team_logo         VARCHAR(100),
        team_rgb          VARCHAR(100),
        team_link         VARCHAR(100),
        ribbon            VARCHAR(100), 
        name              VARCHAR(100),
        abbr              VARCHAR(100),
        value             VARCHAR(100),
        reference_ribbon  VARCHAR(100),
        reference_column  VARCHAR(100),
        reference_sort    VARCHAR(100)
    )
    DECLARE @teams TABLE
    (
        sub_ribbon VARCHAR(100), 
        team_key VARCHAR(100),
        name       VARCHAR(100)
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
            [era] VARCHAR(100),
            -- reference NULL
            team VARCHAR(100)
        )
        
        INSERT INTO @stats (team_key, ribbon, category, [column], value)
        SELECT stss.team_key, scd.ribbon, stss.category, scd.[column], stss.value 
          FROM SportsEditDB.dbo.SMG_Column_Details scd
         INNER JOIN SportsEditDB.dbo.SMG_Statistics stss
            ON stss.league_key = scd.league_key AND stss.[column] = scd.[column] AND stss.season_key = @seasonKey AND
               stss.sub_season_type = @subSeasonType AND stss.category = 'feed' AND stss.player_key = 'team'
         INNER JOIN dbo.SMG_Teams st
            ON st.team_key = stss.team_key AND st.season_key = @seasonKey
         INNER JOIN @conferences c
            ON c.conference_key = st.conference_key
         WHERE scd.league_key = @league_key AND scd.page = 'league' AND scd.[level] = 'team' AND scd.ribbon = 'PITCHING'

        INSERT INTO @pitchings                 
        SELECT p.team_key, p.ribbon, p.category, [events-played], [innings-pitched], ISNULL([pitching-hits], 0), ISNULL([runs-allowed], 0), ISNULL([earned-runs], 0),
               ISNULL([pitching-bases-on-balls], 0), ISNULL([pitching-strikeouts], 0), ISNULL([wins], 0), ISNULL([losses], 0), ISNULL([saves], 0), ISNULL([games-complete], 0), ISNULL([shutouts], 0), [whip], [era], NULL
          FROM (SELECT team_key, ribbon, category, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([events-played], [innings-pitched], [pitching-hits], [runs-allowed], [earned-runs],
                                                [pitching-bases-on-balls], [pitching-strikeouts], [wins], [losses], [saves], [games-complete],
                                                [shutouts], [whip], [era])) AS p

        -- leaders
        INSERT INTO @leaders (team_key, ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 team_key, 'EARNED RUN AVERAGE', CAST(CAST(era AS DECIMAL(5,2)) AS VARCHAR) + ' ERA', ribbon, 'era'
          FROM @pitchings
         WHERE ribbon = 'PITCHING'
         ORDER BY CAST([era] AS FLOAT) ASC
         
        INSERT INTO @leaders (team_key, ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 team_key, 'RUNS ALLOWED', [runs-allowed] + ' R', ribbon, 'runs-allowed'
          FROM @pitchings
         WHERE ribbon = 'PITCHING'
         ORDER BY CAST([runs-allowed] AS FLOAT) ASC
         
        INSERT INTO @leaders (team_key, ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 team_key, 'STRIKEOUTS', [pitching-strikeouts] + ' SO', ribbon, 'pitching-strikeouts'
          FROM @pitchings
         WHERE ribbon = 'PITCHING'
         ORDER BY CAST([pitching-strikeouts] AS FLOAT) DESC

        UPDATE l
           SET l.reference_sort = stn.sort
          FROM @leaders l
         INNER JOIN SportsEditDB.dbo.SMG_TSN_Nodes stn
            ON stn.sport = 'baseball' AND stn.[level] = 'team' AND stn.attribute = l.reference_column

        UPDATE l
           SET l.team_logo = @logo_prefix + @logo_folder + st.team_abbreviation + @logo_suffix,
               l.team_rgb = st.rgb, l.team_link = '/sports/mlb/' + st.team_slug + '/'
          FROM @leaders l
         INNER JOIN dbo.SMG_Teams st
            ON st.league_key = @league_key AND st.season_key = @seasonKey AND st.team_key = l.team_key

        -- teams
        INSERT INTO @teams (sub_ribbon, team_key)
        SELECT TOP 4 'EARNED RUN AVERAGE', team_key
          FROM @pitchings
         WHERE ribbon = 'PITCHING' AND team_key NOT IN (SELECT l.team_key FROM @leaders l WHERE l.ribbon = 'ERA')
         ORDER BY CAST([era] AS FLOAT) ASC          

        INSERT INTO @teams (sub_ribbon, team_key)
        SELECT TOP 4 'RUNS ALLOWED', team_key
          FROM @pitchings
         WHERE ribbon = 'PITCHING' AND team_key NOT IN (SELECT l.team_key FROM @leaders l WHERE l.ribbon = 'RUNS ALLOWED')
         ORDER BY CAST([runs-allowed] AS FLOAT) ASC

        INSERT INTO @teams (sub_ribbon, team_key)
        SELECT TOP 4 'STRIKEOUTS', team_key
          FROM @pitchings
         WHERE ribbon = 'PITCHING' AND team_key NOT IN (SELECT l.team_key FROM @leaders l WHERE l.ribbon = 'STRIKEOUTS')
         ORDER BY CAST([pitching-strikeouts] AS FLOAT) DESC

	    UPDATE l
	       SET l.name = st.team_last, l.abbr = st.team_abbreviation
	      FROM @leaders l
	     INNER JOIN dbo.SMG_Teams st
            ON st.team_key = l.team_key AND st.season_key = @seasonKey

	    UPDATE t
	       SET t.name = st.team_last
	      FROM @teams t
	     INNER JOIN dbo.SMG_Teams st
            ON st.team_key = t.team_key AND st.season_key = @seasonKey

	    UPDATE p
	       SET p.team = st.team_abbreviation + '|' + st.team_slug
	      FROM @pitchings p
	     INNER JOIN dbo.SMG_Teams st
            ON st.team_key = p.team_key AND st.season_key = @seasonKey
         
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
               scd.league_key = @league_key AND scd.page = 'league' AND scd.[level] = 'team' AND scd.ribbon = r.ribbon

		-- SDI formatting (may want to move to UX for better datatables sort capabilities in future
		UPDATE @pitchings
		   SET whip = CAST(CAST(whip AS DECIMAL(5,2)) AS VARCHAR),
			   era = CAST(CAST(era AS DECIMAL(5,2)) AS VARCHAR)

        SELECT
        (
            SELECT 'PITCHING LEAGUE LEADERS' AS super_ribbon, team_logo, team_rgb, team_link,
                    team_key, name, abbr, ribbon, value, reference_ribbon, reference_sort, reference_column,
                   (
                       SELECT team_key, name, team_link
                        FROM @teams
                       WHERE sub_ribbon = l.ribbon
                         FOR XML RAW('team'), TYPE
                   )
              FROM @leaders l
               FOR XML RAW('leader'), TYPE
        ),
        (
            SELECT scd.ribbon, scd.sub_ribbon, scd.[column], scd.display, scd.tooltip, stn.[type], stn.[sort], scd.[order]
              FROM SportsEditDB.dbo.SMG_Column_Details scd
             INNER JOIN SportsEditDB.dbo.SMG_TSN_Nodes stn
                ON stn.sport = 'baseball' AND stn.[level] = scd.[level] AND stn.attribute = scd.[column]                
             WHERE scd.league_key = @league_key AND scd.page = 'league' AND scd.[level] = 'team' AND scd.ribbon = 'PITCHING'
             ORDER BY scd.[order] ASC
               FOR XML RAW('pitching_column'), TYPE
        ),
        (
            SELECT team, [events-played], [innings-pitched], [pitching-hits], [runs-allowed], [earned-runs], [pitching-bases-on-balls],
                   [pitching-strikeouts], [wins], [losses], [saves], [games-complete], [shutouts], [whip], [era]
              FROM @pitchings WHERE ribbon = 'PITCHING'
             ORDER BY category ASC
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
            [on-base-plus-slugging-percentage] VARCHAR(100),
            -- reference NULL
            team VARCHAR(100)
        )
        INSERT INTO @stats (team_key, ribbon, category, [column], value)
        SELECT stss.team_key, scd.ribbon, stss.category, scd.[column], stss.value 
          FROM SportsEditDB.dbo.SMG_Column_Details scd
         INNER JOIN SportsEditDB.dbo.SMG_Statistics stss
            ON stss.league_key = scd.league_key AND stss.[column] = scd.[column] AND stss.season_key = @seasonKey AND
               stss.sub_season_type = @subSeasonType AND stss.category = 'feed' AND stss.player_key = 'team'
         INNER JOIN dbo.SMG_Teams st
            ON st.team_key = stss.team_key AND st.season_key = @seasonKey
         INNER JOIN @conferences c
            ON c.conference_key = st.conference_key
         WHERE scd.league_key = @league_key AND scd.page = 'league' AND scd.[level] = 'team' AND scd.ribbon = 'BATTING'
              
        INSERT INTO @battings
        SELECT p.team_key, p.ribbon, p.category, [events-played], [at-bats], ISNULL([runs-scored], 0), ISNULL([hits], 0), ISNULL([doubles], 0), ISNULL([triples], 0), ISNULL([home-runs], 0),
               ISNULL([rbi], 0), ISNULL([bases-on-balls], 0), ISNULL([strikeouts], 0), ISNULL([stolen-bases], 0), ISNULL([stolen-bases-caught], 0), [average], [on-base-percentage],
               [slugging-percentage], [on-base-plus-slugging-percentage], NULL
          FROM (SELECT team_key, ribbon, category, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN ([events-played], [at-bats], [runs-scored], [hits], [doubles], [triples], [home-runs],
                                                [rbi], [bases-on-balls], [strikeouts], [stolen-bases], [stolen-bases-caught], [average],
                                                [on-base-percentage], [slugging-percentage], [on-base-plus-slugging-percentage])) AS p

        -- leaders                
        INSERT INTO @leaders (team_key, ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 team_key, 'BATTING AVERAGE', REPLACE(CAST(CAST([average] AS DECIMAL(6,3)) AS VARCHAR), '0.', '.') + ' AVG', ribbon, 'average'
          FROM @battings
         WHERE ribbon = 'BATTING'
         ORDER BY CAST([average] AS FLOAT) DESC
         
        INSERT INTO @leaders (team_key, ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 team_key, 'RUNS SCORED', [runs-scored] + ' R', ribbon, 'runs-scored'
          FROM @battings
         WHERE ribbon = 'BATTING'         
         ORDER BY CAST([runs-scored] AS FLOAT) DESC
         
        INSERT INTO @leaders (team_key, ribbon, value, reference_ribbon, reference_column)
        SELECT TOP 1 team_key, 'HOME RUNS', [home-runs] + ' HR', ribbon, 'home-runs'
          FROM @battings
         WHERE ribbon = 'BATTING'
         ORDER BY CAST([home-runs] AS FLOAT) DESC         

        UPDATE l
           SET l.reference_sort = stn.sort
          FROM @leaders l
         INNER JOIN SportsEditDB.dbo.SMG_TSN_Nodes stn
            ON stn.sport = 'baseball' AND stn.[level] = 'team' AND stn.attribute = l.reference_column

        UPDATE l
           SET l.team_logo = @logo_prefix + @logo_folder + st.team_abbreviation + @logo_suffix,
               l.team_rgb = st.rgb, l.team_link = '/sports/mlb/' + st.team_slug + '/'
          FROM @leaders l
         INNER JOIN dbo.SMG_Teams st
            ON st.league_key = @league_key AND st.season_key = @seasonKey AND st.team_key = l.team_key

        -- teams
        INSERT INTO @teams (sub_ribbon, team_key)
        SELECT TOP 4 'BATTING AVERAGE', team_key
          FROM @battings
         WHERE ribbon = 'BATTING' AND
               team_key NOT IN (SELECT l.team_key FROM @leaders l WHERE l.ribbon = 'BATTING AVERAGE')
         ORDER BY CAST([average] AS FLOAT) DESC

        INSERT INTO @teams (sub_ribbon, team_key)
        SELECT TOP 4 'RUNS SCORED', team_key
          FROM @battings
         WHERE ribbon = 'BATTING' AND
               team_key NOT IN (SELECT l.team_key FROM @leaders l WHERE l.ribbon = 'RUNS SCORED')
         ORDER BY CAST([runs-scored] AS FLOAT) DESC

        INSERT INTO @teams (sub_ribbon, team_key)
        SELECT TOP 4 'HOME RUNS', team_key
          FROM @battings
         WHERE ribbon = 'BATTING' AND
               team_key NOT IN (SELECT l.team_key FROM @leaders l WHERE l.ribbon = 'HOME RUNS')
         ORDER BY CAST([home-runs] AS FLOAT) DESC

	    UPDATE l
	       SET l.name = st.team_last, l.abbr = st.team_abbreviation
	      FROM @leaders l
	     INNER JOIN dbo.SMG_Teams st
            ON st.team_key = l.team_key AND st.season_key = @seasonKey

	    UPDATE t
	       SET t.name = st.team_last
	      FROM @teams t
	     INNER JOIN dbo.SMG_Teams st
            ON st.team_key = t.team_key AND st.season_key = @seasonKey

	    UPDATE b
	       SET b.team = st.team_abbreviation + '|' + st.team_slug
	      FROM @battings b
	     INNER JOIN dbo.SMG_Teams st
            ON st.team_key = b.team_key AND st.season_key = @seasonKey
         
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
               scd.league_key = @league_key AND scd.page = 'league' AND scd.[level] = 'team' AND scd.ribbon = r.ribbon

		-- SDI formatting (may want to move to UX for better datatables sort capabilities in future
		UPDATE @battings
		   SET [average] = REPLACE(CAST(CAST([average] AS DECIMAL(6,3)) AS VARCHAR), '0.', '.'),
			   [on-base-percentage] = REPLACE(CAST(CAST([on-base-percentage] AS DECIMAL(6,3)) AS VARCHAR), '0.', '.'),
			   [slugging-percentage] = REPLACE(CAST(CAST([slugging-percentage] AS DECIMAL(6,3)) AS VARCHAR), '0.', '.'),
			   [on-base-plus-slugging-percentage] = REPLACE(CAST(CAST([on-base-plus-slugging-percentage] AS DECIMAL(6,3)) AS VARCHAR), '0.', '.')

        SELECT
        (
            SELECT 'BATTING LEAGUE LEADERS' AS super_ribbon, team_logo, team_rgb, team_link,
                   team_key, name, abbr, ribbon, value, reference_ribbon, reference_sort, reference_column,
                   (
                       SELECT team_key, name, team_link
                        FROM @teams
                       WHERE sub_ribbon = l.ribbon
                         FOR XML RAW('team'), TYPE
                   )
              FROM @leaders l
               FOR XML RAW('leader'), TYPE
        ),
        (
            SELECT scd.ribbon, scd.sub_ribbon, scd.[column], scd.display, scd.tooltip, stn.[type], stn.[sort], scd.[order]
              FROM SportsEditDB.dbo.SMG_Column_Details scd
             INNER JOIN SportsEditDB.dbo.SMG_TSN_Nodes stn
                ON stn.sport = 'baseball' AND stn.[level] = scd.[level] AND stn.attribute = scd.[column]                
             WHERE scd.league_key = @league_key AND scd.page = 'league' AND scd.[level] = 'team' AND scd.ribbon = 'BATTING'
             ORDER BY scd.[order] ASC
               FOR XML RAW('batting_column'), TYPE
        ),
        (
            SELECT team, [events-played], [at-bats], [runs-scored], [hits], [doubles], [triples], [home-runs],
                   [rbi], [bases-on-balls], [strikeouts], [stolen-bases], [stolen-bases-caught], [average],
                   [on-base-percentage], [slugging-percentage], [on-base-plus-slugging-percentage]
              FROM @battings WHERE ribbon = 'BATTING'
             ORDER BY category ASC
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
