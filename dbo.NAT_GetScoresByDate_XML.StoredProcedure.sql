USE [SportsDB]
GO
/****** Object:  StoredProcedure [dbo].[NAT_GetScoresByDate_XML]    Script Date: 10/28/2015 2:03:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[NAT_GetScoresByDate_XML]
   @host       VARCHAR(100),
   @leagueName VARCHAR(100),
   @year       INT,
   @month      INT,
   @day        INT
AS
  --=============================================
  -- Author: John Lin
  -- Create date: 07/08/2014
  -- Description: get schedules by date for native
  -- Update: 08/04/2014 - John Lin - NULL for filter
  -- Update: 08/05/2014 - Johh Lin - add domain
  -- =============================================
BEGIN
    SET NOCOUNT ON
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
    
    DECLARE @start_date DATETIME = CAST(CAST(@year AS VARCHAR) + '-' + CAST(@month AS VARCHAR) + '-' + CAST(@day AS VARCHAR) AS DATETIME)

    EXEC dbo.NAT_GetScores_XML @host, @leagueName, NULL, NULL, NULL, @start_date, NULL
   
END

GO
