USE [SportsDB]
GO
/****** Object:  Table [dbo].[baseball_defensive_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[baseball_defensive_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[double_plays] [int] NULL,
	[triple_plays] [int] NULL,
	[putouts] [int] NULL,
	[assists] [int] NULL,
	[errors] [int] NULL,
	[fielding_percentage] [float] NULL,
	[defensive_average] [float] NULL,
	[errors_passed_ball] [int] NULL,
	[errors_catchers_interference] [int] NULL,
	[stolen_bases_average] [int] NULL,
	[stolen_bases_caught] [int] NULL,
 CONSTRAINT [PK__baseball_defensi__440B1D61] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
