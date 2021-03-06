USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetStandingsFilter_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DES_GetStandingsFilter_XML]
   @leagueName VARCHAR(100),
   @seasonKey INT,
   @affiliation VARCHAR(100)
AS
--=============================================
-- Author:		ikenticus
-- Create date:	05/26/2015
-- Description:	get standings filters, based on SMG_GetStandingsFilters_XML
-- Update: 06/01/2015 - John Lin - return year for world cup
--         07/07/2015 - John Lin - update MLS
--         07/22/2015 - John Lin - update WNBA
--         07/25/2015 - John Lin - update wild card
-- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @league_key VARCHAR(100) = dbo.SMG_fnGetLeagueKey(@leagueName)

	-- default
	IF (@affiliation = 'default')
	BEGIN
		IF (@leagueName IN ('mlb', 'nfl'))
		BEGIN
			SET @affiliation = 'division'
		END
		ELSE 
		BEGIN
			SET @affiliation = 'conference'
		END
	END

    -- year
    DECLARE @season_keys TABLE
	(
	    season_key INT
	)
    
    INSERT INTO @season_keys (season_key)
    SELECT season_key
      FROM SportsEditDB.dbo.SMG_Standings
     WHERE league_key = @league_key
     GROUP BY season_key

	-- verify season_key
    IF NOT EXISTS (SELECT 1 FROM @season_keys WHERE season_key = @seasonKey)
    BEGIN
        SELECT TOP 1 @seasonKey = season_key
		  FROM @season_keys
		 ORDER BY season_key DESC
    END

    -- affiliations
    DECLARE @affiliations TABLE
	(
	    display VARCHAR(100),
	    id VARCHAR(100)
	)

	IF (@leagueName = 'mlb')
	BEGIN
	    INSERT INTO @affiliations (display, id)
	    VALUES ('All MLB', 'all'), ('League', 'league'), ('Division', 'division')
	    
	    DECLARE @all_star_date_EST DATE
	    
	    SELECT @all_star_date_EST = CAST(ss.start_date_time_EST AS DATE)
	      FROM dbo.SMG_Schedules ss 
	     INNER JOIN dbo.SMG_Event_Tags tag
	        ON tag.event_key = ss.event_key AND tag.season_key = ss.season_key AND tag.score = 'MLB ALL-STAR GAME'
         WHERE ss.league_key = @league_key AND ss.season_key = @seasonKey
 
        IF (@all_star_date_EST IS NOT NULL)
        BEGIN
            IF (CAST(GETDATE() AS DATE) > @all_star_date_EST)
            BEGIN
        	    INSERT INTO @affiliations (display, id)
	            VALUES ('Wild Card', 'wild-card')
            END
        END        
	END
	ELSE IF (@leagueName = 'mls')
	BEGIN
	    INSERT INTO @affiliations (display, id)
	    VALUES ('League', 'league'), ('Conference', 'conference')
	END
	ELSE IF (@leagueName = 'nba')
	BEGIN
	    INSERT INTO @affiliations (display, id)
	    VALUES ('League', 'league'), ('Conference', 'conference'), ('Division', 'division')
	END
	ELSE IF (@leagueName = 'ncaab')
	BEGIN
	    INSERT INTO @affiliations (display, id)
	    VALUES ('Conference', 'conference')
	END
	ELSE IF (@leagueName = 'ncaaf')
	BEGIN
	    INSERT INTO @affiliations (display, id)
	    VALUES ('Conference', 'conference')
	END
	ELSE IF (@leagueName = 'nfl')
	BEGIN
	    INSERT INTO @affiliations (display, id)
	    VALUES ('League', 'league'), ('Conference', 'conference'), ('Division', 'division')
	END
	ELSE IF (@leagueName = 'nhl')
	BEGIN
	    INSERT INTO @affiliations (display, id)
	    VALUES ('League', 'league'), ('Conference', 'conference'), ('Division', 'division')
	END
	ELSE IF (@leagueName = 'wnba')
	BEGIN
	    INSERT INTO @affiliations (display, id)
	    VALUES ('League', 'league'), ('Conference', 'conference')
	END
	ELSE
	BEGIN
	    INSERT INTO @affiliations (display, id)
		VALUES ('League', 'league')
	END

	-- verify affiliation
    IF NOT EXISTS (SELECT 1 FROM @affiliations WHERE id = @affiliation)
    BEGIN
        SELECT TOP 1 @affiliation = id FROM @affiliations
    END


    
    SELECT
    (
        SELECT season_key AS id,
               (CASE
                   WHEN @leagueName IN ('mlb', 'mls', 'wnba') THEN CAST(season_key AS VARCHAR(100)) + ' Season'  
                   WHEN @leagueName IN ('natl', 'wwc') THEN CAST(season_key AS VARCHAR(100))
                   ELSE CAST(season_key AS VARCHAR(100)) + '-' + RIGHT(CONVERT(VARCHAR(100), season_key + 1), 2) + ' Season'
               END) AS display               
          FROM @season_keys
         ORDER BY season_key DESC
           FOR XML RAW('year'), TYPE
    ),
    (
        SELECT id, display
          FROM @affiliations
           FOR XML RAW('affiliation'), TYPE
    ),
    (
        SELECT @seasonKey AS [year],
               @affiliation AS affiliation
           FOR XML RAW('default'), TYPE
    )    
    FOR XML RAW('root'), TYPE
    
END


GO
