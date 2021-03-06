USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[fnGetOffset]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Karthik Muthyala
-- Create date: 2012-09-01
-- Description:	Returns dates
-- Update: 11/14/2014 - John Lin - fix replication
-- =============================================
CREATE FUNCTION [dbo].[fnGetOffset] (@league VARCHAR(30), @getDate DATETIME)
RETURNS @dates TABLE (
  startDate DATETIME,
  endDate   DATETIME)
AS
BEGIN
/* DEPRECATED

    DECLARE @dow            INT,
            @leagueStartDay INT,
            @offset         INT,
            @startDate      DATETIME,
            @endDate        DATETIME;

    SET @getDate = CAST(@getDate AS DATE)
    SET @startDate = @getDate
    SET @endDate = DATEADD(second, -1, @getDate + 1)

    IF ( @league = 'l.nfl.com' )
      BEGIN
          SET @leagueStartDay = 4; --wednesday
          SET @dow = DATEPART(DW, @getDate);

          IF ( @dow < @leagueStartDay )
            BEGIN
                SET @offset = @leagueStartDay - @dow - 7
            END
          ELSE
            BEGIN
                SET @offset = @leagueStartDay - @dow
            END

          SET @startDate = DATEADD(HOUR, 11, DATEADD(DAY, @offset, @getDate));
          SET @endDate = DATEADD(HOUR, 11, DATEADD(DAY, @offset + 7, @getDate));
      END

    IF ( @league = 'l.ncaa.org.mfoot' )
      BEGIN
          SET @leagueStartDay = 3; --tuesday
          SET @dow = DATEPART(DW, @getDate);

          IF ( @dow < @leagueStartDay )
            BEGIN
                SET @offset = @leagueStartDay - @dow - 7
            END
          ELSE
            BEGIN
                SET @offset = @leagueStartDay - @dow
            END

          SET @startDate = DATEADD(HOUR, 11, DATEADD(DAY, @offset, @getDate));
          SET @endDate = DATEADD(HOUR, 11, DATEADD(DAY, @offset + 7, @getDate));
      END

    INSERT INTO @dates
                (startDate,
                 endDate)
    SELECT @startDate,
           @endDate
*/

    RETURN;
END 



GO
