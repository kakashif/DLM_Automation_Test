USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetStandingsFilter_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[MOB_GetStandingsFilter_XML]
    @leagueName VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 01/07/2014
  -- Description: get standings afflication
  -- Update: 01/14/2014 - John Lin - add MLS
  --         04/14/2014 - John Lin - mlb wild-card after all-star
  --         06/17/2014 - John Lin - modify wild card logic
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

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
	    DECLARE @season_key INT
	    
	    SELECT @season_key = team_season_key
	      FROM dbo.SMG_Default_Dates
	     WHERE league_key = 'mlb' AND page = 'schedules'
	    
	    SELECT @all_star_date_EST = CAST(ss.start_date_time_EST AS DATE)
	      FROM dbo.SMG_Schedules ss 
	     INNER JOIN dbo.SMG_Event_Tags tag
	        ON tag.event_key = ss.event_key AND tag.season_key = @season_key AND tag.score = 'MLB ALL-STAR GAME'

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
	ELSE IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
	BEGIN
	    INSERT INTO @affiliations (display, id)
	    VALUES ('Conference', 'conference')
	END
	ELSE IF (@leagueName IN ('nfl', 'nhl'))
	BEGIN
	    INSERT INTO @affiliations (display, id)
	    VALUES ('League', 'league'), ('Conference', 'conference'), ('Division', 'division')
	END
	ELSE IF (@leagueName = 'wnba')
	BEGIN
	    INSERT INTO @affiliations (display, id)
	    VALUES ('League', 'league'), ('Conference', 'conference')
	END
    
    
    SELECT
    (
        SELECT id, display
          FROM @affiliations
           FOR XML RAW('affiliations'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF
END

GO
