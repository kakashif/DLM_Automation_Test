USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetSchedulesFilterByYearSubSeasonTypeWeek_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[DES_GetSchedulesFilterByYearSubSeasonTypeWeek_XML]
   @year INT,
   @subSeasonType VARCHAR(100),
   @week VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 03/18/2014
  -- Description: get schedules filter for nfl for desktop
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    EXEC dbo.DES_GetScoresFilterByYearSubSeasonTypeWeek_XML @year, @subseasonType, @week, 'schedules'
        
END

GO
