USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[PSA_GetScoresByDate_XML]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[PSA_GetScoresByDate_XML]
   @leagueName VARCHAR(100),
   @year       INT,
   @month      INT,
   @day        INT
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 06/10/2014
  -- Description: get scores by date for mobile
  -- Update: 10/23/2014 - John Lin - add round
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
    
    DECLARE @start_date DATETIME = CAST(CAST(@year AS VARCHAR) + '-' + CAST(@month AS VARCHAR) + '-' + CAST(@day AS VARCHAR) AS DATETIME)

    EXEC dbo.PSA_GetScores_XML @leagueName, NULL, NULL, NULL, @start_date, NULL, NULL
   
END

GO
