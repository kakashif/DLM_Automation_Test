USE [SportsDB]
GO
/****** Object:  Table [dbo].[USAT_Team_Names]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[USAT_Team_Names](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[Team_Name] [varchar](64) NULL,
	[Team_Nick_Name] [varchar](64) NULL,
	[Category] [varchar](64) NULL,
	[entity_id] [int] NULL,
	[SDI] [varchar](16) NULL,
	[TSN] [varchar](16) NULL,
	[team_key] [varchar](64) NULL,
 CONSTRAINT [PK_USAT_Team_Names] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
