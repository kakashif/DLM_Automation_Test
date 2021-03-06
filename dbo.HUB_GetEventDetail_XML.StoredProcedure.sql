USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_GetEventDetail_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_GetEventDetail_XML] 
    @leagueName VARCHAR(100),
    @seasonKey INT,
    @eventId INT
AS
-- =============================================
-- Author:		John Lin
-- Create date:	07/29/2014
-- Description:	get event detail
-- Update: 08/13/2014 - John Lin - supress link
--		   08/28/2014 - ikenticus - adding team slug
--         09/02/2014 - thlam - adding team_link to usat presto team page if not SEC
--         09/26/2014 - thlam - adding abbr for matchup stats bar
--         11/25/2014 - John Lin - only link ncaaf back to usat
--         12/11/2014 - John Lin - fix post season
--         12/16/2014 - John Lin - add playoffs
--         07/10/2015 - John Lin - STATS team records
--         07/29/2015 - John Lin - SDI migration
-- =============================================
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 

    IF (@leagueName NOT IN ('mlb', 'mls', 'nba', 'ncaab', 'ncaaf', 'ncaaw', 'nfl', 'nhl', 'wnba'))
    BEGIN
        RETURN
    END
    
    DECLARE @logo_prefix VARCHAR(100) = 'http://www.gannett-cdn.com/media/SMG/sports_logos/ncaa-whitebg/'
    DECLARE @logo_suffix VARCHAR(100) = '.png'
        
    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @event_key VARCHAR(100)
    DECLARE @event_status VARCHAR(100)
    DECLARE @tv_coverage VARCHAR(100)
    DECLARE @start_date_time_EST DATETIME
    DECLARE @game_status VARCHAR(100)
    DECLARE @week VARCHAR(100)
    DECLARE @ribbon VARCHAR(100)
    -- away
    DECLARE @away_key VARCHAR(100)
    DECLARE @away_score VARCHAR(100)
    DECLARE @away_winner VARCHAR(100)
    DECLARE @away_abbr VARCHAR(100)
    DECLARE @away_first VARCHAR(100)
    DECLARE @away_last VARCHAR(100)
    DECLARE @away_rank VARCHAR(100)
    DECLARE @away_record VARCHAR(100)
    DECLARE @away_link VARCHAR(100)
    DECLARE @away_slug VARCHAR(100)
    -- home
    DECLARE @home_key VARCHAR(100)
    DECLARE @home_score VARCHAR(100)
    DECLARE @home_winner VARCHAR(100)
    DECLARE @home_abbr VARCHAR(100)
    DECLARE @home_first VARCHAR(100)
    DECLARE @home_last VARCHAR(100)
    DECLARE @home_rank VARCHAR(100)
    DECLARE @home_record VARCHAR(100)
    DECLARE @home_link VARCHAR(100)
    DECLARE @home_slug VARCHAR(100)
   
    SELECT TOP 1 @event_key = event_key, @event_status = event_status, @tv_coverage = tv_coverage, @start_date_time_EST = start_date_time_EST,
           @game_status = game_status, @away_key = away_team_key, @away_score = away_team_score,
           @home_key = home_team_key, @home_score = home_team_score, @week = [week]
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND season_key = @seasonKey AND event_key LIKE '%' + CAST(@eventId AS VARCHAR) 
        
    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        SELECT @away_abbr = team_abbreviation, @away_first = team_first, @away_last = team_last, @away_slug = team_slug,
               @away_link = CASE
								WHEN team_slug IS NULL OR team_slug = '' THEN ''
                                WHEN conference_key = '/sport/football/conference:12' THEN '/ncaa/sec/' + team_slug + '/' + CASE
                                                                                                                 WHEN @leagueName = 'ncaab' THEN 'mens-basketball/'
                                                                                                                 WHEN @leagueName = 'ncaaf' THEN 'football/'
                                                                                                                 WHEN @leagueName = 'ncaaw' THEN 'womens-basketball/'
                                                                                                             END
                                WHEN @leagueName = 'ncaaf' THEN 'http://www.usatoday.com/sports/ncaaf/' + team_slug + '/'
                                ELSE ''
                            END
          FROM dbo.SMG_Teams
         WHERE season_key = @seasonKey AND team_key = @away_key

        SELECT @home_abbr = team_abbreviation, @home_first = team_first, @home_last = team_last, @home_slug = team_slug,
               @home_link = CASE
								WHEN team_slug IS NULL OR team_slug = '' THEN ''
                                WHEN conference_key = '/sport/football/conference:12' THEN '/ncaa/sec/' + team_slug + '/' + CASE
                                                                                                                 WHEN @leagueName = 'ncaab' THEN 'mens-basketball/'
                                                                                                                 WHEN @leagueName = 'ncaaf' THEN 'football/'
                                                                                                                 WHEN @leagueName = 'ncaaw' THEN 'womens-basketball/'
                                                                                                             END
                                WHEN @leagueName = 'ncaaf' THEN 'http://www.usatoday.com/sports/ncaaf/' + team_slug + '/'
                                ELSE '' 
                            END
          FROM dbo.SMG_Teams
         WHERE season_key = @seasonKey AND team_key = @home_key


        IF (@week NOT IN ('playoffs', 'bowls', 'ncaa', 'nit', 'cbi', 'cit', 'wnit', 'wbi') AND
            EXISTS (SELECT 1
		              FROM SportsEditDB.dbo.SMG_Polls
			    	 WHERE league_key = @league_key AND season_key = @seasonKey AND fixture_key = 'smg-usat' AND [week] = @week))
        BEGIN
            SELECT @away_rank = ranking
              FROM SportsEditDB.dbo.SMG_Polls
             WHERE league_key = @league_key AND season_key = @seasonKey AND fixture_key = 'smg-usat' AND
                   team_key = @away_key AND [week] = CAST(@week AS INT)
               
            SELECT @home_rank = ranking
              FROM SportsEditDB.dbo.SMG_Polls
             WHERE league_key = @league_key AND season_key = @seasonKey AND fixture_key = 'smg-usat' AND
                   team_key = @home_key AND [week] = CAST(@week AS INT)
    	END
	    ELSE
    	BEGIN
	    	DECLARE @max_week INT
	             
    		SELECT TOP 1 @max_week = [week]
	    	  FROM SportsEditDB.dbo.SMG_Polls
		     WHERE league_key = @league_key AND season_key = @seasonKey AND fixture_key = 'smg-usat'
    		 ORDER BY [week] DESC
	        
	    	-- set to max week
            SELECT @away_rank = ranking
              FROM SportsEditDB.dbo.SMG_Polls
             WHERE league_key = @league_key AND season_key = @seasonKey AND fixture_key = 'smg-usat' AND
                   team_key = @away_key AND [week] = @max_week
               
            SELECT @home_rank = ranking
              FROM SportsEditDB.dbo.SMG_Polls
             WHERE league_key = @league_key AND season_key = @seasonKey AND fixture_key = 'smg-usat' AND
                   team_key = @home_key AND [week] = @max_week
    	END

        -- SEED        
        IF (@leagueName IN ('ncaab', 'ncaaw') AND @week IS NOT NULL AND @week = 'ncaa')
        BEGIN
            SELECT @away_rank = seed
              FROM SportsEditDB.dbo.Edit_NCAA_Bracket_Teams
             WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @away_key

            SELECT @home_rank = seed
              FROM SportsEditDB.dbo.Edit_NCAA_Bracket_Teams
             WHERE league_key = @league_key AND season_key = @seasonKey AND team_key = @home_key
        END
        
        -- RIBBON
        SELECT @ribbon = schedule
          FROM dbo.SMG_Event_Tags
         WHERE event_key = @event_key
    END
    ELSE
    BEGIN
        SELECT @away_abbr = team_abbreviation, @away_first = team_first, @away_last = team_last
          FROM dbo.SMG_Teams
         WHERE season_key = @seasonKey AND team_key = @away_key

        SELECT @home_abbr = team_abbreviation, @home_first = team_first, @home_last = team_last
          FROM dbo.SMG_Teams
         WHERE season_key = @seasonKey AND team_key = @home_key
    END

    SET @away_record = dbo.SMG_fn_Team_Records(@leagueName, @seasonKey, @away_key, @event_key)
    SET @home_record = dbo.SMG_fn_Team_Records(@leagueName, @seasonKey, @home_key, @event_key)

    IF (@event_status = 'post-event')
    BEGIN
        IF (CAST(@away_score AS INT) > CAST(@home_score AS INT))
        BEGIN
            SET @away_winner = '1'
            SET @home_winner = '0'
        END
        IF (CAST(@home_score AS INT) > CAST(@away_score AS INT))
        BEGIN
            SET @away_winner = '0'
            SET @home_winner = '1'
        END
    END



    SELECT
	(
        SELECT @leagueName AS league, @event_status AS event_status, @tv_coverage AS tv_coverage,
               @start_date_time_EST AS start_date_time_EST, @game_status AS game_status, @ribbon AS ribbon,
			   (
			       SELECT @away_score AS score, @away_winner AS winner, @away_first AS [first], @away_last AS [last], @away_slug AS slug,
                          @logo_prefix + '220/' + @away_abbr + @logo_suffix AS logo, @logo_prefix + '60/' + @away_abbr + @logo_suffix AS logo_small,
                          @away_rank AS [rank], @away_record AS record, @away_link AS link, @away_abbr AS abbr
                      FOR XML RAW('away'), TYPE                   
			   ),
			   ( 
			       SELECT @home_score AS score, @home_winner AS winner, @home_first AS [first], @home_last AS [last], @home_slug AS slug,
                          @logo_prefix + '220/' + @home_abbr + @logo_suffix AS logo, @logo_prefix + '60/' + @home_abbr + @logo_suffix AS logo_small,
                          @home_rank AS [rank], @home_record AS record, @home_link AS link, @home_abbr AS abbr
                      FOR XML RAW('home'), TYPE
               )
           FOR XML RAW('detail'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

        
    SET NOCOUNT OFF;
END

GO
