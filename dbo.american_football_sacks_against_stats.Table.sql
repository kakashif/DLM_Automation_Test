USE [SportsDB]
GO
/****** Object:  Table [dbo].[american_football_sacks_against_stats]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[american_football_sacks_against_stats](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[sacks_against_yards] [varchar](100) NULL,
	[sacks_against_total] [varchar](100) NULL,
 CONSTRAINT [PK__american_footbal__2B3F6F97] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
