USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetStandingsFilters_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetStandingsFilters_XML]
   @leagueKey VARCHAR(100),
   @seasonKey INT,
   @affiliation VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 10/02/2013
  -- Description: get standings filters
  -- Update: 04/14/2014 - John Lin - mlb wild-card after all-star
  --         10/14/2014 - John Lin - remove league key from SMG_Standings
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

/* DEPRECATED 
    -- affiliations
    DECLARE @affiliations TABLE
	(
	    display VARCHAR(100),
	    id VARCHAR(100)
	)
	
	IF (@leagueKey = 'l.mlb.com')
	BEGIN
	    INSERT INTO @affiliations (display, id)
	    VALUES ('All MLB', 'all'), ('League', 'league'), ('Division', 'division')
	    
	    DECLARE @all_star_date_EST DATE
	    
	    SELECT @all_star_date_EST = CAST(ss.start_date_time_EST AS DATE)
	      FROM dbo.SMG_Schedules ss 
	     INNER JOIN dbo.SMG_Event_Tags tag
	        ON tag.event_key = ss.event_key AND tag.season_key = @seasonKey AND tag.score = 'MLB ALL-STAR GAME'

        IF (@all_star_date_EST IS NOT NULL)
        BEGIN
            IF (CAST(GETDATE() AS DATE) > @all_star_date_EST)
            BEGIN
        	    INSERT INTO @affiliations (display, id)
	            VALUES ('Wild Card', 'wild-card')
            END
        END        
	END
	ELSE IF (@leagueKey = 'l.mlsnet.com')
	BEGIN
	    INSERT INTO @affiliations (display, id)
	    VALUES ('League', 'league'), ('Conference', 'conference')
	END
	ELSE IF (@leagueKey = 'l.nba.com')
	BEGIN
	    INSERT INTO @affiliations (display, id)
	    VALUES ('League', 'league'), ('Conference', 'conference'), ('Division', 'division')
	END
	ELSE IF (@leagueKey = 'l.ncaa.org.mbasket')
	BEGIN
	    INSERT INTO @affiliations (display, id)
	    VALUES ('Conference', 'conference')
	END
	ELSE IF (@leagueKey = 'l.ncaa.org.mfoot')
	BEGIN
	    INSERT INTO @affiliations (display, id)
	    VALUES ('Conference', 'conference')
	END
/*	
	ELSE IF (@leagueKey = 'l.ncaa.org.wbasket')
	BEGIN
	    INSERT INTO @affiliations (display, id)
	    VALUES ('Conference', 'conference')	    
	END
*/	
	ELSE IF (@leagueKey = 'l.nfl.com')
	BEGIN
	    INSERT INTO @affiliations (display, id)
	    VALUES ('League', 'league'), ('Conference', 'conference'), ('Division', 'division')
	END
	ELSE IF (@leagueKey = 'l.nhl.com')
	BEGIN
	    INSERT INTO @affiliations (display, id)
	    VALUES ('League', 'league'), ('Conference', 'conference'), ('Division', 'division')
	END
	ELSE IF (@leagueKey = 'l.wnba.com')
	BEGIN
	    INSERT INTO @affiliations (display, id)
	    VALUES ('League', 'league'), ('Conference', 'conference')
	END
	
	-- verify affiliation
    IF NOT EXISTS (SELECT 1 FROM @affiliations WHERE id = @affiliation)
    BEGIN
        SELECT TOP 1 @affiliation = id FROM @affiliations
    END


    -- year
    DECLARE @seasonKeys TABLE
	(
	    seasonKey INT
	)
    
    INSERT INTO @seasonKeys (seasonKey)
    SELECT season_key
      FROM SportsEditDB.dbo.SMG_Standings
     WHERE LEFT(team_key, LEN(@leagueKey)) = @leagueKey
     GROUP BY season_key

    
    SELECT
    (
        SELECT seasonKey AS id,
               (CASE
                   WHEN @leagueKey = 'l.mlb.com' THEN CAST(seasonKey AS VARCHAR(100)) + ' Season'  
                   ELSE CAST(seasonKey AS VARCHAR(100)) + '-' + RIGHT(CONVERT(VARCHAR(100), seasonKey + 1), 2) + ' Season'
               END) AS display               
          FROM @seasonKeys
         ORDER BY seasonKey DESC
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
*/    
END


GO
