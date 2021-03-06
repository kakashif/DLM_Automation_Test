USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[SMG_GetFiltersByYearSubSeasonTypeWeek_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[SMG_GetFiltersByYearSubSeasonTypeWeek_XML]
   @page VARCHAR(100),
   @seasonKey INT,
   @subSeasonType VARCHAR(100),
   @week VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 05/01/2013
  -- Description: get filter for NFL
  -- Update: 06/04/2013 - John Lin - rename filter procedure
  --         06/05/2013 - John Lin - VARCHAR defaults to empty
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
    
    EXEC dbo.SMG_GetScoreScheduleFilters_XML 'l.nfl.com', @page, @seasonKey, @subSeasonType, @week, NULL, ''
   
END


GO
