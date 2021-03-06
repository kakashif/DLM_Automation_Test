USE [SportsDB]
GO
/****** Object:  Table [dbo].[USAT_teams_ignored]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[USAT_teams_ignored](
	[team_key] [char](64) NOT NULL,
	[create_date] [date] NOT NULL,
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[active] [bit] NULL,
 CONSTRAINT [PK_USAT_teams_ignored] PRIMARY KEY CLUSTERED 
(
	[team_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
ALTER TABLE [dbo].[USAT_teams_ignored] ADD  CONSTRAINT [DF_USAT_teams_ignored_create_date]  DEFAULT (getdate()) FOR [create_date]
GO
ALTER TABLE [dbo].[USAT_teams_ignored] ADD  CONSTRAINT [DF_USAT_teams_ignored_active]  DEFAULT ((1)) FOR [active]
GO
