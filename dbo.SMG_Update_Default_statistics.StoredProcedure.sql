USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_Update_Default_statistics]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_Update_Default_statistics]
AS
-- =============================================
-- Author:		John Lin
-- Create date: 06/04/2013
-- Description:	update default statistics
-- Update: 07/23/2013 - John Lin - add team season key
--         08/30/2013 - John Lin - use SportsEditDB.dbo.SMG_Team_Season_Statistics
--         09/20/2013 - John Lin - add MLB and NHL
--         11/07/2013 - John Lin - add NBA
--         02/06/2014 - John Lin - check NULL before compare
--         06/17/2014 - John Lin - use league name for SMG_Default_Dates
--         02/20/2015 - ikenticus - migrating to SMG_Statistics and away from Events_Warehouse
--         09/08/2015 - John Lin - SDI migration
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @season_key INT
	DECLARE @sub_season_type VARCHAR(100)
	DECLARE @league_key VARCHAR(100)
	DECLARE @league_name VARCHAR(100)
    
    DECLARE @defaults TABLE
	(
        id          INT IDENTITY(1, 1) PRIMARY KEY,
	    league_key  VARCHAR(100),
	    league_name VARCHAR(100)
	)	
	INSERT INTO @defaults (league_key, league_name)
	VALUES (dbo.SMG_fnGetLeagueKey('mlb'), 'mlb'), (dbo.SMG_fnGetLeagueKey('mls'), 'mls'), (dbo.SMG_fnGetLeagueKey('nba'), 'nba'),
	       (dbo.SMG_fnGetLeagueKey('ncaab'), 'ncaab'), (dbo.SMG_fnGetLeagueKey('ncaaf'), 'ncaaf'), (dbo.SMG_fnGetLeagueKey('ncaaw'), 'ncaaw'),
	       (dbo.SMG_fnGetLeagueKey('nfl'), 'nfl'), (dbo.SMG_fnGetLeagueKey('nhl'), 'nhl'), (dbo.SMG_fnGetLeagueKey('wnba'), 'wnba')

	DECLARE @id INT = 1
	DECLARE @max INT

    SELECT @max = MAX(id)
      FROM @defaults

    WHILE (@id <= @max)
    BEGIN
        SELECT @league_key = league_key, @league_name = league_name
          FROM @defaults
         WHERE id = @id

        SELECT @season_key = MAX(season_key)
          FROM SportsEditDB.dbo.SMG_Statistics
         WHERE league_key = @league_key AND player_key = 'team'

        SELECT @sub_season_type = 'season-regular'
        
        IF EXISTS (SELECT 1
                     FROM SportsEditDB.dbo.SMG_Statistics
                    WHERE league_key = @league_key AND player_key = 'team' AND
						  season_key = @season_key AND sub_season_type = 'post-season')
        BEGIN
            -- next event
            SET @sub_season_type = NULL

            IF (@league_name = 'mlb')
            BEGIN
			    SELECT TOP 1 @sub_season_type = sub_season_type
			      FROM dbo.SMG_Schedules
                 WHERE league_key = @league_key AND start_date_time_EST > CONVERT(DATE, GETDATE())
                 ORDER BY start_date_time_EST ASC
            END
             
            IF (@sub_season_type IS NULL OR @sub_season_type <> 'post-season')
            BEGIN
                -- no more event
                SET @sub_season_type = 'season-regular'
            END
        END
        
        UPDATE dbo.SMG_Default_Dates
           SET season_key = @season_key, sub_season_type = @sub_season_type, team_season_key = @season_key
         WHERE league_key = @league_name AND page = 'statistics'
        
        SET @id = @id + 1
    END

END


GO
