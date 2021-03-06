USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetScoresByYearSubSeasonTypeWeek_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[MOB_GetScoresByYearSubSeasonTypeWeek_XML]
   @year INT,
   @subSeasonType VARCHAR(100),
   @week VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 12/03/2013
  -- Description: get scores for NFL
  -- Update: 08/12/2013 - John Lin - add NFL Hall of Fame to pre season
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    EXEC dbo.MOB_GetScores_XML 'nfl', @year, @subSeasonType, @week, NULL, NULL
        
END

GO
