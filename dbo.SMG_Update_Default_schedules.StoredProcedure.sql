USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_Update_Default_schedules]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_Update_Default_schedules]
AS
-- =============================================
-- Author:		John Lin
-- Create date: 04/11/2013
-- Description:	update default schedules
-- Update: 05/13/2013 - John Lin - bypass start/end sub season
--         07/22/2013 - John Lin - add schedules
--         09/06/2013 - John Lin - use default year sub season start date
--         03/18/2013 - John Lin - old ncaab use new logic
--         05/16/2014 - John Lin - skip not played games
--         01/06/2014 - John Lin - fix bug
--         05/18/2015 - John Lin - add Women's World Cup
--         07/01/2015 - ikenticus - adjusting to STATS migration and SMG_Polls* conversion
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @league_key VARCHAR(100)
    DECLARE @today DATETIME = CONVERT(DATE, GETDATE())

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
            ELSE
            BEGIN
                SET @start_date = @today
            END
        END
        ELSE
        BEGIN
            SET @start_date = @today
        END

        UPDATE dbo.SMG_Default_Dates
           SET [start_date] = @start_date, team_season_key = @season_key
         WHERE league_key = 'mlb' AND page = 'schedules'
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
            ELSE
            BEGIN
                SET @start_date = @today
            END
        END
        ELSE
        BEGIN
            SET @start_date = @today
        END

        UPDATE dbo.SMG_Default_Dates
           SET [start_date] = @start_date, team_season_key = @season_key
         WHERE league_key = 'mls' AND page = 'schedules'
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
        SET @start_date = @today

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
         WHERE league_key = 'nba' AND page = 'schedules'
    END


    -- NCAAB NEW
	SET @league_key = dbo.SMG_fnGetLeagueKey('ncaab')
    SET @start_date = NULL
    SELECT TOP 1 @start_date = CAST(start_date_time_EST AS DATE), @season_key = season_key, @sub_season_type = sub_season_type, @week = [week]
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND start_date_time_EST > @today
     ORDER BY start_date_time_EST ASC

    IF (@start_date IS NOT NULL)
    BEGIN
        SET @start_date = @today
        
        IF (@sub_season_type = 'season-regular')
        BEGIN
            SELECT TOP 1 @reg_start_date = CAST(start_date_time_EST AS DATE)
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = @sub_season_type
             ORDER BY start_date_time_EST ASC

            IF (@today < @reg_start_date)
            BEGIN
                SET @start_date = @reg_start_date
                SET @week = '1'
            END
        
            UPDATE dbo.SMG_Default_Dates
               SET [start_date] = @start_date, filter = 'top25', team_season_key = @season_key, [week] = @week
             WHERE league_key = 'ncaab' AND page = 'schedules'

            SELECT TOP 1 @week = CAST([week] AS VARCHAR)
              FROM SportsEditDB.dbo.SMG_Polls 
             WHERE league_key = @league_key AND season_key = @season_key AND poll_date <= @start_date
             ORDER BY poll_date DESC                        

            IF NOT EXISTS (SELECT 1
                             FROM dbo.SMG_Schedules ss
                            INNER JOIN SportsEditDB.dbo.SMG_Polls sp
                               ON ss.season_key = sp.season_key AND sp.[week] = CAST(@week AS INT)
							INNER JOIN dbo.SMG_Teams AS ta ON ta.team_key = ss.home_team_key AND ta.season_key = ss.season_key
							INNER JOIN dbo.SMG_Teams AS th ON th.team_key = ss.home_team_key AND th.season_key = ss.season_key
                            WHERE ss.league_key = @league_key AND sp.league_key = 'ncaab' AND
							      ss.season_key = @season_key AND sp.team_key IN (ta.team_abbreviation, th.team_abbreviation) AND
                                  ss.start_date_time_EST BETWEEN @start_date AND DATEADD(WEEK, 1, @start_date))
            BEGIN
                UPDATE dbo.SMG_Default_Dates
                   SET filter = 'div1'
                 WHERE league_key = 'ncaab' AND page = 'schedules'
            END
        END 
        ELSE
        BEGIN
            IF EXISTS (SELECT 1
                         FROM dbo.SMG_Schedules
                        WHERE league_key = @league_key AND [week] = 'ncaa' AND
                                start_date_time_EST BETWEEN @start_date AND DATEADD(WEEK, 1, @start_date))
            BEGIN  
                UPDATE dbo.SMG_Default_Dates
                   SET [start_date] = @start_date, filter = 'ncaa', team_season_key = @season_key, [week] = @week
                 WHERE league_key = 'ncaab' AND page = 'scores'
            END
            ELSE
            BEGIN
                UPDATE dbo.SMG_Default_Dates
                   SET [start_date] = @start_date, filter = 'tourney', team_season_key = @season_key, [week] = @week
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
             WHERE league_key = 'ncaaf' AND page = 'schedules'
        END
        ELSE
        BEGIN
            UPDATE dbo.SMG_Default_Dates
               SET season_key = @season_key, [week] = @week, filter = 'top25', team_season_key = @season_key
             WHERE league_key = 'ncaaf' AND page = 'schedules'

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
                   SET filter = 'div1.a'
                 WHERE league_key = 'ncaaf' AND page = 'schedules'
            END
       END
    END  


    -- NCAAW NEW
	SET @league_key = dbo.SMG_fnGetLeagueKey('ncaaw')
    SET @start_date = NULL
    SELECT TOP 1 @start_date = CAST(start_date_time_EST AS DATE), @season_key = season_key, @sub_season_type = sub_season_type, @week = [week]
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND start_date_time_EST > @today
     ORDER BY start_date_time_EST ASC

    IF (@start_date IS NOT NULL)
    BEGIN
        SET @start_date = @today
        
        IF (@sub_season_type = 'season-regular')
        BEGIN
            SELECT TOP 1 @reg_start_date = CAST(start_date_time_EST AS DATE)
              FROM dbo.SMG_Schedules
             WHERE league_key = @league_key AND season_key = @season_key AND sub_season_type = @sub_season_type
             ORDER BY start_date_time_EST ASC

            IF (@today < @reg_start_date)
            BEGIN
                SET @start_date = @reg_start_date
                SET @week = '1'
            END
        
            UPDATE dbo.SMG_Default_Dates
               SET [start_date] = @start_date, filter = 'top25', team_season_key = @season_key, [week] = @week
             WHERE league_key = 'ncaaw' AND page = 'schedules'

            SELECT TOP 1 @week = CAST([week] AS VARCHAR)
              FROM SportsEditDB.dbo.SMG_Polls 
             WHERE league_key = @league_key AND season_key = @season_key AND poll_date <= @start_date
             ORDER BY poll_date DESC                        

            IF NOT EXISTS (SELECT 1
                             FROM dbo.SMG_Schedules ss
                            INNER JOIN SportsEditDB.dbo.SMG_Polls sp
                               ON ss.season_key = sp.season_key AND sp.[week] = CAST(@week AS INT)
							INNER JOIN dbo.SMG_Teams AS ta ON ta.team_key = ss.home_team_key AND ta.season_key = ss.season_key
							INNER JOIN dbo.SMG_Teams AS th ON th.team_key = ss.home_team_key AND th.season_key = ss.season_key
                            WHERE ss.league_key = @league_key AND sp.league_key = 'ncaaw' AND
							      ss.season_key = @season_key AND sp.team_key IN (ta.team_abbreviation, th.team_abbreviation) AND
                                  ss.start_date_time_EST BETWEEN @start_date AND DATEADD(WEEK, 1, @start_date))
            BEGIN
                UPDATE dbo.SMG_Default_Dates
                   SET filter = 'div1'
                 WHERE league_key = 'ncaaw' AND page = 'schedules'
            END
        END 
        ELSE
        BEGIN
            IF EXISTS (SELECT 1
                         FROM dbo.SMG_Schedules
                        WHERE league_key = @league_key AND [week] = 'ncaa' AND
                                start_date_time_EST BETWEEN @start_date AND DATEADD(WEEK, 1, @start_date))
            BEGIN  
                UPDATE dbo.SMG_Default_Dates
                   SET [start_date] = @start_date, filter = 'ncaa', team_season_key = @season_key, [week] = @week
                 WHERE league_key = 'ncaaw' AND page = 'scores'
            END
            ELSE
            BEGIN
                UPDATE dbo.SMG_Default_Dates
                   SET [start_date] = @start_date, filter = 'tourney', team_season_key = @season_key, [week] = @week
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
         WHERE league_key = 'nfl' AND page = 'schedules'
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
            ELSE
            BEGIN
                SET @start_date = @today
            END
        END
        ELSE
        BEGIN
            SET @start_date = @today
        END

        UPDATE dbo.SMG_Default_Dates
           SET start_date = @start_date, team_season_key = @season_key
         WHERE league_key = 'nhl' AND page = 'schedules'
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
            ELSE
            BEGIN
                SET @start_date = @today
            END
        END
        ELSE
        BEGIN
            SET @start_date = @today
        END

        UPDATE dbo.SMG_Default_Dates
           SET [start_date] = @start_date, team_season_key = @season_key
         WHERE league_key = 'wnba' AND page = 'schedules'
    END


	-- Women's World Cup
	SET @league_key = dbo.SMG_fnGetLeagueKey('wwc')
    SET @start_date = NULL
    SELECT TOP 1 @start_date = CAST(start_date_time_EST AS DATE), @season_key = season_key, @week = [week]
      FROM dbo.SMG_Schedules
     WHERE league_key = @league_key AND start_date_time_EST > @today
     ORDER BY start_date_time_EST ASC

    IF (@start_date IS NOT NULL)
    BEGIN
        UPDATE dbo.SMG_Default_Dates
           SET season_key = @season_key, [week] = @week, team_season_key = @season_key
         WHERE league_key = 'wwc' AND page = 'schedules'
    END
 
END

GO
