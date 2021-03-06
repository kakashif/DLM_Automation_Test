USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetInjuriesFilters_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SMG_GetInjuriesFilters_XML] 
   @leagueName VARCHAR(100),
   @affiliation VARCHAR(100),
   @position VARCHAR(100)
AS
--=============================================
-- Author:	  ikenticus
-- Create date: 01/02/2015
-- Description: get injuries filters
-- Update:		06/04/2015 - ikenticus - applying switchover league_key logic
--              06/09/2015 - ikenticus - fixing affiliation/position filtering
--              06/29/2015 - John Lin - add season to group
--              06/30/2015 - ikenticus - join Rosters with League to omit future Roster seasons
--              07/08/2015 - ikenticus - switching to conference_display instead of conference_name, adding NCAA
--              09/16/2015 - ikenticus - adding WNBA to the basketball POS logic
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)
    DECLARE @season_key INT
    
    SELECT TOP 1 @season_key = l.season_key
      FROM dbo.SMG_Rosters AS r
     INNER JOIN dbo.SMG_Leagues AS l ON l.league_key = r.league_key AND l.season_key = r.season_key
     WHERE l.league_key = @league_key
     ORDER BY l.season_key DESC
    
    DECLARE @affiliations TABLE
	(
	    display VARCHAR(100),
	    id VARCHAR(100)
	)

	INSERT INTO @affiliations (display, id) VALUES ('All ' + UPPER(@leagueName), 'all')

	INSERT INTO @affiliations (display, id)
	SELECT conference_display, SportsEditDB.dbo.SMG_fnSlugifyName(conference_display)
	  FROM dbo.SMG_Leagues
	 WHERE league_key = @league_key AND season_key = @season_key
	 GROUP BY conference_display, conference_order
	 ORDER BY conference_order ASC

    IF NOT EXISTS (SELECT 1 FROM @affiliations WHERE id = @affiliation)
    BEGIN
        SELECT TOP 1 @affiliation = id FROM @affiliations
    END


    DECLARE @positions TABLE
	(
	    display VARCHAR(100),
	    id VARCHAR(100)
	)

	INSERT INTO @positions (display, id) VALUES ('All POS', 'all')

	IF (@leagueName = 'mlb')
	BEGIN
    	INSERT INTO @positions (display, id)
	    VALUES ('C', 'c'), ('1B', '1b'), ('2B', '2b'), ('SS', 'ss'), ('3B', '3b'), ('OF', 'of'), ('DH', 'dh'), ('P', 'p')
	END
	ELSE IF (@leagueName IN ('nba', 'ncaab', 'ncaaw', 'wnba'))
	BEGIN
    	INSERT INTO @positions (display, id)
	    VALUES ('C', 'c'), ('F', 'f'), ('G', 'g')
	END
	ELSE IF (@leagueName IN ('nfl', 'ncaaf'))
	BEGIN
    	INSERT INTO @positions (display, id)
	    VALUES ('Offense', 'offense'), ('Defense', 'defense'), ('Special Teams', 'special'), ('QB', 'qb'), ('RB', 'rb'), ('WR', 'wr'), ('TE', 'te'), ('PK', 'pk')
	END
	ELSE IF (@leagueName = 'nhl')
	BEGIN
    	INSERT INTO @positions (display, id)
	    VALUES ('G', 'g'), ('D', 'd'), ('C', 'c'), ('LW', 'lw'), ('RW', 'rw')
	END

   	IF NOT EXISTS (SELECT 1 FROM @positions WHERE id = @position)
	BEGIN
	    SELECT TOP 1 @position = id FROM @positions
	END		


    SELECT
    (
        SELECT id, display             
          FROM @affiliations
           FOR XML RAW('affiliation'), TYPE
    ),
    (
        SELECT id, display
          FROM @positions
           FOR XML RAW('position'), TYPE
    ),
    (
        SELECT @affiliation AS affiliation, @position AS position
           FOR XML RAW('default'), TYPE
    )    
    FOR XML RAW('root'), TYPE
    
END


GO
