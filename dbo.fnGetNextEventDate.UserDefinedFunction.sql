USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[fnGetNextEventDate]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[fnGetNextEventDate] (	
	@leagueKey VARCHAR(100),
	@eventDate DATETIME
)
RETURNS DATETIME
AS
-- =============================================
-- Author:		Prashant Kamat
-- Create date: 1/22/2013
-- Description:	Return next Event Date (if present) after the input Event Date of a league 
-- =============================================
BEGIN
	DECLARE @nextEventDate DATETIME;
/* DEPREDATED

    SELECT @nextEventDate = CONVERT(DATE, MIN(ew.actual_dt))
      FROM dbo.Events_Warehouse ew WITH (NOLOCK)
     INNER JOIN dbo.affiliations la WITH (NOLOCK)
        ON la.affiliation_key = ew.league_key
     WHERE ew.league_key = @leagueKey
       AND la.publisher_id = 2
   	   AND ew.actual_dt >= @eventDate
       AND NOT EXISTS (select event_key from dbo.FnGamesToBeHidden(@leagueKey, DATEPART(YEAR, @eventDate)) where event_key = ew.event_key)
       ;
*/
	RETURN @nextEventDate; 
END

GO
