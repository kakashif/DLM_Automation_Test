USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetEvent_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DES_GetEvent_XML]
    @leagueName VARCHAR(100),
    @eventType VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:		John Lin
-- Create date: 12/08/2013
-- Description:	get event boxscore for desktop
-- Update: 03/18/2014 - John Lin - leaders during game
--         03/24/2014 - John Lin - add team link
--         03/31/2014 - John Lin - add parentheses to team record
--         04/30/2014 - ikenticus - adding gallery parameters
--         06/10/2014 - John Lin - set pre event score to null
--         06/17/2014 - John Lin - move SMG_Events_Leaders
--         06/23/2014 - John Lin - adjustments for All Stars
--         07/09/2014 - ikenticus - adjusting gallery start/end times
--         02/20/2015 - ikenticus - migrating SMG_Team_Season_Statistics to SMG_Statistics
--         06/02/2015 - John Lin - adjust for epl, natl, wwc
--         06/09/2015 - ikenticus - setting world cup gallery terms to soccer
--         06/23/2013 - John Lin - STATS migration
--         06/24/2015 - ikenticus - adding failover event_key logic for source transitions
--		   07/01/2015 - ikenticus - adjusting to SMG_Polls* conversion
--         07/10/2015 - John Lin - STATS team records
--         07/28/2015 - John Lin - MLS All Stars
--         09/03/2015 - ikenticus - SDI and logo logic adjustments
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @event_key VARCHAR(100)
    DECLARE @sub_season_type VARCHAR(100)
    DECLARE @site_name VARCHAR(100)
    DECLARE @attendance VARCHAR(100)
    DECLARE @event_status VARCHAR(100)
    DECLARE @away_key VARCHAR(100)
    DECLARE @away_first VARCHAR(100)
    DECLARE @away_last VARCHAR(100)
    DECLARE @away_short VARCHAR(100)
    DECLARE @away_abbr VARCHAR(100)
    DECLARE @away_logo VARCHAR(100)
    DECLARE @away_logo_80 VARCHAR(100)
    DECLARE @away_rgb VARCHAR(100)    
    DECLARE @away_slug VARCHAR(100)
    DECLARE @away_rank VARCHAR(100) = ''
    DECLARE @away_score VARCHAR(100)
    DECLARE @away_winner VARCHAR(100)
    DECLARE @away_record VARCHAR(100)
    DECLARE @away_link VARCHAR(100)
    DECLARE @home_key VARCHAR(100)
    DECLARE @home_first VARCHAR(100)
    DECLARE @home_last VARCHAR(100)
    DECLARE @home_short VARCHAR(100)
    DECLARE @home_abbr VARCHAR(100)
    DECLARE @home_logo VARCHAR(100)
    DECLARE @home_logo_80 VARCHAR(100)
    DECLARE @home_rgb VARCHAR(100)    
    DECLARE @home_slug VARCHAR(100)
    DECLARE @home_rank VARCHAR(100) = ''
    DECLARE @home_score VARCHAR(100)
    DECLARE @home_winner VARCHAR(100)
    DECLARE @home_record VARCHAR(100)
    DECLARE @home_link VARCHAR(100)
    DECLARE @level_name VARCHAR(100)
    DECLARE @start_date_time_EST DATETIME
    DECLARE @winner_key VARCHAR(100)
    DECLARE @game_status VARCHAR(100)
    DECLARE @ribbon VARCHAR(100)
    DECLARE @poll_date DATE
    
    DECLARE @region VARCHAR(100)
    DECLARE @round_id VARCHAR(100)
    DECLARE @round_diplay VARCHAR(100)
    DECLARE @region_order VARCHAR(100)

    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/'
    DECLARE @logo_folder VARCHAR(100) = '-whitebg/'
    DECLARE @flag_folder VARCHAR(100) = 'countries/flags/'
    DECLARE @logo_suffix VARCHAR(100) = '.png'
  
    SELECT TOP 1 @event_key = event_key, @sub_season_type = sub_season_type, @site_name = site_name, @event_status = event_status,
           @away_key = away_team_key, @away_score = away_team_score, @home_key = home_team_key, @home_score = home_team_score,
           @start_date_time_EST = start_date_time_EST, @winner_key = winner_team_key, @game_status = game_status, @level_name = level_name
      FROM SportsDB.dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)

	IF (@event_key IS NULL)
	BEGIN
		-- Failover during source transitions
		SELECT TOP 1 @league_key = league_key,
			   @event_key = event_key, @sub_season_type = sub_season_type, @site_name = site_name, @event_status = event_status,
			   @away_key = away_team_key, @away_score = away_team_score, @home_key = home_team_key, @home_score = home_team_score,
			   @start_date_time_EST = start_date_time_EST, @winner_key = winner_team_key, @game_status = game_status
		  FROM SportsDB.dbo.SMG_Schedules AS s
		 INNER JOIN SportsDB.dbo.SMG_Mappings AS m ON m.value_from = s.league_key AND m.value_to = @leagueName AND m.value_type = 'league'
		 WHERE season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR)
		 ORDER BY league_key DESC
	END

    IF (@event_status = 'pre-event')
    BEGIN
        SET @away_score = NULL
        SET @home_score = NULL
    END

    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        SELECT @away_short = team_first, @away_abbr = team_abbreviation, @away_slug = team_slug,
               @away_first = team_first, @away_last = team_last, @away_rgb = rgb
          FROM SportsDB.dbo.SMG_Teams
         WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @away_key	 

        SELECT @home_short = team_first, @home_abbr = team_abbreviation, @home_slug = team_slug,
               @home_first = team_first, @home_last = team_last, @home_rgb = rgb
          FROM SportsDB.dbo.SMG_Teams
         WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @home_key
    END
    ELSE IF (@leagueName IN ('natl', 'wwc', 'mls', 'epl', 'champions'))
    BEGIN
        SELECT @away_short = team_first, @away_abbr = team_abbreviation, @away_slug = team_slug,
               @away_first = team_first, @away_last = team_first, @away_rgb = rgb
          FROM SportsDB.dbo.SMG_Teams
         WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @away_key	 

        SELECT @home_short = team_first, @home_abbr = team_abbreviation, @home_slug = team_slug,
               @home_first = team_first, @home_last = team_first, @home_rgb = rgb
          FROM SportsDB.dbo.SMG_Teams
         WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @home_key
    END
	ELSE
    BEGIN        
        SELECT @away_short = team_last, @away_abbr = team_abbreviation, @away_slug = team_slug,
               @away_first = team_first, @away_last = team_last, @away_rgb = rgb
          FROM SportsDB.dbo.SMG_Teams
         WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @away_key	 

        SELECT @home_short = team_last, @home_abbr = team_abbreviation, @home_slug = team_slug,
               @home_first = team_first, @home_last = team_last, @home_rgb = rgb
          FROM SportsDB.dbo.SMG_Teams
         WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @home_key
    END

    IF (@leagueName IN ('mlb', 'nba', 'nfl', 'ncaaf'))
    BEGIN
        SET @away_link = '/sports/' + @leagueName + '/' + @away_slug + '/'
        SET @home_link = '/sports/' + @leagueName + '/' + @home_slug + '/'
    END

    -- logo
	SET @away_logo = dbo.SMG_fnTeamLogo(@leagueName, @away_abbr, '30')
	SET @home_logo = dbo.SMG_fnTeamLogo(@leagueName, @home_abbr, '30')
	SET @away_logo_80 = dbo.SMG_fnTeamLogo(@leagueName, @away_abbr, '80')
	SET @home_logo_80 = dbo.SMG_fnTeamLogo(@leagueName, @home_abbr, '80')

    IF (@leagueName = 'mls' AND @level_name = 'exhibition')
    BEGIN
        SET @away_logo = dbo.SMG_fnTeamLogo('euro', @away_abbr, '30')
        SET @away_logo_80 = dbo.SMG_fnTeamLogo('euro', @away_abbr, '80') 
	END

    IF (@away_last <> 'All-Stars')
    BEGIN
        SET @away_record = '(' + SportsDB.dbo.SMG_fn_Team_Records(@leagueName, @seasonKey, @away_key, @event_key) + ')'
    END
    
    IF (@home_last <> 'All-Stars')
    BEGIN
        SET @home_record = '(' + SportsDB.dbo.SMG_fn_Team_Records(@leagueName, @seasonKey, @home_key, @event_key) + ')'
    END
       
    IF (@away_key = @winner_key)
    BEGIN
       SET @away_winner = '1'
       SET @home_winner = '0'
    END
     
    IF (@home_key = @winner_key)
    BEGIN
       SET @home_winner = '1'
       SET @away_winner = '0'
    END

    SELECT @attendance = value
      FROM dbo.SMG_Scores
     WHERE event_key = @event_key AND column_type = 'attendance'

    -- RIBBON
    SELECT @ribbon = score
      FROM dbo.SMG_Event_Tags
     WHERE event_key = @event_key

    -- MATCHUP
	DECLARE @matchup TABLE
    (
		id INT IDENTITY(1, 1) PRIMARY KEY,
		name VARCHAR(100),
		[column] VARCHAR(100),
		away_value VARCHAR(100),
		away_percentage VARCHAR(100),
		home_value VARCHAR(100),
		home_percentage VARCHAR(100)
    )

    IF (@eventType = 'bracket')
    BEGIN
        SELECT @region = enb.region, @round_id = enbr.round_id, @round_diplay = enbr.round_display
          FROM SportsEditDB.dbo.Edit_NCAA_Bracket enb
         INNER JOIN SportsEditDB.dbo.Edit_NCAA_Bracket_Rounds enbr
            ON enbr.match_id = enb.match_id AND enbr.league_name = @leagueName
         WHERE enb.league_key = @league_key AND enb.event_key = @event_key AND enb.slug = 'live'
	
	    IF (@region <> '')
	    BEGIN	    
	        SELECT @region_order = [column]
	          FROM SportsEditDB.dbo.Edit_NCAA_Bracket_Regions
	         WHERE league_key = @league_key AND season_key = @seasonKey AND slug = 'live' AND value = @region
	    END
	     
	
        SELECT @away_rank = CAST(seed AS VARCHAR)
	      FROM SportsEditDB.dbo.Edit_NCAA_Bracket_Teams
	     WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @away_key

	    SELECT @home_rank = CAST(seed AS VARCHAR)
	      FROM SportsEditDB.dbo.Edit_NCAA_Bracket_Teams
	     WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @home_key

	    -- EDIT OVERRIDE
        SELECT @away_score = edit_away_score
          FROM SportsEditDB.dbo.Edit_NCAA_Bracket
         WHERE event_key = @event_key AND away_team_key = @away_key AND edit_away_score IS NOT NULL

        SELECT @away_score = edit_home_score
          FROM SportsEditDB.dbo.Edit_NCAA_Bracket
         WHERE event_key = @event_key AND home_team_key = @away_key AND edit_home_score IS NOT NULL

        SELECT @home_score = edit_home_score
          FROM SportsEditDB.dbo.Edit_NCAA_Bracket
         WHERE event_key = @event_key AND home_team_key = @home_key AND edit_home_score IS NOT NULL

        SELECT @home_score = edit_away_score
          FROM SportsEditDB.dbo.Edit_NCAA_Bracket
         WHERE event_key = @event_key AND away_team_key = @home_key AND edit_away_score IS NOT NULL

        SELECT @game_status = edit_game_status
          FROM SportsEditDB.dbo.Edit_NCAA_Bracket
         WHERE event_key = @event_key AND edit_game_status IS NOT NULL

        SELECT @winner_key = winner_team_key
          FROM SportsEditDB.dbo.Edit_NCAA_Bracket
         WHERE event_key = @event_key AND winner_team_key IS NOT NULL AND away_team_key = winner_team_key

        IF (@away_key = @winner_key)
        BEGIN
           SET @away_winner = '1'
           SET @home_winner = '0'
        END
     
        IF (@home_key = @winner_key)
        BEGIN
           SET @home_winner = '1'
           SET @away_winner = '0'
        END
	     
	    -- MATCHUP
	    IF (@event_status = 'pre-event')
	    BEGIN        
            INSERT INTO @matchup (name, [column])
            VALUES ('POINTS', 'points-scored-total-per-game'), ('REBOUNDS', 'rebounds-total-per-game'),
                   ('ASSISTS', 'assists-total-per-game'),('STEALS', 'steals-total-per-game'), ('BLOCKS', 'blocks-total-per-game')

            UPDATE m
               SET m.away_value = stst.value
              FROM @matchup m
             INNER JOIN SportsEditDB.dbo.SMG_Statistics stst
    	        ON stst.league_key = @league_key AND stst.season_key = @seasonKey AND stst.sub_season_type = 'season-regular' AND
    	           stst.team_key = @away_key AND stst.[column] = m.[column] AND stst.category = 'feed' AND stst.player_key = 'team'

            UPDATE m
               SET m.home_value = stst.value
              FROM @matchup m
             INNER JOIN SportsEditDB.dbo.SMG_Statistics stst
    	        ON stst.league_key = @league_key AND stst.season_key = @seasonKey AND stst.sub_season_type = 'season-regular' AND
	               stst.team_key = @home_key AND stst.[column] = m.[column] AND stst.category = 'feed' AND stst.player_key = 'team'

            UPDATE @matchup
               SET away_percentage = ROUND(CAST(away_value AS FLOAT) / (CAST(away_value AS FLOAT) + CAST(home_value AS FLOAT)) * 100, 2)

            UPDATE @matchup
               SET home_percentage = ROUND(CAST(home_value AS FLOAT) / (CAST(away_value AS FLOAT) + CAST(home_value AS FLOAT)) * 100, 2)
        END
	END
	ELSE
	BEGIN                   
        SELECT TOP 1 @poll_date = poll_date
          FROM SportsEditDB.dbo.SMG_Polls
          WHERE league_key = @leagueName AND fixture_key = 'smg-usat' AND poll_date < @start_date_time_EST
          ORDER BY poll_date DESC

        SELECT @away_rank = ranking
	      FROM SportsEditDB.dbo.SMG_Polls
	     WHERE league_key = @leagueName AND poll_date = @poll_date AND fixture_key = 'smg-usat' AND team_key = @away_abbr

        SELECT @home_rank = ranking
	      FROM SportsEditDB.dbo.SMG_Polls
	     WHERE league_key = @leagueName AND poll_date = @poll_date AND fixture_key = 'smg-usat' AND team_key = @home_abbr
	 END


    -- LEADERS
    DECLARE @leaders TABLE
    (
        team_key       VARCHAR(100),
        category       VARCHAR(100),
        category_order INT,
        player_value   VARCHAR(100),
        stat_value     VARCHAR(100),
        stat_order     INT
    )

    IF (@event_status <> 'pre-event')
    BEGIN
        INSERT INTO @leaders (team_key, category, category_order, player_value, stat_value, stat_order)
        SELECT team_key, category, category_order, player_value, stat_value, stat_order
          FROM dbo.SMG_Events_Leaders
         WHERE event_key = @event_key AND team_key IN (@away_key, @home_key)
    END


	-- GALLERY (SportsImages searchAPI)
	DECLARE @gallery_terms VARCHAR(100)
	DECLARE @gallery_keywords VARCHAR(100)
	DECLARE @gallery_start_date INT
	DECLARE	@gallery_end_date INT

    IF (@leagueName = 'ncaaf')
	BEGIN
		SET @gallery_terms = 'NCAA Football'
	END
	ELSE IF (@leagueName ='ncaab')
	BEGIN
		SET @gallery_terms = 'NCAA Basketball'
	END
	ELSE IF (@leagueName IN ('natl', 'wwc'))
	BEGIN
		SET @gallery_terms = 'soccer'
	END
	ELSE
	BEGIN
		SET @gallery_terms = @leagueName
	END

	IF ((@away_short IN ('49ers', '76ers')) OR (@home_short IN ('49ers', '76ers')))
	BEGIN
		SET @gallery_keywords = @away_first + ' ' + @home_first
	END
	ELSE
	BEGIN
		SET @gallery_keywords = @away_short + ' ' + @home_short
	END

	SET @gallery_start_date = DATEDIFF(SECOND, '1970-01-01' , @start_date_time_EST)
	SET @gallery_end_date = DATEDIFF(SECOND, '1970-01-01' , @start_date_time_EST) + 21600

    
    SELECT
	(
        SELECT @event_status AS event_status, @game_status AS game_status, @site_name AS [site], @attendance AS attendance, @start_date_time_EST AS start_date_time_EST,
               (
                   SELECT @away_first AS first_name, @away_last AS last_name, @away_short AS short_name, @away_logo AS team_logo,
                          @away_logo_80 AS team_logo_80, @away_rank AS [rank], @away_rgb AS team_rgb,
                          @away_record AS record, @away_score AS score, @away_winner AS winner, @away_link AS link
                      FOR XML RAW('away_team'), TYPE
               ),
               (
                   SELECT @home_first AS first_name, @home_last AS last_name, @home_short AS short_name, @home_logo AS team_logo,
                          @home_logo_80 AS team_logo_80, @home_rank AS [rank], @home_rgb AS team_rgb,
                          @home_record AS record, @home_score AS score, @home_winner AS winner, @home_link AS link
                      FOR XML RAW('home_team'), TYPE
               ),
               (
                   SELECT @region AS region, @round_id AS round_id, @round_diplay AS round_display, @region_order AS region_order
                      FOR XML RAW('bracket'), TYPE
               )
           FOR XML RAW('event'), TYPE
    ),
	(
	    SELECT l.category, 
	           (
	               SELECT l_a.player_value, l_a.stat_value
	                 FROM @leaders l_a
	                WHERE l_a.category_order = l.category_order AND l_a.team_key = @away_key
	                ORDER BY l_a.stat_order ASC
	                  FOR XML PATH('away_team'), TYPE
	           ),
	           (
	               SELECT l_h.player_value, l_h.stat_value
	                 FROM @leaders l_h
	                WHERE l_h.category_order = l.category_order AND l_h.team_key = @home_key
	                ORDER BY l_h.stat_order ASC
	                  FOR XML PATH('home_team'), TYPE
	           )
          FROM @leaders l
         GROUP BY l.category, l.category_order
         ORDER BY l.category_order ASC
            FOR XML RAW('leaders'), TYPE
    ),
	(
	    SELECT @away_logo AS away_team_logo, @home_logo AS home_team_logo, 
               (
                   SELECT name, away_value, away_percentage, home_value, home_percentage
                     FROM @matchup
                    ORDER BY id ASC
                      FOR XML RAW('stats'), TYPE
               )
           FOR XML RAW('matchup'), TYPE
    ),
	(
		SELECT	@gallery_terms AS terms,
				@gallery_keywords AS keywords,
				@gallery_start_date AS start_date,
				@gallery_end_date AS end_date
           FOR XML RAW('gallery'), TYPE
    )    
    FOR XML PATH(''), ROOT('root')
	    
    SET NOCOUNT OFF;
END

GO
