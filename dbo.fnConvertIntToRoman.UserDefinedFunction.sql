USE [SportsDB]
GO
/****** Object:  UserDefinedFunction [dbo].[fnConvertIntToRoman]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		John Lin
-- Create date: 12/3/12
-- Description:	Convert integer to Roman numeral
-- =============================================
CREATE FUNCTION [dbo].[fnConvertIntToRoman] (@input INT)
RETURNS VARCHAR(100)
AS
BEGIN
  RETURN REPLICATE('M', @input / 1000)
         + REPLACE(REPLACE(REPLACE(
             REPLICATE('C', (@input % 1000) / 100),
             REPLICATE('C', 9), 'CM'),
             REPLICATE('C', 5), 'D'),
             REPLICATE('C', 4), 'CD')
         + REPLACE(REPLACE(REPLACE(
             REPLICATE('X', (@input % 100) / 10),
             REPLICATE('X', 9),'XC'),
             REPLICATE('X', 5), 'L'),
             REPLICATE('X', 4), 'XL')
         + REPLACE(REPLACE(REPLACE(
             REPLICATE('I', @input % 10),
             REPLICATE('I', 9),'IX'),
             REPLICATE('I', 5), 'V'),
             REPLICATE('I', 4),'IV')

END



GO
