USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_Update_Default_scores]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_Update_Default_scores]
AS
-- =============================================
-- Author:		John Lin
-- Create date: 04/11/2013
-- Description:	update default scores and suspender
-- Update: 07/22/2013 - John Lin - add schedules
--         09/06/2013 - John Lin - use default year sub season start date
--         01/06/2014 - Johh Lin - use SMG_Schedules
--         01/17/2014 - John Lin - sync
--         03/09/2014 - John Lin - update default logic
--         03/18/2014 - John Lin - old ncaab use new logic
--         05/16/2014 - John Lin - skip not played games
--         08/13/2014 - John Lin - set ncaaf suspender start date to null after bowls
--         09/17/2014 - ikenticus - adding european soccer leagues: epl, champions
--         12/30/2014 - John Lin - update ncaaf suspender logic
--         01/06/2015 - John Lin - update ncaaf suspender logic again
--         05/18/2015 - John Lin - add Women's World Cup
--         07/01/2015 - ikenticus - adjusting to STATS migration and SMG_Polls* conversion
--         07/07/2015 - ikenticus - adjusting champions league to only change with season-regular
--         08/12/2015 - ikenticus - adjusting euro soccer to retrieve week and start_date
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @league_key VARCHAR(100)
    DECLARE @today DATETIME = CAST(GETDATE() AS DATE)

    DECLARE @start_date DATETIME
    DECLARE @sub_season_type VARCHAR(100)
    DECLARE @season_key INT
    DECLARE @week VARCHAR(100)

    DECLARE @pre_start_date DATETIME
    DECLARE @reg_start_date DATETIME
    
    DECLARE @shift_today DATETIME
    DECLARE @week_start_date DATETIME
    DECLARE @day_of_week INT
    DECLARE @pivot_day_of_week INT = 4

    -- MLB NEW
	SET @league_key = dbo.SMG_fnGetLeagueKey('mlb')
    SET @start_date = NULL
    SELECT TOP 1 @start_date = CAST(start_date_time_EST AS DATE), @season_key = season_key, @sub_season_type = sub_season_type
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND event_status <> 'smg-not-played' AND start_date_time_EST > @today
     ORDER BY start_date_time_EST ASC

    IF (@start_date IS NOT NULL)
    BEGIN
        IF (@sub_season_type = 'pre-season')
        BEGIN
            SELECT TOP 1 @pre_start_date = CAST(start_date_time_EST AS DATE)
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = @sub_season_type
             ORDER BY start_date_time_EST ASC
            
            IF (@today < @pre_start_date)
            BEGIN
                SELECT TOP 1 @reg_start_date = CAST(start_date_time_EST AS DATE)
                  FROM dbo.SMG_Schedules
                 WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = 'season-regular'
                 ORDER BY start_date_time_EST ASC

                IF (@reg_start_date IS NOT NULL)
                BEGIN
                    SET @start_date = @reg_start_date
                END 
            END
        END

        UPDATE dbo.SMG_Default_Dates
           SET [start_date] = @start_date, team_season_key = @season_key
         WHERE league_key = 'mlb' AND page IN ('scores', 'suspender')
    END


    -- MLS NEW
	SET @league_key = dbo.SMG_fnGetLeagueKey('mls')
    SET @start_date = NULL
    SELECT TOP 1 @start_date = CAST(start_date_time_EST AS DATE), @season_key = season_key, @sub_season_type = sub_season_type
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND start_date_time_EST > @today
     ORDER BY start_date_time_EST ASC

    IF (@start_date IS NOT NULL)
    BEGIN
        IF (@sub_season_type = 'pre-season')
        BEGIN
            SELECT TOP 1 @pre_start_date = CAST(start_date_time_EST AS DATE)
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = @sub_season_type
             ORDER BY start_date_time_EST ASC
            
            IF (@today < @pre_start_date)
            BEGIN
                SELECT TOP 1 @reg_start_date = CAST(start_date_time_EST AS DATE)
                  FROM dbo.SMG_Schedules
                 WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = 'season-regular'
                 ORDER BY start_date_time_EST ASC

                IF (@reg_start_date IS NOT NULL)
                BEGIN
                    SET @start_date = @reg_start_date
                END 
            END
        END

        UPDATE dbo.SMG_Default_Dates
           SET [start_date] = @start_date, team_season_key = @season_key
         WHERE league_key = 'mls' AND page IN ('scores', 'suspender')
    END


    -- NBA NEW
	SET @league_key = dbo.SMG_fnGetLeagueKey('nba')
    SET @start_date = NULL
    SELECT TOP 1 @start_date = CAST(start_date_time_EST AS DATE), @season_key = season_key, @sub_season_type = sub_season_type
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND event_status <> 'smg-not-played' AND start_date_time_EST > @today
     ORDER BY start_date_time_EST ASC

    IF (@start_date IS NOT NULL)
    BEGIN
        IF (@sub_season_type = 'pre-season')
        BEGIN
            SELECT TOP 1 @pre_start_date = CAST(start_date_time_EST AS DATE)
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = @sub_season_type
             ORDER BY start_date_time_EST ASC
            
            IF (@today < @pre_start_date)
            BEGIN
                SELECT TOP 1 @reg_start_date = CAST(start_date_time_EST AS DATE)
                  FROM dbo.SMG_Schedules
                 WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = 'season-regular'
                 ORDER BY start_date_time_EST ASC

                IF (@reg_start_date IS NOT NULL)
                BEGIN
                    SET @start_date = @reg_start_date
                END 
            END
        END

        UPDATE dbo.SMG_Default_Dates
           SET [start_date] = @start_date, team_season_key = @season_key
         WHERE league_key = 'nba' AND page IN ('scores', 'suspender')
    END


    -- NCAAB NEW
	SET @league_key = dbo.SMG_fnGetLeagueKey('ncaab')
    SET @start_date = NULL
    SELECT TOP 1 @start_date = CAST(start_date_time_EST AS DATE), @season_key = season_key, @sub_season_type = sub_season_type
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND start_date_time_EST > @today
     ORDER BY start_date_time_EST ASC

    IF (@start_date IS NOT NULL)
    BEGIN
        IF (@sub_season_type = 'post-season')
        BEGIN
            -- suspender
            SET @start_date = NULL
            SELECT TOP 1 @start_date = CAST(start_date_time_EST AS DATE), @season_key = season_key
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND [week] = 'ncaa' AND start_date_time_EST > @today
             ORDER BY start_date_time_EST ASC

            IF (@start_date IS NOT NULL)
            BEGIN
                UPDATE dbo.SMG_Default_Dates
                   SET [start_date] = @start_date, filter = 'ncaa', team_season_key = @season_key
                 WHERE league_key = 'ncaab' AND page = 'suspender'
            END 

            -- scores
            SET @start_date = NULL
            SELECT TOP 1 @start_date = CAST(start_date_time_EST AS DATE), @season_key = season_key, @week = [week]
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND [week] IN ('ncaa', 'nit', 'cbi', 'cit') AND start_date_time_EST > @today
             ORDER BY start_date_time_EST ASC

            IF (@start_date IS NOT NULL)
            BEGIN
                IF EXISTS (SELECT 1
                             FROM dbo.SMG_Schedules
                            WHERE league_key = @league_key AND [week] = 'ncaa' AND
                                  start_date_time_EST BETWEEN @start_date AND DATEADD(DAY, 1, @start_date))
                BEGIN  
                    UPDATE dbo.SMG_Default_Dates
                       SET [start_date] = @start_date, filter = 'ncaa', team_season_key = @season_key
                     WHERE league_key = 'ncaab' AND page = 'scores'
                END
                ELSE
                BEGIN
                    UPDATE dbo.SMG_Default_Dates
                       SET [start_date] = @start_date, filter = 'tourney', team_season_key = @season_key
                     WHERE league_key = 'ncaab' AND page = 'scores'
                END
            END
        END 
        ELSE
        BEGIN
            -- assumtion is that every week there will be a top25 game
            UPDATE dbo.SMG_Default_Dates
               SET [start_date] = @start_date, filter = 'top25', team_season_key = @season_key
             WHERE league_key = 'ncaab' AND page IN ('scores', 'suspender')

            SELECT TOP 1 @week = CAST([week] AS VARCHAR)
              FROM SportsEditDB.dbo.SMG_Polls 
             WHERE league_key = 'ncaab' AND season_key = @season_key AND poll_date <= @start_date
             ORDER BY poll_date DESC                        

            IF NOT EXISTS (SELECT 1
                             FROM dbo.SMG_Schedules ss
                            INNER JOIN SportsEditDB.dbo.SMG_Polls sp
                               ON ss.season_key = sp.season_key AND sp.[week] = CAST(@week AS INT)
							INNER JOIN dbo.SMG_Teams AS ta ON ta.team_key = ss.home_team_key AND ta.season_key = ss.season_key
							INNER JOIN dbo.SMG_Teams AS th ON th.team_key = ss.home_team_key AND th.season_key = ss.season_key
                            WHERE ss.league_key = @league_key AND sp.league_key = 'ncaab' AND
							      ss.season_key = @season_key AND sp.team_key IN (ta.team_abbreviation, th.team_abbreviation) AND
                                  ss.start_date_time_EST BETWEEN @start_date AND DATEADD(DAY, 1, @start_date))
            BEGIN
                UPDATE dbo.SMG_Default_Dates
                   SET [start_date] = @start_date, filter = 'div1', team_season_key = @season_key
                 WHERE league_key = 'ncaab' AND page = 'scores'
            END
        END
    END


    -- NCAAF NEW
	SET @league_key = dbo.SMG_fnGetLeagueKey('ncaaf')
    SET @pivot_day_of_week = 3
    SET @day_of_week = DATEPART(dw, @today)
            
    IF (@day_of_week < @pivot_day_of_week)
    BEGIN
        SET @day_of_week = @day_of_week + 6
    END            
    
    SET @shift_today = DATEADD(DAY, -(@day_of_week - @pivot_day_of_week), @today)
    SET @start_date = NULL
    
    SELECT TOP 1 @start_date = CAST(start_date_time_EST AS DATE), @season_key = season_key, @week = [week]
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND start_date_time_EST > @shift_today
     ORDER BY start_date_time_EST ASC

    IF (@start_date IS NOT NULL)
    BEGIN
        IF (@week IN ('bowls', 'playoffs'))
        BEGIN
            UPDATE dbo.SMG_Default_Dates
               SET season_key = @season_key, [week] = 'bowls', filter = 'div1.a', team_season_key = @season_key
             WHERE league_key = 'ncaaf' AND page = 'scores'            

            -- suspender
            SET @start_date = NULL
    
            SELECT TOP 1 @start_date = CAST(start_date_time_EST AS DATE), @season_key = season_key
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND start_date_time_EST > @today
             ORDER BY start_date_time_EST ASC
            
            IF (@start_date IS NOT NULL)
            BEGIN
                UPDATE dbo.SMG_Default_Dates
                   SET [start_date] = @start_date, [week] = 'bowls', filter = 'div1.a', team_season_key = @season_key
                 WHERE league_key = 'ncaaf' AND page = 'suspender'
            END
        END
        ELSE
        BEGIN
            -- assumtion is that every week there will be a top25 game
            UPDATE dbo.SMG_Default_Dates
               SET season_key = @season_key, [week] = @week, filter = 'top25', team_season_key = @season_key
             WHERE league_key = 'ncaaf' AND page IN ('scores', 'suspender')

            UPDATE dbo.SMG_Default_Dates
               SET [start_date] = NULL
             WHERE league_key = 'ncaaf' AND page = 'suspender'

            IF NOT EXISTS (SELECT 1
                             FROM dbo.SMG_Schedules ss
                            INNER JOIN SportsEditDB.dbo.SMG_Polls sp
                               ON ss.season_key = sp.season_key AND CAST(ss.[week] AS INT) = sp.[week]
							INNER JOIN dbo.SMG_Teams AS ta ON ta.team_key = ss.home_team_key AND ta.season_key = ss.season_key
							INNER JOIN dbo.SMG_Teams AS th ON th.team_key = ss.home_team_key AND th.season_key = ss.season_key
                            WHERE ss.league_key = @league_key AND sp.league_key = 'ncaaf' AND
							      ss.season_key = @season_key AND ss.[week] = @week AND
                                  sp.team_key IN (ta.team_abbreviation, th.team_abbreviation))
            BEGIN
                UPDATE dbo.SMG_Default_Dates
                   SET season_key = @season_key, [week] = @week, filter = 'div1.a', team_season_key = @season_key
                 WHERE league_key = 'ncaaf' AND page = 'scores'
            END
       END
    END  


    -- NCAAW NEW
	SET @league_key = dbo.SMG_fnGetLeagueKey('ncaaw')
    SET @start_date = NULL
    SELECT TOP 1 @start_date = CAST(start_date_time_EST AS DATE), @season_key = season_key, @sub_season_type = sub_season_type
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND start_date_time_EST > @today
     ORDER BY start_date_time_EST ASC

    IF (@start_date IS NOT NULL)
    BEGIN
        IF (@sub_season_type = 'post-season')
        BEGIN
            -- suspender
            SET @start_date = NULL
            SELECT TOP 1 @start_date = CAST(start_date_time_EST AS DATE), @season_key = season_key
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND [week] = 'ncaa' AND start_date_time_EST > @today
             ORDER BY start_date_time_EST ASC

            IF (@start_date IS NOT NULL)
            BEGIN
                UPDATE dbo.SMG_Default_Dates
                   SET [start_date] = @start_date, filter = 'ncaa', team_season_key = @season_key
                 WHERE league_key = 'ncaaw' AND page = 'suspender'
            END 

            -- scores
            SET @start_date = NULL
            SELECT TOP 1 @start_date = CAST(start_date_time_EST AS DATE), @season_key = season_key, @week = [week]
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND [week] IN ('ncaa', 'wnit', 'wbi') AND start_date_time_EST > @today
             ORDER BY start_date_time_EST ASC

            IF (@start_date IS NOT NULL)
            BEGIN
                IF EXISTS (SELECT 1
                             FROM dbo.SMG_Schedules
                            WHERE league_key = @league_key AND [week]  = 'ncaa' AND
                                  start_date_time_EST BETWEEN @start_date AND DATEADD(DAY, 1, @start_date))
                BEGIN  
                    UPDATE dbo.SMG_Default_Dates
                       SET [start_date] = @start_date, filter = 'ncaa', team_season_key = @season_key
                     WHERE league_key = 'ncaaw' AND page = 'scores'
                END
                ELSE
                BEGIN
                    UPDATE dbo.SMG_Default_Dates
                       SET [start_date] = @start_date, filter = 'tourney', team_season_key = @season_key
                     WHERE league_key = 'ncaaw' AND page = 'scores'
                END
            END
        END 
        ELSE
        BEGIN
            -- assumtion is that every week there will be a top25 game
            UPDATE dbo.SMG_Default_Dates
               SET [start_date] = @start_date, filter = 'top25', team_season_key = @season_key
             WHERE league_key = 'ncaaw' AND page IN ('scores', 'suspender')

            SELECT TOP 1 @week = CAST([week] AS VARCHAR)
              FROM SportsEditDB.dbo.SMG_Polls 
             WHERE league_key = 'ncaaw' AND season_key = @season_key AND poll_date <= @start_date
             ORDER BY poll_date DESC                        

            IF NOT EXISTS (SELECT 1
                             FROM dbo.SMG_Schedules ss
                            INNER JOIN SportsEditDB.dbo.SMG_Polls sp
                               ON ss.season_key = sp.season_key AND sp.[week] = CAST(@week AS INT)
							INNER JOIN dbo.SMG_Teams AS ta ON ta.team_key = ss.home_team_key AND ta.season_key = ss.season_key
							INNER JOIN dbo.SMG_Teams AS th ON th.team_key = ss.home_team_key AND th.season_key = ss.season_key
                            WHERE ss.league_key = @league_key AND sp.league_key = 'ncaaw' AND
							      ss.season_key = @season_key AND sp.team_key IN (ta.team_abbreviation, th.team_abbreviation) AND
                                  ss.start_date_time_EST BETWEEN @start_date AND DATEADD(DAY, 1, @start_date))
            BEGIN
                UPDATE dbo.SMG_Default_Dates
                   SET [start_date] = @start_date, filter = 'div1', team_season_key = @season_key
                 WHERE league_key = 'ncaaw' AND page = 'scores'
            END
        END
    END


    -- NFL NEW
	SET @league_key = dbo.SMG_fnGetLeagueKey('nfl')
    SET @day_of_week = DATEPART(dw, @today)
            
    IF (@day_of_week < @pivot_day_of_week)
    BEGIN
        SET @day_of_week = @day_of_week + 6
    END            
    
    SET @shift_today = DATEADD(DAY, -(@day_of_week - @pivot_day_of_week), @today)
    SET @season_key = NULL
    
    SELECT TOP 1 @season_key = season_key, @sub_season_type = sub_season_type, @week = [week]
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND start_date_time_EST > @shift_today
     ORDER BY start_date_time_EST ASC

    IF (@season_key IS NOT NULL)
    BEGIN
        IF (@sub_season_type = 'pre-season')
        BEGIN
            SELECT TOP 1 @pre_start_date = CAST(start_date_time_EST AS DATE)
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = @sub_season_type
             ORDER BY start_date_time_EST ASC
            
            IF (@today < @pre_start_date)
            BEGIN
                SELECT TOP 1 @reg_start_date = CAST(start_date_time_EST AS DATE)
                  FROM dbo.SMG_Schedules
                 WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = 'season-regular'
                 ORDER BY start_date_time_EST ASC

                IF (@reg_start_date IS NOT NULL)
                BEGIN
                    SET @sub_season_type = 'season-regular'
                    SET @week = '1'
                END 
            END
        END

	    UPDATE dbo.SMG_Default_Dates
           SET season_key = @season_key, sub_season_type = @sub_season_type, [week] = @week, team_season_key = @season_key
         WHERE league_key = 'nfl' AND page IN ('scores', 'suspender')
    END  


    -- NHL NEW
	SET @league_key = dbo.SMG_fnGetLeagueKey('nhl')
    SET @start_date = NULL
    SELECT TOP 1 @start_date = CAST(start_date_time_EST AS DATE), @season_key = season_key, @sub_season_type = sub_season_type
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND event_status <> 'smg-not-played' AND start_date_time_EST > @today
     ORDER BY start_date_time_EST ASC

    IF (@start_date IS NOT NULL)
    BEGIN
        IF (@sub_season_type = 'pre-season')
        BEGIN
            SELECT TOP 1 @pre_start_date = CAST(start_date_time_EST AS DATE)
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = @sub_season_type
             ORDER BY start_date_time_EST ASC
            
            IF (@today < @pre_start_date)
            BEGIN
                SELECT TOP 1 @reg_start_date = CAST(start_date_time_EST AS DATE)
                  FROM dbo.SMG_Schedules
                 WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = 'season-regular'
                 ORDER BY start_date_time_EST ASC

                IF (@reg_start_date IS NOT NULL)
                BEGIN
                    SET @start_date = @reg_start_date
                END 
            END
        END

        UPDATE dbo.SMG_Default_Dates
           SET [start_date] = @start_date, team_season_key = @season_key
         WHERE league_key = 'nhl' AND page IN ('scores', 'suspender')
    END


    -- WNBA NEW
	SET @league_key = dbo.SMG_fnGetLeagueKey('wnba')
    SET @start_date = NULL
    SELECT TOP 1 @start_date = CAST(start_date_time_EST AS DATE), @season_key = season_key, @sub_season_type = sub_season_type
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND event_status <> 'smg-not-played' AND start_date_time_EST > @today
     ORDER BY start_date_time_EST ASC

    IF (@start_date IS NOT NULL)
    BEGIN
        IF (@sub_season_type = 'pre-season')
        BEGIN
            SELECT TOP 1 @pre_start_date = CAST(start_date_time_EST AS DATE)
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = @sub_season_type
             ORDER BY start_date_time_EST ASC
            
            IF (@today < @pre_start_date)
            BEGIN
                SELECT TOP 1 @reg_start_date = CAST(start_date_time_EST AS DATE)
                  FROM dbo.SMG_Schedules
                 WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = 'season-regular'
                 ORDER BY start_date_time_EST ASC

                IF (@reg_start_date IS NOT NULL)
                BEGIN
                    SET @start_date = @reg_start_date
                END 
            END
        END

        UPDATE dbo.SMG_Default_Dates
           SET [start_date] = @start_date, team_season_key = @season_key
         WHERE league_key = 'wnba' AND page IN ('scores', 'suspender')
    END


	-- EPL: English Premier League
	SET @league_key = dbo.SMG_fnGetLeagueKey('epl')
    SET @season_key = NULL
    SELECT TOP 1 @season_key = season_key, @week = [week], @start_date = CAST(start_date_time_EST AS DATE)
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND start_date_time_EST > @today
     ORDER BY start_date_time_EST ASC

    IF (@season_key IS NOT NULL)
    BEGIN
		IF (@week IS NULL)
		BEGIN
			UPDATE dbo.SMG_Default_Dates
			   SET season_key = @season_key, [week] = NULL, [start_date] = @start_date, team_season_key = @season_key
			 WHERE league_key = 'epl' AND page = 'scores'
		END
		ELSE
		BEGIN
			UPDATE dbo.SMG_Default_Dates
			   SET season_key = @season_key, [week] = @week, [start_date] = NULL, team_season_key = @season_key
			 WHERE league_key = 'epl' AND page = 'scores'
		END
    END


	-- UEFA Champions League
	SET @league_key = dbo.SMG_fnGetLeagueKey('champions')
    SET @season_key = NULL
    SELECT TOP 1 @season_key = season_key, @week = [week], @start_date = CAST(start_date_time_EST AS DATE)
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND sub_season_type = 'season-regular' AND start_date_time_EST > @today
     ORDER BY start_date_time_EST ASC

    IF (@season_key IS NOT NULL)
    BEGIN
		IF (@week IS NULL)
		BEGIN
			UPDATE dbo.SMG_Default_Dates
			   SET season_key = @season_key, [week] = NULL, [start_date] = @start_date, team_season_key = @season_key
			 WHERE league_key = 'champions' AND page = 'scores'
		END
		ELSE
		BEGIN
			UPDATE dbo.SMG_Default_Dates
			   SET season_key = @season_key, [week] = @week, [start_date] = NULL, team_season_key = @season_key
			 WHERE league_key = 'champions' AND page = 'scores'
		END
    END


	-- Women's World Cup
	SET @league_key = dbo.SMG_fnGetLeagueKey('wwc')
    SET @start_date = NULL
    SELECT TOP 1 @season_key = season_key, @week = [week], @start_date = CAST(start_date_time_EST AS DATE)
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND event_status <> 'smg-not-played' AND start_date_time_EST > @today
     ORDER BY start_date_time_EST ASC

    IF (@start_date IS NOT NULL)
    BEGIN
        UPDATE dbo.SMG_Default_Dates
           SET season_key = @season_key, [week] = @week, [start_date] = NULL, team_season_key = @season_key
         WHERE league_key = @league_key AND page = 'scores'

        UPDATE dbo.SMG_Default_Dates
           SET [week] = NULL, [start_date] = @start_date, team_season_key = @season_key
         WHERE league_key = 'wwc' AND page = 'suspender'
    END	



    -- varnish
    DECLARE @defaults TABLE
	(
        id          INT IDENTITY(1, 1) PRIMARY KEY,
	    league_name VARCHAR(100)
	)	
	INSERT INTO @defaults (league_name)
	VALUES ('mlb'), ('mls'), ('nba'), ('ncaab'), ('ncaaf'), ('ncaaw'), 
	       ('nfl'), ('nhl'), ('wnba'), ('champions'), ('epl')

    DECLARE @league_name VARCHAR(100)
    DECLARE @end_point VARCHAR(100)
	DECLARE @id INT = 1
	DECLARE @max INT

    SELECT @max = MAX(id)
      FROM @defaults

    WHILE (@id <= @max)
    BEGIN
        SELECT @league_name = league_name
          FROM @defaults
         WHERE id = @id

        -- varnish
        SET @end_point = '/SportsJameson/Scores.svc/' + @league_name
        
        IF NOT EXISTS (SELECT 1 FROM SportsEditDB.dbo.SMG_Varnish WHERE end_point = @end_point)
        BEGIN
            INSERT INTO SportsEditDB.dbo.SMG_Varnish (end_point)
            VALUES (@end_point)
        END

        SET @end_point = '/SportsNative/Scores.svc/' + @league_name
        
        IF NOT EXISTS (SELECT 1 FROM SportsEditDB.dbo.SMG_Varnish WHERE end_point = @end_point)
        BEGIN
            INSERT INTO SportsEditDB.dbo.SMG_Varnish (end_point)
            VALUES (@end_point)
        END
            
        SET @id = @id + 1
    END

END


GO
