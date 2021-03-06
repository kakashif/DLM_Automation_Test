USE [SportsDB]
GO
/****** Object:  Table [dbo].[team_phases]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[team_phases](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[team_id] [int] NOT NULL,
	[start_season_id] [int] NULL,
	[end_season_id] [int] NULL,
	[affiliation_id] [int] NOT NULL,
	[start_date_time] [varchar](100) NULL,
	[end_date_time] [varchar](100) NULL,
	[phase_status] [varchar](40) NULL,
	[role_id] [int] NULL,
 CONSTRAINT [PK__team_phases__3F115E1A] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
