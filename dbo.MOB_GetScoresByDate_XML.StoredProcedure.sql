USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[MOB_GetScoresByDate_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[MOB_GetScoresByDate_XML]
   @leagueName VARCHAR(100),
   @year       INT,
   @month      INT,
   @day        INT
AS
  --=============================================
  -- Author:	  John Lin
  -- Create date: 12/03/2013
  -- Description: get schedules by date for mobile
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
    
    DECLARE @start_date DATETIME = CAST(CAST(@year AS VARCHAR) + '-' + CAST(@month AS VARCHAR) + '-' + CAST(@day AS VARCHAR) AS DATETIME)

    EXEC dbo.MOB_GetScores_XML @leagueName, NULL, NULL, NULL, @start_date, NULL
   
END

GO
