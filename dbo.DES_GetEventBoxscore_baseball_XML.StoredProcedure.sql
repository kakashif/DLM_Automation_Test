USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetEventBoxscore_baseball_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DES_GetEventBoxscore_baseball_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:		thlam
-- Create date: 02/24/2014
-- Description:	get boxscore for desktop for baseball
-- Update: 04/22/2014 - John Lin - use event position
--		   04/22/2014 - thlam - adding the timestamp for boxscores
--         05/02/2014 - John Lin - add extra stats
--         05/06/2014 - John Lin - extra stats formating
--         05/09/2014 - John Lin - use SMG_Periods
--         09/03/2014 - ikenticus - per JIRA SCI-371, using more stats than at_bats to determine batting table players
--         09/09/2014 - ikenticus: fixing position-event
--         10/02/2014 - John Lin - refactor
--         10/25/2014 - ikenticus - SOC-111: display all batters from game
--         10/28/2014 - ikenticus - SOC-111: display all pinch hitters footnotes from game
--         05/21/2015 - John Lin - expand footnote to max
--         06/02/2015 - ikenticus - adding hit-by-pitch, cought->caught, removing team from extra_display calculations
--         06/05/2015 - ikenticus - using non-xmlteam league_key logic
--         06/24/2015 - ikenticus - adding failover event_key logic for source transitions
--         07/15/2015 - ikenticus - removing empty extras, fixing boxscore footnotes for pitchers/pinch-hitters
--         07/17/2015 - ikenticus - replacing footnote-batting calculations with STATS ingested data
--         07/22/2015 - ikenticus - missing comma in the home_team pitching select
--         08/28/2015 - ikenticus - SDI migration
--         08/31/2015 - ikenticus - fixing zero at-bats with .000 average pinch hitting
--         09/17/2015 - ikenticus: adding recap logic
--         10/13/2015 - ikenticus: adding 0.00 ERA only if no era-season and IP not null
--         10/21/2015 - ikenticus: updating suppression logic in preparation for CMS tool
--         10/22/2015 - ikenticus - fixing BA/ERA formatting when no season data yet, removing TSN position mapping
--         10/26/2015 - ikenticus - adding display_status logic for column suppression
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey('mlb')
    DECLARE @event_key VARCHAR(100)
    DECLARE @event_status VARCHAR(100)
    DECLARE @away_team_key VARCHAR(100)
    DECLARE @home_team_key VARCHAR(100)
    DECLARE @officials VARCHAR(MAX)
	DECLARE @date_time VARCHAR(100)
    DECLARE @recap VARCHAR(100)

    SELECT TOP 1 @event_key = event_key, @event_status = event_status,
           @away_team_key = away_team_key, @home_team_key = home_team_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key,
			   @event_key = event_key, @event_status = event_status,
			   @away_team_key = away_team_key, @home_team_key = home_team_key
		  FROM SportsDB.dbo.SMG_Schedules AS s
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = s.league_key AND m.value_to = @leagueName AND m.value_type = 'league'
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		 ORDER BY league_key DESC
	END

    -- LINESCORE
    DECLARE @linescore TABLE
    (
        period INT,
        period_value VARCHAR(100),
        away_value VARCHAR(100),
        home_value VARCHAR(100)
    )
    INSERT INTO @linescore (period, period_value, away_value, home_value)
    SELECT period, period_value, away_value, home_value
      FROM dbo.SMG_Periods
     WHERE event_key = @event_key
     
    -- BOXSCORE
    DECLARE @tables TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        table_name VARCHAR(100),    
        table_display VARCHAR(100)
    )
    DECLARE @columns TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        table_name     VARCHAR(100),
        column_name    VARCHAR(100),
        column_display VARCHAR(100),
        tooltip        VARCHAR(100)
    )
    DECLARE @stats TABLE
    (
        team_key       VARCHAR(100),
        player_key     VARCHAR(100),
        player_display VARCHAR(100),
        column_name    VARCHAR(100), 
        value          VARCHAR(100)
    )

    INSERT INTO @tables (table_name, table_display)
    VALUES ('batting', 'batting'), ('pitching', 'pitching')
        
    INSERT INTO @columns (table_name, column_name, column_display, tooltip)
    VALUES ('batting', 'player_display', 'PLAYER', 'Player'),
           ('batting', 'at_bats', 'AB', 'At Bats'),
           ('batting', 'runs_scored', 'R', 'Run Scored'),
           ('batting', 'hits', 'H', 'Hits'),
           ('batting', 'rbi', 'RBI', 'RBI'), 
           ('batting', 'bases_on_balls', 'BB', 'Bases On Balls'),
           ('batting', 'strikeouts', 'SO', 'Total Rebounds'),
           ('batting', 'average', 'AVG', 'Batting Average'),

		   ('pitching', 'player_display', 'PLAYER', 'Player'),
		   ('pitching', 'innings_pitched', 'IP', 'Innings Pitched'),
		   ('pitching', 'pitching_hits', 'H', 'Hits Allowed'),
		   ('pitching', 'runs_allowed', 'R', 'Runs Allowed'),
		   ('pitching', 'earned_runs', 'ER', 'Earned Runs'),
		   ('pitching', 'pitching_bases_on_balls', 'BB', 'Bases on Balls'),
		   ('pitching', 'pitching_strikeouts', 'SO', 'Pitching Strikeout'),
		   ('pitching', 'number_of_pitches', 'Pitches', 'Number of Pitches'),
		   ('pitching', 'number_of_strikes', 'Strikes', 'Number of Strikes'),
		   ('pitching', 'era', 'ERA', 'Earned Run Average')

    INSERT INTO @stats (team_key, player_key, column_name, value)
    SELECT team_key, player_key, REPLACE([column], '-', '_'), value 
      FROM SportsEditDB.dbo.SMG_Events_baseball
     WHERE season_key = @seasonKey AND event_key = @event_key

	DECLARE @baseball TABLE
	(
		team_key                 VARCHAR(100),
		player_key               VARCHAR(100),
	    batting_display          VARCHAR(100),
	    pitching_display         VARCHAR(100),
		position_event           VARCHAR(100),
		--batting
		at_bats					 INT,
		runs_scored				 INT,
		hits					 INT,
		rbi						 INT,
		bases_on_balls			 INT,
		strikeouts				 INT,
        average					 VARCHAR(100),
        batting_average_season	 VARCHAR(100),
		-- pitching
		innings_pitched			 VARCHAR(100),
		pitching_hits			 INT,
		runs_allowed			 INT,
		earned_runs				 INT,
		pitching_bases_on_balls	 INT,
		pitching_strikeouts		 INT,
		number_of_pitches		 INT,
		number_of_strikes		 INT,
		era						 VARCHAR(100),
		earned_run_average_season VARCHAR(100),
		-- extra
	    lineup_slot_sequence     INT,
	    lineup_slot              INT,
	    pitching_order           INT,
		event_credit             VARCHAR(100),
		save_credit              VARCHAR(100),
		wins_season              VARCHAR(100),
		losses_season            VARCHAR(100),
		saves_season             VARCHAR(100),
		saves_blown_season       VARCHAR(100),
		holds_season             VARCHAR(100),
		ip_first                 INT,
		ip_second                INT,
	    footnote_id              VARCHAR(100),
	    footnote_display         VARCHAR(100)
	)

	INSERT INTO @baseball (player_key, team_key, position_event, lineup_slot, pitching_order, at_bats, runs_scored, hits, rbi, bases_on_balls, strikeouts,
	                       average, batting_average_season, era, earned_run_average_season,
	                       innings_pitched, pitching_hits, runs_allowed, earned_runs, pitching_bases_on_balls,
	                       pitching_strikeouts, number_of_pitches, number_of_strikes, event_credit, save_credit, wins_season, losses_season,
	                       saves_season, saves_blown_season, holds_season, lineup_slot_sequence)
    SELECT p.player_key, p.team_key, (CASE WHEN CHARINDEX(',', position_event) > 0 THEN UPPER(LEFT(position_event, 1)) ELSE UPPER(position_event) END),
           lineup_slot, pitching_order, ISNULL(at_bats, 0), ISNULL(runs_scored, 0), ISNULL(hits, 0), ISNULL(rbi, 0), ISNULL(bases_on_balls, 0), ISNULL(strikeouts, 0),
           average, batting_average_season, era, earned_run_average_season,
           innings_pitched, ISNULL(pitching_hits, 0), ISNULL(runs_allowed, 0), ISNULL(earned_runs, 0), ISNULL(pitching_bases_on_balls, 0), ISNULL(pitching_strikeouts, 0),
           number_of_pitches, number_of_strikes, event_credit, save_credit, wins_season, losses_season, saves_season, saves_blown_season, holds_season, lineup_slot_sequence
      FROM (SELECT player_key, team_key, column_name, value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.column_name IN (position_event, lineup_slot, pitching_order, at_bats, runs_scored, hits, rbi, bases_on_balls, strikeouts,
                                               average, batting_average_season, era, earned_run_average_season,
			                                   innings_pitched, pitching_hits, runs_allowed, earned_runs, pitching_bases_on_balls, pitching_strikeouts,
			                                   number_of_pitches, number_of_strikes, event_credit, save_credit, wins_season, losses_season,
			                                   saves_season, saves_blown_season, holds_season, lineup_slot_sequence)) AS p

	UPDATE @baseball
	   SET average = batting_average_season
	 WHERE batting_average_season IS NOT NULL

	UPDATE @baseball
	   SET average = REPLACE(CAST(CAST(average AS DECIMAL(6,3)) AS VARCHAR), '0.', '.')
	 WHERE average IS NOT NULL

	UPDATE @baseball
	   SET average = '.000'
	 WHERE average IS NULL

	UPDATE @baseball
	   SET era = earned_run_average_season
	 WHERE earned_run_average_season IS NOT NULL

	UPDATE @baseball
	   SET era = CAST(CAST(era AS DECIMAL(5,2)) AS VARCHAR)
	 WHERE era IS NOT NULL

	UPDATE @baseball
	   SET era = '0.00'
	 WHERE earned_run_average_season IS NULL AND innings_pitched IS NOT NULL


	-- footnotes: pitchers and pinch hitters
	DECLARE @footnotes TABLE (
		team_key VARCHAR(100),
		player_key VARCHAR(100),
		footnote_type VARCHAR(100),
		footnote_display VARCHAR(100),
		footnote_id VARCHAR(100)
	)

	-- pitching footnotes calculated by SMG ingestor sproc
    INSERT INTO @footnotes (team_key, player_key, footnote_type, footnote_display, footnote_id)
    SELECT team_key, player_key, 'footnote-pitching', footnote_pitching, footnote_pitching_id
      FROM (SELECT player_key, team_key, column_name, value FROM @stats) AS s
	 PIVOT (MAX(s.value) FOR s.column_name IN (footnote_pitching, footnote_pitching_id)) AS p

	-- batting footnotes come from STATS
    INSERT INTO @footnotes (team_key, player_key, footnote_type, footnote_display, footnote_id)
    SELECT team_key, player_key, 'footnote-batting', footnote_batting, footnote_batting_id
      FROM (SELECT player_key, team_key, column_name, value FROM @stats) AS s
	 PIVOT (MAX(s.value) FOR s.column_name IN (footnote_batting, footnote_batting_id)) AS p

	UPDATE b
	   SET footnote_id = f.footnote_id, footnote_display = REPLACE(f.footnote_display, '_', ' ')
	  FROM @baseball AS b
	 INNER JOIN @footnotes AS f ON f.team_key = f.team_key AND f.player_key = b.player_key


    -- player
	UPDATE b
	   SET b.batting_display = s.first_name + ' ' + s.last_name, b.pitching_display = s.first_name + ' ' + s.last_name
	  FROM @baseball AS b
	 INNER JOIN SportsDB.dbo.SMG_Players AS s
		ON s.player_key = b.player_key AND s.first_name <> 'TEAM'

    UPDATE @baseball
       SET batting_display = batting_display + ' (' + position_event + ')'
     WHERE position_event IS NOT NULL

  	UPDATE @baseball
	   SET pitching_display = pitching_display + ' (W, ' + wins_season + '-' + losses_season + ')'
     WHERE event_credit = 'win' AND wins_season IS NOT NULL AND wins_season <> '' AND losses_season IS NOT NULL AND losses_season <> ''

  	UPDATE @baseball
	   SET pitching_display = pitching_display + ' (L, ' + wins_season + '-' + losses_season + ')'
     WHERE event_credit = 'loss' AND wins_season IS NOT NULL AND wins_season <> '' AND losses_season IS NOT NULL AND losses_season <> ''

  	UPDATE @baseball
	   SET pitching_display = pitching_display + ' (S, ' + saves_season + ')'
     WHERE save_credit = 'save' AND saves_season IS NOT NULL AND saves_season <> ''

  	UPDATE @baseball
	   SET pitching_display = pitching_display + ' (BS, ' + saves_blown_season + ')'
     WHERE save_credit = 'blown' AND saves_blown_season IS NOT NULL AND saves_blown_season <> ''

  	UPDATE @baseball
	   SET pitching_display = pitching_display + ' (H, ' + holds_season + ')'
     WHERE save_credit = 'hold' AND holds_season IS NOT NULL AND holds_season <> ''

    DELETE @baseball
     WHERE batting_display IS NULL

    DELETE @baseball
     WHERE pitching_display IS NULL



    -- split innings_pitched into ip_first and ip_second
    UPDATE @baseball
       SET ip_first = CAST(CAST(innings_pitched AS DECIMAL(3,1)) AS INT),
           ip_second = CAST(RIGHT(CAST(innings_pitched AS DECIMAL(3,1)), 1) AS INT)



    -- batting
    DECLARE @batting TABLE
    (
        team_key       VARCHAR(100),
        lineup_slot    INT,
        player_display VARCHAR(100),
		at_bats		   INT,
		runs_scored	   INT,
		hits		   INT,
		rbi			   INT,
		bases_on_balls INT,
		strikeouts	   INT,
        average		   VARCHAR(100),
		--extra
        lineup_slot_sequence     INT,
	    footnote_id              VARCHAR(100),
	    footnote_display         VARCHAR(100)
    )
	INSERT INTO @batting (team_key, lineup_slot_sequence, lineup_slot, player_display, at_bats, runs_scored, hits, rbi,
		   bases_on_balls, strikeouts, average, footnote_id, footnote_display)
	SELECT team_key, lineup_slot_sequence, lineup_slot, batting_display, at_bats, runs_scored, hits, rbi,
		   bases_on_balls, strikeouts, average, footnote_id, footnote_display
	  FROM @baseball
     WHERE lineup_slot_sequence > 0 OR lineup_slot > 0

	IF EXISTS (SELECT 1 FROM @batting)
	BEGIN
		INSERT INTO @batting (team_key, player_display, at_bats, runs_scored, hits, rbi, bases_on_balls, strikeouts, average)
		SELECT @away_team_key, 'TEAM', SUM(at_bats), SUM(runs_scored), SUM(hits), SUM(rbi), SUM(bases_on_balls), SUM(strikeouts), '-'
		  FROM @batting
		 WHERE team_key = @away_team_key 

		INSERT INTO @batting (team_key, player_display, at_bats, runs_scored, hits, rbi, bases_on_balls, strikeouts, average)
		SELECT @home_team_key, 'TEAM', SUM(at_bats), SUM(runs_scored), SUM(hits), SUM(rbi), SUM(bases_on_balls), SUM(strikeouts), '-'
		  FROM @batting
		 WHERE team_key = @home_team_key 
	END
	ELSE IF (@eventId <> 999999999)
	BEGIN
		DELETE FROM @tables WHERE table_name = 'batting'
	END

    -- pitching
    DECLARE @pitching TABLE
    (
        team_key                 VARCHAR(100),
        pitching_order           INT,
        ip_first                 INT,
        ip_second                INT,
        player_display           VARCHAR(100),
		innings_pitched			 VARCHAR(100),
		pitching_hits			 INT,
		runs_allowed			 INT,
		earned_runs				 INT,
		pitching_bases_on_balls	 INT,
		pitching_strikeouts		 INT,
		number_of_pitches		 INT,
		number_of_strikes		 INT,
		era						 VARCHAR(100),
	    footnote_id              VARCHAR(100),
	    footnote_display         VARCHAR(100)
    )
	INSERT INTO @pitching (team_key, pitching_order, ip_first, ip_second, player_display, innings_pitched, pitching_hits,
	                       runs_allowed, earned_runs, pitching_bases_on_balls, pitching_strikeouts, number_of_pitches, number_of_strikes, era,
						   footnote_id, footnote_display)
	SELECT team_key, pitching_order, ip_first, ip_second, pitching_display, innings_pitched, pitching_hits,
	       runs_allowed, earned_runs, pitching_bases_on_balls, pitching_strikeouts, number_of_pitches, number_of_strikes, era,
		   footnote_id, footnote_display
	  FROM @baseball
     WHERE pitching_order > 0

	IF EXISTS (SELECT 1 FROM @pitching)
	BEGIN
		INSERT INTO @pitching (team_key, player_display, innings_pitched, pitching_hits, runs_allowed, earned_runs,
		                       pitching_bases_on_balls, pitching_strikeouts, number_of_pitches, number_of_strikes, era)
		SELECT @away_team_key, 'TEAM', CAST((SUM(ip_first) + SUM(ip_second) / 3) AS VARCHAR) + '.' + CAST(SUM(ip_second) % 3 AS VARCHAR),
		       SUM(pitching_hits), SUM(runs_allowed), SUM(earned_runs), SUM(pitching_bases_on_balls), SUM(pitching_strikeouts),
		       SUM(number_of_pitches), SUM(number_of_strikes), '-'
		  FROM @pitching
		 WHERE team_key = @away_team_key 

		INSERT INTO @pitching (team_key, player_display, innings_pitched, pitching_hits, runs_allowed, earned_runs,
		                       pitching_bases_on_balls, pitching_strikeouts, number_of_pitches, number_of_strikes, era)
		SELECT @home_team_key, 'TEAM',  CAST((SUM(ip_first) + SUM(ip_second) / 3) AS VARCHAR) + '.' + CAST(SUM(ip_second) % 3 AS VARCHAR),
		       SUM(pitching_hits), SUM(runs_allowed), SUM(earned_runs), SUM(pitching_bases_on_balls), SUM(pitching_strikeouts),
		       SUM(number_of_pitches), SUM(number_of_strikes), '-'
		  FROM @pitching
		 WHERE team_key = @home_team_key 
	END
	ELSE IF (@eventId <> 999999999)
	BEGIN
		DELETE FROM @tables WHERE table_name = 'pitching'
	END


    -- EXTRA
    DECLARE @extra_stats TABLE
    (
        team_key       VARCHAR(100),
        player_key     VARCHAR(100),
        column_name    VARCHAR(100), 
        value          VARCHAR(100)
    )
    INSERT INTO @extra_stats (team_key, player_key, column_name, value)
    SELECT team_key, player_key, REPLACE([column], '-', '_'), value 
      FROM SportsEditDB.dbo.SMG_Events_baseball
     WHERE season_key = @seasonKey AND event_key = @event_key AND
           [column] IN ('doubles', 'doubles-season', 'triples', 'triples-season', 'home-runs', 'home-runs-season',
                        'sacrifices', 'sac-flies', 'stolen-bases', 'stolen-bases-season', 'stolen-bases-caught',
                        'errors-defense', 'errors-defense-season', 'double-plays', 'errors-wild-pitch',
                        'bases-on-balls-intentional', 'hit-by-pitch')


	DECLARE @extra TABLE
	(
		team_key VARCHAR(100),
		player_key VARCHAR(100),
        -- individual batting
        doubles VARCHAR(100),
        doubles_season VARCHAR(100),
        triples VARCHAR(100),
        triples_season VARCHAR(100),
        home_runs VARCHAR(100),
        home_runs_season VARCHAR(100),
        sacrifices VARCHAR(100),
        sac_flies VARCHAR(100),
        hit_by_pitch VARCHAR(100),
        -- base running
        stolen_bases VARCHAR(100),
        stolen_bases_season VARCHAR(100),
        stolen_bases_caught VARCHAR(100),
        -- fielding
        errors_defense VARCHAR(100),
        errors_defense_season VARCHAR(100),
        double_plays VARCHAR(100),
        -- pitching
        errors_wild_pitch VARCHAR(100),
        bases_on_balls_intentional VARCHAR(100),
        first_name VARCHAR(100),
        last_name VARCHAR(100)
    )
	INSERT INTO @extra (team_key, player_key, doubles, doubles_season, triples, triples_season, home_runs, home_runs_season,
                        sacrifices, sac_flies, hit_by_pitch, stolen_bases, stolen_bases_season, stolen_bases_caught, errors_defense,
                        errors_defense_season, double_plays, errors_wild_pitch, bases_on_balls_intentional)
    SELECT p.team_key, p.player_key, doubles, doubles_season, triples, triples_season, home_runs, home_runs_season, sacrifices,
           sac_flies, hit_by_pitch, stolen_bases, stolen_bases_season, stolen_bases_caught, errors_defense, errors_defense_season,
           double_plays, errors_wild_pitch, bases_on_balls_intentional
      FROM (SELECT player_key, team_key, column_name, value FROM @extra_stats) AS s
     PIVOT (MAX(s.value) FOR s.column_name IN (doubles, doubles_season, triples, triples_season, home_runs, home_runs_season,
                                               sacrifices, sac_flies, hit_by_pitch, stolen_bases, stolen_bases_season, stolen_bases_caught,
                                               errors_defense, errors_defense_season, double_plays, errors_wild_pitch,
                                               bases_on_balls_intentional)) AS p

    UPDATE e
       SET e.first_name = sp.first_name, e.last_name = sp.last_name
      FROM @extra e
     INNER JOIN dbo.SMG_Players sp
        ON sp.player_key = e.player_key

	DELETE @extra
	 WHERE player_key = 'team'

    DECLARE @extra_display TABLE
    (
        team_key VARCHAR(100),
        category VARCHAR(100),
        category_order INT,
        item VARCHAR(100),
        item_display VARCHAR(100),
        item_order INT
    )    
    DECLARE @teams TABLE
    (
        id       INT IDENTITY(1, 1) PRIMARY KEY,
        team_key VARCHAR(100)
    )
    DECLARE @id INT = 1
    DECLARE @max INT
    DECLARE @team_key VARCHAR(100)
    DECLARE @doubles VARCHAR(100)
    DECLARE @triples VARCHAR(100)
    DECLARE @home_runs VARCHAR(100)
    DECLARE @sacrifices VARCHAR(100)
    DECLARE @sac_flies VARCHAR(100)
    DECLARE @hit_by_pitch VARCHAR(100)
    DECLARE @stolen_bases VARCHAR(100)
    DECLARE @stolen_bases_caught VARCHAR(100)
    DECLARE @errors_defense VARCHAR(100)
    DECLARE @double_plays VARCHAR(100)
    DECLARE @errors_wild_pitch VARCHAR(100)
    DECLARE @bases_on_balls_intentional VARCHAR(100)

    INSERT INTO @teams (team_key)
    VALUES (@away_team_key), (@home_team_key)

    SELECT @max = MAX(id)
      FROM @teams
          
    WHILE (@id <= @max)
    BEGIN
        SET @doubles = NULL
        SET @triples = NULL
        SET @home_runs = NULL
        SET @sacrifices = NULL
        SET @sac_flies = NULL
        SET @hit_by_pitch = NULL
        SET @stolen_bases = NULL
        SET @stolen_bases_caught = NULL
        SET @errors_defense = NULL
        SET @double_plays = NULL
        SET @errors_wild_pitch = NULL
        SET @bases_on_balls_intentional = NULL

        SELECT @team_key = team_key
          FROM @teams
         WHERE id = @id

        SELECT @doubles = COALESCE(@doubles + ', ', '') + first_name + ' ' + last_name + ' ' +
               CASE
                   WHEN doubles_season IS NOT NULL THEN doubles + ' (' + doubles_season + ')'
                   ELSE doubles
               END
          FROM @extra
         WHERE team_key = @team_key AND CAST(doubles AS INT) > 0
         
        INSERT INTO @extra_display (team_key, category, category_order, item, item_display, item_order)
        VALUES (@team_key, 'Individual Batting:', 1, 'Doubles:', ISNULL(@doubles, ''), 1)

        SELECT @triples = COALESCE(@triples + ', ', '') + first_name + ' ' + last_name + ' ' +
               CASE
                   WHEN triples_season IS NOT NULL THEN triples + ' (' + triples_season + ')'
                   ELSE triples
               END
          FROM @extra
         WHERE team_key = @team_key AND CAST(triples AS INT) > 0
         
        INSERT INTO @extra_display (team_key, category, category_order, item, item_display, item_order)
        VALUES (@team_key, 'Individual Batting:', 1, 'Triples:', ISNULL(@triples, ''), 2)

        SELECT @home_runs = COALESCE(@home_runs + ', ', '') + first_name + ' ' + last_name + ' ' +
               CASE
                   WHEN home_runs_season IS NOT NULL THEN home_runs + ' (' + home_runs_season + ')'
                   ELSE home_runs
               END
          FROM @extra
         WHERE team_key = @team_key AND CAST(home_runs AS INT) > 0
         
        INSERT INTO @extra_display (team_key, category, category_order, item, item_display, item_order)
        VALUES (@team_key, 'Individual Batting:', 1, 'Home Runs:', ISNULL(@home_runs, ''), 3)

        SELECT @sacrifices = COALESCE(@sacrifices + ', ', '') + first_name + ' ' + last_name + ' ' + sacrifices
          FROM @extra
         WHERE team_key = @team_key AND CAST(sacrifices AS INT) > 0

        INSERT INTO @extra_display (team_key, category, category_order, item, item_display, item_order)
        VALUES (@team_key, 'Individual Batting:', 1, 'Sacrifice Bunts:', ISNULL(@sacrifices, ''), 4)

        SELECT @sac_flies = COALESCE(@sac_flies + ', ', '') + first_name + ' ' + last_name + ' ' + sac_flies
          FROM @extra
         WHERE team_key = @team_key AND CAST(sac_flies AS INT) > 0

        INSERT INTO @extra_display (team_key, category, category_order, item, item_display, item_order)
        VALUES (@team_key, 'Individual Batting:', 1, 'Sacrifice Flies:', ISNULL(@sac_flies, ''), 5)

        SELECT @hit_by_pitch = COALESCE(@hit_by_pitch + ', ', '') + first_name + ' ' + last_name + ' ' + hit_by_pitch
          FROM @extra
         WHERE team_key = @team_key AND CAST(hit_by_pitch AS INT) > 0

        INSERT INTO @extra_display (team_key, category, category_order, item, item_display, item_order)
        VALUES (@team_key, 'Individual Batting:', 1, 'Hit By Pitch:', ISNULL(@hit_by_pitch, ''), 5)

        SELECT @stolen_bases = COALESCE(@stolen_bases + ', ', '') + first_name + ' ' + last_name + ' ' +
               CASE
                   WHEN stolen_bases_season IS NOT NULL THEN stolen_bases + ' (' + stolen_bases_season + ')'
                   ELSE stolen_bases
               END
          FROM @extra
         WHERE team_key = @team_key AND CAST(stolen_bases AS INT) > 0

        INSERT INTO @extra_display (team_key, category, category_order, item, item_display, item_order)
        VALUES (@team_key, 'Base Running:', 2, 'Stolen Bases:', ISNULL(@stolen_bases, ''), 1)

        SELECT @stolen_bases_caught = COALESCE(@stolen_bases_caught + ', ', '') + first_name + ' ' + last_name + ' ' + stolen_bases_caught
          FROM @extra
         WHERE team_key = @team_key AND CAST(stolen_bases_caught AS INT) > 0

        INSERT INTO @extra_display (team_key, category, category_order, item, item_display, item_order)
        VALUES (@team_key, 'Base Running:', 2, 'Caught Stealing:', ISNULL(@stolen_bases_caught, ''), 2)

        SELECT @errors_defense = COALESCE(@errors_defense + ', ', '') + first_name + ' ' + last_name + ' ' + 
               CASE
                   WHEN errors_defense_season IS NOT NULL THEN errors_defense + ' (' + errors_defense_season + ')'
                   ELSE errors_defense
               END
          FROM @extra
         WHERE team_key = @team_key AND CAST(errors_defense AS INT) > 0

        INSERT INTO @extra_display (team_key, category, category_order, item, item_display, item_order)
        VALUES (@team_key, 'Fielding:', 3, 'Errors:', ISNULL(@errors_defense, ''), 1)

        SELECT @double_plays = COALESCE(@double_plays + ', ', '') + first_name + ' ' + last_name + ' ' + double_plays
          FROM @extra
         WHERE team_key = @team_key AND CAST(double_plays AS INT) > 0

        INSERT INTO @extra_display (team_key, category, category_order, item, item_display, item_order)
        VALUES (@team_key, 'Fielding:', 3, 'Double Plays:', ISNULL(@double_plays, ''), 1)
        
        SELECT @errors_wild_pitch = COALESCE(@errors_wild_pitch + ', ', '') + first_name + ' ' + last_name + ' ' + errors_wild_pitch
          FROM @extra
         WHERE team_key = @team_key AND CAST(errors_wild_pitch AS INT) > 0

        INSERT INTO @extra_display (team_key, category, category_order, item, item_display, item_order)
        VALUES (@team_key, 'Pitching:', 4, 'Wild Pitches:', ISNULL(@errors_wild_pitch, ''), 1)

        SELECT @bases_on_balls_intentional = COALESCE(@bases_on_balls_intentional + ', ', '') + first_name + ' ' + last_name + ' ' + bases_on_balls_intentional
          FROM @extra
         WHERE team_key = @team_key AND CAST(bases_on_balls_intentional AS INT) > 0

        INSERT INTO @extra_display (team_key, category, category_order, item, item_display, item_order)
        VALUES (@team_key, 'Pitching:', 4, 'Intentional Walk:', ISNULL(@bases_on_balls_intentional, ''), 2)
                
        SET @id = @id + 1
    END

	-- remove empty extras
	DELETE @extra_display
	 WHERE item_display = ''


    -- officials
    DECLARE @umpires TABLE
    (
        position varchar(100),
        umpire varchar(100),
        [order] INT
    )

    INSERT INTO @umpires (position, umpire)
    SELECT [column], value
      FROM dbo.SMG_Scores
     WHERE event_key = @event_key AND column_type = 'officials'

    UPDATE @umpires
       SET position = 'H', [order] = 1
     WHERE position = 'Home Plate Umpire'
   
    UPDATE @umpires
       SET position = '1B', [order] = 2
     WHERE position = 'First Base Umpire'

    UPDATE @umpires
       SET position = '2B', [order] = 3
     WHERE position = 'Second Base Umpire'

    UPDATE @umpires
       SET position = '3B', [order] = 4
     WHERE position = 'Third Base Umpire'
  
    SELECT @officials = COALESCE(@officials + ', ', '') + position + ': ' + umpire
      FROM @umpires
     ORDER BY [order] ASC
     
    -- DATETIME
	SELECT TOP 1 @date_time = date_time
		  FROM SportsDB.dbo.SMG_Scores
		 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key = @event_key
	ORDER BY date_time DESC

	IF (@event_status = 'post-event')
	BEGIN
		-- Recap
		SELECT @recap = '/sports/' + @leagueName + '/event/' + CAST(@seasonKey AS VARCHAR) + '/' + CAST(@eventId AS VARCHAR) + '/recap/'
		  FROM SportsDB.dbo.SMG_Scores
		 WHERE league_key = @league_key AND season_key = @seasonKey AND event_key = @event_key AND column_type = 'post-event-coverage'
		END

	-- Display Column Status suppression
	IF (@eventID <> '999999999')
	BEGIN
		DELETE c
		  FROM @columns c
		 INNER JOIN SportsEditDB.dbo.SMG_Column_Display_Status s
		    ON s.table_name = c.table_name AND s.column_name = c.column_name
		 WHERE s.platform = 'DES' AND s.page = 'boxscore' AND s.league_name = 'mlb'
		   AND display_status = 'hidden'
	END

    SELECT @officials AS officials, @recap AS recap,
	(
		SELECT t.table_name, t.table_display,
			   (
				   SELECT c.column_name, c.column_display, c.tooltip
					 FROM @columns c
					WHERE c.table_name = t.table_name
					ORDER BY c.id ASC
					  FOR XML PATH('columns'), TYPE
			   ),
			   -- away
               (
                   SELECT player_display, at_bats, runs_scored, hits, rbi, bases_on_balls, strikeouts, average, lineup_slot, lineup_slot_sequence, footnote_id
                     FROM @batting
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'batting'
                    ORDER BY lineup_slot ASC, lineup_slot_sequence ASC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT footnote_id, footnote_display
                     FROM @batting
                    WHERE team_key = @away_team_key AND footnote_id IS NOT NULL AND t.table_name = 'batting'
                    ORDER BY footnote_id ASC
                      FOR XML PATH('away_notes'), TYPE
               ),
               (
                   SELECT player_display, at_bats, runs_scored, hits, rbi, bases_on_balls, strikeouts, average
                     FROM @batting
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'batting'
                      FOR XML PATH('away_total'), TYPE
               ),			   
			   (
				   SELECT ed_c.category, ed_c.item, ed_c.item_display
					 FROM @extra_display ed_c
					WHERE t.table_name = 'batting' AND ed_c.team_key = @away_team_key
					ORDER BY ed_c.category_order ASC, ed_c.item_order ASC
					  FOR XML PATH('away_extra'), TYPE
			   ),
               (
                   SELECT player_display, innings_pitched, pitching_hits, runs_allowed, earned_runs, pitching_bases_on_balls, pitching_strikeouts,
                          number_of_pitches, number_of_strikes, era, footnote_id
                     FROM @pitching
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'pitching'
                    ORDER BY pitching_order ASC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT footnote_id, footnote_display
                     FROM @pitching
                    WHERE team_key = @away_team_key AND footnote_id IS NOT NULL AND t.table_name = 'pitching'
                    ORDER BY footnote_id ASC
                      FOR XML PATH('away_notes'), TYPE
               ),
               (
                   SELECT player_display, innings_pitched, pitching_hits, runs_allowed, earned_runs, pitching_bases_on_balls, pitching_strikeouts,
                          number_of_pitches, number_of_strikes, era
                     FROM @pitching
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'pitching'
                      FOR XML PATH('away_total'), TYPE
               ),
			   -- home
               (
                   SELECT player_display, at_bats, runs_scored, hits, rbi, bases_on_balls, strikeouts, average, lineup_slot, lineup_slot_sequence, footnote_id
                     FROM @batting
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'batting'
                    ORDER BY  lineup_slot ASC, lineup_slot_sequence ASC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT footnote_id, footnote_display
                     FROM @batting
                    WHERE team_key = @home_team_key AND footnote_id IS NOT NULL AND t.table_name = 'batting'
                    ORDER BY footnote_id ASC
                      FOR XML PATH('home_notes'), TYPE
               ),
               (
                   SELECT player_display, at_bats, runs_scored, hits, rbi, bases_on_balls, strikeouts, average
                     FROM @batting
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'batting'
                      FOR XML PATH('home_total'), TYPE
               ),
			   (
				   SELECT ed_c.category, ed_c.item, ed_c.item_display
					 FROM @extra_display ed_c
					WHERE t.table_name = 'batting' AND ed_c.team_key = @home_team_key
					ORDER BY ed_c.category_order ASC, ed_c.item_order ASC
					  FOR XML PATH('home_extra'), TYPE
			   ),
               (
                   SELECT player_display, innings_pitched, pitching_hits, runs_allowed, earned_runs, pitching_bases_on_balls, pitching_strikeouts,
                          number_of_pitches, number_of_strikes, era, footnote_id
                     FROM @pitching
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'pitching'
                    ORDER BY pitching_order ASC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT footnote_id, footnote_display
                     FROM @pitching
                    WHERE team_key = @home_team_key AND footnote_id IS NOT NULL AND t.table_name = 'pitching'
                    ORDER BY footnote_id ASC
                      FOR XML PATH('home_notes'), TYPE
               ),
               (
                   SELECT player_display, innings_pitched, pitching_hits, runs_allowed, earned_runs, pitching_bases_on_balls, pitching_strikeouts,
                          number_of_pitches, number_of_strikes, era
                     FROM @pitching
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'pitching'
                      FOR XML PATH('home_total'), TYPE
               )
		  FROM @tables t
		 ORDER BY t.id ASC
		   FOR XML PATH('boxscore'), TYPE
	),
	(
	    SELECT (
                   SELECT period_value AS periods
                     FROM @linescore
                    ORDER BY period ASC
                      FOR XML PATH(''), TYPE
               ),
               (
                   SELECT away_value AS away_sub_score
                     FROM @linescore
                    ORDER BY period ASC
                      FOR XML PATH(''), TYPE
               ),
               (
                   SELECT home_value AS home_sub_score
                     FROM @linescore
                    ORDER BY period ASC
                      FOR XML PATH(''), TYPE
               )                   
           FOR XML PATH('linescore'), TYPE
    ),
	(
		SELECT @date_time        
           FOR XML PATH('updated_date'), TYPE
	)
	FOR XML PATH(''), ROOT('root')


    SET NOCOUNT OFF;
END

GO
