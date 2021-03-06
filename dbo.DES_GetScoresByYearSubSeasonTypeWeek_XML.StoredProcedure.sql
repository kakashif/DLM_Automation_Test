USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[DES_GetScoresByYearSubSeasonTypeWeek_XML]    Script Date: 10/28/2015 2:03:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


create PROCEDURE [dbo].[DES_GetScoresByYearSubSeasonTypeWeek_XML]
   @year INT,
   @subSeasonType VARCHAR(100),
   @week VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 02/21/2014
  -- Description: get scores for NFL for desktop
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    EXEC dbo.DES_GetScores_XML 'nfl', @year, @subSeasonType, @week, NULL, NULL
        
END

GO
