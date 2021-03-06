USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetEventBoxscore_football_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DES_GetEventBoxscore_football_XML]
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:		Thomas Lam
-- Create date: 06/02/2014
-- Description:	get boxscore for desktop for football
--				09/03/2014 - ikenticus: calculating missing TEAM PCT, AVG, LG; fixing @kick_returns
--				09/04/2014 - ikenticus - removing tables for empty boxscore stats
--              09/09/2014 - John Lin - defense_sack_yards changed to VARCHAR
--              09/09/2014 - ikenticus - fixing kick_returns AVG and LNG
--              11/13/2014 - ikenticus - turnovers = passing_plays_intercepted + fumbles_lost
--				06/24/2015 - ikenticus - adding failover event_key logic for source transitions
--              07/30/2015 - John Lin - SDI migration
--				09/17/2015 - ikenticus: adding recap logic
--				10/21/2015 - ikenticus: updating suppression logic in preparation for CMS tool
--				10/26/2015 - ikenticus - adding display_status logic for column suppression
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @event_key VARCHAR(100)
    DECLARE @sub_season_type VARCHAR(100)
    DECLARE @event_status VARCHAR(100)
    DECLARE @away_team_key VARCHAR(100)
    DECLARE @home_team_key VARCHAR(100)
    DECLARE @officials VARCHAR(100)
	DECLARE @date_time VARCHAR(100)
    DECLARE @recap VARCHAR(100)
   
    SELECT TOP 1 @event_key = event_key, @sub_season_type = sub_season_type, @event_status = event_status,
		   @away_team_key = away_team_key, @home_team_key = home_team_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key,
			   @event_key = event_key, @sub_season_type = sub_season_type, @event_status = event_status,
			   @away_team_key = away_team_key, @home_team_key = home_team_key
		  FROM SportsDB.dbo.SMG_Schedules AS s
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = s.league_key AND m.value_to = @leagueName AND m.value_type = 'league'
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		 ORDER BY league_key DESC
	END

    -- LINESCORE
    DECLARE @linescore TABLE
    (
        period       INT,
        period_value VARCHAR(100),
        away_value   VARCHAR(100),
        home_value   VARCHAR(100)
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
    INSERT INTO @tables (table_name, table_display)
    VALUES ('passing', 'passing'), ('rushing', 'rushing'), ('receiving', 'receiving'), ('tackles', 'tackles'), ('interceptions', 'interceptions'),
           ('fumbles', 'fumbles'), ('punting', 'punting'), ('punt_returns', 'Punt Returns'), ('kicking', 'Kicking'), ('kick_returns', 'Kick Returns')

    DECLARE @columns TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        table_name     VARCHAR(100),
        column_name    VARCHAR(100),
        column_display VARCHAR(100)
    )
    INSERT INTO @columns (table_name, column_name, column_display)
    VALUES ('passing', 'player_display', 'PLAYER'),
           ('passing', 'passing_plays_completed_attempted', 'C/ATT'),
           ('passing', 'passing_yards', 'YDS'),
           ('passing', 'passing_percentage', 'PCT%'),
           ('passing', 'passing_touchdowns', 'TD'),
           ('passing', 'passing_plays_intercepted', 'INT'),
           
           ('rushing', 'player_display', 'PLAYER'),
           ('rushing', 'rushing_plays', 'CAR'),
           ('rushing', 'rushing_net_yards', 'YDS'),
           ('rushing', 'rushing_average_yards', 'AVG'),
           ('rushing', 'rushing_touchdowns', 'TD'),
           ('rushing', 'rushing_longest_yards', 'LG'),
           
           ('receiving', 'player_display', 'PLAYER'),
           ('receiving', 'receiving_receptions', 'REC'),
           ('receiving', 'receiving_yards', 'YDS'),
           ('receiving', 'receiving_average_yards', 'AVG'),
           ('receiving', 'receiving_touchdowns', 'TD'),
           ('receiving', 'receiving_longest_yards', 'LG'),

           ('tackles', 'player_display', 'PLAYER'),
           ('tackles', 'tackles_total', 'TKL'),
           ('tackles', 'defense_solo_tackles', 'SOL'),
           ('tackles', 'defense_assisted_tackles', 'AST'),
           ('tackles', 'defense_defense_sack_yards', 'SK-YD'),
               
           ('interceptions', 'player_display', 'PLAYER'),
           ('interceptions', 'defense_interceptions', 'INT'),
           ('interceptions', 'defense_interception_yards', 'YDS'),
           ('interceptions', 'interception_returned_average_yards', 'AVG'),
           ('interceptions', 'interception_returned_longest_yards', 'LG'),
           ('interceptions', 'interceptions_returned_touchdowns', 'TD'),

           ('fumbles', 'player_display', 'PLAYER'),
           ('fumbles', 'fumbles', 'FUM'),
           ('fumbles', 'fumbles_lost', 'LOST'),
           ('fumbles', 'fumbles_recovered_lost_by_opposition', 'REC'),
           ('fumbles', 'fumbles_yards', 'YDS'),
           
           ('punting', 'player_display', 'PLAYER'),
           ('punting', 'punting_plays', 'TOT'),
           ('punting', 'punting_gross_yards', 'YDS'),
           ('punting', 'punting_average_yards', 'AVG'),
           ('punting', 'punting_inside_twenty', '-20'),
           
           ('punt_returns', 'player_display', 'PLAYER'),
           ('punt_returns', 'punt_returns', 'TOT'),
           ('punt_returns', 'punt_return_yards', 'YDS'),
           ('punt_returns', 'punt_return_average_yards', 'AVG'),
           ('punt_returns', 'punt_return_longest_yards', 'LG'),
           ('punt_returns', 'punt_return_touchdowns', 'TD'),
           
           ('kicking', 'player_display', 'PLAYER'),
           ('kicking', 'field_goals_succeeded_attempted', 'FG'),
           ('kicking', 'field_goals_succeeded_longest_yards', 'LG'),
           ('kicking', 'extra_point_kicks_succeeded_attempted', 'XP'),
           
           ('kick_returns', 'player_display', 'PLAYER'),
           ('kick_returns', 'kickoff_returns', 'TOT'),
           ('kick_returns', 'kickoff_return_yards', 'YDS'),
           ('kick_returns', 'kickoff_return_average_yards', 'AVG'),
           ('kick_returns', 'kickoff_return_longest_yards', 'LG'),
           ('kick_returns', 'kickoff_return_touchdowns', 'TD')

    IF (@leagueName = 'ncaaf')
    BEGIN
        DELETE @columns
         WHERE column_name IN ('rushing_longest_yards', 'receiving_longest_yards', 'interception_returned_longest_yards')
    END

    DECLARE @stats TABLE
    (
        team_key       VARCHAR(100),
        player_key     VARCHAR(100),
        player_display VARCHAR(100),
        column_name    VARCHAR(100), 
        value          VARCHAR(100)
    )
    INSERT INTO @stats (team_key, player_key, column_name, value)
    SELECT team_key, player_key, [column], value 
      FROM SportsEditDB.dbo.SMG_Events_football
     WHERE league_key = @league_key AND season_key = @seasonKey AND sub_season_type = @sub_season_type AND event_key = @event_key

    DECLARE @football TABLE
	(
		team_key       VARCHAR(100),
		player_key     VARCHAR(100),
	    player_display VARCHAR(100),
        -- passing --
        passing_plays_completed   INT,
        passing_plays_attempted   INT,
        passing_yards             INT,
        passing_touchdowns        INT,
        passing_plays_intercepted INT,
        -- rushing --
        rushing_plays         INT,
        rushing_net_yards     INT,
        rushing_touchdowns    INT,
        rushing_longest_yards INT,
        -- receiving --
        receiving_receptions    INT,
        receiving_yards         INT,
        receiving_touchdowns    INT,
        receiving_longest_yards INT,
        -- tackles --
        defense_solo_tackles    INT,
        defense_assisted_tackles INT,
        defense_sacks     VARCHAR(100),
        defense_sack_yards     VARCHAR(100),
        -- interceptions --
        defense_interceptions               INT,
        defense_interception_yards          INT,
        interception_returned_longest_yards INT,
        interceptions_returned_touchdowns   INT,
        -- fumbles --
        fumbles                               INT,
        fumbles_lost                          INT,
        fumbles_recovered_lost_by_opposition  INT,
        fumbles_recovered_yards_defense       INT,
        fumbles_recovered_yards_special_teams INT,
        fumbles_recovered_yards_other         INT,        
        -- punting --
        punting_plays         INT,
        punting_gross_yards   INT,
        punting_inside_twenty INT,
        -- punt_returns --
        punt_returns              INT,
        punt_return_yards         INT,
        punt_return_longest_yards INT,
        punt_return_touchdowns    INT,
        -- kicking --
        field_goals_succeeded               INT,
        field_goals_attempted               INT,
        field_goals_succeeded_longest_yards INT,
        extra_point_kicks_succeeded         INT,
        extra_point_kicks_attempted         INT,
        -- kick-returns --
        kickoff_returns              INT,
        kickoff_return_yards         INT,
        kickoff_return_longest_yards VARCHAR(100),
        kickoff_return_touchdowns    INT,
        -- team
        total_first_downs       INT,
        passing_first_downs     INT,
        rushing_first_downs     INT,
        penalty_first_downs     INT,
        third_downs_succeeded   INT,
        third_downs_attempted   INT,
        fourth_downs_succeeded  INT,
        fourth_downs_attempted  INT,
        passing_gross_yards     INT,
        passing_net_yards       INT,        
        rushing_gross_yards     INT,        
        passing_plays_sacked    INT,
        passing_sacked_yards    INT,
        penalties               INT,
        penalty_yards           INT,
        time_of_possession_secs INT
	)

                           
	INSERT INTO @football (player_key, team_key, 
	                       passing_plays_completed, passing_plays_attempted, passing_yards, passing_touchdowns, passing_plays_intercepted,
                           rushing_plays, rushing_net_yards, rushing_touchdowns, rushing_longest_yards,
                           receiving_receptions, receiving_yards, receiving_touchdowns, receiving_longest_yards,
                           defense_solo_tackles, defense_assisted_tackles, defense_sacks, defense_sack_yards,
                           defense_interceptions, defense_interception_yards, interception_returned_longest_yards, interceptions_returned_touchdowns,
                           fumbles, fumbles_lost, fumbles_recovered_lost_by_opposition, fumbles_recovered_yards_defense, fumbles_recovered_yards_special_teams, fumbles_recovered_yards_other,
                           punting_plays, punting_gross_yards, punting_inside_twenty,
                           punt_returns, punt_return_yards, punt_return_longest_yards, punt_return_touchdowns,
                           field_goals_succeeded, field_goals_attempted, field_goals_succeeded_longest_yards, extra_point_kicks_succeeded, extra_point_kicks_attempted,
                           kickoff_returns, kickoff_return_yards, kickoff_return_longest_yards, kickoff_return_touchdowns,
                           total_first_downs, passing_first_downs, rushing_first_downs, penalty_first_downs,
                           third_downs_succeeded, third_downs_attempted,
                           fourth_downs_succeeded, fourth_downs_attempted,
                           passing_gross_yards, passing_net_yards, rushing_gross_yards, passing_plays_sacked, passing_sacked_yards,
                           penalties, penalty_yards, time_of_possession_secs)
    SELECT p.player_key, p.team_key,
           ISNULL(passing_plays_completed, 0), ISNULL(passing_plays_attempted, 0), ISNULL(passing_yards, 0), ISNULL(passing_touchdowns, 0), ISNULL(passing_plays_intercepted, 0),
           ISNULL(rushing_plays, 0), ISNULL(rushing_net_yards, 0), ISNULL(rushing_touchdowns, 0), ISNULL(rushing_longest_yards, 0),
           ISNULL(receiving_receptions, 0), receiving_yards, ISNULL(receiving_touchdowns, 0), ISNULL(receiving_longest_yards, 0),
           ISNULL(defense_solo_tackles, 0), ISNULL(defense_assisted_tackles, 0), ISNULL(defense_sacks, 0), ISNULL(defense_sack_yards, 0),
           ISNULL(defense_interceptions, 0), ISNULL(defense_interception_yards, 0), ISNULL(interception_returned_longest_yards, 0), ISNULL(interceptions_returned_touchdowns, 0),
           ISNULL(fumbles, 0), ISNULL(fumbles_lost, 0), ISNULL(fumbles_recovered_lost_by_opposition, 0), ISNULL(fumbles_recovered_yards_defense, 0), ISNULL(fumbles_recovered_yards_special_teams, 0), ISNULL(fumbles_recovered_yards_other, 0),
           ISNULL(punting_plays, 0), ISNULL(punting_gross_yards, 0), ISNULL(punting_inside_twenty, 0),
           ISNULL(punt_returns, 0), ISNULL(punt_return_yards, 0), ISNULL(punt_return_longest_yards, 0), ISNULL(punt_return_touchdowns, 0),
           ISNULL(field_goals_succeeded, 0), ISNULL(field_goals_attempted, 0), field_goals_succeeded_longest_yards, ISNULL(extra_point_kicks_succeeded, 0), ISNULL(extra_point_kicks_attempted, 0),
           ISNULL(kickoff_returns, 0), ISNULL(kickoff_return_yards, 0), ISNULL(kickoff_return_longest_yards, 0), ISNULL(kickoff_return_touchdowns, 0),
           ISNULL(total_first_downs, 0), ISNULL(passing_first_downs, 0), ISNULL(rushing_first_downs, 0), ISNULL(penalty_first_downs, 0),
           ISNULL(third_downs_succeeded, 0), ISNULL(third_downs_attempted, 0),
           ISNULL(fourth_downs_succeeded, 0), ISNULL(fourth_downs_attempted, 0),
           ISNULL(passing_gross_yards, 0), ISNULL(passing_net_yards, 0), ISNULL(rushing_gross_yards, 0), ISNULL(passing_plays_sacked, 0), ISNULL(passing_sacked_yards, 0),
           ISNULL(penalties, 0), ISNULL(penalty_yards, 0), time_of_possession_secs
      FROM (SELECT player_key, team_key, column_name, value FROM @stats) AS s
     PIVOT (MAX(s.value) FOR s.column_name IN (passing_plays_completed, passing_plays_attempted, passing_yards, passing_touchdowns, passing_plays_intercepted,
                                               rushing_plays, rushing_net_yards, rushing_touchdowns, rushing_longest_yards,
                                               receiving_receptions, receiving_yards, receiving_touchdowns, receiving_longest_yards,
                                               defense_solo_tackles, defense_assisted_tackles, defense_sacks, defense_sack_yards,
                                               defense_interceptions, defense_interception_yards, interception_returned_longest_yards, interceptions_returned_touchdowns,
                                               fumbles, fumbles_lost, fumbles_recovered_lost_by_opposition, fumbles_recovered_yards_defense, fumbles_recovered_yards_special_teams, fumbles_recovered_yards_other,
                                               punting_plays, punting_gross_yards, punting_inside_twenty,
                                               punt_returns, punt_return_yards, punt_return_longest_yards, punt_return_touchdowns,
                                               field_goals_succeeded, field_goals_attempted, field_goals_succeeded_longest_yards, extra_point_kicks_succeeded, extra_point_kicks_attempted,
                                               kickoff_returns, kickoff_return_yards, kickoff_return_longest_yards, kickoff_return_touchdowns,
                                               total_first_downs, passing_first_downs, rushing_first_downs, penalty_first_downs,
                                               third_downs_succeeded, third_downs_attempted,
                                               fourth_downs_succeeded, fourth_downs_attempted,
                                               passing_gross_yards, passing_net_yards, rushing_gross_yards, passing_plays_sacked, passing_sacked_yards,
                                               penalties, penalty_yards, time_of_possession_secs)) AS p

    -- team
    -- head to head
    DECLARE @head2head TABLE
    (
        id INT IDENTITY(1, 1) PRIMARY KEY,
        display     VARCHAR(100),
        away_value  VARCHAR(100),
        home_value  VARCHAR(100),
        column_name VARCHAR(100),
        parent      INT
    )    
    INSERT INTO @head2head (display, column_name, parent)
    VALUES ('1st Downs', 'total_first_downs', 1),
           ('Passing 1st downs', 'passing_first_downs', 0),
           ('Rushing 1st downs', 'rushing_first_downs', 0),
           ('1st downs from penalties', 'penalty_first_downs', 0),
           ('3rd down efficiency', '', 0),
           ('4th down efficiency', '', 0),
           ('Total Yards', '', 1),
           ('Yards Per Offensive Play', '', 0),
           ('Passing', 'passing_net_yards', 1),
           ('Comp - Att', '', 0),
           ('Yards per completion', '', 0),
           ('Sacked (number - yards)', '', 0),
           ('Rushing', 'rushing_net_yards', 1),
           ('Rushing carries', 'rushing_plays', 0),
           ('Yards per carry', '', 0),
           ('Penalties - Yards', '', 1),
           ('Turnovers', '', 1),
           ('Fumbles - Fumbles lost', '', 0),
           ('Interceptions thrown', 'passing_plays_intercepted', 0),
           ('Possession', '', 1)

    UPDATE h2h
       SET h2h.away_value = s.value
      FROM @head2head h2h
     INNER JOIN @stats s
        ON s.column_name = h2h.column_name AND s.team_key = @away_team_key AND s.player_key = 'team'

    UPDATE h2h
       SET h2h.home_value = s.value
      FROM @head2head h2h
     INNER JOIN @stats s
        ON s.column_name = h2h.column_name AND s.team_key = @home_team_key AND s.player_key = 'team'

    -- default
    UPDATE @head2head
       SET away_value = 0
     WHERE column_name = 'penalty_first_downs' AND away_value IS NULL

    UPDATE @head2head
       SET home_value = 0
     WHERE column_name = 'penalty_first_downs' AND home_value IS NULL

    UPDATE @head2head
       SET away_value = (SELECT CAST(third_downs_succeeded AS VARCHAR) + '-' + CAST(third_downs_attempted AS VARCHAR) + ' (' +
                                CASE
                                    WHEN third_downs_attempted = 0 THEN '0'
                                    ELSE CAST(ROUND((100 * CAST(third_downs_succeeded AS FLOAT) / third_downs_attempted), 0) AS VARCHAR)
                                END + '%)'
                           FROM @football WHERE team_key = @away_team_key AND player_key = 'team'),
           home_value = (SELECT CAST(third_downs_succeeded AS VARCHAR) + '-' + CAST(third_downs_attempted AS VARCHAR) + ' (' +
                                CASE
                                    WHEN third_downs_attempted = 0 THEN '0'
                                    ELSE CAST(ROUND((100 * CAST(third_downs_succeeded AS FLOAT) / third_downs_attempted), 0) AS VARCHAR)
                                END + '%)'
                           FROM @football WHERE team_key = @home_team_key AND player_key = 'team')
     WHERE display = '3rd down efficiency'

    UPDATE @head2head
       SET away_value = (SELECT CAST(fourth_downs_succeeded AS VARCHAR) + '-' + CAST(fourth_downs_attempted AS VARCHAR) + ' (' +
                                CASE
                                    WHEN fourth_downs_attempted = 0 THEN '0'
                                    ELSE CAST(ROUND((100 * CAST(fourth_downs_succeeded AS FLOAT) / fourth_downs_attempted), 0) AS VARCHAR)
                                END + '%)'
                           FROM @football WHERE team_key = @away_team_key AND player_key = 'team'),
           home_value = (SELECT CAST(fourth_downs_succeeded AS VARCHAR) + '-' + CAST(fourth_downs_attempted AS VARCHAR) + ' (' +
                                CASE
                                    WHEN fourth_downs_attempted = 0 THEN '0'
                                    ELSE CAST(ROUND((100 * CAST(fourth_downs_succeeded AS FLOAT) / fourth_downs_attempted), 0) AS VARCHAR)
                                END + '%)'
                           FROM @football WHERE team_key = @home_team_key AND player_key = 'team')
     WHERE display = '4th down efficiency'
    
    UPDATE @head2head
       SET away_value = (SELECT passing_net_yards + rushing_net_yards
                           FROM @football WHERE team_key = @away_team_key AND player_key = 'team'),
           home_value = (SELECT passing_net_yards + rushing_net_yards
                           FROM @football WHERE team_key = @home_team_key AND player_key = 'team')
     WHERE display = 'Total Yards'

    UPDATE @head2head
       SET away_value = (SELECT CAST(ROUND(CAST(passing_net_yards + rushing_net_yards AS FLOAT) / (passing_plays_attempted + rushing_plays + passing_plays_sacked), 1) AS DECIMAL(4, 1))
                           FROM @football WHERE team_key = @away_team_key AND player_key = 'team'),
           home_value = (SELECT CAST(ROUND(CAST(passing_net_yards + rushing_net_yards AS FLOAT) / (passing_plays_attempted + rushing_plays + passing_plays_sacked), 1) AS DECIMAL(4, 1))
                           FROM @football WHERE team_key = @home_team_key AND player_key = 'team')
     WHERE display = 'Yards Per Offensive Play'

    UPDATE @head2head
       SET away_value = (SELECT CAST(passing_plays_completed AS VARCHAR) + '-' + CAST(passing_plays_attempted AS VARCHAR)
                           FROM @football WHERE team_key = @away_team_key AND player_key = 'team'),
           home_value = (SELECT CAST(passing_plays_completed AS VARCHAR) + '-' + CAST(passing_plays_attempted AS VARCHAR)
                           FROM @football WHERE team_key = @home_team_key AND player_key = 'team')
      WHERE display = 'Comp - Att'

    UPDATE @head2head
       SET away_value = (SELECT CAST(CAST(passing_gross_yards AS FLOAT) / passing_plays_completed AS DECIMAL(4, 1))
                           FROM @football WHERE team_key = @away_team_key AND player_key = 'team'),
           home_value = (SELECT CAST(CAST(passing_gross_yards AS FLOAT) / passing_plays_completed AS DECIMAL(4, 1))
                           FROM @football WHERE team_key = @home_team_key AND player_key = 'team')
      WHERE display = 'Yards per completion'

    UPDATE @head2head
       SET away_value = (SELECT CAST(passing_plays_sacked AS VARCHAR) + '-' + CAST(passing_sacked_yards AS VARCHAR)
                           FROM @football WHERE team_key = @away_team_key AND player_key = 'team'),
           home_value = (SELECT CAST(passing_plays_sacked AS VARCHAR) + '-' + CAST(passing_sacked_yards AS VARCHAR)
                           FROM @football WHERE team_key = @home_team_key AND player_key = 'team')
      WHERE display = 'Sacked (number - yards)'

    UPDATE @head2head
       SET away_value = (SELECT CAST(CAST(rushing_net_yards AS FLOAT) / rushing_plays AS DECIMAL(4, 1))
                           FROM @football WHERE team_key = @away_team_key AND player_key = 'team'),
           home_value = (SELECT CAST(CAST(rushing_net_yards AS FLOAT) / rushing_plays AS DECIMAL(4, 1))
                           FROM @football WHERE team_key = @home_team_key AND player_key = 'team')
      WHERE display = 'Yards per carry'

    UPDATE @head2head
       SET away_value = (SELECT CAST(penalties AS VARCHAR) + '-' + CAST(penalty_yards AS VARCHAR)
                           FROM @football WHERE team_key = @away_team_key AND player_key = 'team'),
           home_value = (SELECT CAST(penalties AS VARCHAR) + '-' + CAST(penalty_yards AS VARCHAR)
                           FROM @football WHERE team_key = @home_team_key AND player_key = 'team')
      WHERE display = 'Penalties - Yards'

    UPDATE @head2head
       SET away_value = (SELECT passing_plays_intercepted + fumbles
                           FROM @football WHERE team_key = @away_team_key AND player_key = 'team'),
           home_value = (SELECT passing_plays_intercepted + fumbles
                           FROM @football WHERE team_key = @home_team_key AND player_key = 'team')
      WHERE display = 'Turnovers'

    UPDATE @head2head
       SET away_value = (SELECT CAST(fumbles AS VARCHAR) + '-' + CAST(fumbles_lost AS VARCHAR)
                           FROM @football WHERE team_key = @away_team_key AND player_key = 'team'),
           home_value = (SELECT CAST(fumbles AS VARCHAR) + '-' + CAST(fumbles_lost AS VARCHAR)
                           FROM @football WHERE team_key = @home_team_key AND player_key = 'team')
      WHERE display = 'Fumbles - Fumbles lost'

    UPDATE @head2head
       SET away_value = (SELECT CAST((time_of_possession_secs / 60) AS VARCHAR) + ':' +
                                CASE
                                    WHEN time_of_possession_secs % 60 > 10 THEN CAST((time_of_possession_secs % 60) AS VARCHAR)
                                    ELSE '0' + CAST((time_of_possession_secs % 60) AS VARCHAR)
                                END
                           FROM @football WHERE team_key = @away_team_key AND player_key = 'team'),
           home_value = (SELECT CAST((time_of_possession_secs / 60) AS VARCHAR) + ':' +
                                CASE
                                    WHEN time_of_possession_secs % 60 > 9 THEN CAST((time_of_possession_secs % 60) AS VARCHAR)
                                    ELSE '0' + CAST((time_of_possession_secs % 60) AS VARCHAR)
                                END
                           FROM @football WHERE team_key = @home_team_key AND player_key = 'team')
      WHERE display = 'Possession'



                         

    -- player
	UPDATE f
	   SET f.player_display = (CASE
	                              WHEN s.last_name IS NOT NULL THEN s.first_name + ' ' + s.last_name
	                           END)
	  FROM @football AS f
	 INNER JOIN SportsDB.dbo.SMG_Players AS s
		ON s.player_key = f.player_key AND s.first_name <> 'TEAM'

    DELETE @football
     WHERE player_display IS NULL


    -- passing
    DECLARE @passing TABLE
    (
        team_key                  VARCHAR(100),
        player_display            VARCHAR(100),
        passing_plays_completed   INT,
        passing_plays_attempted   INT,
        passing_yards             INT,
        passing_percentage        VARCHAR(100),
        passing_touchdowns        INT,
        passing_plays_intercepted INT
    )
	INSERT INTO @passing (team_key, player_display, passing_plays_completed, passing_plays_attempted, passing_yards, passing_percentage, passing_touchdowns, passing_plays_intercepted)
	SELECT team_key, player_display, passing_plays_completed, passing_plays_attempted, passing_yards,
	       CAST((100 * CAST(passing_plays_completed AS FLOAT) / passing_plays_attempted) AS DECIMAL(4,1)),
	       passing_touchdowns, passing_plays_intercepted
	  FROM @football
     WHERE player_key <> 'team' AND passing_plays_attempted > 0

	IF ((SELECT COUNT(*) FROM @passing) > 0)
	BEGIN
		INSERT INTO @passing (team_key, player_display, passing_plays_completed, passing_plays_attempted, passing_yards, passing_percentage, passing_touchdowns, passing_plays_intercepted)
		SELECT @away_team_key, 'TEAM', SUM(passing_plays_completed), SUM(passing_plays_attempted), SUM(passing_yards),
		       CAST(100 * CAST(SUM(passing_plays_completed) AS FLOAT) / SUM(passing_plays_attempted) AS DECIMAL(4,1)),
		       SUM(passing_touchdowns), SUM(passing_plays_intercepted)
		  FROM @passing
		 WHERE team_key = @away_team_key 

		INSERT INTO @passing (team_key, player_display, passing_plays_completed, passing_plays_attempted, passing_yards, passing_percentage, passing_touchdowns, passing_plays_intercepted)
		SELECT @home_team_key, 'TEAM', SUM(passing_plays_completed), SUM(passing_plays_attempted), SUM(passing_yards),
		       CAST(100 * CAST(SUM(passing_plays_completed) AS FLOAT) / SUM(passing_plays_attempted) AS DECIMAL(4,1)),
		       SUM(passing_touchdowns), SUM(passing_plays_intercepted)
		  FROM @passing
		 WHERE team_key = @home_team_key 
	END
	ELSE IF (@eventId <> 999999999)
	BEGIN
		DELETE FROM @tables WHERE table_name = 'passing'
	END


    -- rushing
    DECLARE @rushing TABLE
    (
        team_key              VARCHAR(100),
        player_display        VARCHAR(100),
        rushing_plays         INT,
        rushing_net_yards     INT,
        rushing_average_yards VARCHAR(100),
        rushing_touchdowns    INT,
        rushing_longest_yards INT
    )
	INSERT INTO @rushing (team_key, player_display, rushing_plays, rushing_net_yards, rushing_average_yards, rushing_touchdowns, rushing_longest_yards)
	SELECT team_key, player_display, rushing_plays, rushing_net_yards,
	       CAST((CAST(rushing_net_yards AS FLOAT) / rushing_plays) AS DECIMAL(4,1)),
	       rushing_touchdowns, rushing_longest_yards
	  FROM @football
     WHERE player_key <> 'team' AND rushing_plays > 0

	IF ((SELECT COUNT(*) FROM @rushing) > 0)
	BEGIN
		INSERT INTO @rushing (team_key, player_display, rushing_plays, rushing_net_yards, rushing_average_yards, rushing_touchdowns, rushing_longest_yards)
		SELECT @away_team_key, 'TEAM', SUM(rushing_plays),
		       SUM(rushing_net_yards), CAST(CAST(SUM(rushing_net_yards) AS FLOAT) / SUM(rushing_plays) AS DECIMAL(4,1)),
		       SUM(rushing_touchdowns), MAX(rushing_longest_yards)
		  FROM @rushing
		 WHERE team_key = @away_team_key 

		INSERT INTO @rushing (team_key, player_display, rushing_plays, rushing_net_yards, rushing_average_yards, rushing_touchdowns, rushing_longest_yards)
		SELECT @home_team_key, 'TEAM', SUM(rushing_plays), SUM(rushing_net_yards),
		       CAST(CAST(SUM(rushing_net_yards) AS FLOAT) / SUM(rushing_plays) AS DECIMAL(4,1)),
		       SUM(rushing_touchdowns), MAX(rushing_longest_yards)
		  FROM @rushing
		 WHERE team_key = @home_team_key 
	END
	ELSE IF (@eventId <> 999999999)
	BEGIN
		DELETE FROM @tables WHERE table_name = 'rushing'
	END


    -- receiving
    DECLARE @receiving TABLE
    (
        team_key                VARCHAR(100),
        player_display          VARCHAR(100),
        receiving_receptions    INT,
        receiving_yards         INT,
        receiving_average_yards VARCHAR(100),
        receiving_touchdowns    INT,
        receiving_longest_yards INT
    )
	INSERT INTO @receiving (team_key, player_display, receiving_receptions, receiving_yards, receiving_average_yards, receiving_touchdowns, receiving_longest_yards)
	SELECT team_key, player_display, receiving_receptions, receiving_yards,
	       CAST((CAST(receiving_yards AS FLOAT) / receiving_receptions) AS DECIMAL(4,1)),
	       receiving_touchdowns, receiving_longest_yards
	  FROM @football
     WHERE player_key <> 'team' AND receiving_receptions > 0

	IF ((SELECT COUNT(*) FROM @receiving) > 0)
	BEGIN
		INSERT INTO @receiving (team_key, player_display, receiving_receptions, receiving_yards, receiving_average_yards, receiving_touchdowns, receiving_longest_yards)
		SELECT @away_team_key, 'TEAM', SUM(receiving_receptions), SUM(receiving_yards),
		       CAST(CAST(SUM(receiving_yards) AS FLOAT) / SUM(receiving_receptions) AS DECIMAL(4,1)),
		       SUM(receiving_touchdowns), MAX(receiving_longest_yards)
		  FROM @receiving
		 WHERE team_key = @away_team_key 

		INSERT INTO @receiving (team_key, player_display, receiving_receptions, receiving_yards, receiving_average_yards, receiving_touchdowns, receiving_longest_yards)
		SELECT @home_team_key, 'TEAM', SUM(receiving_receptions), SUM(receiving_yards),
		       CAST(CAST(SUM(receiving_yards) AS FLOAT) / SUM(receiving_receptions) AS DECIMAL(4,1)),
		       SUM(receiving_touchdowns), MAX(receiving_longest_yards)
		  FROM @receiving
		 WHERE team_key = @home_team_key 
	END
	ELSE IF (@eventId <> 999999999)
	BEGIN
		DELETE FROM @tables WHERE table_name = 'receiving'
	END


    -- tackles
    DECLARE @tackles TABLE
    (
        team_key                 VARCHAR(100),
        player_display           VARCHAR(100),
        tackles_total            INT,
        defense_solo_tackles     INT,
        defense_assisted_tackles INT,
        defense_sacks            VARCHAR(100),
        defense_sack_yards       VARCHAR(100)
    )
    INSERT INTO @tackles (team_key, player_display, tackles_total, defense_solo_tackles, defense_assisted_tackles, defense_sacks, defense_sack_yards)
    SELECT team_key, player_display, defense_solo_tackles + defense_assisted_tackles, defense_solo_tackles, defense_assisted_tackles, defense_sacks, defense_sack_yards
      FROM @football
     WHERE player_key <> 'team' AND defense_solo_tackles + defense_assisted_tackles + CAST(defense_sacks AS FLOAT) > 0

	IF ((SELECT COUNT(*) FROM @tackles) > 0)
	BEGIN
		INSERT INTO @tackles (team_key, player_display, tackles_total, defense_solo_tackles, defense_assisted_tackles, defense_sacks, defense_sack_yards)
		SELECT @away_team_key, 'TEAM', SUM(tackles_total), SUM(defense_solo_tackles), SUM(defense_assisted_tackles), SUM(CAST(defense_sacks AS FLOAT)), SUM(CAST(defense_sack_yards AS FLOAT))
		  FROM @tackles
		 WHERE team_key = @away_team_key 

		INSERT INTO @tackles (team_key, player_display, tackles_total, defense_solo_tackles, defense_assisted_tackles, defense_sacks, defense_sack_yards)
		SELECT @home_team_key, 'TEAM', SUM(tackles_total), SUM(defense_solo_tackles), SUM(defense_assisted_tackles), SUM(CAST(defense_sacks AS FLOAT)), SUM(CAST(defense_sack_yards AS FLOAT))
		  FROM @tackles
		 WHERE team_key = @home_team_key
	END
	ELSE IF (@eventId <> 999999999)
	BEGIN
		DELETE FROM @tables WHERE table_name = 'tackles'
	END


    -- interceptions
    DECLARE @interceptions TABLE
    (
        team_key                            VARCHAR(100),
        player_display                      VARCHAR(100),
        defense_interceptions               INT,
        defense_interception_yards          INT,
		interception_returned_average_yards	VARCHAR(100),
        interception_returned_longest_yards INT,
        interceptions_returned_touchdowns   INT
    )
	INSERT INTO @interceptions (team_key, player_display, defense_interceptions, defense_interception_yards, interception_returned_average_yards, interception_returned_longest_yards, interceptions_returned_touchdowns)
	SELECT team_key, player_display, defense_interceptions, defense_interception_yards,
	       CAST(CAST(defense_interception_yards AS FLOAT) / defense_interceptions AS DECIMAL(3, 1)),
	       interception_returned_longest_yards, interceptions_returned_touchdowns
	  FROM @football
     WHERE player_key <> 'team' AND defense_interceptions > 0

	IF ((SELECT COUNT(*) FROM @interceptions) > 0)
	BEGIN
		INSERT INTO @interceptions (team_key, player_display, defense_interceptions, defense_interception_yards, interception_returned_average_yards, interception_returned_longest_yards, interceptions_returned_touchdowns)
		SELECT @away_team_key, 'TEAM', SUM(defense_interceptions), SUM(defense_interception_yards),
               CAST(CAST(SUM(defense_interception_yards) AS FLOAT) / SUM(defense_interceptions) AS DECIMAL(4,1)),
		       MAX(CAST(interception_returned_longest_yards AS INT)), SUM(interceptions_returned_touchdowns)
		  FROM @interceptions
		 WHERE team_key = @away_team_key 

		INSERT INTO @interceptions (team_key, player_display, defense_interceptions, defense_interception_yards, interception_returned_average_yards, interception_returned_longest_yards, interceptions_returned_touchdowns)
		SELECT @home_team_key, 'TEAM', SUM(defense_interceptions), SUM(defense_interception_yards),
		       CAST(CAST(SUM(defense_interception_yards) AS FLOAT) / SUM(defense_interceptions) AS DECIMAL(4,1)),
		       MAX(CAST(interception_returned_longest_yards AS INT)), SUM(interceptions_returned_touchdowns)
		  FROM @interceptions
		 WHERE team_key = @home_team_key 
	END
	ELSE IF (@eventId <> 999999999)
	BEGIN
		DELETE FROM @tables WHERE table_name = 'interceptions'
	END


    -- fumbles
    DECLARE @fumbles TABLE
    (
        team_key                              VARCHAR(100),
        player_display                        VARCHAR(100),
        fumbles                               INT,
        fumbles_lost                          INT,
        fumbles_recovered_lost_by_opposition  INT,
        fumbles_recovered_yards_defense       INT,
        fumbles_recovered_yards_special_teams INT,
        fumbles_recovered_yards_other         INT
    )
	INSERT INTO @fumbles (team_key, player_display, fumbles, fumbles_lost, fumbles_recovered_lost_by_opposition, fumbles_recovered_yards_defense, fumbles_recovered_yards_special_teams, fumbles_recovered_yards_other)
	SELECT team_key, player_display, fumbles, fumbles_lost, fumbles_recovered_lost_by_opposition, fumbles_recovered_yards_defense, fumbles_recovered_yards_special_teams, fumbles_recovered_yards_other
	  FROM @football
     WHERE player_key <> 'team' AND fumbles + fumbles_recovered_lost_by_opposition + fumbles_recovered_yards_defense + fumbles_recovered_yards_special_teams + fumbles_recovered_yards_other > 0

	IF ((SELECT COUNT(*) FROM @fumbles) > 0)
	BEGIN
		INSERT INTO @fumbles (team_key, player_display, fumbles, fumbles_lost, fumbles_recovered_lost_by_opposition, fumbles_recovered_yards_defense, fumbles_recovered_yards_special_teams, fumbles_recovered_yards_other)
		SELECT @away_team_key, 'TEAM', SUM(fumbles), SUM(fumbles_lost), SUM(fumbles_recovered_lost_by_opposition), SUM(fumbles_recovered_yards_defense), SUM(fumbles_recovered_yards_special_teams), SUM(fumbles_recovered_yards_other)
		  FROM @fumbles
		 WHERE team_key = @away_team_key 

		INSERT INTO @fumbles (team_key, player_display, fumbles, fumbles_lost, fumbles_recovered_lost_by_opposition, fumbles_recovered_yards_defense, fumbles_recovered_yards_special_teams, fumbles_recovered_yards_other)
		SELECT @home_team_key, 'TEAM', SUM(fumbles), SUM(fumbles_lost), SUM(fumbles_recovered_lost_by_opposition), SUM(fumbles_recovered_yards_defense), SUM(fumbles_recovered_yards_special_teams), SUM(fumbles_recovered_yards_other)
		  FROM @fumbles
		 WHERE team_key = @home_team_key 
	END
	ELSE IF (@eventId <> 999999999)
	BEGIN
		DELETE FROM @tables WHERE table_name = 'fumbles'
	END


    -- punting
    DECLARE @punting TABLE
    (
        team_key              VARCHAR(100),
        player_display        VARCHAR(100),
        punting_plays         INT,
        punting_gross_yards   INT,
        punting_average_yards VARCHAR(100),
        punting_inside_twenty INT
    )
	INSERT INTO @punting (team_key, player_display, punting_plays, punting_gross_yards, punting_average_yards, punting_inside_twenty)
	SELECT team_key, player_display, punting_plays, punting_gross_yards,
	       CAST((CAST(punting_gross_yards AS FLOAT) / punting_plays) AS DECIMAL(4,1)),
	       punting_inside_twenty
	  FROM @football
     WHERE player_key <> 'team' AND punting_plays > 0

	IF ((SELECT COUNT(*) FROM @punting) > 0)
	BEGIN
		INSERT INTO @punting (team_key, player_display, punting_plays, punting_gross_yards, punting_average_yards, punting_inside_twenty)
		SELECT @away_team_key, 'TEAM', SUM(punting_plays), SUM(punting_gross_yards), CAST(CAST(SUM(punting_gross_yards) AS FLOAT) / SUM(punting_plays) AS DECIMAL(4,1)), SUM(punting_inside_twenty)
		  FROM @punting
		 WHERE team_key = @away_team_key 

		INSERT INTO @punting (team_key, player_display, punting_plays, punting_gross_yards, punting_average_yards, punting_inside_twenty)
		SELECT @home_team_key, 'TEAM', SUM(punting_plays), SUM(punting_gross_yards), CAST(CAST(SUM(punting_gross_yards) AS FLOAT) / SUM(punting_plays) AS DECIMAL(4,1)), SUM(punting_inside_twenty)
		  FROM @punting
		 WHERE team_key = @home_team_key 
	END
	ELSE IF (@eventId <> 999999999)
	BEGIN
		DELETE FROM @tables WHERE table_name = 'punting'
	END


    -- punt_returns
    DECLARE @punt_returns TABLE
    (
        team_key                  VARCHAR(100),
        player_display            VARCHAR(100),
        punt_returns              INT,
        punt_return_yards         INT,
        punt_return_average_yards VARCHAR(100),
        punt_return_longest_yards INT,
        punt_return_touchdowns    INT
    )
	INSERT INTO @punt_returns (team_key, player_display, punt_returns, punt_return_yards, punt_return_average_yards, punt_return_longest_yards, punt_return_touchdowns)
	SELECT team_key, player_display, punt_returns, punt_return_yards,
	       CAST(CAST(punt_return_yards AS FLOAT) / punt_returns AS DECIMAL(4,1)),
	       punt_return_longest_yards, ISNULL(punt_return_touchdowns, 0)
	  FROM @football
     WHERE player_key <> 'team' AND punt_returns > 0
           
	IF ((SELECT COUNT(*) FROM @punt_returns) > 0)
	BEGIN
		INSERT INTO @punt_returns (team_key, player_display, punt_returns, punt_return_yards, punt_return_average_yards, punt_return_longest_yards, punt_return_touchdowns)
		SELECT @away_team_key, 'TEAM', SUM(punt_returns), SUM(punt_return_yards),
		       CAST(CAST(SUM(punt_return_yards) AS FLOAT) / SUM(punt_returns) AS DECIMAL(4,1)),
		       MAX(punt_return_longest_yards), SUM(punt_return_touchdowns)
		  FROM @punt_returns
		 WHERE team_key = @away_team_key 

		INSERT INTO @punt_returns (team_key, player_display, punt_returns, punt_return_yards, punt_return_average_yards, punt_return_longest_yards, punt_return_touchdowns)
		SELECT @home_team_key, 'TEAM', SUM(punt_returns), SUM(punt_return_yards),
		       CAST(CAST(SUM(punt_return_yards) AS FLOAT) / SUM(punt_returns) AS DECIMAL(4,1)),
		       MAX(punt_return_longest_yards), SUM(punt_return_touchdowns)
		  FROM @punt_returns
		 WHERE team_key = @home_team_key 
	END
	ELSE IF (@eventId <> 999999999)
	BEGIN
		DELETE FROM @tables WHERE table_name = 'punt_returns'
	END


    -- kicking
    DECLARE @kicking TABLE
    (
        team_key                            VARCHAR(100),
        player_display                      VARCHAR(100),
        field_goals_succeeded               INT,
        field_goals_attempted               INT,
		field_goals_succeeded_longest_yards INT,
        extra_point_kicks_succeeded         INT,
        extra_point_kicks_attempted         INT
    )
	INSERT INTO @kicking (team_key, player_display, field_goals_succeeded, field_goals_attempted, field_goals_succeeded_longest_yards, extra_point_kicks_succeeded, extra_point_kicks_attempted)
	SELECT team_key, player_display, field_goals_succeeded, field_goals_attempted, field_goals_succeeded_longest_yards, extra_point_kicks_succeeded, extra_point_kicks_attempted
	  FROM @football
     WHERE player_key <> 'team' AND field_goals_attempted + extra_point_kicks_attempted > 0

	IF ((SELECT COUNT(*) FROM @kicking) > 0)
	BEGIN
		INSERT INTO @kicking (team_key, player_display, field_goals_succeeded, field_goals_attempted, field_goals_succeeded_longest_yards, extra_point_kicks_succeeded, extra_point_kicks_attempted)
		SELECT @away_team_key, 'TEAM', SUM(field_goals_succeeded), SUM(field_goals_attempted), MAX(field_goals_succeeded_longest_yards), SUM(extra_point_kicks_succeeded), SUM(extra_point_kicks_attempted)
		  FROM @kicking
		 WHERE team_key = @away_team_key 

		INSERT INTO @kicking (team_key, player_display, field_goals_succeeded, field_goals_attempted, field_goals_succeeded_longest_yards, extra_point_kicks_succeeded, extra_point_kicks_attempted)
		SELECT @home_team_key, 'TEAM', SUM(field_goals_succeeded), SUM(field_goals_attempted), MAX(field_goals_succeeded_longest_yards), SUM(extra_point_kicks_succeeded), SUM(extra_point_kicks_attempted)
		  FROM @kicking
		 WHERE team_key = @home_team_key 
	END
	ELSE IF (@eventId <> 999999999)
	BEGIN
		DELETE FROM @tables WHERE table_name = 'kicking'
	END


    -- kick_returns
    DECLARE @kick_returns TABLE
    (
        team_key                      VARCHAR(100),
        player_display                VARCHAR(100),
        kickoff_returns               INT,
        kickoff_return_yards          INT,
        kickoff_return_average_yards  VARCHAR(100),
        kickoff_return_longest_yards  INT,
        kickoff_return_touchdowns     INT
    )
	INSERT INTO @kick_returns (team_key, player_display, kickoff_returns, kickoff_return_yards, kickoff_return_average_yards, kickoff_return_longest_yards, kickoff_return_touchdowns)
	SELECT team_key, player_display, kickoff_returns, kickoff_return_yards, 
	       CAST(kickoff_return_yards AS FLOAT) / CAST(kickoff_returns AS FLOAT), 
	       kickoff_return_longest_yards, kickoff_return_touchdowns
	  FROM @football
     WHERE player_key <> 'team' AND kickoff_returns > 0

	IF ((SELECT COUNT(*) FROM @kick_returns) > 0)
	BEGIN
		INSERT INTO @kick_returns (team_key, player_display, kickoff_returns, kickoff_return_yards, kickoff_return_average_yards, kickoff_return_longest_yards, kickoff_return_touchdowns)
		SELECT @away_team_key, 'TEAM', SUM(kickoff_returns), SUM(kickoff_return_yards),
		       CAST(CAST(SUM(kickoff_return_yards) AS FLOAT) / SUM(kickoff_returns) AS DECIMAL(4,1)),
		       MAX(kickoff_return_longest_yards), SUM(kickoff_return_touchdowns)
		  FROM @kick_returns
		 WHERE team_key = @away_team_key 

		INSERT INTO @kick_returns (team_key, player_display, kickoff_returns, kickoff_return_yards, kickoff_return_average_yards, kickoff_return_longest_yards, kickoff_return_touchdowns)
		SELECT @home_team_key, 'TEAM', SUM(kickoff_returns), SUM(kickoff_return_yards),
		       CAST(CAST(SUM(kickoff_return_yards) AS FLOAT) / SUM(kickoff_returns) AS DECIMAL(4,1)),
		       MAX(kickoff_return_longest_yards), SUM(kickoff_return_touchdowns)
		  FROM @kick_returns
		 WHERE team_key = @home_team_key 
	END
	ELSE IF (@eventId <> 999999999)
	BEGIN
		DELETE FROM @tables WHERE table_name = 'kick_returns'
	END


    -- officials
    DECLARE @referee TABLE
	(
		position VARCHAR(100),
		judge VARCHAR(100),
		[order] INT
	)

	INSERT INTO @referee (position, judge)
	SELECT [column], value
	  FROM dbo.SMG_Scores
	 WHERE event_key = @event_key AND column_type = 'officials'

	UPDATE @referee
	   SET [order] = CASE
	                     WHEN position = 'Referee' THEN 1
	                     WHEN position = 'Umpire' THEN 2
	                     WHEN position = 'Head Linesman' THEN 3
	                     WHEN position = 'Line Judge' THEN 4
	                     WHEN position = 'Side Judge' THEN 5
	                     WHEN position = 'Back Judge' THEN 6
	                     WHEN position = 'Field Judge' THEN 7
	                     ELSE 99
	                 END

     SELECT @officials = COALESCE(@officials + ', ', '') + position + ': ' + judge
	  FROM @referee
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
		 WHERE s.platform = 'DES' AND s.page = 'boxscore' AND s.league_name = @leagueName
		   AND display_status = 'hidden'
	END


	SELECT @recap AS recap,
	(
		SELECT t.table_name, t.table_display,
		       (
				   SELECT c.column_name, c.column_display
					 FROM @columns c
					WHERE c.table_name = t.table_name
					ORDER BY c.id ASC
					  FOR XML PATH('columns'), TYPE
			   ),
			   -- away
               (
                   SELECT player_display, passing_yards, passing_percentage, passing_touchdowns, passing_plays_intercepted,
                          CAST(passing_plays_completed AS VARCHAR) + '/' + CAST(passing_plays_attempted AS VARCHAR) AS passing_plays_completed_attempted
                     FROM @passing
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'passing'
                    ORDER BY passing_yards DESC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT player_display, passing_yards, passing_percentage, passing_touchdowns, passing_plays_intercepted,
                          CAST(passing_plays_completed AS VARCHAR) + '/' + CAST(passing_plays_attempted AS VARCHAR) AS passing_plays_completed_attempted
                     FROM @passing
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'passing'
                      FOR XML PATH('away_total'), TYPE
               ),
               (
                   SELECT player_display, rushing_plays, rushing_net_yards, rushing_average_yards, rushing_touchdowns, rushing_longest_yards
                     FROM @rushing
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'rushing'
                    ORDER BY rushing_net_yards DESC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT player_display, rushing_plays, rushing_net_yards, rushing_average_yards, rushing_touchdowns, rushing_longest_yards
                     FROM @rushing
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'rushing'
                      FOR XML PATH('away_total'), TYPE
               ),
               (
                   SELECT player_display, receiving_receptions, receiving_yards, receiving_average_yards, receiving_touchdowns, receiving_longest_yards
                     FROM @receiving
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'receiving'
                    ORDER BY receiving_yards DESC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT player_display, receiving_receptions, receiving_yards, receiving_average_yards, receiving_touchdowns, receiving_longest_yards
                     FROM @receiving
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'receiving'
                      FOR XML PATH('away_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, tackles_total, defense_solo_tackles, defense_assisted_tackles,
                          defense_sacks + '-' + CAST(defense_sack_yards AS VARCHAR) AS defense_defense_sack_yards
                     FROM @tackles
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'tackles'
                    ORDER BY tackles_total DESC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, tackles_total, defense_solo_tackles, defense_assisted_tackles,
                          defense_sacks + '-' + CAST(defense_sack_yards AS VARCHAR) AS defense_defense_sack_yards
                     FROM @tackles
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'tackles'
                      FOR XML PATH('away_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, defense_interceptions, defense_interception_yards, interception_returned_longest_yards, interceptions_returned_touchdowns, interception_returned_average_yards
                     FROM @interceptions
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'interceptions'
                    ORDER BY defense_interceptions DESC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, defense_interceptions, defense_interception_yards, interception_returned_longest_yards, interceptions_returned_touchdowns, interception_returned_average_yards
                     FROM @interceptions
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'interceptions'
                      FOR XML PATH('away_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, fumbles, fumbles_lost, fumbles_recovered_lost_by_opposition,
                          fumbles_recovered_yards_defense + fumbles_recovered_yards_special_teams + fumbles_recovered_yards_other AS fumbles_yards
                     FROM @fumbles
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'fumbles'
                    ORDER BY fumbles DESC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, fumbles, fumbles_lost, fumbles_recovered_lost_by_opposition,
                          fumbles_recovered_yards_defense + fumbles_recovered_yards_special_teams + fumbles_recovered_yards_other AS fumbles_yards
                     FROM @fumbles
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'fumbles'
                      FOR XML PATH('away_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, punting_plays, punting_gross_yards, punting_average_yards, punting_inside_twenty
                     FROM @punting
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'punting'
                    ORDER BY punting_gross_yards DESC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, punting_plays, punting_gross_yards, punting_average_yards, punting_inside_twenty
                     FROM @punting
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'punting'
                      FOR XML PATH('away_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, punt_returns, punt_return_yards, punt_return_average_yards, punt_return_longest_yards, punt_return_touchdowns
                     FROM @punt_returns
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'punt_returns'
                    ORDER BY punt_return_yards DESC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, punt_returns, punt_return_yards, punt_return_average_yards, punt_return_longest_yards, punt_return_touchdowns
                     FROM @punt_returns
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'punt_returns'
                      FOR XML PATH('away_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, field_goals_succeeded_longest_yards,
                          CAST(field_goals_succeeded AS VARCHAR) + '/' + CAST(field_goals_attempted AS VARCHAR) AS field_goals_succeeded_attempted,
                          CAST(extra_point_kicks_succeeded AS VARCHAR) + '/' + CAST(extra_point_kicks_attempted AS VARCHAR) AS extra_point_kicks_succeeded_attempted
                     FROM @kicking
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'kicking'
                    ORDER BY field_goals_succeeded DESC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, field_goals_succeeded_longest_yards,
                          CAST(field_goals_succeeded AS VARCHAR) + '/' + CAST(field_goals_attempted AS VARCHAR) AS field_goals_succeeded_attempted,
                          CAST(extra_point_kicks_succeeded AS VARCHAR) + '/' + CAST(extra_point_kicks_attempted AS VARCHAR) AS extra_point_kicks_succeeded_attempted
                     FROM @kicking
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'kicking'
                      FOR XML PATH('away_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, kickoff_returns, kickoff_return_yards, kickoff_return_average_yards, kickoff_return_longest_yards, kickoff_return_touchdowns
                     FROM @kick_returns
                    WHERE team_key = @away_team_key AND player_display <> 'TEAM' AND t.table_name = 'kick_returns'
                    ORDER BY kickoff_return_yards DESC
                      FOR XML PATH('away_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, kickoff_returns, kickoff_return_yards, kickoff_return_average_yards, kickoff_return_longest_yards, kickoff_return_touchdowns
                     FROM @kick_returns
                    WHERE team_key = @away_team_key AND player_display = 'TEAM' AND t.table_name = 'kick_returns'
                      FOR XML PATH('away_total'), TYPE
               ),
               -- home               
               (
                   SELECT player_display, passing_yards, passing_percentage, passing_touchdowns, passing_plays_intercepted,
                          CAST(passing_plays_completed AS VARCHAR) + '/' + CAST(passing_plays_attempted AS VARCHAR) AS passing_plays_completed_attempted
                     FROM @passing
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'passing'
                    ORDER BY passing_yards DESC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT player_display, passing_yards, passing_percentage, passing_touchdowns, passing_plays_intercepted,
                          CAST(passing_plays_completed AS VARCHAR) + '/' + CAST(passing_plays_attempted AS VARCHAR) AS passing_plays_completed_attempted
                     FROM @passing
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'passing'
                      FOR XML PATH('home_total'), TYPE
               ),
               (
                   SELECT player_display, rushing_plays, rushing_net_yards, rushing_average_yards, rushing_touchdowns, rushing_longest_yards
                     FROM @rushing
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'rushing'
                    ORDER BY rushing_net_yards DESC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT player_display, rushing_plays, rushing_net_yards, rushing_average_yards, rushing_touchdowns, rushing_longest_yards
                     FROM @rushing
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'rushing'
                      FOR XML PATH('home_total'), TYPE
               ),
               (
                   SELECT player_display, receiving_receptions, receiving_yards, receiving_average_yards, receiving_touchdowns, receiving_longest_yards
                     FROM @receiving
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'receiving'
                    ORDER BY receiving_yards DESC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT player_display, receiving_receptions, receiving_yards, receiving_average_yards, receiving_touchdowns, receiving_longest_yards
                     FROM @receiving
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'receiving'
                      FOR XML PATH('home_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, tackles_total, defense_solo_tackles, defense_assisted_tackles,
                          defense_sacks + '-' + CAST(defense_sack_yards AS VARCHAR) AS defense_defense_sack_yards
                     FROM @tackles
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'tackles'
                    ORDER BY tackles_total DESC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, tackles_total, defense_solo_tackles, defense_assisted_tackles,
                          defense_sacks + '-' + CAST(defense_sack_yards AS VARCHAR) AS defense_defense_sack_yards
                     FROM @tackles
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'tackles'
                      FOR XML PATH('home_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, defense_interceptions, defense_interception_yards, interception_returned_longest_yards, interceptions_returned_touchdowns, interception_returned_average_yards
                     FROM @interceptions
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'interceptions'
                    ORDER BY defense_interceptions DESC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, defense_interceptions, defense_interception_yards, interception_returned_longest_yards, interceptions_returned_touchdowns, interception_returned_average_yards
                     FROM @interceptions
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'interceptions'
                      FOR XML PATH('home_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, fumbles, fumbles_lost, fumbles_recovered_lost_by_opposition,
                          fumbles_recovered_yards_defense + fumbles_recovered_yards_special_teams + fumbles_recovered_yards_other AS fumbles_yards
                     FROM @fumbles
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'fumbles'
                    ORDER BY fumbles DESC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, fumbles, fumbles_lost, fumbles_recovered_lost_by_opposition,
                          fumbles_recovered_yards_defense + fumbles_recovered_yards_special_teams + fumbles_recovered_yards_other AS fumbles_yards
                     FROM @fumbles
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'fumbles'
                      FOR XML PATH('home_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, punting_plays, punting_gross_yards, punting_average_yards, punting_inside_twenty
                     FROM @punting
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'punting'
                    ORDER BY punting_gross_yards DESC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, punting_plays, punting_gross_yards, punting_average_yards, punting_inside_twenty
                     FROM @punting
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'punting'
                      FOR XML PATH('home_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, punt_returns, punt_return_yards, punt_return_average_yards, punt_return_longest_yards, punt_return_touchdowns
                     FROM @punt_returns
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'punt_returns'
                    ORDER BY punt_return_yards DESC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, punt_returns, punt_return_yards, punt_return_average_yards, punt_return_longest_yards, punt_return_touchdowns
                     FROM @punt_returns
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'punt_returns'
                      FOR XML PATH('home_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, field_goals_succeeded_longest_yards,
                          CAST(field_goals_succeeded AS VARCHAR) + '/' + CAST(field_goals_attempted AS VARCHAR) AS field_goals_succeeded_attempted,
                          CAST(extra_point_kicks_succeeded AS VARCHAR) + '/' + CAST(extra_point_kicks_attempted AS VARCHAR) AS extra_point_kicks_succeeded_attempted
                     FROM @kicking
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'kicking'
                    ORDER BY field_goals_succeeded DESC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, field_goals_succeeded_longest_yards,
                          CAST(field_goals_succeeded AS VARCHAR) + '/' + CAST(field_goals_attempted AS VARCHAR) AS field_goals_succeeded_attempted,
                          CAST(extra_point_kicks_succeeded AS VARCHAR) + '/' + CAST(extra_point_kicks_attempted AS VARCHAR) AS extra_point_kicks_succeeded_attempted
                     FROM @kicking
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'kicking'
                      FOR XML PATH('home_total'), TYPE
               ),
               (
                   SELECT team_key, player_display, kickoff_returns, kickoff_return_yards, kickoff_return_average_yards, kickoff_return_longest_yards, kickoff_return_touchdowns
                     FROM @kick_returns
                    WHERE team_key = @home_team_key AND player_display <> 'TEAM' AND t.table_name = 'kick_returns'
                    ORDER BY kickoff_return_yards DESC
                      FOR XML PATH('home_team'), TYPE
               ),
               (
                   SELECT team_key, player_display, kickoff_returns, kickoff_return_yards, kickoff_return_average_yards, kickoff_return_longest_yards, kickoff_return_touchdowns
                     FROM @kick_returns
                    WHERE team_key = @home_team_key AND player_display = 'TEAM' AND t.table_name = 'kick_returns'
                      FOR XML PATH('home_total'), TYPE
               )
   		  FROM @tables t
		 ORDER BY t.id ASC
		   FOR XML PATH('boxscore'), TYPE		   
	),
    (
        SELECT display, away_value, home_value, parent
          FROM @head2head
         ORDER BY id ASC
           FOR XML PATH('head_to_head'), TYPE
    ),
    (
	    SELECT @officials
	       FOR XML PATH('officials'), TYPE
	),
	(
	    SELECT @date_time
	       FOR XML PATH('updated_date'), TYPE
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
    )
	FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF;
END


GO
