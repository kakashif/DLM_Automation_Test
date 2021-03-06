USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_Statistics_football_player_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[DES_Statistics_football_player_XML]
   @leagueName    VARCHAR(100),
   @seasonKey     INT,
   @subSeasonType VARCHAR(100),
   @affiliation   VARCHAR(100),
   @category      VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 07/26/2013
  -- Description: get NFL league player statistics
  -- Update: 08/16/2013 - John Lin - add head shot
  --         09/25/2013 - John Lin - pre calculation
  --         10/21/2013 - John Lin - use team slug
  --         02/20/2015 - ikenticus - migrating SMG_Player_Season_Statistics to SMG_Statistics
  --         04/08/2015 - John Lin - new head shot logic
  --         06/05/2015 - ikenticus - replacing hard-coded league_key with function for non-xmlteam results
  --         07/02/2015 - John Lin - remove hardcoded conference
  --         08/12/2015 - John Lin - SDI migration
  --         08/24/2015 - John Lin - remove passer rating qualify
  --         10/09/2015 - John Lin - slugify conference display
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)

    DECLARE @stats TABLE
    (
        team_key   VARCHAR(100),
        player_key VARCHAR(100),
        [column]   VARCHAR(100), 
        value      VARCHAR(100),
        affiliate  INT DEFAULT 0
    )
    INSERT INTO @stats (team_key, player_key, [column], value)
    SELECT team_key, player_key, [column], value 
      FROM SportsEditDB.dbo.SMG_Statistics
     WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @subSeasonType AND player_key <> 'team' AND category = 'feed'
    
    IF (@affiliation <> 'all')
    BEGIN
        SELECT @affiliation = conference_key
          FROM dbo.SMG_Leagues
         WHERE league_key = @league_key AND SportsEditDb.dbo.SMG_fnSlugifyName(conference_display) = @affiliation
         
        UPDATE s
           SET s.affiliate = 1
          FROM @stats s
         INNER JOIN dbo.SMG_Teams t
            ON t.team_key = s.team_key AND t.conference_key = @affiliation

        DELETE @stats
         WHERE affiliate = 0
    END

    DECLARE @tables TABLE
    (
        ribbon VARCHAR(100),
        [column] VARCHAR(100),
        sub_ribbon VARCHAR(100),
        display VARCHAR(100),
        tooltip VARCHAR(100),
        [order] INT
    )
    DECLARE @football TABLE
    (
        team_key VARCHAR(100),
        player_key VARCHAR(100),
        -- passing
        passing_plays_completed INT,
        passing_plays_attempted INT,
        [passing-plays-percentage] VARCHAR(100),
        passer_rating VARCHAR(100),
        passing_yards INT,
        [passing-yards-per-game] VARCHAR(100),
        [passing-yards-per-attempted] VARCHAR(100),
        passing_longest_yards INT,
        passing_touchdowns INT,
        passing_plays_intercepted INT,
        passing_plays_sacked INT,
        -- rushing            
        rushing_plays INT,
        rushing_net_yards INT,
        [rushing-net-yards-per-game] VARCHAR(100),
        [rushing-net-yards-per-play] VARCHAR(100),
        rushing_longest_yards INT,
        rushing_touchdowns INT,
        fumbles INT,
        -- receiving
        receiving_receptions INT,
        receiving_yards INT,
        [receiving_yards-per-game] VARCHAR(100),
        [receiving-yards-per-reception] VARCHAR(100),
        receiving_longest_yards INT,
        receiving_touchdowns INT,
        field_goals_succeeded INT,
        -- scoring
        points INT,
        [points-per-game] VARCHAR(100),            
        [total-touchdowns] INT,
        -- defense
        defense_solo_tackles INT,
        defense_assisted_tackles INT,
        [tackles-total] INT,
        defense_sacks VARCHAR(100),
        defense_interceptions INT,
        defense_interception_yards INT,
        interception_returned_longest_yards INT,
        defense_forced_fumbles INT,
        fumbles_recovered_lost_by_opposition INT,
        -- special team
        field_goals_attempted INT,
        [field-goals-attempted-qualify] VARCHAR(100),
        [field-goals-percentage] VARCHAR(100),
        extra_point_kicks_attempted INT,
        [extra-point-kicks-attempted-qualify] VARCHAR(100),
        [extra-points-percentage] VARCHAR(100),
        punting_plays INT,
        punting_gross_yards INT,
        punting_longest_yards INT,
        [punting-average] VARCHAR(100),
        punting_inside_twenty INT,
        punting_touchbacks VARCHAR(100),
        kickoff_returns VARCHAR(100),
        kickoff_return_yards VARCHAR(100),
        [kickoff-return-average] VARCHAR(100),
        kickoff_return_longest_yards VARCHAR(100),
        punt_returns VARCHAR(100),
        punt_return_yards VARCHAR(100),
        [punt-return-average] VARCHAR(100),
        punt_return_longest_yards VARCHAR(100),
        punt_return_faircatches VARCHAR(100),            
        -- shared
        interceptions_returned_touchdowns INT,
        fumbles_recovered_touchdowns INT,
        extra_point_kicks_succeeded INT,
        kickoff_return_touchdowns INT,
        punt_return_touchdowns INT,
        -- reference NULL
        position_regular VARCHAR(100),
        name VARCHAR(100),
        team VARCHAR(100)
    )
    DECLARE @leaders TABLE
    (
        team_key          VARCHAR(100),
        player_key        VARCHAR(100),
        name              VARCHAR(100),
        uniform_number    VARCHAR(100),
        position_regular  VARCHAR(100),
        ribbon            VARCHAR(100),
        value             VARCHAR(100),
        reference_ribbon  VARCHAR(100),
        reference_column  VARCHAR(100),
        abbr              VARCHAR(100),
        team_rgb          VARCHAR(100),
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

    IF (@category = 'defense')
    BEGIN
        INSERT INTO @tables (ribbon, [column], sub_ribbon, display, tooltip, [order])
        VALUES ('DEFENSE', 'name', '', 'NAME', 'Player Name and Position', 1),
               ('DEFENSE', 'team', '', 'TEAM', 'Team', 2),
               ('DEFENSE', 'defense_solo_tackles', 'TACKLES', 'SOLO', 'Solo Tackles', 3),
               ('DEFENSE', 'defense_assisted_tackles', 'TACKLES', 'AST', 'Assisted Tackles', 4),
               ('DEFENSE', 'tackles-total', 'TACKLES', 'TOTAL', 'Total Tackles', 5),
               ('DEFENSE', 'defense_sacks', 'SACKS', 'SACK', 'Total Sacks', 6),
               ('DEFENSE', 'defense_interceptions', 'INTERCEPTIONS', 'INT', 'Total Interceptions', 7),
               ('DEFENSE', 'defense_interception_yards', 'INTERCEPTIONS', 'YDS', 'Interception Return Yards', 8),
               ('DEFENSE', 'interception_returned_longest_yards', 'INTERCEPTIONS', 'LNG', 'Longest Interception Yards', 9),
               ('DEFENSE', 'interceptions_returned_touchdowns', 'INTERCEPTIONS', 'TD', 'Interceptions Returned For Touchdown', 10),
               ('DEFENSE', 'defense_forced_fumbles', 'FUMBLES', 'FF', 'Forced Fumbles', 11),
               ('DEFENSE', 'fumbles_recovered_lost_by_opposition', 'FUMBLES', 'REC', 'Forced Fumbles Recovered', 12),
               ('DEFENSE', 'fumbles_recovered_touchdowns', 'FUMBLES', 'TD', 'Fumbles Returned For Touchdown', 13)

        IF (@leagueName = 'ncaaf')
        BEGIN
            DELETE @tables
             WHERE [column] IN ('interception_returned_longest_yards')
        END

        INSERT INTO @football (team_key, player_key,
               defense_solo_tackles, defense_assisted_tackles, defense_sacks,
               defense_interceptions, defense_interception_yards, interception_returned_longest_yards, interceptions_returned_touchdowns,
               defense_forced_fumbles, fumbles_recovered_lost_by_opposition, fumbles_recovered_touchdowns)
        SELECT p.team_key, p.player_key,
               ISNULL(defense_solo_tackles, 0), ISNULL(defense_assisted_tackles, 0), ISNULL(defense_sacks, '0.0'),
               ISNULL(defense_interceptions, 0), defense_interception_yards, interception_returned_longest_yards, ISNULL(interceptions_returned_touchdowns, 0),
               ISNULL(defense_forced_fumbles, 0), ISNULL(fumbles_recovered_lost_by_opposition, 0), ISNULL(fumbles_recovered_touchdowns, 0)
          FROM (SELECT team_key, player_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN (defense_solo_tackles, defense_assisted_tackles, defense_sacks,
                                                defense_interceptions, defense_interception_yards, interception_returned_longest_yards, interceptions_returned_touchdowns,
                                                defense_forced_fumbles, fumbles_recovered_lost_by_opposition, fumbles_recovered_touchdowns)) AS p

        -- calculations
        UPDATE @football
           SET [tackles-total] = defense_solo_tackles + defense_assisted_tackles

        -- update defense
	    UPDATE f
	       SET f.position_regular = sr.position_regular
	      FROM @football f
	     INNER JOIN dbo.SMG_Rosters sr
            ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.team_key = f.team_key AND sr.player_key = f.player_key
                           
	    UPDATE f
	       SET f.name = sp.first_name + ' ' + sp.last_name
	      FROM @football f
	     INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = f.player_key

	    UPDATE f
	       SET f.team = st.team_abbreviation + '|' + ISNULL(st.team_slug, '')
	      FROM @football f
	     INNER JOIN dbo.SMG_Teams st
            ON st.team_key = f.team_key AND st.season_key = @seasonKey

        -- delete no name
        DELETE @football
         WHERE name IS NULL
         
        DELETE @football
         WHERE team IS NULL

        -- leaders
        INSERT INTO @leaders (ribbon, team_key, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'TACKLES', team_key, player_key, name, position_regular, CAST([tackles-total] AS VARCHAR) + ' TACK', 'DEFENSE', 'tackles-total'
          FROM @football
         ORDER BY [tackles-total] DESC

        INSERT INTO @leaders (ribbon, team_key, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'SACKS', team_key, player_key, name, position_regular, defense_sacks + ' SACKS', 'DEFENSE', 'defense_sacks'
          FROM @football
         ORDER BY CONVERT(FLOAT, defense_sacks) DESC

        INSERT INTO @leaders (ribbon, team_key, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'INTERCEPTIONS', team_key, player_key, name, position_regular, CAST(defense_interceptions AS VARCHAR) + ' INT', 'DEFENSE', 'defense_interceptions'
          FROM @football
         ORDER BY defense_interceptions DESC

        -- update leaders
        UPDATE l
           SET l.abbr = st.team_abbreviation, l.team_rgb = st.rgb
          FROM @leaders l
         INNER JOIN dbo.SMG_Teams st
            ON st.team_key = l.team_key AND st.season_key = @seasonKey

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

        -- reference
        INSERT INTO @reference (ribbon, ribbon_node, [column], display)
        VALUES ('DEFENSE', 'defense', 'tackles-total', 'TOTAL')


        SELECT
        (
            SELECT 'DEFENSIVE LEAGUE LEADERS' AS super_ribbon, team_key, team_rgb, abbr, ribbon, name, uniform_number,
                   position_regular, value, head_shot, reference_ribbon, reference_column
              FROM @leaders
               FOR XML RAW('leader'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip, 'desc,asc' AS [sort],
                   CASE
                       WHEN [column] IN ('name', 'team') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'DEFENSE' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('defense_column'), TYPE
        ),
        (
            SELECT (CASE 
                       WHEN position_regular IS NULL THEN name
                       ELSE name + ', ' + position_regular
                   END) AS name,
                   team, defense_solo_tackles, defense_assisted_tackles, [tackles-total], defense_sacks, defense_interceptions,
                   defense_interception_yards, interception_returned_longest_yards, interceptions_returned_touchdowns, defense_forced_fumbles,
                   fumbles_recovered_lost_by_opposition, fumbles_recovered_touchdowns
              FROM @football
             WHERE defense_solo_tackles + defense_assisted_tackles +  CAST(defense_sacks AS FLOAT) + defense_interceptions + defense_forced_fumbles + fumbles_recovered_lost_by_opposition > 0
             ORDER BY [tackles-total] DESC
               FOR XML RAW('defense'), TYPE
        ),
        (
            SELECT ribbon, ribbon_node, display, [sort]
              FROM @reference
               FOR XML RAW('reference'), TYPE
        )
        FOR XML RAW('root'), TYPE
    END
    ELSE IF (@category = 'special-teams')
    BEGIN
        INSERT INTO @tables (ribbon, [column], sub_ribbon, display, tooltip, [order])
        VALUES ('KICKING', 'name', '', 'NAME', 'Player Name and Position', 1),
               ('KICKING', 'team', '', 'TEAM', 'Team', 2),
               ('KICKING', 'field_goals_succeeded', 'FIELD GOALS', 'FGM', 'Field Goals Made', 3),
               ('KICKING', 'field_goals_attempted', 'FIELD GOALS', 'FGA', 'Field Goal Attempts', 4),
               ('KICKING', 'field-goals-percentage', 'FIELD GOALS', 'PCT', 'Percent of Field Goal Made', 5),
               ('KICKING', 'field-goals-attempted-qualify', '', '', '', -1),
               ('KICKING', 'extra_point_kicks_succeeded', 'EXTRA POINTS', 'XPM', 'Extra Points Made', 6),
               ('KICKING', 'extra_point_kicks_attempted', 'EXTRA POINTS', 'XMA', 'Extra Point Attempts', 7),
               ('KICKING', 'extra-point-kicks-attempted-qualify', '', '', '', -1),
               ('KICKING', 'extra-points-percentage', 'EXTRA POINTS', 'PCT', 'Percent of Extra Points Made', 8),
               
               ('PUNTING', 'name', '', 'NAME', 'Player Name and Position', 1),
               ('PUNTING', 'team', '', 'TEAM', 'Team', 2),
               ('PUNTING', 'punting_plays', '', 'PUNTS', 'Total Punts', 3),
               ('PUNTING', 'punting_gross_yards', '', 'YDS', 'Punting Gross Yards', 4),
               ('PUNTING', 'punting_longest_yards', '', 'LNG', 'Longest Punt', 5),
               ('PUNTING', 'punting-average', '', 'AVG', 'Punting Average', 6),
               ('PUNTING', 'punting_inside_twenty', '', 'IN20', 'Punts Inside 20 Yard Line', 7),
               ('PUNTING', 'punting_touchbacks', '', 'TB', 'Touchbacks', 8),
               
               ('RETURNING', 'name', '', 'NAME', 'Player Name and Position', 1),
               ('RETURNING', 'team', '', 'TEAM', 'Team', 2),
               ('RETURNING', 'kickoff_returns', 'KICKOFFS', 'ATT', 'Kickoff Return Attempts', 3),
               ('RETURNING', 'kickoff_return_yards', 'KICKOFFS', 'YDS', 'Kickoff Return Yards', 4),
               ('RETURNING', 'kickoff-return-average', 'KICKOFFS', 'AVG', 'Average Yards Per Kickoff Return', 5),
               ('RETURNING', 'kickoff_return_longest_yards', 'KICKOFFS', 'LNG', 'Longest Kickoff Return', 6),
               ('RETURNING', 'kickoff_return_touchdowns', 'KICKOFFS', 'TD', 'Kickoff Returns For Touchdown', 7),
               ('RETURNING', 'punt_returns', 'PUNTS', 'ATT', 'Punt Return Attempts', 8),
               ('RETURNING', 'punt_return_yards', 'PUNTS', 'YDS', 'Punt Return Yards', 9),
               ('RETURNING', 'punt-return-average', 'PUNTS', 'AVG', 'Average Yards Per Punt Return', 10),
               ('RETURNING', 'punt_return_longest_yards', 'PUNTS', 'LNG', 'Longest Punt Return', 11),
               ('RETURNING', 'punt_return_touchdowns', 'PUNTS', 'TD', 'Punt Returns For Touchdown', 12),
               ('RETURNING', 'punt_return_faircatches', 'PUNTS', 'FC', 'Fair Catches', 13)

        INSERT INTO @football (team_key, player_key,
                               field_goals_succeeded, field_goals_attempted, [field-goals-attempted-qualify], [field-goals-percentage],
                               extra_point_kicks_succeeded, extra_point_kicks_attempted, [extra-point-kicks-attempted-qualify], [extra-points-percentage],
                               punting_plays, punting_gross_yards, punting_longest_yards, punting_inside_twenty, punting_touchbacks,
                               kickoff_returns, kickoff_return_yards, kickoff_return_longest_yards, kickoff_return_touchdowns,
                               punt_returns, punt_return_yards, punt_return_longest_yards, punt_return_touchdowns, punt_return_faircatches)                
        SELECT p.team_key, p.player_key,
               ISNULL(field_goals_succeeded, 0), ISNULL(field_goals_attempted, 0), [field-goals-attempted-qualify], [field-goals-percentage],
               ISNULL(extra_point_kicks_succeeded, 0), ISNULL(extra_point_kicks_attempted, 0), [extra-point-kicks-attempted-qualify], [extra-points-percentage],
               ISNULL(punting_plays, 0), punting_gross_yards, punting_longest_yards, ISNULL(punting_inside_twenty, 0), ISNULL(punting_touchbacks, 0),
               ISNULL(kickoff_returns, 0), kickoff_return_yards, kickoff_return_longest_yards, ISNULL(kickoff_return_touchdowns, 0),
               ISNULL(punt_returns, 0), punt_return_yards, punt_return_longest_yards, ISNULL(punt_return_touchdowns, 0), ISNULL(punt_return_faircatches, 0)
          FROM (SELECT team_key, player_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN (field_goals_succeeded, field_goals_attempted, [field-goals-attempted-qualify], [field-goals-percentage],
                                                extra_point_kicks_succeeded, extra_point_kicks_attempted, [extra-point-kicks-attempted-qualify], [extra-points-percentage],
                                                punting_plays, punting_gross_yards, punting_longest_yards, punting_inside_twenty, punting_touchbacks,
                                                kickoff_returns, kickoff_return_yards, kickoff_return_longest_yards, kickoff_return_touchdowns,
                                                punt_returns, punt_return_yards, punt_return_longest_yards, punt_return_touchdowns, punt_return_faircatches)) AS p

        -- calculations
        UPDATE @football
           SET [punting-average] = CAST((CAST(punting_gross_yards AS FLOAT) / punting_plays) AS DECIMAL(6, 2))
         WHERE punting_plays > 0

        UPDATE @football
           SET [kickoff-return-average] = CAST((CAST(kickoff_return_yards AS FLOAT) / kickoff_returns) AS DECIMAL(6, 2))
         WHERE kickoff_returns > 0

        UPDATE @football
           SET [punt-return-average] = CAST((CAST(punt_return_yards AS FLOAT) / punt_returns) AS DECIMAL(6, 2))
         WHERE punt_returns > 0

        -- update special teams
	    UPDATE f
	       SET f.position_regular = sr.position_regular
	      FROM @football f
	     INNER JOIN dbo.SMG_Rosters sr
            ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.team_key = f.team_key AND sr.player_key = f.player_key
                           
	    UPDATE f
	       SET f.name = sp.first_name + ' ' + sp.last_name
	      FROM @football f
	     INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = f.player_key

	    UPDATE f
	       SET f.team = st.team_abbreviation + '|' + ISNULL(st.team_slug, '')
	      FROM @football f
	     INNER JOIN dbo.SMG_Teams st
            ON st.team_key = f.team_key AND st.season_key = @seasonKey

        -- delete no name
        DELETE @football
         WHERE name IS NULL
         
        DELETE @football
         WHERE team IS NULL

        -- leaders
        INSERT INTO @leaders (ribbon, team_key, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'KICKING', team_key, player_key, name, position_regular, [field-goals-percentage] + ' FG%', 'KICKING', 'field-goals-percentage'
          FROM @football
         ORDER BY CONVERT(FLOAT, [field-goals-percentage]) DESC

        INSERT INTO @leaders (ribbon, team_key, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'PUNTING', team_key, player_key, name, position_regular, [punting-average] + ' AVG YDS', 'PUNTING', 'punting-average'
          FROM @football
         ORDER BY CONVERT(FLOAT, [punting-average]) DESC

        INSERT INTO @leaders (ribbon, team_key, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'KICK RETURNING', team_key, player_key, name, position_regular,
               REPLACE(CONVERT(VARCHAR, CAST(kickoff_return_yards AS MONEY), 1), '.00', '') + ' YDS', 'RETURNING', 'kickoff_return_yards'
          FROM @football
         ORDER BY kickoff_return_yards DESC

        -- update leaders
        UPDATE l
           SET l.abbr = st.team_abbreviation, l.team_rgb = st.rgb
          FROM @leaders l
         INNER JOIN dbo.SMG_Teams st
            ON st.team_key = l.team_key AND st.season_key = @seasonKey

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

        -- reference
        INSERT INTO @reference (ribbon, ribbon_node, [column], display)
        VALUES ('KICKING', 'kicking', 'field-goals-percentage', 'PCT'),
               ('PUNTING', 'punting', 'punting-average', 'AVG'),
               ('RETURNING', 'returning', 'kickoff_return_yards', 'YDS')


        SELECT
        (
            SELECT 'SPECIAL TEAMS LEAGUE LEADERS' AS super_ribbon, team_key, team_rgb, abbr, ribbon, name, uniform_number,
                   position_regular, value, head_shot, reference_ribbon, reference_column
              FROM @leaders
               FOR XML RAW('leader'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip, 'desc,asc' AS [sort],
                   CASE
                       WHEN [column] IN ('name', 'team') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type],
                   CASE
                       WHEN [column] IN ('field_goals_attempted', 'extra_point_kicks_attempted') THEN 1
                       ELSE 0
                   END AS qualify            
              FROM @tables
             WHERE ribbon = 'KICKING' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('kicking_column'), TYPE
        ),
        (
            SELECT (CASE 
                       WHEN position_regular IS NULL THEN name
                       ELSE name + ', ' + position_regular
                   END) AS name,
                   team, field_goals_succeeded,
                   CAST(field_goals_attempted AS VARCHAR) + '|' + CAST([field-goals-attempted-qualify] AS VARCHAR) AS field_goals_attempted,
                   [field-goals-percentage], extra_point_kicks_succeeded,
                   CAST(extra_point_kicks_attempted AS VARCHAR) + '|' + CAST([extra-point-kicks-attempted-qualify] AS VARCHAR) AS extra_point_kicks_attempted,
                   [extra-points-percentage]
              FROM @football
             WHERE field_goals_attempted + extra_point_kicks_attempted > 0
             ORDER BY CONVERT(FLOAT, [field-goals-percentage]) DESC
               FOR XML RAW('kicking'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip, 'desc,asc' AS [sort],
                   CASE
                       WHEN [column] IN ('name', 'team') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'PUNTING' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('punting_column'), TYPE
        ),
        (
            SELECT (CASE 
                       WHEN position_regular IS NULL THEN name
                       ELSE name + ', ' + position_regular
                   END) AS name,
                  team, punting_plays, punting_gross_yards, punting_longest_yards, [punting-average],
                  punting_inside_twenty, punting_touchbacks
              FROM @football
             WHERE punting_plays > 0
             ORDER BY CONVERT(FLOAT, [punting-average]) DESC
               FOR XML RAW('punting'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip, 'desc,asc' AS [sort],
                   CASE
                       WHEN [column] IN ('name', 'team') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'RETURNING' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('returning_column'), TYPE
        ),
        (
            SELECT (CASE 
                       WHEN position_regular IS NULL THEN name
                       ELSE name + ', ' + position_regular
                   END) AS name,
                   team, kickoff_returns, kickoff_return_yards, [kickoff-return-average], kickoff_return_longest_yards, kickoff_return_touchdowns,
                   punt_returns, punt_return_yards, [punt-return-average], punt_return_longest_yards, punt_return_touchdowns, punt_return_faircatches
              FROM @football
             WHERE kickoff_returns + punt_returns > 0
             ORDER BY CONVERT(FLOAT, kickoff_return_yards) DESC
               FOR XML RAW('returning'), TYPE
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
        INSERT INTO @tables (ribbon, [column], sub_ribbon, display, tooltip, [order])
        VALUES ('PASSING OFFENSE', 'name', '', 'NAME', 'Player Name and Position', 1),
               ('PASSING OFFENSE', 'team', '', 'TEAM', 'Team', 2),
               ('PASSING OFFENSE', 'passing_plays_completed', '', 'COMP', 'Completions', 3),
               ('PASSING OFFENSE', 'passing_plays_attempted', '', 'ATT', 'Passing Attempts', 4),
               ('PASSING OFFENSE', 'passing-plays-percentage', '', 'PCT', 'Completion Percentage', 5),
               ('PASSING OFFENSE', 'passer_rating', '', 'RAT', 'Passer Rating', 6),
               ('PASSING OFFENSE', 'passing_yards', '', 'YDS', 'Passing Yards', 7),
               ('PASSING OFFENSE', 'passing-yards-per-attempted', '', 'YDS/A', 'Yards Per Pass Attempt', 8),
               ('PASSING OFFENSE', 'passing-yards-per-game', '', 'YDS/G', 'Pass Yards Per Game', 9),
               ('PASSING OFFENSE', 'passing_longest_yards', '', 'LNG', 'Longest Pass', 10),
               ('PASSING OFFENSE', 'passing_touchdowns', '', 'TD', 'Passing Touchdowns', 11),
               ('PASSING OFFENSE', 'passing_plays_intercepted', '', 'INT', 'Interceptions Thrown', 12),
               ('PASSING OFFENSE', 'passing_plays_sacked', '', 'SACK', 'Sacks', 13),
               
               ('RUSHING OFFENSE', 'name', '', 'NAME', 'Player Name and Position', 1),
               ('RUSHING OFFENSE', 'team', '', 'TEAM', 'Team', 2),
               ('RUSHING OFFENSE', 'rushing_plays', '', 'ATT', 'Rushing Attempts', 3),
               ('RUSHING OFFENSE', 'rushing_net_yards', '', 'YDS', 'Rushing Yards', 4),
               ('RUSHING OFFENSE', 'rushing-net-yards-per-play', '', 'YDS/A', 'Yards Per Rush Attempt', 5),
               ('RUSHING OFFENSE', 'rushing_longest_yards', '', 'LNG', 'Longest Rush', 6),
               ('RUSHING OFFENSE', 'rushing-net-yards-per-game', '', 'YDS/G', 'Rushing Yards Per Game', 7),
               ('RUSHING OFFENSE', 'rushing_touchdowns', '', 'TD', 'Rushing Touchdowns', 8),
               ('RUSHING OFFENSE', 'fumbles', '', 'FUM', 'Rushing Fumbles', 9),
               
               ('RECEIVING OFFENSE', 'name', '', 'NAME', 'Player Name and Position', 1),
               ('RECEIVING OFFENSE', 'team', '', 'TEAM', 'Team', 2),
               ('RECEIVING OFFENSE', 'receiving_receptions', '', 'REC', 'Receptions', 3),
               ('RECEIVING OFFENSE', 'receiving_yards', '', 'YDS', 'Receiving Yards', 4),
               ('RECEIVING OFFENSE', 'receiving-yards-per-reception', '', 'AVG', 'Average Yards Per Attempt', 5),
               ('RECEIVING OFFENSE', 'receiving_longest_yards', '', 'LNG', 'Longest Reception', 6),
               ('RECEIVING OFFENSE', 'receiving_yards-per-game', '', 'YDS/G', 'Receiving Yards Per Game', 7),
               ('RECEIVING OFFENSE', 'receiving_touchdowns', '', 'TD', 'Receiving Touchdowns', 8),
               
               ('TOTAL SCORING', 'name', '', 'NAME', 'Player Name and Position', 1),
               ('TOTAL SCORING', 'team', '', 'TEAM', 'Team', 2),
               ('TOTAL SCORING', 'rushing_touchdowns', 'TOUCHDOWNS', 'RUSH', 'Rushing Touchdowns', 4),
               ('TOTAL SCORING', 'receiving_touchdowns', 'TOUCHDOWNS', 'REC', 'Receiving Touchdowns', 5),
               ('TOTAL SCORING', 'interceptions_returned_touchdowns', 'TOUCHDOWNS', 'INT', 'Interceptions Touchdowns', 6),
               ('TOTAL SCORING', 'fumbles_recovered_touchdowns', 'TOUCHDOWNS', 'FUM', 'Fumble Recovery Touchdown', 7),
               ('TOTAL SCORING', 'kickoff_return_touchdowns', 'TOUCHDOWNS', 'KRET', 'Kickoff Return Touchdowns', 8),
               ('TOTAL SCORING', 'punt_return_touchdowns', 'TOUCHDOWNS', 'PRET', 'Punt Return Touchdowns', 9),
               ('TOTAL SCORING', 'total-touchdowns', 'TOUCHDOWNS', 'TOTAL', 'Total Touchdowns', 10),
               ('TOTAL SCORING', 'field_goals_succeeded', 'SCORING', 'FG', 'Field Goals Made', 11),
               ('TOTAL SCORING', 'extra_point_kicks_succeeded', 'SCORING', 'XP', 'Extra Point Made', 12),
               ('TOTAL SCORING', 'points', 'SCORING', 'PTS', 'Total Points', 13),
               ('TOTAL SCORING', 'points-per-game', 'SCORING', 'PTS/G', 'Total Points Per Game', 14)

        IF (@leagueName = 'ncaaf')
        BEGIN
            DELETE @tables
             WHERE [column] IN ('passing_longest_yards', 'rushing_longest_yards', 'receiving_longest_yards', 'points', 'points-per-game')
        END
        
        INSERT INTO @football (team_key, player_key,
                               passing_plays_completed, passing_plays_attempted, passer_rating, passing_yards,
                               [passing-yards-per-game], passing_longest_yards, passing_touchdowns, passing_plays_intercepted, passing_plays_sacked,
                               rushing_plays, rushing_net_yards, [rushing-net-yards-per-game], rushing_longest_yards, rushing_touchdowns, fumbles,
                               receiving_receptions, receiving_yards, [receiving_yards-per-game], receiving_longest_yards, receiving_touchdowns,
                               interceptions_returned_touchdowns, fumbles_recovered_touchdowns, kickoff_return_touchdowns, punt_return_touchdowns,
                               field_goals_succeeded, extra_point_kicks_succeeded, points, [points-per-game])                 
        SELECT p.team_key, p.player_key,
               ISNULL(passing_plays_completed, 0), ISNULL(passing_plays_attempted, 0), passer_rating, passing_yards,
               [passing-yards-per-game], passing_longest_yards, ISNULL(passing_touchdowns, 0), ISNULL(passing_plays_intercepted, 0), ISNULL(passing_plays_sacked, 0),
               ISNULL(rushing_plays, 0), rushing_net_yards, [rushing-net-yards-per-game], rushing_longest_yards, ISNULL(rushing_touchdowns, 0), ISNULL(fumbles, 0),
               ISNULL(receiving_receptions, 0), receiving_yards, [receiving_yards-per-game], receiving_longest_yards, ISNULL(receiving_touchdowns, 0),
               ISNULL(interceptions_returned_touchdowns, 0), ISNULL(fumbles_recovered_touchdowns, 0), ISNULL(kickoff_return_touchdowns, 0), ISNULL(punt_return_touchdowns, 0),
               ISNULL(field_goals_succeeded, 0), ISNULL(extra_point_kicks_succeeded, 0), ISNULL(points, 0), [points-per-game]
          FROM (SELECT team_key, player_key, [column], value FROM @stats) AS s
         PIVOT (MAX(s.value) FOR s.[column] IN (passing_plays_completed, passing_plays_attempted, passer_rating, passing_yards,
                                                [passing-yards-per-game], passing_longest_yards, passing_touchdowns, passing_plays_intercepted, passing_plays_sacked,
                                                rushing_plays, rushing_net_yards, [rushing-net-yards-per-game], rushing_longest_yards, rushing_touchdowns, fumbles,
                                                receiving_receptions, receiving_yards, [receiving_yards-per-game], receiving_longest_yards, receiving_touchdowns,
                                                interceptions_returned_touchdowns, fumbles_recovered_touchdowns, kickoff_return_touchdowns, punt_return_touchdowns,
                                                field_goals_succeeded, extra_point_kicks_succeeded, points, [points-per-game])) AS p

        -- calculations
        UPDATE @football
           SET passer_rating = CAST(passer_rating AS DECIMAL(5, 1))

        UPDATE @football
           SET [passing-plays-percentage] = CAST((100 * CAST(passing_plays_completed AS FLOAT) / passing_plays_attempted) AS DECIMAL(4, 1))
         WHERE passing_plays_completed > 0

        UPDATE @football
           SET [passing-yards-per-attempted] = CAST((CAST(passing_yards AS FLOAT) / passing_plays_attempted) AS DECIMAL(6, 2))
         WHERE passing_plays_attempted > 0

        UPDATE @football
           SET [rushing-net-yards-per-play] = CAST((CAST(rushing_net_yards AS FLOAT) / rushing_plays) AS DECIMAL(6, 2))
         WHERE rushing_plays > 0

        UPDATE @football
           SET [receiving-yards-per-reception] = CAST((CAST(receiving_yards AS FLOAT) / receiving_receptions) AS DECIMAL(6, 2))
         WHERE receiving_receptions > 0

        UPDATE @football
           SET [total-touchdowns] = rushing_touchdowns + receiving_touchdowns + interceptions_returned_touchdowns +
                                    fumbles_recovered_touchdowns + kickoff_return_touchdowns + punt_return_touchdowns

        -- update offense
	    UPDATE f
	       SET f.position_regular = sr.position_regular
	      FROM @football f
	     INNER JOIN dbo.SMG_Rosters sr
            ON sr.league_key = @league_key AND sr.season_key = @seasonKey AND sr.team_key = f.team_key AND sr.player_key = f.player_key
                           
	    UPDATE f
	       SET f.name = sp.first_name + ' ' + sp.last_name
	      FROM @football f
	     INNER JOIN dbo.SMG_Players sp
            ON sp.player_key = f.player_key

	    UPDATE f
	       SET f.team = st.team_abbreviation + '|' + ISNULL(st.team_slug, '')
	      FROM @football f
	     INNER JOIN dbo.SMG_Teams st
            ON st.team_key = f.team_key AND st.season_key = @seasonKey

        -- delete no name
        DELETE @football
         WHERE name IS NULL
         
        DELETE @football
         WHERE team IS NULL

        -- leaders
        INSERT INTO @leaders (ribbon, team_key, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'PASSING OFFENSE', team_key, player_key, name, position_regular, passing_yards, 'PASSING OFFENSE', 'passing_yards'
          FROM @football
         ORDER BY passing_yards DESC

        INSERT INTO @leaders (ribbon, team_key, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'RUSHING OFFENSE', team_key, player_key, name, position_regular, rushing_net_yards, 'RUSHING OFFENSE', 'rushing_net_yards'
          FROM @football
         ORDER BY rushing_net_yards DESC

        INSERT INTO @leaders (ribbon, team_key, player_key, name, position_regular, value, reference_ribbon, reference_column)
        SELECT TOP 1 'RECEIVING OFFENSE', team_key, player_key, name, position_regular, receiving_yards, 'RECEIVING OFFENSE', 'receiving_yards'
          FROM @football
         ORDER BY receiving_yards DESC

        -- update leaders
        UPDATE l
           SET l.abbr = st.team_abbreviation, l.team_rgb = st.rgb
          FROM @leaders l
         INNER JOIN dbo.SMG_Teams st
            ON st.team_key = l.team_key AND st.season_key = @seasonKey

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

        -- reference
        INSERT INTO @reference (ribbon, ribbon_node, [column], display)
        VALUES ('PASSING OFFENSE', 'passing', 'passing_yards', 'YDS'), ('RUSHING OFFENSE', 'rushing', 'rushing_net_yards', 'YDS'),
               ('RECEIVING OFFENSE', 'receiving', 'receiving_yards', 'YDS'), ('TOTAL SCORING', 'scoring', 'total-touchdowns', 'TOTAL')


        SELECT
        (
            SELECT 'OFFENSIVE LEAGUE LEADERS' AS super_ribbon, team_key, team_rgb, abbr, ribbon,
                   name, uniform_number, position_regular,
                   REPLACE(CONVERT(VARCHAR, CAST(value AS MONEY), 1), '.00', '') + ' YDS' AS value, head_shot,
                   reference_ribbon, reference_column
              FROM @leaders
               FOR XML RAW('leader'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip,
                   CASE
                       WHEN [column] IN ('passing_plays_intercepted', 'passing_plays_sacked') THEN 'asc,desc'
                       ELSE 'desc,asc'
                   END AS [sort],
                   CASE
                       WHEN [column] IN ('name', 'team') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'PASSING OFFENSE' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('passing_column'), TYPE
        ),
        (
            SELECT (CASE 
                       WHEN position_regular IS NULL THEN name
                       ELSE name + ', ' + position_regular
                   END) AS name,
                   team, passing_plays_completed, passing_plays_attempted, [passing-plays-percentage], passer_rating,
                   passing_yards, [passing-yards-per-attempted], [passing-yards-per-game],
                   passing_longest_yards, passing_touchdowns, passing_plays_intercepted, passing_plays_sacked
              FROM @football
             WHERE passing_plays_attempted > 0
             ORDER BY passing_yards DESC
               FOR XML RAW('passing'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip,
                   CASE
                       WHEN [column] IN ('fumbles') THEN 'asc,desc'
                       ELSE 'desc,asc'
                   END AS [sort],
                   CASE
                       WHEN [column] IN ('name', 'team') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'RUSHING OFFENSE' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('rushing_column'), TYPE
        ),
        (
            SELECT (CASE 
                       WHEN position_regular IS NULL THEN name
                       ELSE name + ', ' + position_regular
                   END) AS name,
                   team, rushing_plays, rushing_net_yards, [rushing-net-yards-per-play],
                   rushing_longest_yards, [rushing-net-yards-per-game], rushing_touchdowns, fumbles
              FROM @football
             WHERE rushing_plays > 0
             ORDER BY rushing_net_yards DESC
               FOR XML RAW('rushing'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip, 'desc,asc' AS [sort],
                   CASE
                       WHEN [column] IN ('name', 'team') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'RECEIVING OFFENSE' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('receiving_column'), TYPE
        ),
        (
            SELECT (CASE 
                       WHEN position_regular IS NULL THEN name
                       ELSE name + ', ' + position_regular
                   END) AS name,
                   team, receiving_receptions, receiving_yards, [receiving-yards-per-reception],
                   receiving_longest_yards, [receiving_yards-per-game], receiving_touchdowns
              FROM @football
             WHERE receiving_receptions > 0
             ORDER BY CONVERT(FLOAT, receiving_yards) DESC
               FOR XML RAW('receiving'), TYPE
        ),
        (
            SELECT ribbon, sub_ribbon, [column], display, tooltip, 'desc,asc' AS [sort],
                   CASE
                       WHEN [column] IN ('name', 'team') THEN 'string'
                       ELSE 'formatted-num'
                   END AS [type]
              FROM @tables
             WHERE ribbon = 'TOTAL SCORING' AND [order] > 0
             ORDER BY [order] ASC
               FOR XML RAW('scoring_column'), TYPE
        ),
        (
            SELECT (CASE 
                       WHEN position_regular IS NULL THEN name
                       ELSE name + ', ' + position_regular
                   END) AS name,
                   team, rushing_touchdowns, receiving_touchdowns, interceptions_returned_touchdowns,
                   fumbles_recovered_touchdowns, kickoff_return_touchdowns, punt_return_touchdowns,
                   [total-touchdowns],
                   field_goals_succeeded, extra_point_kicks_succeeded, points, [points-per-game]
              FROM @football
             WHERE points > 0 OR ([total-touchdowns] + field_goals_succeeded + extra_point_kicks_succeeded) > 0
             ORDER BY points DESC
               FOR XML RAW('scoring'), TYPE
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
