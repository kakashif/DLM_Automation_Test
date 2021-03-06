USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetScoresByRound_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[PSA_GetScoresByRound_XML]
   @leagueName VARCHAR(100),
   @seasonKey  INT,
   @round      VARCHAR(100)
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 10/23/2014
  -- Description: get scores by round for jameson
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    EXEC dbo.PSA_GetScores_XML @leagueName, @seasonKey, NULL, NULL, NULL, NULL, @round

END


GO
