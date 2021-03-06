USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_Update_Default_standings]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SMG_Update_Default_standings]
AS
-- =============================================
-- Author:		John Lin
-- Create date: 06/04/2013
-- Description:	update default standings
-- Update: 01/07/2014 - John Lin - add league name
--         01/17/2014 - John Lin - sync
--         09/17/2014 - ikenticus - adding epl and champions
--         10/14/2014 - John Lin - remove league key from SMG_Standings
--         12/05/2014 - John Lin - varnish
--         01/12/2015 - ikenticus - preventing bad standings season_key by limiting to length 4
--         09/08/2015 - John Lin - SDI migration
-- =============================================
BEGIN
    SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @season_key INT
	DECLARE @sub_season_type VARCHAR(100)
	DECLARE @league_key VARCHAR(100)
	DECLARE @league_name VARCHAR(100)
	DECLARE @affiliation VARCHAR(100)
	DECLARE @end_point VARCHAR(100)
    
    DECLARE @defaults TABLE
	(
        id          INT IDENTITY(1, 1) PRIMARY KEY,
	    league_key  VARCHAR(100),
	    league_name VARCHAR(100),
	    affiliation VARCHAR(100)
	)	
	INSERT INTO @defaults (league_key, league_name, affiliation)
	VALUES (dbo.SMG_fnGetLeagueKey('mlb'), 'mlb', 'division'), (dbo.SMG_fnGetLeagueKey('mls'), 'mls', 'conference'),
	       (dbo.SMG_fnGetLeagueKey('nba'), 'nba', 'conference'), (dbo.SMG_fnGetLeagueKey('ncaab'), 'ncaab', 'conference'),
	       (dbo.SMG_fnGetLeagueKey('ncaaf'), 'ncaaf', 'conference'), (dbo.SMG_fnGetLeagueKey('ncaaw'), 'ncaaw', 'conference'),
	       (dbo.SMG_fnGetLeagueKey('nfl'), 'nfl', 'division'), (dbo.SMG_fnGetLeagueKey('nhl'), 'nhl', 'conference'),
	       (dbo.SMG_fnGetLeagueKey('wnba'), 'wnba', 'conference'), (dbo.SMG_fnGetLeagueKey('champions'), 'champions', 'division'),
	       (dbo.SMG_fnGetLeagueKey('epl'), 'epl', '')
	       
	DECLARE @id INT = 1
	DECLARE @max INT

    SELECT @max = MAX(id)
      FROM @defaults

    WHILE (@id <= @max)
    BEGIN
        SELECT @league_key = league_key, @league_name = league_name, @affiliation = affiliation
          FROM @defaults
         WHERE id = @id

        SELECT TOP 1 @season_key = season_key
          FROM SportsEditDB.dbo.SMG_Standings
         WHERE league_key = @league_key
         ORDER BY season_key DESC
        
        UPDATE dbo.SMG_Default_Dates
           SET season_key = @season_key, sub_season_type = 'season-regular', filter = @affiliation, team_season_key = @season_key
         WHERE league_key IN (@league_key, @league_name) AND page = 'standings'

        -- varnish
        SET @end_point = '/SportsJameson/Standings.svc/' + @league_name
        
        IF NOT EXISTS (SELECT 1 FROM SportsEditDB.dbo.SMG_Varnish WHERE end_point = @end_point)
        BEGIN
            INSERT INTO SportsEditDB.dbo.SMG_Varnish (end_point)
            VALUES (@end_point)
        END

        SET @end_point = '/SportsJameson/Standings.svc/' + @league_name + '/' + @affiliation
        
        IF NOT EXISTS (SELECT 1 FROM SportsEditDB.dbo.SMG_Varnish WHERE end_point = @end_point)
        BEGIN
            INSERT INTO SportsEditDB.dbo.SMG_Varnish (end_point)
            VALUES (@end_point)
        END
            
        SET @id = @id + 1
    END

END

GO
