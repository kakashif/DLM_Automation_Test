USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetStandingsLegend_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[MOB_GetStandingsLegend_XML]
    @leagueName VARCHAR(100)
AS
  -- =============================================
  -- Author:      John Lin
  -- Create date: 01/07/2014
  -- Description: get standings legend
  -- Update: 01/14/2014 - John Lin - add MLS
  --         11/04/2014 - John Lin - change clinched z to chinched y
  --         04/15/2015 - ikenticus - added EPL legend
  --         07/10/2015 - John Lin - update STATS MLS legend
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


    DECLARE @legend TABLE
    (
        class  VARCHAR(100),
        symbol VARCHAR(100),
        [desc] VARCHAR(100),
        logo   VARCHAR(100)
    )

    IF (@leagueName = 'mlb')
    BEGIN
        INSERT INTO @legend (class, symbol, [desc])
        VALUES ('clinched-y', 'y', 'Clinched Division'),
               ('clinched-x', 'x', 'Clinched Playoff Berth'),
               ('clinched-w', 'w', 'Clinched Wild Card'),
               ('clinched-s', 's', 'Clinched Best Record in League')
    END
    ELSE IF (@leagueName = 'mls')
    BEGIN
        INSERT INTO @legend (class, symbol, [desc])
        VALUES ('clinched-y', 'z', 'Clinched Conference'),
               ('clinched-x', 'y', 'Clinched Playoff Berth'),
               ('clinched-s', 's', 'Clinched Supporters'' Shield')
    END
    ELSE IF (@leagueName IN ('nba', 'wnba'))
    BEGIN
        INSERT INTO @legend (class, symbol, [desc])
        VALUES ('clinched-z', 'z', 'Clinched Conference'),
               ('clinched-y', 'y', 'Clinched Divison'),
               ('clinched-x', 'x', 'Clinched Playoff Berth')
    END
    ElSE IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        INSERT INTO @legend (class, symbol, [desc])
        VALUES ('clinched-z', 'z', 'Clinched Conference')
    END
    ELSE IF (@leagueName = 'nfl')
    BEGIN
        INSERT INTO @legend (class, symbol, [desc])
        VALUES ('clinched-w', 'w', 'Clinched Wild Card'),
               ('clinched-y', 'y', 'Clinched Division'),
               ('clinched-x', 'x', 'Clinched Playoff Berth'),
               ('clinched-s', '*', 'Clinched Division & Home Field')
    END
    ELSE IF (@leagueName = 'nhl')
    BEGIN
        INSERT INTO @legend (class, symbol, [desc])
        VALUES ('clinched-z', 'z', 'Clinched Conference'),
               ('clinched-y', 'y', 'Clinched Division'),
               ('clinched-x', 'x', 'Clinched Playoff Berth'),
               ('clinched-s', '*', 'Clinched Presidents/Trophy')
    END
    ELSE IF (@leagueName = 'epl')
    BEGIN
        INSERT INTO @legend (class, symbol, [desc])
        VALUES ('box-red', 'c', 'Champions League'),
               ('box-ltgrey', 'e', 'Europa League'),
               ('box-dkgrey', 'r', 'Relegation')
    END

    UPDATE @legend
       SET logo = 'http://www.gannett-cdn.com/media/SMG/sports_logos/legends/' + class + '.png'
    
    SELECT
    (
        SELECT symbol AS [key], [desc] AS value, logo
          FROM @legend
           FOR XML RAW('legend'), TYPE
    )
    FOR XML PATH(''), ROOT('root')

    SET NOCOUNT OFF
END

GO
