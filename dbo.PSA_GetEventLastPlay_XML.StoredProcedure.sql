USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetEventLastPlay_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetEventLastPlay_XML] 
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:      John Lin
-- Create date: 07/10/2014
-- Description: get addional event detail by event status
-- Update: 07/17/2014 - John Lin - update matchup logic
--         09/29/2014 - John Lin - break up return for mlb
--         10/01/2014 - ikenticus - changing last_play to varchar(max)
--         10/07/2014 - John Lin - seperate current and last play
--         10/08/2014 - John Lin - fix last play image
--         10/09/2014 - John Lin - whitebg
--         10/12/2014 - ikenticus - adding current_down_yardage for NFL/NCAAF
--         10/12/2014 - ikenticus - adding current_team_in_possession for NFL/NCAAF
--         11/18/2014 - John Lin - add score type to play
--         11/19/2014 - ikenticus - adding epl/champions just to get the null nodes
--         11/21/2014 - John Lin - fix check bug
--         02/20/2015 - ikenticus - migrating SMG_Player_Season_Statistics to SMG_Statistics
--         04/08/2015 - John Lin - missing inning half
--         05/14/2015 - ikenticus - obtain league_key from SMG_fnGetLeagueKey
--         06/10/2015 - John Lin - set runner to 0 or 1
--		   06/24/2015 - ikenticus - adding failover event_key logic for source transitions
--		   07/01/2015 - ikenticus - excluding substitutions from MLB last_play
--		   07/10/2015 - ikenticus - last play is inaccurate when date_time is the same, using sequence desc
--		   09/01/2015 - ikenticus - formatting hitting/pitching season stats
--         09/22/2015 - John Lin - NFL use SMG_Transient for last play 
--         10/22/2015 - John Lin - use event table instead of season table
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    IF (@leagueName NOT IN ('mlb', 'mls', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba', 'epl', 'champions'))
    BEGIN
        RETURN
    END
        
    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/'
    DECLARE @logo_folder VARCHAR(100) = '-whitebg/110/'
    DECLARE @logo_suffix VARCHAR(100) = '.png'
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)

    DECLARE @event_key VARCHAR(100)
    DECLARE @event_status VARCHAR(100)
    -- away
    DECLARE @away_key VARCHAR(100)
    DECLARE @away_abbr VARCHAR(100)
    DECLARE @away_name VARCHAR(100)
    -- home
    DECLARE @home_key VARCHAR(100)
    DECLARE @home_abbr VARCHAR(100)
    DECLARE @home_name VARCHAR(100)
      
    SELECT TOP 1 @event_key = event_key, @event_status = event_status, @away_key = away_team_key, @home_key = home_team_key
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key,
			   @event_key = event_key, @event_status = event_status, @away_key = away_team_key, @home_key = home_team_key
		  FROM SportsDB.dbo.SMG_Schedules AS s
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = s.league_key AND m.value_to = @leagueName AND m.value_type = 'league'
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		 ORDER BY league_key DESC
	END

    IF (@leagueName NOT IN ('mlb', 'ncaaf', 'nfl') OR @event_status NOT IN ('mid-event'))
    BEGIN
        SELECT '' AS current_play, '' AS last_play
           FOR XML PATH(''), ROOT('root')        

        RETURN
    END



    IF (@leagueName = 'ncaaf')
    BEGIN
        SELECT @away_abbr = team_abbreviation, @away_name = team_first
          FROM dbo.SMG_Teams 
         WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @away_key

        SELECT @home_abbr = team_abbreviation, @home_name = team_first
          FROM dbo.SMG_Teams 
         WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @home_key
    END
    ELSE
    BEGIN
        SELECT @away_abbr = team_abbreviation, @away_name = team_last
          FROM dbo.SMG_Teams 
         WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @away_key

        SELECT @home_abbr = team_abbreviation, @home_name = team_last
          FROM dbo.SMG_Teams 
         WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @home_key
    END


    -- PLAYS
    -- LAST PLAY
    DECLARE @last_team_key VARCHAR(100)
    DECLARE @last_team_abbr VARCHAR(100)
    DECLARE @last_play VARCHAR(MAX)
    DECLARe @last_play_type VARCHAR(100)
    DECLARE @last_team_logo VARCHAR(100)
   
    -- CURRENT PLAY: MLB
    DECLARE @inning_half VARCHAR(100)
    DECLARE @outs INT
    DECLARE @strikes INT
    DECLARE @balls INT
    DECLARE @runner_on_first VARCHAR(100)
    DECLARE @runner_on_second VARCHAR(100)
    DECLARE @runner_on_third VARCHAR(100)
    DECLARE @away_team_key VARCHAR(100)
    DECLARE @home_team_key VARCHAR(100)    
    DECLARE @away_team_abbr VARCHAR(100)
    DECLARE @home_team_abbr VARCHAR(100)
    DECLARE @away_team_logo VARCHAR(100)
    DECLARE @home_team_logo VARCHAR(100)
    DECLARE @pitcher_key VARCHAR(100)
    DECLARE @batter_key VARCHAR(100)
    DECLARE @away_player_name VARCHAR(100)
    DECLARE @away_player_stat VARCHAR(100)
    DECLARE @away_player_description VARCHAR(100)
    DECLARE @home_player_name VARCHAR(100)
    DECLARE @home_player_stat VARCHAR(100)
    DECLARE @home_player_description VARCHAR(100)

    DECLARE @batting_average_season VARCHAR(100)
    DECLARE @on_base_percentage_season VARCHAR(100)
    DECLARE @slugging_percentage_season VARCHAR(100)

    DECLARE @earned_run_average_season VARCHAR(100)
    DECLARE @wins_season VARCHAR(100)
    DECLARE @losses_season VARCHAR(100)
    
    -- CURRENT PLAY: NFL
    DECLARE @down VARCHAR(100)
    DECLARE @down_ord VARCHAR(100)
    DECLARE @team_key VARCHAR(100)
    DECLARE @team_abbr VARCHAR(100)
    DECLARE @field_side VARCHAR(100)
    DECLARE @field_line VARCHAR(100)
    DECLARE @distance_1st_down VARCHAR(100)
    DECLARE @current_down_yardage VARCHAR(100) = ''
    DECLARE @current_team_in_possession VARCHAR(100) = ''

        
    IF (@leagueName = 'mlb')
    BEGIN
        -- current play
/*        
        SELECT TOP 1 @inning_half = inning_half, @outs = outs, @strikes = strikes, @balls = balls,
               @runner_on_first = ISNULL(NULLIF(runner_on_first, ''), '0'),
               @runner_on_second = ISNULL(NULLIF(runner_on_second, ''), '0'),
               @runner_on_third = ISNULL(NULLIF(runner_on_third, ''), '0'),
               @away_team_key = away_team_key, @home_team_key = home_team_key,
               @pitcher_key = pitcher_key, @batter_key = batter_key
          FROM dbo.SMG_Transient
         WHERE event_key = @event_key
         ORDER BY CAST(sequence_number AS FLOAT) DESC
*/    
        SELECT TOP 1 @inning_half = inning_half, @outs = outs, @strikes = strikes, @balls = balls,
               @runner_on_first = ISNULL(NULLIF(runner_on_first, ''), '0'),
               @runner_on_second = ISNULL(NULLIF(runner_on_second, ''), '0'),
               @runner_on_third = ISNULL(NULLIF(runner_on_third, ''), '0'),
               @away_team_key = away_team_key, @home_team_key = home_team_key,
               @pitcher_key = pitcher_key, @batter_key = batter_key
          FROM dbo.SMG_Transient
         WHERE event_key = @event_key
         ORDER BY inning_value DESC, inning_half ASC


        IF (@runner_on_first <> '0')
        BEGIN
            SET @runner_on_first = '1'
        END

        IF (@runner_on_second <> '0')
        BEGIN
            SET @runner_on_second = '1'
        END

        IF (@runner_on_third <> '0')
        BEGIN
            SET @runner_on_third = '1'
        END
    
        SELECT @away_team_abbr = team_abbreviation
          FROM dbo.SMG_Teams
         WHERE season_key = @seasonKey AND team_key = @away_team_key

        SELECT @home_team_abbr = team_abbreviation
          FROM dbo.SMG_Teams
         WHERE season_key = @seasonKey AND team_key = @home_team_key
        
        SET @away_team_logo = @logo_prefix + 'mlb' + @logo_folder + @away_team_abbr + @logo_suffix
        SET @home_team_logo = @logo_prefix + 'mlb' + @logo_folder + @home_team_abbr + @logo_suffix
                     
        IF (@inning_half = 'top')
        BEGIN
            SET @away_player_description = 'Hitting'
                         
            SELECT @away_player_name = LEFT(first_name, 1) + '. ' + last_name
              FROM dbo.SMG_Players
             WHERE player_key = @batter_key

            SELECT @batting_average_season = batting_average_season, @on_base_percentage_season = on_base_percentage_season, @slugging_percentage_season = slugging_percentage_season
              FROM (SELECT team_key, [column], value
                      FROM SportsEditDB.dbo.SMG_Events_baseball
                     WHERE event_key = @event_key AND team_key = @away_team_key AND player_key = @batter_key) AS s
             PIVOT (MAX(s.value) FOR s.[column] IN (batting_average_season, on_base_percentage_season, slugging_percentage_season)) AS p
     
            SET @away_player_stat = REPLACE(CAST(CAST(ISNULL(@batting_average_season, '.000') AS DECIMAL(6,3)) AS VARCHAR), '0.', '.') + '/' + 
                                    REPLACE(CAST(CAST(ISNULL(@on_base_percentage_season, '.000') AS DECIMAL(6,3)) AS VARCHAR), '0.', '.') + '/' + 
                                    REPLACE(CAST(CAST(ISNULL(@slugging_percentage_season, '.000') AS DECIMAL(6,3)) AS VARCHAR), '0.', '.')

            SET @home_player_description = 'Pitching'

            SELECT @home_player_name = LEFT(first_name, 1) + '. ' + last_name
              FROM dbo.SMG_Players
             WHERE player_key = @pitcher_key

            SELECT @earned_run_average_season = earned_run_average_season, @wins_season = [wins-season], @losses_season = [losses-season]
              FROM (SELECT team_key, [column], value
                      FROM SportsEditDB.dbo.SMG_Events_baseball
                     WHERE event_key = @event_key AND team_key = @home_team_key AND player_key = @pitcher_key) AS s
             PIVOT (MAX(s.value) FOR s.[column] IN (earned_run_average_season, [wins-season], [losses-season])) AS p

            SELECT @home_player_stat = '(' + ISNULL(@wins_season, '0') + '-' + ISNULL(@losses_season, '0') + ') ' +
                                       CAST(CAST(ISNULL(@earned_run_average_season, '0.00') AS DECIMAL(5,2)) AS VARCHAR) + ' era'
        END

        IF (@inning_half = 'bottom')
        BEGIN
            SET @home_player_description = 'Hitting'

            SELECT @home_player_name = LEFT(first_name, 1) + '. ' + last_name
              FROM dbo.SMG_Players
             WHERE player_key = @batter_key

            SELECT @batting_average_season = batting_average_season, @on_base_percentage_season = on_base_percentage_season, @slugging_percentage_season = slugging_percentage_season
              FROM (SELECT team_key, [column], value
                      FROM SportsEditDB.dbo.SMG_Events_baseball
                     WHERE event_key = @event_key AND team_key = @home_team_key AND player_key = @batter_key) AS s
             PIVOT (MAX(s.value) FOR s.[column] IN (batting_average_season, on_base_percentage_season, slugging_percentage_season)) AS p
     
            SET @home_player_stat = REPLACE(CAST(CAST(ISNULL(@batting_average_season, '.000') AS DECIMAL(6,3)) AS VARCHAR), '0.', '.') + '/' + 
                                    REPLACE(CAST(CAST(ISNULL(@on_base_percentage_season, '.000') AS DECIMAL(6,3)) AS VARCHAR), '0.', '.') + '/' + 
                                    REPLACE(CAST(CAST(ISNULL(@slugging_percentage_season, '.000') AS DECIMAL(6,3)) AS VARCHAR), '0.', '.')

            SET @away_player_description = 'Pitching'

            SELECT @away_player_name = LEFT(first_name, 1) + '. ' + last_name
              FROM dbo.SMG_Players
             WHERE player_key = @pitcher_key

            SELECT @earned_run_average_season = earned_run_average_season, @wins_season = [wins-season], @losses_season = [losses-season]
              FROM (SELECT team_key, [column], value
                      FROM SportsEditDB.dbo.SMG_Events_baseball
                     WHERE event_key = @event_key AND team_key = @away_team_key AND player_key = @pitcher_key) AS s
             PIVOT (MAX(s.value) FOR s.[column] IN (earned_run_average_season, [wins-season], [losses-season])) AS p

            SELECT @away_player_stat = '(' + ISNULL(@wins_season, '0') + '-' + ISNULL(@losses_season, '0') + ') ' +
                                       CAST(CAST(ISNULL(@earned_run_average_season, '0.00') AS DECIMAL(5,2)) AS VARCHAR) + ' era'
        END
        
        -- last play
        SELECT TOP 1 @last_team_key = team_key, @last_play = value
          FROM dbo.SMG_Plays_MLB
         WHERE event_key = @event_key AND play_type NOT IN ('Substitution')
         ORDER BY CAST(sequence_number AS FLOAT) DESC
    END
    ELSE
    BEGIN
        -- current play and last play
        SELECT TOP 1 @team_key = team_key, @field_side = field_side, @field_line = field_line,
					 @down = down, @distance_1st_down = distance_1st_down,
                     @last_team_key = team_key, @last_play = last_play, @last_play_type = play_type
          FROM dbo.SMG_Transient
         WHERE event_key = @event_key
         ORDER BY date_time DESC

		IF (@field_side = 'away')
		BEGIN
			SET @team_abbr = @away_abbr
		END
		ELSE
		BEGIN
			SET @team_abbr = @home_abbr
		END

		SET @down_ord = (CASE WHEN @down = '1' THEN '1st'
							  WHEN @down = '2' THEN '2nd'
							  WHEN @down = '3' THEN '3rd'
							  WHEN @down = '4' THEN '4th'
							  ELSE '' END)

		IF (@down_ord = '')
		BEGIN
			SET @current_down_yardage = ''
		END
		ELSE
		BEGIN
			SET @current_down_yardage = @down_ord + ' & ' + @distance_1st_down + ' on ' + @team_abbr + ' ' + @field_line
		END

        SET @last_play = CASE                            
                             WHEN @last_play_type = 'field_goal_by' THEN 'FG - ' + @last_play
                             WHEN @last_play_type = 'one_point_conversion' THEN 'XP - ' + @last_play
                             WHEN @last_play_type = 'safety' THEN 'S - ' + @last_play
                             WHEN @last_play_type = 'touchdown' THEN 'TD - ' + @last_play
                             WHEN @last_play_type = 'two_point_conversion' THEN '2-PT - ' + @last_play
                             ELSE @last_play
                         END            
    END

    SELECT @last_team_abbr = team_abbreviation
      FROM dbo.SMG_Teams
     WHERE season_key = @seasonKey AND team_key = @last_team_key

    SELECT @current_team_in_possession = team_abbreviation
      FROM dbo.SMG_Teams
     WHERE season_key = @seasonKey AND team_key = @team_key


    IF (@leagueName = 'ncaaf')
    BEGIN
        SET @last_team_logo = @logo_prefix + 'ncaa' + @logo_folder + @last_team_abbr + @logo_suffix
    END
    ELSE
    BEGIN
        SET @last_team_logo = @logo_prefix + @leagueName + @logo_folder + @last_team_abbr + @logo_suffix
    END

    
    IF (@leagueName = 'mlb')
    BEGIN
        SELECT
        (
            SELECT @outs AS outs, @strikes AS strikes, @balls AS balls,
                   @runner_on_first AS runner_on_first, @runner_on_second AS runner_on_second, @runner_on_third AS runner_on_third,
                   (
                       SELECT @away_team_logo AS logo, @away_player_name AS player, @away_player_stat AS stat, @away_player_description AS [description]
                          FOR XML RAW('away'), TYPE
                   ),
                   (
                       SELECT @home_team_logo AS logo, @home_player_name AS player, @home_player_stat AS stat, @home_player_description AS [description]
                          FOR XML RAW('home'), TYPE
                   )
               FOR XML RAW('current_play'), TYPE
        ),
        '' AS last_play
/* HACK
        (
            SELECT @last_team_abbr AS abbr, @last_team_logo AS logo, @last_play AS play
               FOR XML RAW('last_play'), TYPE
        )
*/        
        FOR XML PATH(''), ROOT('root')
    END
    ELSE
    BEGIN
        SELECT '' AS current_play, @current_down_yardage AS current_down_yardage, @current_team_in_possession AS current_team_in_possession,
               '' AS last_play
/* HACK              
               (
                   SELECT @last_team_abbr AS abbr, @last_team_logo AS logo, @last_play AS play
                   FOR XML RAW('last_play'), TYPE
               )
*/        
           FOR XML PATH(''), ROOT('root')
    END

    SET NOCOUNT OFF;
END

GO
