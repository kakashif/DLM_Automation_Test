USE [SportsDB]
GO
/****** Object:  UserDefinedTableType [dbo].[IdIntTable ]    Script Date: 10/28/2015 2:03:48 PM ******/
CREATE TYPE [dbo].[IdIntTable ] AS TABLE(
	[Id] [int] NOT NULL,
	PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO
