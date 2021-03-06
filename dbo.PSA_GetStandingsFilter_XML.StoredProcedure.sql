USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetStandingsFilter_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PSA_GetStandingsFilter_XML]
    @leagueName VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 07/02/2014
  -- Description: get standings afflication
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @affiliations TABLE
	(
	    display VARCHAR(100),
	    tab_endpoint VARCHAR(100)
	)
	
	IF (@leagueName = 'mlb')
	BEGIN
	    DECLARE @season_key INT
	    DECLARE @all_star_date_EST DATE

	    INSERT INTO @affiliations (display, tab_endpoint)
	    VALUES ('Division', '/Standings.svc/mlb/division'), ('League', '/Standings.svc/mlb/league')

        SELECT @season_key = season_key
          FROM dbo.SMG_Default_Dates
         WHERE league_key = @leagueName AND page = 'standings'

	    SELECT @all_star_date_EST = CAST(ss.start_date_time_EST AS DATE)
	      FROM dbo.SMG_Schedules ss 
	     INNER JOIN dbo.SMG_Event_Tags tag
	        ON tag.event_key = ss.event_key AND tag.season_key = @season_key AND tag.score = 'MLB ALL-STAR GAME'

        IF (@all_star_date_EST IS NOT NULL)
        BEGIN
            IF (CAST(GETDATE() AS DATE) > @all_star_date_EST)
            BEGIN
        	    INSERT INTO @affiliations (display, tab_endpoint)
	            VALUES ('Wild Card', '/Standings.svc/mlb/wild-card')
            END
        END
	END
	ELSE IF (@leagueName IN ('nba', 'nfl', 'nhl'))
	BEGIN
	    INSERT INTO @affiliations (display, tab_endpoint)
	    VALUES ('Division', '/Standings.svc/' + @leagueName + '/division'),
	           ('Conference', '/Standings.svc/' + @leagueName + '/conference')
	END
    
    
    SELECT
    (
        SELECT tab_endpoint, display
          FROM @affiliations
           FOR XML RAW('affiliations'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF
END

GO
