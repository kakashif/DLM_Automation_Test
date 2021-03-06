USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetScoresBySeasonKeyWeekFilter_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetScoresBySeasonKeyWeekFilter_XML]
   @seasonKey INT,
   @week VARCHAR(100),
   @filter VARCHAR(100) = NULL
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 06/10/2014
  -- Description: get scores for ncaaf for jameson
  -- Update: 10/23/2014 - John Lin - add round
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    EXEC dbo.PSA_GetScores_XML 'ncaaf', @seasonKey, NULL, @week, NULL, @filter, NULL

END

GO
