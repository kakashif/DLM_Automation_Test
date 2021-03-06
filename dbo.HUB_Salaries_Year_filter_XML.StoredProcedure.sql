USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[HUB_Salaries_Year_filter_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[HUB_Salaries_Year_filter_XML]
	@leagueName VARCHAR(100),
	@year       INT
AS
--=============================================
-- Author:	  ikenticus
-- Create date: 01/08/2015
-- Description: get salaries filters using new SMG_Salaries table
-- Update:		03/23/2015 - ikenticus: removing position filter for "team" level
--              03/31/2015 - John Lin - seperate salaries and finances
--              04/02/2015 - John Lin - use next available season for team
--				07/27/2015 - ikenticus - migrating to decoupled player/team keys
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DECLARE @league_key VARCHAR(100) = SportsDB.dbo.SMG_fnGetLeagueKey(@leagueName)
	DECLARE @embargo_season INT

   	-- embargo latest season
   	SELECT @embargo_season = season_key
      FROM SportsDB.dbo.SMG_Default_Dates
   	 WHERE league_key = @leagueName AND page = 'salaries'

   	IF (@embargo_season IS NULL)
    BEGIN
	    SET @embargo_season = YEAR(GETDATE())
    END

    IF (@year = 0 OR @year > @embargo_season)
    BEGIN   
        SET @year = @embargo_season
    END

    -- position
    DECLARE @positions TABLE
	(
	    display VARCHAR(100),
	    id VARCHAR(100)
	)
	INSERT INTO @positions (display, id)
	VALUES ('ALL POSITIONS', 'all')
		
	IF (@leagueName = 'mlb')
	BEGIN
		INSERT INTO @positions (display, id)
		VALUES ('C', 'c'), ('1B', '1b'), ('2B', '2b'), ('SS', 'ss'), ('3B', '3b'), ('IF', 'if'), ('OF', 'of'), ('DH', 'dh'), ('P', 'p')
	END
	ELSE IF (@leagueName = 'nhl')
	BEGIN
		INSERT INTO @positions (display, id)
		VALUES ('G', 'g'), ('D', 'd'), ('C', 'c'), ('LW', 'lw'), ('RW', 'rw'), ('F', 'f')
	END

    -- seasons
    DECLARE @seasons TABLE
	(
	    display VARCHAR(100),
	    id INT
	)
	INSERT INTO @seasons (id)
	SELECT season_key
	  FROM SportsEditDB.dbo.SMG_Salaries
	 WHERE league_key = @league_key AND season_key <= @embargo_season
	 GROUP BY season_key
    
	IF (@leagueName = 'mlb')
	BEGIN
	    UPDATE @seasons
	       SET display = CAST(id AS VARCHAR(4))
	END
	ELSE
	BEGIN
	    UPDATE @seasons
	       SET display = CAST(id AS VARCHAR(4)) + '-' + RIGHT(CAST(id + 1 AS VARCHAR(4)), 2) + ' Season'
	END

    -- teams
    DECLARE @team_keys TABLE
	(
	    team_key VARCHAR(100)
	)
	DECLARE @team_season INT
    
    SELECT TOP 1 @team_season = season_key
	  FROM dbo.SMG_Teams
	 WHERE league_key = @league_key AND season_key >= @year
	 ORDER BY season_key ASC
	 	
	INSERT INTO @team_keys (team_key)
	SELECT team_key
	  FROM SportsEditDB.dbo.SMG_Salaries
	 WHERE league_key = @league_key AND season_key = @team_season
	 GROUP BY team_key

    DECLARE @teams TABLE
	(
	    display VARCHAR(100),
	    id VARCHAR(100)
	)    
	INSERT INTO @teams (id, display)
	VALUES ('all', 'ALL TEAMS')

	INSERT INTO @teams (id, display)
	SELECT st.team_slug, st.team_last
	  FROM dbo.SMG_Teams st
	 INNER JOIN @team_keys tk
	    ON tk.team_key = st.team_key AND st.season_key = @team_season
	 ORDER BY st.team_last ASC



    SELECT
    (
        SELECT id, display             
          FROM @seasons
         ORDER BY id DESC
           FOR XML RAW('season'), TYPE
    ),
    (
        SELECT id, display
          FROM @teams
           FOR XML RAW('team'), TYPE
    ),
    (
        SELECT id, display
          FROM @positions
           FOR XML RAW('position'), TYPE
    )
    FOR XML RAW('root'), TYPE
    
END


GO
