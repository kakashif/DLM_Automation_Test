USE [SportsDB]
GO
/****** Object:  Table [dbo].[standings]    Script Date: 10/28/2015 2:03:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[standings](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[affiliation_id] [int] NOT NULL,
	[standing_type] [varchar](100) NULL,
	[sub_season_id] [int] NOT NULL,
	[last_updated] [varchar](100) NULL,
	[source] [varchar](100) NULL,
 CONSTRAINT [PK__standings__17036CC0] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
