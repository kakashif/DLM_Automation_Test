USE [SportsDB]
GO
/****** Object:  Table [dbo].[USAT_lookup_teamId_SX_AP]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[USAT_lookup_teamId_SX_AP](
	[sx_id] [int] NOT NULL,
	[name] [varchar](250) NULL,
	[ap_id] [varchar](50) NULL,
	[league] [varchar](10) NOT NULL,
	[PagePath] [varchar](250) NULL,
	[Owner_Id] [bigint] NULL,
	[Team_Key] [nvarchar](50) NULL,
 CONSTRAINT [PK_USAT_lookup_teamId_SX_AP] PRIMARY KEY CLUSTERED 
(
	[sx_id] ASC,
	[league] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
ALTER TABLE [dbo].[USAT_lookup_teamId_SX_AP] ADD  CONSTRAINT [DF_lookup_teamId_SX_AP_league]  DEFAULT ('ncaab') FOR [league]
GO
