USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetScoresBySeasonKeySubSeasonTypeWeek_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[PSA_GetScoresBySeasonKeySubSeasonTypeWeek_XML]
   @seasonKey INT,
   @subSeasonType VARCHAR(100),
   @week VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 06/10/2014
  -- Description: get scores for nfl
  -- Update: 10/23/2014 - John Lin - add round
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    EXEC dbo.PSA_GetScores_XML 'nfl', @seasonKey, @subSeasonType, @week, NULL, NULL, NULL
        
END

GO
