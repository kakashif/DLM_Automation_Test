USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[fnSplitString]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[fnSplitString](@string as VARCHAR(MAX), @delimiter varchar(20) = ' ')
RETURNS @SplitStrings TABLE (splitPiece VARCHAR(MAX))
--RETURNS VARCHAR(MAX)
AS
BEGIN
/* DEPRECATED

	DECLARE @pos INT	
	DECLARE @piece VARCHAR(500)
	
	-- Need to tack a delimiter onto the end of the input string if one doesn't exist
	IF RIGHT(RTRIM(@string),1) <> @delimiter
	 SET @string = @string  + @delimiter

	SET @pos =  PATINDEX('%'+ @delimiter +'%' , @string)
	WHILE @pos <> 0 
	BEGIN
	 SET @piece = left(@string, @pos - 1)

	-- You have a piece of data, so insert it, print it, do whatever you want to with it.
	 --print cast(@piece as varchar(500))
	INSERT INTO @SplitStrings values(cast(@piece AS VARCHAR(MAX)))
	
	 SET @string = STUFF(@string, 1, @pos, '')
	 SET @pos =  PATINDEX('%,%' , @string)
	END
*/	
	RETURN
END

GO
