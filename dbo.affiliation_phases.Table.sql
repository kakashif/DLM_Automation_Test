USE [SportsDB]
GO
/****** Object:  Table [dbo].[affiliation_phases]    Script Date: 10/28/2015 2:03:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[affiliation_phases](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[affiliation_id] [int] NOT NULL,
	[ancestor_affiliation_id] [int] NULL,
	[start_season_id] [int] NULL,
	[start_date_time] [datetime] NULL,
	[end_season_id] [int] NULL,
	[end_date_time] [datetime] NULL,
	[Root_id] [int] NULL,
 CONSTRAINT [PK__affiliation_phas__060DEAE8] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
