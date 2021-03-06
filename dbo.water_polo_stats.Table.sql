USE [SportsDB]
GO
/****** Object:  Table [dbo].[water_polo_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[water_polo_stats](
	[id] [int] NOT NULL,
	[events_played] [int] NULL,
	[sprints_won] [int] NULL,
	[sprints_total] [varchar](40) NULL,
	[technical_faults] [varchar](40) NULL,
 CONSTRAINT [PK_water_polo_stats] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
