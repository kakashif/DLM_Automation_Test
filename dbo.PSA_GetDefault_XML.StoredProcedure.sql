USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetDefault_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetDefault_XML]
   @leagueName VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 06/10/2014
  -- Description: get default for jameson
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @season_key INT
    DECLARE @sub_season_type VARCHAR(100)
    DECLARE @week VARCHAR(100)
    DECLARE @start_date DATETIME
    DECLARE @filter VARCHAR(100)
	
    SELECT @season_key = season_key,
           @sub_season_type = sub_season_type,
           @week = [week],
           @start_date = [start_date],
           @filter = filter
      FROM dbo.SMG_Default_Dates
     WHERE league_key = @leagueName AND page = 'scores'

    IF (@leagueName IN ('ncaab', 'ncaaf', 'ncaaw'))
    BEGIN
        IF (@filter IN ('div1', 'div1.a'))
        BEGIN
            SET @filter = 'top25'
        END
    END

   	SELECT (
               SELECT ISNULL(@season_key, '') AS season_key, ISNULL(@sub_season_type, '') AS sub_season_type,
                      ISNULL(@week, '') AS [week], ISNULL(@start_date, '') AS [start_date], ISNULL(@filter, '') AS filter
     			  FOR XML RAW('default'), TYPE
           )
       FOR XML PATH(''), ROOT('root')
END

GO
