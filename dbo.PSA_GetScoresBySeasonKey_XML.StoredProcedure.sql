USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetScoresBySeasonKey_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetScoresBySeasonKey_XML]
   @seasonKey INT
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 06/10/2014
  -- Description: get bowls scores for ncaaf for jameson
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    EXEC dbo.PSA_GetScoresBySeasonKeyWeekFilter_XML @seasonKey, 'bowls', NULL

END

GO
